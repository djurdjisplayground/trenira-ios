import Foundation

enum AuthState: Equatable {
    case signedOut
    case guest
    case apple(userId: String)
    case google(userId: String, email: String?)
    case email(userId: String, email: String)

    var isSignedIn: Bool {
        switch self {
        case .signedOut:
            false
        case .guest, .apple, .google, .email:
            true
        }
    }

    var isGuest: Bool {
        if case .guest = self { return true }
        return false
    }

    var displayName: String {
        switch self {
        case .signedOut:
            "Signed out"
        case .guest:
            "Guest"
        case .apple:
            "Apple account"
        case .google(_, let email):
            email ?? "Google account"
        case .email(_, let email):
            email
        }
    }
}
