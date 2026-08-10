import Foundation

#if DEBUG
/// DEBUG assertions for Data Protection writes, Keychain accessibility migration helpers,
/// and local erasure key inventory. Invoked from Developer Settings.
enum LocalDataProtectionSelfTests {
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

        // 1. Preferred protection class
        check(
            "preferred file protection is complete",
            ProtectedFileWriter.preferredProtection == .complete
        )

        // 2. Atomic protected write + read round-trip
        do {
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("trenira-protection-tests", isDirectory: true)
            try? FileManager.default.removeItem(at: dir)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let url = dir.appendingPathComponent("sample.json")
            let payload = Data(#"{"ok":true}"#.utf8)
            try ProtectedFileWriter.writeAtomically(payload, to: url)
            let loaded = try Data(contentsOf: url)
            check("protected write round-trip", loaded == payload)

            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            let protection = attrs[.protectionKey] as? FileProtectionType
            check(
                "written file reports complete protection",
                protection == .complete
            )
            try? FileManager.default.removeItem(at: dir)
        } catch {
            check("protected write round-trip", false)
            lines.append("  error: \(error.localizedDescription)")
        }

        // 3. Snapshot empty decode still works (existing local JSON compatibility)
        let empty = UserDataSnapshot.empty(ownerId: "account:apple:test")
        if let data = try? JSONEncoder().encode(empty),
           let decoded = try? JSONDecoder().decode(UserDataSnapshot.self, from: data) {
            check("empty snapshot encode/decode", decoded.ownerId == empty.ownerId && decoded.workouts.isEmpty)
        } else {
            check("empty snapshot encode/decode", false)
        }

        // 4. Erasure inventory includes critical workout keys
        let keys = Set(LocalDataErasureService.userContentUserDefaultsKeys)
        for required in [
            "savedWorkouts",
            "savedWorkoutsDeleted",
            "weightHistory",
            "workoutPerformanceLogs",
            "activeWorkoutSession",
            "globalExerciseProgress",
            "userSettings",
            "customExercises",
            "googleEmail",
            "accountUserIdentifier",
            "authMode",
            ConsultationDraftStore.storageKey,
            OnboardingStore.storageKey,
        ] {
            check("erasure inventory contains \(required)", keys.contains(required))
        }

        // 5. Keychain accessibility migration preserves guest identity
        let before = GuestIdentityStore.localGuestID()
        let after = GuestIdentityStore.localGuestID()
        check("guest identity stable across migrate/read", before == after && !before.isEmpty)

        let provider = "selftest"
        let testID = "provider-user-123"
        SecureAccountIdentityStore.save(provider: provider, userID: testID)
        let loaded = SecureAccountIdentityStore.load(provider: provider)
        check("account identity load/migrate preserves value", loaded == testID)
        SecureAccountIdentityStore.clear(provider: provider)
        check("account identity clear removes value", SecureAccountIdentityStore.load(provider: provider) == nil)

        return Outcome(passed: passed, failed: failed, lines: lines)
    }
}
#endif
