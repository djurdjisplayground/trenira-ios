import Foundation

#if DEBUG
/// Lightweight DEBUG assertions for guest migration / merge behavior.
/// Invoked from Developer Settings — no XCTest target is required.
enum UserDataMigrationSelfTests {
    struct Outcome: Sendable {
        var passed: Int
        var failed: Int
        var lines: [String]

        var summary: String {
            "\(passed) passed, \(failed) failed\n" + lines.joined(separator: "\n")
        }
    }

    static func runAll() -> Outcome {
        var passed = 0
        var failed = 0
        var lines: [String] = []

        func check(_ name: String, _ condition: @autoclosure () -> Bool) {
            if condition() {
                passed += 1
                lines.append("✓ \(name)")
            } else {
                failed += 1
                lines.append("✗ \(name)")
            }
        }

        let guestOwner = DataOwnerID.guest("test-guest").rawValue
        let accountOwner = DataOwnerID.account(provider: "apple", userID: "user-1").rawValue

        // Guest snapshot with one workout
        var guestWorkout = Workout(name: "Guest Legs", ownerId: guestOwner)
        let guest = UserDataSnapshot(
            schemaVersion: 1,
            ownerId: guestOwner,
            updatedAt: .now,
            workouts: [guestWorkout],
            weightHistory: [
                WeightHistoryEntry(exerciseId: "squat", weightKg: 40, event: .initial, ownerId: guestOwner)
            ],
            weeklyCompletions: [],
            performanceLogs: [],
            customExercises: [],
            tombstones: [],
            progressionBlob: nil,
            globalProgressBlob: nil,
            userSettingsBlob: nil
        )

        // 1. Guest remains guest identity
        check("guest owner is guest", DataOwnerID(rawValue: guestOwner).isGuest)

        // 2. Guest → empty account transfers all
        let emptyAccount = UserDataSnapshot.empty(ownerId: accountOwner)
        let toEmpty = UserDataMergeEngine.merge(local: guest, remote: emptyAccount, resultingOwnerId: accountOwner)
        check("empty account receives guest workout", toEmpty.snapshot.workouts.count == 1)
        check("ownership becomes account", toEmpty.snapshot.workouts.first?.ownerId == accountOwner)
        check("history preserved", toEmpty.snapshot.weightHistory.count == 1)

        // 3. Guest → account with existing data merges both
        let accountWorkout = Workout(name: "Account Push", ownerId: accountOwner)
        let account = UserDataSnapshot(
            schemaVersion: 1,
            ownerId: accountOwner,
            updatedAt: .now,
            workouts: [accountWorkout],
            weightHistory: [],
            weeklyCompletions: [],
            performanceLogs: [],
            customExercises: [],
            tombstones: [],
            progressionBlob: nil,
            globalProgressBlob: nil,
            userSettingsBlob: nil
        )
        let merged = UserDataMergeEngine.merge(local: guest, remote: account, resultingOwnerId: accountOwner)
        check("merge keeps both workouts", merged.snapshot.workouts.count == 2)

        // 4. Idempotent second merge does not duplicate
        let again = UserDataMergeEngine.merge(
            local: merged.snapshot,
            remote: merged.snapshot,
            resultingOwnerId: accountOwner
        )
        check("second merge no duplicates", again.snapshot.workouts.count == 2)

        // 5. Empty remote must not wipe populated local
        let wiped = UserDataMergeEngine.merge(
            local: merged.snapshot,
            remote: .empty(ownerId: accountOwner),
            resultingOwnerId: accountOwner
        )
        check("empty remote does not wipe local", wiped.snapshot.workouts.count == 2)

        // 6. Empty local does not wipe populated remote
        let restore = UserDataMergeEngine.merge(
            local: .empty(ownerId: accountOwner),
            remote: merged.snapshot,
            resultingOwnerId: accountOwner
        )
        check("empty local does not wipe remote", restore.snapshot.workouts.count == 2)

        // 7. Tombstones suppress workouts
        let tombstonedID = guestWorkout.id
        var withTombstone = merged.snapshot
        withTombstone.tombstones = [
            DataTombstone(id: tombstonedID, entityType: "workout", ownerId: accountOwner)
        ]
        let afterDelete = UserDataMergeEngine.merge(
            local: withTombstone,
            remote: guest,
            resultingOwnerId: accountOwner
        )
        check(
            "tombstone prevents reappearance",
            !afterDelete.snapshot.workouts.contains(where: { $0.id == tombstonedID })
        )

        // 8. Newer wins on conflict
        var localEdit = guestWorkout
        localEdit.name = "Local Edit"
        localEdit.updatedAt = Date().addingTimeInterval(100)
        localEdit.ownerId = accountOwner
        var remoteEdit = guestWorkout
        remoteEdit.name = "Remote Edit"
        remoteEdit.updatedAt = Date().addingTimeInterval(50)
        remoteEdit.ownerId = accountOwner
        let conflict = UserDataMergeEngine.merge(
            local: UserDataSnapshot(
                schemaVersion: 1,
                ownerId: accountOwner,
                updatedAt: .now,
                workouts: [localEdit],
                weightHistory: [],
                weeklyCompletions: [],
                performanceLogs: [],
                customExercises: [],
                tombstones: [],
                progressionBlob: nil,
                globalProgressBlob: nil,
                userSettingsBlob: nil
            ),
            remote: UserDataSnapshot(
                schemaVersion: 1,
                ownerId: accountOwner,
                updatedAt: .now,
                workouts: [remoteEdit],
                weightHistory: [],
                weeklyCompletions: [],
                performanceLogs: [],
                customExercises: [],
                tombstones: [],
                progressionBlob: nil,
                globalProgressBlob: nil,
                userSettingsBlob: nil
            ),
            resultingOwnerId: accountOwner
        )
        check("newer local wins", conflict.snapshot.workouts.first?.name == "Local Edit")

        // 9. Transfer ownership never drops records
        let transferred = UserDataMergeEngine.transferOwnership(guest, to: accountOwner)
        check("transfer keeps count", transferred.workouts.count == guest.workouts.count)

        // 10. Premium separation — ownership model does not encode entitlements
        check("owner raw has no premium", !accountOwner.contains("premium"))

        return Outcome(passed: passed, failed: failed, lines: lines)
    }
}
#endif
