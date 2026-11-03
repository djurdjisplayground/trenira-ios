import Foundation

#if DEBUG
enum MovementActivitySelfTests {
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

        let defaults = UserDefaults(suiteName: "trenira.movementSelfTests.\(UUID().uuidString)")!
        defer {
            SavedVideoStore.clear(defaults: defaults)
            MovementRecordStore.clear(defaults: defaults)
        }

        check("empty link is rejected", YouTubeLink.validatedURL(from: "  ") == nil)
        check("a non-YouTube link is rejected", YouTubeLink.validatedURL(from: "https://vimeo.com/123") == nil)
        check("a script link is rejected", YouTubeLink.validatedURL(from: "javascript:alert(1)") == nil)
        let watch = YouTubeLink.validatedURL(from: "https://www.youtube.com/watch?v=abc123")
        check("a watch link is accepted", watch?.host == "www.youtube.com")
        let short = YouTubeLink.validatedURL(from: "youtu.be/abc123")
        check("a short link is accepted as https", short?.scheme == "https" && short?.host == "youtu.be")

        let video = SavedVideo(
            id: UUID(),
            title: "Quiet strength",
            urlString: watch?.absoluteString ?? "",
            durationMinutes: nil,
            savedAt: .now,
            ownerId: "guest:test"
        )
        SavedVideoStore.add(video, defaults: defaults)
        let loadedVideos = SavedVideoStore.load(defaults: defaults)
        check("a video title is saved", loadedVideos.first?.title == "Quiet strength")
        check("an unknown video length stays unknown", loadedVideos.first?.durationMinutes == nil)
        check("another owner does not see the video", SavedVideoStore.load(defaults: defaults, ownerId: "account:other").isEmpty)

        let early = MovementRecord(
            kind: .walking,
            title: "Walk",
            actualMinutes: 4,
            plannedMinutes: 10,
            feeling: nil,
            ownerId: "guest:test"
        )
        check("stopping early is recorded from the minutes", early.finishedEarlier)
        check("a reflection can be left empty", early.feeling == nil)
        MovementRecordStore.add(early, defaults: defaults)
        let loadedWalk = MovementRecordStore.load(defaults: defaults).first
        check("a walk is saved", loadedWalk?.kind == .walking && loadedWalk?.actualMinutes == 4)
        check(
            "movement records do not use the strength log key",
            defaults.data(forKey: "workoutPerformanceLogs") == nil
        )

        let strength = StrengthHistorySnapshot(id: UUID(), title: "Upper body", completedAt: .now)
        let items = MovementJournal.items(
            records: MovementRecordStore.load(defaults: defaults),
            strengthLogs: [strength]
        )
        check("strength and a walk both appear", items.count == 2)
        check("strength keeps its own history id", items.contains { $0.id == "strength-\(strength.id.uuidString)" })
        check("strength minutes stay unknown", items.first { $0.kind == .strength }?.actualMinutes == nil)
        let again = MovementJournal.items(records: [], strengthLogs: [strength])
        check("a strength log is not stored as a second movement record", again.count == 1 && again[0].kind == .strength)

        let summary = MovementJournal.weekSummary(items: items)
        check("the week counts both activities", summary.activityCount == 2)
        check("only known minutes are added", summary.recordedMinutes == 4)
        check("strength is counted without minutes", summary.strengthCountWithoutMinutes == 1)

        let old = MovementHistoryItem(
            id: "old",
            kind: .walking,
            title: "Old walk",
            completedAt: Date(timeIntervalSince1970: 0),
            actualMinutes: 30,
            plannedMinutes: nil,
            feeling: .calm
        )
        let oldSummary = MovementJournal.weekSummary(items: [old])
        check("an old activity is outside this week", oldSummary.activityCount == 0 && oldSummary.recordedMinutes == 0)

        let keys = Set(LocalDataErasureService.userContentUserDefaultsKeys)
        check("erasure removes saved videos", keys.contains(SavedVideoStore.storageKey))
        check("erasure removes movement records", keys.contains(MovementRecordStore.storageKey))
        SavedVideoStore.clear(defaults: defaults)
        MovementRecordStore.clear(defaults: defaults)
        check("clearing videos removes them", SavedVideoStore.load(defaults: defaults).isEmpty)
        check("clearing movement records removes them", MovementRecordStore.load(defaults: defaults).isEmpty)

        let strengthOnly = MovementWeekSummary(
            activityCount: 1,
            recordedMinutes: 0,
            kinds: [.strength],
            strengthCountWithoutMinutes: 1
        )
        let strengthLine = MovementJournal.weekLine(strengthOnly)
        check("unknown strength time is not shown as zero minutes", !strengthLine.contains("0 minutes"))

        let oldJSON = """
        {"schemaVersion":1,"ownerId":"guest:old","updatedAt":0,"workouts":[],"weightHistory":[],"weeklyCompletions":[],"performanceLogs":[],"customExercises":[],"tombstones":[]}
        """.data(using: .utf8)!
        let oldSnapshot = try? JSONDecoder().decode(UserDataSnapshot.self, from: oldJSON)
        check("an older backup omits movement records", oldSnapshot?.movementRecords == nil)
        check("an older backup omits saved videos", oldSnapshot?.savedVideos == nil)

        let kept = MovementRecord(kind: .walking, title: "Kept", actualMinutes: 8, ownerId: "guest:test")
        MovementRecordStore.add(kept, defaults: defaults)
        MovementRecordStore.replace(ownerId: "guest:test", records: nil, defaults: defaults)
        check("a nil backup does not erase walks", MovementRecordStore.load(defaults: defaults).contains { $0.title == "Kept" })
        MovementRecordStore.replace(ownerId: "guest:other", records: [], defaults: defaults)
        check("replacing another owner keeps this walk", MovementRecordStore.load(defaults: defaults, ownerId: "guest:test").contains { $0.title == "Kept" })

        return Outcome(passed: passed, failed: failed, lines: lines)
    }
}
#endif
