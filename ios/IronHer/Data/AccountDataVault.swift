import Foundation

/// Per-account local cache so sign-out never deletes workouts and accounts stay separated.
enum AccountDataVault {
    private static let folderName = "AccountDataVault"
    private static let activeOwnerKey = "trenira.activeDataOwnerId"
    private static let detachedOwnerKey = "trenira.detachedAccountOwnerId"
    private static let migrationTokenPrefix = "trenira.migrationDone."

    static var activeOwnerId: String? {
        get { UserDefaults.standard.string(forKey: activeOwnerKey) }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: activeOwnerKey)
            } else {
                UserDefaults.standard.removeObject(forKey: activeOwnerKey)
            }
        }
    }

    /// After sign-out, data on screen still belongs to this account and must not merge into a different login.
    static var detachedAccountOwnerId: String? {
        get { UserDefaults.standard.string(forKey: detachedOwnerKey) }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: detachedOwnerKey)
            } else {
                UserDefaults.standard.removeObject(forKey: detachedOwnerKey)
            }
        }
    }

    static func save(_ snapshot: UserDataSnapshot) throws {
        let url = try fileURL(for: snapshot.ownerId)
        let data = try JSONEncoder().encode(snapshot)
        try ProtectedFileWriter.writeAtomically(data, to: url)
    }

    static func load(ownerId: String) -> UserDataSnapshot? {
        guard let url = try? fileURL(for: ownerId) else { return nil }
        ProtectedFileWriter.ensureProtectionIfPresent(at: url)
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(UserDataSnapshot.self, from: data) else {
            return nil
        }
        return decoded
    }

    static func hasCompletedMigration(from guestOwnerId: String, to accountOwnerId: String) -> Bool {
        UserDefaults.standard.bool(forKey: migrationKey(from: guestOwnerId, to: accountOwnerId))
    }

    static func markMigrationCompleted(from guestOwnerId: String, to accountOwnerId: String) {
        UserDefaults.standard.set(true, forKey: migrationKey(from: guestOwnerId, to: accountOwnerId))
    }

    static func delete(ownerId: String) {
        guard let url = try? fileURL(for: ownerId) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func clearOwnershipPointers() {
        activeOwnerId = nil
        detachedAccountOwnerId = nil
    }

    private static func migrationKey(from guestOwnerId: String, to accountOwnerId: String) -> String {
        migrationTokenPrefix + guestOwnerId + "->" + accountOwnerId
    }

    private static func fileURL(for ownerId: String) throws -> URL {
        let safe = ownerId
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "/", with: "_")
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return root
            .appendingPathComponent(folderName, isDirectory: true)
            .appendingPathComponent("\(safe).json", isDirectory: false)
    }
}
