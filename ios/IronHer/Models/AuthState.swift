import Foundation

enum AuthState: Equatable {
    case signedOut
    case guest
    case apple(userId: String)
    case google(userId: String)

    var isSignedIn: Bool {
        switch self {
        case .signedOut:
            false
        case .guest, .apple, .google:
            true
        }
    }

    var isGuest: Bool {
        if case .guest = self { return true }
        return false
    }

    /// Neutral signed-in label for Settings. Never includes email or profile names.
    var displayName: String {
        switch self {
        case .signedOut:
            "Signed out"
        case .guest:
            "Guest"
        case .apple:
            "Signed in with Apple"
        case .google:
            "Signed in with Google"
        }
    }
}
