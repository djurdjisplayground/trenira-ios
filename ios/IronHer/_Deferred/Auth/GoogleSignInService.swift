import GoogleSignIn
import UIKit

enum GoogleSignInService {
    static var isConfigured: Bool {
        guard let clientID = clientID else { return false }
        return !clientID.isEmpty && !clientID.contains("REPLACE_WITH")
    }

    private static var clientID: String? {
        Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String
    }

    static func configureIfNeeded() {
        guard let clientID, isConfigured else { return }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
    }

    static func signIn() async throws -> GIDGoogleUser {
        guard isConfigured else {
            throw GoogleSignInError.notConfigured
        }

        configureIfNeeded()

        guard let presenter = UIApplication.shared.topViewController else {
            throw GoogleSignInError.noPresenter
        }

        return try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(withPresenting: presenter) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let user = result?.user else {
                    continuation.resume(throwing: GoogleSignInError.missingUser)
                    return
                }

                continuation.resume(returning: user)
            }
        }
    }
}

enum GoogleSignInError: LocalizedError {
    case notConfigured
    case noPresenter
    case missingUser

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Google Sign-In isn't configured yet. Add your GIDClientID to Info.plist."
        case .noPresenter:
            "Couldn't present Google Sign-In. Please try again."
        case .missingUser:
            "Google Sign-In didn't return a user profile."
        }
    }
}

private extension UIApplication {
    var topViewController: UIViewController? {
        let scenes = connectedScenes
        let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
            ?? scenes.compactMap { $0 as? UIWindowScene }.first

        guard let root = windowScene?.windows.first(where: \.isKeyWindow)?.rootViewController
            ?? windowScene?.windows.first?.rootViewController else {
            return nil
        }

        return root.topMostViewController
    }
}

private extension UIViewController {
    var topMostViewController: UIViewController {
        if let presented = presentedViewController {
            return presented.topMostViewController
        }
        if let navigation = self as? UINavigationController, let visible = navigation.visibleViewController {
            return visible.topMostViewController
        }
        if let tab = self as? UITabBarController, let selected = tab.selectedViewController {
            return selected.topMostViewController
        }
        return self
    }
}
