import Foundation
import Security

/// Creates and persists a stable per-install guest identifier in the Keychain.
enum GuestIdentityStore {
    private static let service = "com.trenira.app.guest-identity"
    private static let account = "localGuestID"
    private static let accessibility = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

    /// Returns the existing guest UUID or creates one. Never stored in UserDefaults.
    /// Existing values are preserved and rewritten with the current Keychain accessibility class.
    static func localGuestID() -> String {
        if let existing = read() {
            // Migrate older accessibility class without rotating identity.
            save(existing)
            return existing
        }
        let created = UUID().uuidString
        save(created)
        return created
    }

    static func peek() -> String? {
        read()
    }

    /// Rotates the guest identity after a guest data wipe so old vaults cannot return.
    static func rotate() {
        let created = UUID().uuidString
        save(created)
    }

    private static func read() -> String? {
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
        return string
    }

    private static func save(_ value: String) {
        let data = Data(value.utf8)
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
}
