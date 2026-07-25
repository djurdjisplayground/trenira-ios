import Foundation

/// Soft-deletion marker that syncs so remote records do not reappear.
struct DataTombstone: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var entityType: String
    var deletedAt: Date
    var ownerId: String

    init(id: UUID, entityType: String, ownerId: String, deletedAt: Date = .now) {
        self.id = id
        self.entityType = entityType
        self.ownerId = ownerId
        self.deletedAt = deletedAt
    }
}

/// Portable snapshot of all syncable user content for one owner.
struct UserDataSnapshot: Codable, Sendable {
    var schemaVersion: Int
    var ownerId: String
    var updatedAt: Date
    var workouts: [Workout]
    var weightHistory: [WeightHistoryEntry]
    var weeklyCompletions: [WorkoutWeeklyCompletion]
    var performanceLogs: [LoggedWorkoutPerformance]
    var customExercises: [Exercise]
    var tombstones: [DataTombstone]
    /// Opaque JSON bags for progression / settings that already encode as Data in stores.
    var progressionBlob: Data?
    var globalProgressBlob: Data?
    var userSettingsBlob: Data?

    static let currentSchemaVersion = 1

    static func empty(ownerId: String) -> UserDataSnapshot {
        UserDataSnapshot(
            schemaVersion: currentSchemaVersion,
            ownerId: ownerId,
            updatedAt: .now,
            workouts: [],
            weightHistory: [],
            weeklyCompletions: [],
            performanceLogs: [],
            customExercises: [],
            tombstones: [],
            progressionBlob: nil,
            globalProgressBlob: nil,
            userSettingsBlob: nil
        )
    }

    var isEffectivelyEmpty: Bool {
        workouts.filter { $0.deletedAt == nil }.isEmpty
            && weightHistory.isEmpty
            && weeklyCompletions.isEmpty
            && performanceLogs.isEmpty
            && customExercises.isEmpty
    }
}

enum SyncStatus: Equatable, Sendable {
    case localOnly
    case backingUp
    case synced(Date)
    case failed(String)

    var settingsLabel: String {
        switch self {
        case .localOnly:
            "Stored on this device"
        case .backingUp:
            "Backing up…"
        case .synced:
            "Synced"
        case .failed:
            "Sync failed — tap to retry"
        }
    }
}
