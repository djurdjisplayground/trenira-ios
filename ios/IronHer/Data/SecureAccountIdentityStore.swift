import Foundation
import Security

/// Stores the authenticated provider user ID in Keychain (not an OAuth token — those stay with Apple/Google SDKs).
enum SecureAccountIdentityStore {
    private static let service = "com.trenira.app.account-identity"

    /// Device-only, available only while the device is unlocked.
    private static let accessibility = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

    static func save(provider: String, userID: String) {
        let account = "\(provider).userID"
        let data = Data(userID.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = accessibility
        SecItemAdd(add as CFDictionary, nil)
    }

    /// Loads the provider user ID and rewrites it with the current accessibility class when found.
    static func load(provider: String) -> String? {
        let account = "\(provider).userID"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let string = String(data: data, encoding: .utf8),
              !string.isEmpty else {
            return nil
        }
        // Migrate older AfterFirstUnlock items to WhenUnlockedThisDeviceOnly after a successful read.
        save(provider: provider, userID: string)
        return string
    }

    static func clear(provider: String) {
        let account = "\(provider).userID"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func clearAllKnownProviders() {
        ["apple", "google", "email"].forEach(clear)
    }
}
