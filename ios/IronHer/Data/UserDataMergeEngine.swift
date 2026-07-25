import Foundation

/// Idempotent, conflict-safe merge of two snapshots for the same logical account.
enum UserDataMergeEngine {
    struct Result: Sendable {
        var snapshot: UserDataSnapshot
        var conflictFlags: [String]
    }

    /// Never replaces a populated side with an empty side.
    static func merge(local: UserDataSnapshot, remote: UserDataSnapshot, resultingOwnerId: String) -> Result {
        if local.isEffectivelyEmpty && !remote.isEffectivelyEmpty {
            return Result(snapshot: transferOwnership(remote, to: resultingOwnerId), conflictFlags: [])
        }
        if remote.isEffectivelyEmpty && !local.isEffectivelyEmpty {
            return Result(snapshot: transferOwnership(local, to: resultingOwnerId), conflictFlags: [])
        }
        if local.isEffectivelyEmpty && remote.isEffectivelyEmpty {
            return Result(snapshot: .empty(ownerId: resultingOwnerId), conflictFlags: [])
        }

        var conflicts: [String] = []

        let tombstones = mergeTombstones(local.tombstones, remote.tombstones)
        let deletedIDs = Set(tombstones.map(\.id))

        let workouts = mergeByUUID(
            local: local.workouts.filter { !deletedIDs.contains($0.id) && $0.deletedAt == nil },
            remote: remote.workouts.filter { !deletedIDs.contains($0.id) && $0.deletedAt == nil },
            updatedAt: { $0.updatedAt },
            assignOwner: { workout, owner in
                var copy = workout
                copy.ownerId = owner
                copy.deletedAt = nil
                return copy
            },
            resultingOwnerId: resultingOwnerId,
            conflicts: &conflicts,
            entityName: "workout"
        )

        let history = mergeByUUID(
            local: local.weightHistory.filter { !deletedIDs.contains($0.id) },
            remote: remote.weightHistory.filter { !deletedIDs.contains($0.id) },
            updatedAt: { $0.date },
            assignOwner: { entry, owner in
                var copy = entry
                copy.ownerId = owner
                return copy
            },
            resultingOwnerId: resultingOwnerId,
            conflicts: &conflicts,
            entityName: "weightHistory"
        )

        let weekly = mergeByUUID(
            local: local.weeklyCompletions.filter { !deletedIDs.contains($0.id) },
            remote: remote.weeklyCompletions.filter { !deletedIDs.contains($0.id) },
            updatedAt: { $0.completedAt },
            assignOwner: { entry, owner in
                var copy = entry
                copy.ownerId = owner
                return copy
            },
            resultingOwnerId: resultingOwnerId,
            conflicts: &conflicts,
            entityName: "weeklyCompletion"
        )

        let logs = mergeByUUID(
            local: local.performanceLogs.filter { !deletedIDs.contains($0.id) },
            remote: remote.performanceLogs.filter { !deletedIDs.contains($0.id) },
            updatedAt: { $0.completedAt },
            assignOwner: { entry, owner in
                var copy = entry
                copy.ownerId = owner
                return copy
            },
            resultingOwnerId: resultingOwnerId,
            conflicts: &conflicts,
            entityName: "performanceLog"
        )

        let customs = mergeByStringID(
            local: local.customExercises,
            remote: remote.customExercises,
            assignOwner: { exercise, owner in
                var copy = exercise
                copy.ownerId = owner
                return copy
            },
            resultingOwnerId: resultingOwnerId
        )

        let preferLocalBlobs = local.updatedAt >= remote.updatedAt
        let snapshot = UserDataSnapshot(
            schemaVersion: UserDataSnapshot.currentSchemaVersion,
            ownerId: resultingOwnerId,
            updatedAt: max(local.updatedAt, remote.updatedAt),
            workouts: workouts.sorted { $0.updatedAt > $1.updatedAt },
            weightHistory: history.sorted { $0.date < $1.date },
            weeklyCompletions: weekly.sorted { $0.completedAt > $1.completedAt },
            performanceLogs: logs.sorted { $0.completedAt > $1.completedAt },
            customExercises: customs,
            tombstones: tombstones,
            progressionBlob: preferLocalBlobs
                ? (local.progressionBlob ?? remote.progressionBlob)
                : (remote.progressionBlob ?? local.progressionBlob),
            globalProgressBlob: preferLocalBlobs
                ? (local.globalProgressBlob ?? remote.globalProgressBlob)
                : (remote.globalProgressBlob ?? local.globalProgressBlob),
            userSettingsBlob: preferLocalBlobs
                ? (local.userSettingsBlob ?? remote.userSettingsBlob)
                : (remote.userSettingsBlob ?? local.userSettingsBlob)
        )

        return Result(snapshot: snapshot, conflictFlags: conflicts)
    }

    /// Reassigns ownership of every record without dropping any.
    static func transferOwnership(_ snapshot: UserDataSnapshot, to ownerId: String) -> UserDataSnapshot {
        var next = snapshot
        next.ownerId = ownerId
        next.updatedAt = .now
        next.workouts = snapshot.workouts.map {
            var w = $0
            w.ownerId = ownerId
            return w
        }
        next.weightHistory = snapshot.weightHistory.map {
            var e = $0
            e.ownerId = ownerId
            return e
        }
        next.weeklyCompletions = snapshot.weeklyCompletions.map {
            var e = $0
            e.ownerId = ownerId
            return e
        }
        next.performanceLogs = snapshot.performanceLogs.map {
            var e = $0
            e.ownerId = ownerId
            return e
        }
        next.customExercises = snapshot.customExercises.map {
            var e = $0
            e.ownerId = ownerId
            return e
        }
        next.tombstones = snapshot.tombstones.map {
            DataTombstone(id: $0.id, entityType: $0.entityType, ownerId: ownerId, deletedAt: $0.deletedAt)
        }
        return next
    }

    private static func mergeTombstones(_ a: [DataTombstone], _ b: [DataTombstone]) -> [DataTombstone] {
        var map: [UUID: DataTombstone] = [:]
        for item in a + b {
            if let existing = map[item.id] {
                map[item.id] = existing.deletedAt >= item.deletedAt ? existing : item
            } else {
                map[item.id] = item
            }
        }
        return Array(map.values)
    }

    private static func mergeByUUID<T: Identifiable>(
        local: [T],
        remote: [T],
        updatedAt: (T) -> Date,
        assignOwner: (T, String) -> T,
        resultingOwnerId: String,
        conflicts: inout [String],
        entityName: String
    ) -> [T] where T.ID == UUID {
        var map: [UUID: T] = [:]
        for item in local {
            map[item.id] = assignOwner(item, resultingOwnerId)
        }
        for item in remote {
            if let existing = map[item.id] {
                let localDate = updatedAt(existing)
                let remoteDate = updatedAt(item)
                if abs(localDate.timeIntervalSince(remoteDate)) < 1 {
                    continue
                }
                if remoteDate > localDate {
                    map[item.id] = assignOwner(item, resultingOwnerId)
                    conflicts.append("\(entityName):\(item.id.uuidString)")
                } else if localDate > remoteDate {
                    conflicts.append("\(entityName):\(item.id.uuidString)")
                }
            } else {
                map[item.id] = assignOwner(item, resultingOwnerId)
            }
        }
        return Array(map.values)
    }

    private static func mergeByStringID(
        local: [Exercise],
        remote: [Exercise],
        assignOwner: (Exercise, String) -> Exercise,
        resultingOwnerId: String
    ) -> [Exercise] {
        var map: [String: Exercise] = [:]
        for item in local {
            map[item.id] = assignOwner(item, resultingOwnerId)
        }
        for item in remote where map[item.id] == nil {
            map[item.id] = assignOwner(item, resultingOwnerId)
        }
        return Array(map.values)
    }
}
