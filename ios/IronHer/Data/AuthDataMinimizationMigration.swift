import Foundation

/// One-time cleanup that removes obsolete authentication email fields and the
/// UserDefaults duplicate of the provider user identifier after promoting it to Keychain.
///
/// Identifier: `authDataMinimization_v1`
/// Does not touch workout vaults, mirrors, or guest identity.
enum AuthDataMinimizationMigration {
    static let identifier = "authDataMinimization_v1"
    static let completionKey = "trenira.migrationDone.authDataMinimization_v1"

    /// Keys that are no longer written by active auth code and are safe to remove.
    static let obsoleteUserDefaultsKeys: [String] = [
        "googleEmail",
        "emailAddress",
        "emailAuthAccounts",
        "accountUserIdentifier",
    ]

    struct Report: Equatable {
        var alreadyCompleted: Bool = false
        var migratedProviders: [String] = []
        var removedKeys: [String] = []
    }

    /// Idempotent: second call after completion performs no work.
    @discardableResult
    static func runIfNeeded(defaults: UserDefaults = .standard) -> Report {
        if defaults.bool(forKey: completionKey) {
            return Report(alreadyCompleted: true)
        }

        var report = Report()

        // Preserve vault ownership: copy legacy UserDefaults provider ID into Keychain first.
        if let mode = defaults.string(forKey: "authMode"),
           mode == "apple" || mode == "google" {
            if SecureAccountIdentityStore.load(provider: mode) == nil,
               let userID = defaults.string(forKey: "accountUserIdentifier"),
               !userID.isEmpty {
                SecureAccountIdentityStore.save(provider: mode, userID: userID)
                report.migratedProviders.append(mode)
            }
        }

        for key in obsoleteUserDefaultsKeys {
            if defaults.object(forKey: key) != nil {
                defaults.removeObject(forKey: key)
                report.removedKeys.append(key)
            }
        }

        defaults.set(true, forKey: completionKey)
        return report
    }

    #if DEBUG
    static func resetCompletionFlagForTests(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: completionKey)
    }
    #endif
}
