import Foundation
import OSLog
import Security

/// Central wipe of all Trenira-owned local user data on this device.
/// Does not revoke Apple/Google accounts and does not touch StoreKit or bundled catalogues.
@MainActor
enum LocalDataErasureService {
    enum Stage: String {
        case vaults
        case mirrors
        case backups
        case stores
        case keychain
        case auth
    }

    enum ErasureError: LocalizedError {
        case stageFailed(Stage, String)

        var errorDescription: String? {
            switch self {
            case .stageFailed(let stage, let message):
                "Couldn't erase local data (\(stage.rawValue)): \(message)"
            }
        }
    }

    /// UserDefaults keys that hold user-generated Trenira content.
    static let userContentUserDefaultsKeys: [String] = [
        "savedWorkouts",
        "savedWorkoutsDeleted",
        "weightHistory",
        "workoutWeeklyCompletions",
        "workoutPerformanceLogs",
        "activeWorkoutSession",
        "customExercises",
        "exerciseProgressionStates",
        "exerciseProgressionRules",
        "globalProgressionRule",
        "progressionConfigurations",
        "defaultProgressionConfigurationId",
        "progressionExerciseAssignments",
        "progressionCategoryDefaults",
        "progressionDimensionOverrides",
        "globalExerciseProgress",
        "userSettings",
        "developerSettings",
        "gymEquipmentProfiles.v1",
        "gymEquipmentProfiles.activeId.v1",
        "trenira.didShowFirstWorkoutBackupHint",
        "trenira.dataTombstones",
        "trenira.activeDataOwnerId",
        "trenira.detachedAccountOwnerId",
        "testingTimeSimulatedDaysOffset",
        // Auth session pointers (identities, not OAuth tokens)
        "authMode",
        "accountUserIdentifier",
        "googleEmail",
        "emailAddress",
        "emailAuthAccounts",
        ConsultationDraftStore.storageKey,
        OnboardingStore.storageKey,
    ]

    private static let logger = Logger(subsystem: "com.trenira.app", category: "LocalDataErasure")

    /// Erases all local user data and resets ownership to a fresh guest identity.
    /// Caller must sign the user out after success.
    static func eraseAllLocalData(dataCoordinator: UserDataCoordinator) throws {
        do {
            logger.info("Local erasure stage=vaults")
            try eraseVaultDirectory()
        } catch {
            logger.error("Local erasure failed stage=vaults: \(error.localizedDescription, privacy: .public)")
            throw ErasureError.stageFailed(.vaults, error.localizedDescription)
        }

        do {
            logger.info("Local erasure stage=mirrors")
            try eraseMirrorDirectory()
        } catch {
            logger.error("Local erasure failed stage=mirrors: \(error.localizedDescription, privacy: .public)")
            throw ErasureError.stageFailed(.mirrors, error.localizedDescription)
        }

        do {
            logger.info("Local erasure stage=backups")
            try eraseDebugBackupDirectory()
        } catch {
            logger.error("Local erasure failed stage=backups: \(error.localizedDescription, privacy: .public)")
            throw ErasureError.stageFailed(.backups, error.localizedDescription)
        }

        do {
            logger.info("Local erasure stage=stores")
            dataCoordinator.applyFullLocalWipeForErasure()
            clearUserDefaultsKeys()
            clearMigrationTokens()
        }

        do {
            logger.info("Local erasure stage=keychain")
            SecureAccountIdentityStore.clearAllKnownProviders()
            GuestIdentityStore.rotate()
        }

        dataCoordinator.bindToFreshGuestAfterErasure()
        logger.info("Local erasure completed")
    }

    // MARK: - File erasure

    private static func eraseVaultDirectory() throws {
        let root = try applicationSupportSubfolder("AccountDataVault")
        if FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.removeItem(at: root)
        }
        AccountDataVault.clearOwnershipPointers()
    }

    private static func eraseMirrorDirectory() throws {
        let root = try applicationSupportSubfolder("RemoteUserDataMirror")
        if FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.removeItem(at: root)
        }
    }

    private static func eraseDebugBackupDirectory() throws {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let folder = docs.appendingPathComponent("treniraDebugBackups", isDirectory: true)
        if FileManager.default.fileExists(atPath: folder.path) {
            try FileManager.default.removeItem(at: folder)
        }
    }

    private static func applicationSupportSubfolder(_ name: String) throws -> URL {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return root.appendingPathComponent(name, isDirectory: true)
    }

    private static func clearUserDefaultsKeys() {
        let defaults = UserDefaults.standard
        for key in userContentUserDefaultsKeys {
            defaults.removeObject(forKey: key)
        }
        // Migration completion flags
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("trenira.migrationDone.") {
            defaults.removeObject(forKey: key)
        }
    }

    private static func clearMigrationTokens() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("trenira.migrationDone.") {
            defaults.removeObject(forKey: key)
        }
    }
}
