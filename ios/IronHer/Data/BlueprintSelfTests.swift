import Foundation

#if DEBUG
enum BlueprintSelfTests {
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

        let gentle = MovementCatalogRecommender.suggestions(for: RecommendationQuery(
            minutes: 5,
            energy: .low,
            selection: .focused(.none),
            preferred: [],
            avoidFloor: false
        ))
        check("five low-energy minutes returns three choices", gentle.count == 3)
        check(
            "five low-energy minutes stays off strength",
            gentle.allSatisfy { $0.category != .dumbbellStrength && $0.category != .bodyweightStrength }
        )
        check(
            "five low-energy minutes has distinct categories",
            Set(gentle.map(\.category)).count == gentle.count
        )
        check(
            "no equipment can include walking and dancing",
            gentle.contains { $0.category == .walking } && gentle.contains { $0.category == .dancing }
        )
        let joinedGentle = gentle.flatMap(\.instructions).joined(separator: " ").lowercased()
        check("gentle choices do not use a baby as equipment", !joinedGentle.contains("baby"))

        let bodyweight = MovementCatalogRecommender.suggestions(for: RecommendationQuery(
            minutes: 10,
            energy: .high,
            selection: .focused(.none),
            preferred: [],
            avoidFloor: false
        ))
        check("no equipment can include a bodyweight option", bodyweight.contains { $0.category == .bodyweightStrength })
        check("no equipment suggestions stay equipment-free", bodyweight.allSatisfy { $0.equipment == .none })

        let strong = MovementCatalogRecommender.suggestions(for: RecommendationQuery(
            minutes: 5,
            energy: .high,
            selection: .focused(.dumbbells),
            preferred: [],
            avoidFloor: false
        ))
        check("dumbbells returns three choices", strong.count == 3)
        check("dumbbells stays on dumbbells", strong.allSatisfy { $0.equipment == .dumbbells })
        let strongText = strong.map { "\($0.name) \($0.instructions.joined(separator: " "))" }.joined(separator: " ").lowercased()
        check(
            "dumbbells does not substitute walking, dancing, or marching",
            !strongText.contains("walk") && !strongText.contains("danc") && !strongText.contains("march")
        )

        let bands = MovementCatalogRecommender.suggestions(for: RecommendationQuery(
            minutes: 5,
            energy: .okay,
            selection: .focused(.bands),
            preferred: [],
            avoidFloor: false
        ))
        check("bands returns band exercises", bands.count == 3 && bands.allSatisfy { $0.equipment == .bands })

        let lowDumbbells = MovementCatalogRecommender.suggestions(for: RecommendationQuery(
            minutes: 5,
            energy: .low,
            selection: .focused(.dumbbells),
            preferred: [],
            avoidFloor: false
        ))
        let highDumbbells = strong
        check("energy changes dumbbell suggestions", Set(lowDumbbells.map(\.id)) != Set(highDumbbells.map(\.id)))
        let shortDumbbells = MovementCatalogRecommender.suggestions(for: RecommendationQuery(
            minutes: 2,
            energy: .high,
            selection: .focused(.dumbbells),
            preferred: [],
            avoidFloor: false
        ))
        check("two minutes leaves out longer dumbbell sessions", shortDumbbells.allSatisfy { $0.minimumMinutes <= 2 })

        let swapped = MovementCatalogRecommender.suggestions(for: RecommendationQuery(
            minutes: 5,
            energy: .low,
            selection: .focused(.none),
            preferred: [],
            avoidFloor: false,
            excludeIDs: Set(gentle.map(\.id))
        ))
        check("another idea changes the choices", Set(swapped.map(\.id)) != Set(gentle.map(\.id)))
        check("another idea stays with no equipment", swapped.allSatisfy { $0.equipment == .none })

        let floor = MovementCatalogRecommender.suggestions(for: RecommendationQuery(
            minutes: 15,
            energy: .low,
            selection: .focused(.mat),
            preferred: [.stretching],
            avoidFloor: true
        ))
        check("avoiding the floor hides floor moves", !floor.isEmpty && floor.allSatisfy { $0.position != .floor && $0.equipment == .mat })

        let noneLeft = MovementCatalogRecommender.suggestions(for: RecommendationQuery(
            minutes: 5,
            energy: .high,
            selection: .focused(.dumbbells),
            preferred: [],
            avoidFloor: false,
            excludeIDs: Set(MovementCatalog.all.map(\.id))
        ))
        check("no further match stays empty", noneLeft.isEmpty)

        var clock = MovementSessionClock()
        clock.begin(atUptime: 100)
        clock.pause(atUptime: 112)
        clock.resume(atUptime: 400)
        clock.pause(atUptime: 407)
        check("background time is not counted", clock.elapsed(atUptime: 900) == 19)

        let defaults = UserDefaults(suiteName: "trenira.blueprint.\(UUID().uuidString)")!
        let owner = "guest:blueprint"
        let few = MovementRecord(
            kind: .walking,
            title: "Walk",
            actualMinutes: 0,
            ownerId: owner,
            actualDurationSeconds: 4,
            activityAt: Date(),
            source: .guided,
            completionStatus: "saved"
        )
        MovementRecordStore.upsert(few, defaults: defaults)
        MovementRecordStore.upsert(few, defaults: defaults)
        let stored = MovementRecordStore.load(defaults: defaults, ownerId: owner)
        check("a second save does not duplicate the record", stored.filter { $0.id == few.id }.count == 1)
        check("four seconds are not stored as one minute", stored.first { $0.id == few.id }?.actualMinutes == 0)
        check("four seconds are kept", stored.first { $0.id == few.id }?.actualDurationSeconds == 4)

        let second = MovementRecord(
            kind: .dancing,
            title: "Dance",
            actualMinutes: 0,
            ownerId: owner,
            actualDurationSeconds: 30,
            activityAt: Date(),
            source: .manual,
            completionStatus: "saved"
        )
        MovementRecordStore.upsert(second, defaults: defaults)
        let todayCount = MovementDiary.records(
            MovementRecordStore.load(defaults: defaults, ownerId: owner),
            on: Date()
        ).count
        check("two sessions on one day stay separate", todayCount == 2)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let tuesday = calendar.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 12))!
        let laterWeek = calendar.date(from: DateComponents(year: 2026, month: 11, day: 13, hour: 12))!
        let backdated = MovementRecord(
            kind: .walking,
            title: "Tuesday walk",
            completedAt: laterWeek,
            actualMinutes: 0,
            ownerId: owner,
            actualDurationSeconds: 600,
            activityAt: tuesday,
            source: .manual,
            createdAt: laterWeek,
            completionStatus: "saved"
        )
        MovementRecordStore.upsert(backdated, defaults: defaults)
        let all = MovementRecordStore.load(defaults: defaults, ownerId: owner)
        check(
            "a Tuesday walk stays in Tuesday's week",
            MovementDiary.records(all, inWeekOf: tuesday, calendar: calendar).contains { $0.id == backdated.id }
        )
        check(
            "a Tuesday walk is not filed under the later week",
            !MovementDiary.records(all, inWeekOf: laterWeek, calendar: calendar).contains { $0.id == backdated.id }
        )

        var edited = backdated
        edited.actualDurationSeconds = 120
        edited.actualMinutes = 2
        edited.updatedAt = laterWeek
        MovementRecordStore.upsert(edited, defaults: defaults)
        let afterEdit = MovementRecordStore.load(defaults: defaults, ownerId: owner)
        let editedOnly = afterEdit.filter { $0.id == backdated.id }
        let editedWeek = MovementDiary.summary(
            of: MovementDiary.records(editedOnly, inWeekOf: tuesday, calendar: calendar),
            calendar: calendar
        )
        check("editing duration updates the week", editedWeek.activeSeconds == 120)
        MovementRecordStore.delete(id: backdated.id, defaults: defaults)
        let afterDelete = MovementRecordStore.load(defaults: defaults, ownerId: owner)
        check("deleting removes the entry from the week", !afterDelete.contains { $0.id == backdated.id })
        check(
            "an empty week is welcoming",
            DiaryReflection.weekly(activityCount: 0) == DiaryReflection.noMovement
        )

        let legacy = """
        {"id":"22222222-2222-2222-2222-222222222222","kind":"walking","title":"Old walk","completedAt":0,"actualMinutes":6,"ownerId":"guest:blueprint"}
        """.data(using: .utf8)!
        let decoded = try? JSONDecoder().decode(MovementRecord.self, from: legacy)
        check("an older record still decodes", decoded?.actualMinutes == 6 && decoded?.activityAt == nil)
        check("an older record uses its original date", decoded?.activityDate == Date(timeIntervalSinceReferenceDate: 0))

        let drafts = MovementCatalog.all.filter { $0.category == .withBabyNearby }
        let draftText = drafts
            .flatMap { $0.instructions + [$0.easier, $0.caution, $0.name] }
            .joined(separator: " ")
            .lowercased()
        let reviewedText = MovementCatalog.all
            .filter { $0.safety == .reviewedGeneral }
            .flatMap(\.instructions)
            .joined(separator: " ")
            .lowercased()
        check("reviewed ideas do not mention a baby", !reviewedText.contains("baby"))
        check("the library does not prescribe pelvic-floor work", !reviewedText.contains("pelvic") && !draftText.contains("pelvic"))
        check("with baby nearby is a small draft set", (3...5).contains(drafts.count))
        check("baby-nearby drafts wait for professional review", drafts.allSatisfy { $0.safety == .pendingProfessionalReview })
        check("reviewed ideas stay reviewed", MovementCatalog.all.filter { $0.category != .withBabyNearby }.allSatisfy { $0.safety == .reviewedGeneral })
        check("drafts do not say to lift a baby", !draftText.contains("lift"))
        check("drafts do not say to carry a baby", !draftText.contains("carry"))
        check("drafts do not use a baby as a prop", !draftText.contains("prop") && !draftText.contains("as a weight"))
        check("drafts do not claim every postpartum stage", !draftText.contains("every stage is safe") && !draftText.contains("safe for all"))
        let nearby = MovementCatalogRecommender.suggestions(for: RecommendationQuery(
            minutes: 5,
            energy: .okay,
            selection: .focused(.none),
            preferred: [],
            avoidFloor: false,
            excludeIDs: Set(MovementCatalog.all.filter { $0.category != .withBabyNearby }.map(\.id))
        ))
        check(
            "five okay minutes can suggest baby-nearby drafts",
            !nearby.isEmpty && nearby.allSatisfy {
                $0.category == .withBabyNearby && $0.equipment == .none && $0.minimumMinutes <= 5 && $0.energies.contains(.okay)
            }
        )
        let shortNearby = MovementCatalogRecommender.suggestions(for: RecommendationQuery(
            minutes: 2,
            energy: .low,
            selection: .focused(.none),
            preferred: [],
            avoidFloor: false,
            excludeIDs: Set(MovementCatalog.all.filter { $0.category != .withBabyNearby }.map(\.id))
        ))
        check("two minutes leaves out longer baby-nearby drafts", shortNearby.allSatisfy { $0.minimumMinutes <= 2 })
        check("two minutes does not include the longer walk", !shortNearby.contains { $0.id == "baby-nearby-walk" })
        check("dumbbells does not suggest baby-nearby drafts", strong.allSatisfy { $0.category != .withBabyNearby })
        check("your circle preview stays off for the beta", TreniraFeature.yourCirclePreviewEnabled == false)
        check("avatar asset name is explicit", MovementCatalog.avatarAssetName == "trenira_companion_avatar")

        return Outcome(passed: passed, failed: failed, lines: lines)
    }
}
#endif
