import Foundation

/// Stable ownership key for all user-created trenira records.
/// StoreKit / Premium entitlements are intentionally excluded from this model.
struct DataOwnerID: Hashable, Codable, Sendable, RawRepresentable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    static func guest(_ localGuestID: String) -> DataOwnerID {
        DataOwnerID(rawValue: "guest:\(localGuestID)")
    }

    static func account(provider: String, userID: String) -> DataOwnerID {
        DataOwnerID(rawValue: "account:\(provider):\(userID)")
    }

    var isGuest: Bool { rawValue.hasPrefix("guest:") }

    var isAccount: Bool { rawValue.hasPrefix("account:") }

    var displayLabel: String {
        if isGuest { return "This device (guest)" }
        if rawValue.hasPrefix("account:apple:") { return "Apple account" }
        if rawValue.hasPrefix("account:google:") { return "Google account" }
        if rawValue.hasPrefix("account:email:") { return "Email account" }
        return "Account"
    }
}

extension AuthState {
    /// Maps auth to a data owner. Guest uses the Keychain guest id supplied by the caller.
    func dataOwnerID(guestID: String) -> DataOwnerID? {
        switch self {
        case .signedOut:
            return nil
        case .guest:
            return .guest(guestID)
        case .apple(let userId):
            return .account(provider: "apple", userID: userId)
        case .google(let userId):
            return .account(provider: "google", userID: userId)
        }
    }
}
