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

    private let accountUserDefaultsKey = "accountUserIdentifier"
    private let authModeDefaultsKey = "authMode"
    private let googleEmailDefaultsKey = "googleEmail"
    private let emailAddressDefaultsKey = "emailAddress"
    private var authTimeoutTask: Task<Void, Never>?

    /// Fired after auth settles (guest continue, provider sign-in, sign-out). Used for data migration.
    var onAuthStateSettled: ((AuthState) -> Void)?

    /// Must be retained until Apple calls the delegate methods.
    private var appleAuthorizationController: ASAuthorizationController?

    private let logger = Logger(subsystem: "com.ironher.app", category: "Auth")

    var canAccessApp: Bool { authState.isSignedIn }

    override init() {
        super.init()
        restoreSavedState()
    }

    func signInWithApple() {
        guard !isAuthenticating else { return }

        isAuthenticating = true
        errorMessage = nil
        statusMessage = "Waiting for Apple…"
        logger.info("Starting Sign in with Apple")

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

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

    func signInWithEmail(email: String, password: String) {
        guard !isAuthenticating else { return }

        isAuthenticating = true
        errorMessage = nil
        statusMessage = "Signing in…"

        defer { isAuthenticating = false }

        do {
            let account = try EmailAuthService.signIn(email: email, password: password)
            authState = .email(userId: account.userId, email: account.email)
            statusMessage = "Signed in with Email"
            persistState()
            onAuthStateSettled?(.email(userId: account.userId, email: account.email))
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            statusMessage = "Sign in failed"
        }
    }

    func createAccountWithEmail(email: String, password: String) {
        guard !isAuthenticating else { return }

        isAuthenticating = true
        errorMessage = nil
        statusMessage = "Creating account…"

        defer { isAuthenticating = false }

        do {
            let account = try EmailAuthService.createAccount(email: email, password: password)
            authState = .email(userId: account.userId, email: account.email)
            statusMessage = "Account created"
            persistState()
            onAuthStateSettled?(.email(userId: account.userId, email: account.email))
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            statusMessage = "Sign up failed"
        }
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
        case .email:
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

    private func performSignOut() {
        authTimeoutTask?.cancel()
        appleAuthorizationController = nil
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
            let userId = SecureAccountIdentityStore.load(provider: "apple")
                ?? UserDefaults.standard.string(forKey: accountUserDefaultsKey)
            if let userId {
                authState = .apple(userId: userId)
                statusMessage = "Welcome back"
            }
        case "google":
            let userId = SecureAccountIdentityStore.load(provider: "google")
                ?? UserDefaults.standard.string(forKey: accountUserDefaultsKey)
            if let userId {
                let email = UserDefaults.standard.string(forKey: googleEmailDefaultsKey)
                authState = .google(userId: userId, email: email)
                statusMessage = "Welcome back"
            }
        case "email":
            let userId = SecureAccountIdentityStore.load(provider: "email")
                ?? UserDefaults.standard.string(forKey: accountUserDefaultsKey)
            if let userId,
               let email = UserDefaults.standard.string(forKey: emailAddressDefaultsKey) {
                authState = .email(userId: userId, email: email)
                statusMessage = "Welcome back"
            }
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

            logger.info("Apple sign-in succeeded for user \(credential.user, privacy: .private)")
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

        let userId = user.userID ?? UUID().uuidString
        let email = user.profile?.email

        authState = .google(userId: userId, email: email)
        errorMessage = nil
        statusMessage = "Signed in with Google"
        persistState()
        onAuthStateSettled?(.google(userId: userId, email: email))
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
            UserDefaults.standard.removeObject(forKey: accountUserDefaultsKey)
            UserDefaults.standard.removeObject(forKey: googleEmailDefaultsKey)
            UserDefaults.standard.removeObject(forKey: emailAddressDefaultsKey)
            SecureAccountIdentityStore.clearAllKnownProviders()
        case .apple(let userId):
            UserDefaults.standard.set("apple", forKey: authModeDefaultsKey)
            // Legacy key kept for migration; primary identity lives in Keychain.
            UserDefaults.standard.set(userId, forKey: accountUserDefaultsKey)
            SecureAccountIdentityStore.save(provider: "apple", userID: userId)
            UserDefaults.standard.removeObject(forKey: googleEmailDefaultsKey)
            UserDefaults.standard.removeObject(forKey: emailAddressDefaultsKey)
        case .google(let userId, let email):
            UserDefaults.standard.set("google", forKey: authModeDefaultsKey)
            UserDefaults.standard.set(userId, forKey: accountUserDefaultsKey)
            SecureAccountIdentityStore.save(provider: "google", userID: userId)
            UserDefaults.standard.removeObject(forKey: emailAddressDefaultsKey)
            if let email {
                UserDefaults.standard.set(email, forKey: googleEmailDefaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: googleEmailDefaultsKey)
            }
        case .email(let userId, let email):
            UserDefaults.standard.set("email", forKey: authModeDefaultsKey)
            UserDefaults.standard.set(userId, forKey: accountUserDefaultsKey)
            SecureAccountIdentityStore.save(provider: "email", userID: userId)
            UserDefaults.standard.set(email, forKey: emailAddressDefaultsKey)
            UserDefaults.standard.removeObject(forKey: googleEmailDefaultsKey)
        }
    }

    private func clearPersistedState() {
        UserDefaults.standard.removeObject(forKey: authModeDefaultsKey)
        UserDefaults.standard.removeObject(forKey: accountUserDefaultsKey)
        UserDefaults.standard.removeObject(forKey: googleEmailDefaultsKey)
        UserDefaults.standard.removeObject(forKey: emailAddressDefaultsKey)
        SecureAccountIdentityStore.clearAllKnownProviders()
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
