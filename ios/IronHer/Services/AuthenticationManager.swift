import AuthenticationServices
import GoogleSignIn
import OSLog
import SwiftUI
import UIKit

@Observable
@MainActor
final class AuthenticationManager: NSObject {
    private(set) var authState: AuthState = .signedOut
    private(set) var isAuthenticating = false
    var errorMessage: String?
    var statusMessage = "Choose how you'd like to continue"

    private let authModeDefaultsKey = "authMode"
    private var authTimeoutTask: Task<Void, Never>?

    /// Fired after auth settles (guest continue, provider sign-in, sign-out). Used for data migration.
    var onAuthStateSettled: ((AuthState) -> Void)?

    /// Must be retained until Apple calls the delegate methods.
    private var appleAuthorizationController: ASAuthorizationController?

    private let logger = Logger(subsystem: "com.trenira.app", category: "Auth")

    var canAccessApp: Bool { authState.isSignedIn }

    override init() {
        super.init()
        AuthDataMinimizationMigration.runIfNeeded()
        restoreSavedState()
    }

    func signInWithApple() {
        guard !isAuthenticating else { return }

        isAuthenticating = true
        errorMessage = nil
        statusMessage = "Waiting for Apple…"
        logger.info("Starting Sign in with Apple")

        let request = AppleSignInRequestFactory.makeRequest()
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        appleAuthorizationController = controller
        controller.performRequests()

        startAuthTimeout()
    }

    func signInWithGoogle() {
        guard !isAuthenticating else { return }

        guard GoogleSignInService.isConfigured else {
            errorMessage = GoogleSignInError.notConfigured.errorDescription
            statusMessage = "Google sign-in not configured"
            return
        }

        isAuthenticating = true
        errorMessage = nil
        statusMessage = "Waiting for Google…"

        Task {
            do {
                let user = try await GoogleSignInService.signIn()
                completeGoogleSignIn(user: user)
            } catch {
                completeGoogleSignInFailure(error)
            }
        }

        startAuthTimeout()
    }

    func continueAsGuest() {
        authTimeoutTask?.cancel()
        appleAuthorizationController = nil
        isAuthenticating = false
        errorMessage = nil
        authState = .guest
        statusMessage = "Continuing without an account"
        persistState()
        onAuthStateSettled?(.guest)
    }

    func restoreSessionIfNeeded() async {
        switch authState {
        case .signedOut, .guest:
            return
        case .apple(let userId):
            await restoreAppleSession(userId: userId)
        case .google:
            return
        }
    }

    /// Prefer calling through UserDataCoordinator so workouts are never wiped.
    func signOut(preparing dataCoordinator: UserDataCoordinator? = nil) {
        Task { @MainActor in
            await dataCoordinator?.prepareForSignOut()
            performSignOut()
        }
    }

    func signOut() {
        signOut(preparing: nil)
    }

    // MARK: - Local data erasure

    enum LocalDataErasureAuthError: LocalizedError {
        case notSignedIn
        case erasureFailed(String)

        var errorDescription: String? {
            switch self {
            case .notSignedIn:
                "You're not signed in."
            case .erasureFailed(let message):
                message
            }
        }
    }

    /// Erases all Trenira local data on this device, then signs out.
    /// Does not delete the user's Apple ID or Google account.
    func eraseAllLocalData(dataCoordinator: UserDataCoordinator) async throws {
        let logger = Logger(subsystem: "com.trenira.app", category: "LocalDataErasure")
        guard authState.isSignedIn else {
            throw LocalDataErasureAuthError.notSignedIn
        }

        do {
            logger.info("Local erasure requested provider=\(self.authProviderLabel(self.authState), privacy: .public)")
            try LocalDataErasureService.eraseAllLocalData(dataCoordinator: dataCoordinator)
        } catch {
            logger.error("Local erasure failed: \(error.localizedDescription, privacy: .public)")
            throw LocalDataErasureAuthError.erasureFailed(
                (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            )
        }

        performSignOut()
        statusMessage = "Local data erased."
        logger.info("Local erasure finished and session cleared")
    }

    /// Legacy name — routes to local erasure. Does not delete Apple/Google accounts.
    func deleteAccount(dataCoordinator: UserDataCoordinator) async throws {
        try await eraseAllLocalData(dataCoordinator: dataCoordinator)
    }

    private func authProviderLabel(_ state: AuthState) -> String {
        switch state {
        case .signedOut: return "signedOut"
        case .guest: return "guest"
        case .apple: return "apple"
        case .google: return "google"
        }
    }

    private func performSignOut() {
        authTimeoutTask?.cancel()
        appleAuthorizationController = nil
        // End provider SDK session without touching workout UserDefaults / vaults.
        GoogleSignInService.signOut()
        authState = .signedOut
        isAuthenticating = false
        errorMessage = nil
        statusMessage = "Choose how you'd like to continue"
        clearPersistedState()
        onAuthStateSettled?(.signedOut)
    }

    private func restoreSavedState() {
        guard let mode = UserDefaults.standard.string(forKey: authModeDefaultsKey) else {
            authState = .signedOut
            return
        }

        switch mode {
        case "guest":
            authState = .guest
            statusMessage = "Continuing without an account"
        case "apple":
            if let userId = SecureAccountIdentityStore.load(provider: "apple") {
                authState = .apple(userId: userId)
                statusMessage = "Welcome back"
            } else {
                clearPersistedState()
                authState = .signedOut
            }
        case "google":
            if let userId = SecureAccountIdentityStore.load(provider: "google") {
                authState = .google(userId: userId)
                statusMessage = "Welcome back"
            } else {
                clearPersistedState()
                authState = .signedOut
            }
        case "email":
            // Email/password auth was removed for TestFlight. Force welcome screen.
            clearLegacyEmailAuthArtifacts()
            authState = .signedOut
            statusMessage = "Choose how you'd like to continue"
        default:
            break
        }
    }

    private func restoreAppleSession(userId: String) async {
        statusMessage = "Checking existing sign-in…"
        let provider = ASAuthorizationAppleIDProvider()

        do {
            let state = try await provider.credentialState(forUserID: userId)
            switch state {
            case .authorized:
                authState = .apple(userId: userId)
                statusMessage = "Welcome back"
            case .revoked, .notFound:
                signOut()
                statusMessage = "Session expired. Please sign in again."
            case .transferred:
                statusMessage = "Sign in to continue"
            @unknown default:
                statusMessage = "Choose how you'd like to continue"
            }
        } catch {
            signOut()
        }
    }

    private func finishAppleSignInFlow() {
        authTimeoutTask?.cancel()
        appleAuthorizationController = nil
        isAuthenticating = false
    }

    private func completeAppleSignIn(with result: Result<ASAuthorization, Error>) {
        finishAppleSignInFlow()

        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                logger.error("Apple credential type was unexpected")
                errorMessage = "Apple returned an unexpected credential type."
                statusMessage = "Sign in failed"
                return
            }

            // Only the stable Apple user identifier is used for local vault ownership.
            // Name, email, identity token, and authorization code are never read or stored.
            logger.info("Apple sign-in succeeded")
            authState = .apple(userId: credential.user)
            errorMessage = nil
            statusMessage = "Signed in with Apple"
            persistState()
            onAuthStateSettled?(.apple(userId: credential.user))

        case .failure(let error):
            logger.error("Apple sign-in failed: \(error.localizedDescription, privacy: .public)")
            handleSignInFailure(error)
        }
    }

    private func completeGoogleSignIn(user: GIDGoogleUser) {
        authTimeoutTask?.cancel()
        isAuthenticating = false

        guard let userId = GoogleAccountIdentity.stableUserID(from: user.userID) else {
            logger.error("Google sign-in incomplete: missing stable user identifier")
            GoogleSignInService.signOut()
            errorMessage = GoogleSignInError.incompleteIdentity.errorDescription
            statusMessage = "Sign in failed"
            return
        }

        // Profile email / name / photo / tokens are intentionally not read.
        authState = .google(userId: userId)
        errorMessage = nil
        statusMessage = "Signed in with Google"
        persistState()
        onAuthStateSettled?(.google(userId: userId))
    }

    private func completeGoogleSignInFailure(_ error: Error) {
        authTimeoutTask?.cancel()
        isAuthenticating = false

        let nsError = error as NSError
        if nsError.domain == "com.google.GIDSignIn" && nsError.code == -5 {
            statusMessage = "Google sign-in canceled"
            return
        }

        errorMessage = error.localizedDescription
        statusMessage = "Sign in failed"
    }

    private func handleSignInFailure(_ error: Error) {
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            statusMessage = "Sign in canceled"
            return
        }

        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .notHandled:
                errorMessage = """
                Sign in with Apple isn't set up for this app. In Xcode, select the app target, \
                open Signing & Capabilities, choose your Development Team, and ensure \
                "Sign in with Apple" is enabled.
                """
            case .failed:
                errorMessage = "Apple sign-in failed. On the Simulator, open Settings → Apple Account and sign in first."
            case .invalidResponse:
                errorMessage = "Apple returned an invalid response. Please try again."
            case .unknown:
                errorMessage = "An unknown sign-in error occurred. Please try again."
            default:
                errorMessage = authError.localizedDescription
            }
        } else {
            errorMessage = error.localizedDescription
        }

        statusMessage = "Sign in failed"
    }

    private func persistState() {
        switch authState {
        case .signedOut:
            clearPersistedState()
        case .guest:
            UserDefaults.standard.set("guest", forKey: authModeDefaultsKey)
            SecureAccountIdentityStore.clearAllKnownProviders()
            removeObsoleteAuthUserDefaultsKeys()
        case .apple(let userId):
            // Non-sensitive mode flag only. Raw provider ID lives in Keychain.
            UserDefaults.standard.set("apple", forKey: authModeDefaultsKey)
            SecureAccountIdentityStore.save(provider: "apple", userID: userId)
            removeObsoleteAuthUserDefaultsKeys()
        case .google(let userId):
            UserDefaults.standard.set("google", forKey: authModeDefaultsKey)
            SecureAccountIdentityStore.save(provider: "google", userID: userId)
            removeObsoleteAuthUserDefaultsKeys()
        }
    }

    private func clearPersistedState() {
        UserDefaults.standard.removeObject(forKey: authModeDefaultsKey)
        removeObsoleteAuthUserDefaultsKeys()
        clearLegacyEmailAuthArtifacts()
        SecureAccountIdentityStore.clearAllKnownProviders()
    }

    /// Clears leftovers from removed email/password auth and prior googleEmail storage.
    private func clearLegacyEmailAuthArtifacts() {
        removeObsoleteAuthUserDefaultsKeys()
        SecureAccountIdentityStore.clear(provider: "email")
        if UserDefaults.standard.string(forKey: authModeDefaultsKey) == "email" {
            UserDefaults.standard.removeObject(forKey: authModeDefaultsKey)
        }
    }

    private func removeObsoleteAuthUserDefaultsKeys() {
        for key in AuthDataMinimizationMigration.obsoleteUserDefaultsKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func startAuthTimeout() {
        authTimeoutTask?.cancel()
        authTimeoutTask = Task {
            try? await Task.sleep(for: .seconds(45))
            guard !Task.isCancelled, isAuthenticating else { return }

            logger.error("Apple sign-in timed out")
            finishAppleSignInFlow()
            errorMessage = "Sign in timed out. Tap a button to try again."
            statusMessage = "Sign in timed out"
        }
    }
}

extension AuthenticationManager: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            completeAppleSignIn(with: .success(authorization))
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            completeAppleSignIn(with: .failure(error))
        }
    }
}

extension AuthenticationManager: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Apple may invoke this off the main thread. `MainActor.assumeIsolated` aborts when that happens.
        if Thread.isMainThread {
            return Self.resolvePresentationAnchor()
        }
        return DispatchQueue.main.sync {
            Self.resolvePresentationAnchor()
        }
    }

    nonisolated private static func resolvePresentationAnchor() -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
            ?? scenes.compactMap { $0 as? UIWindowScene }.first
        if let window = windowScene?.windows.first(where: \.isKeyWindow)
            ?? windowScene?.windows.first {
            return window
        }
        return ASPresentationAnchor()
    }
}
