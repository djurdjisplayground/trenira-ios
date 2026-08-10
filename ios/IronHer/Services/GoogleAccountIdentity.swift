import Foundation

/// Resolves the stable Google user identifier used for local vault ownership.
enum GoogleAccountIdentity {
    /// Returns a non-empty Google user ID, or `nil` when sign-in is incomplete.
    /// Never invents a random local identity.
    static func stableUserID(from raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
