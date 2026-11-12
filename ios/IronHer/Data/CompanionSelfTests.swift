import Foundation

#if DEBUG
enum CompanionSelfTests {
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

        let defaults = UserDefaults(suiteName: "trenira.companionSelfTests.\(UUID().uuidString)")!
        let strengthFlagBefore = OnboardingStore.hasCompletedOnboarding
        defer {
            CompanionProfileStore.clear(defaults: defaults)
            OnboardingStore.hasCompletedOnboarding = strengthFlagBefore
        }

        check("missing profile is unresolved", !CompanionProfileStore.isResolved(defaults: defaults))

        let workoutID = UUID()
        var profile = CompanionProfile(
            goal: .feelStronger,
            barriers: [.guilt, .notEnoughTime],
            primaryBarrier: .notEnoughTime,
            formats: [.strength, .walking]
        )
        CompanionProfileStore.save(profile, defaults: defaults)
        let loaded = CompanionProfileStore.load(defaults: defaults)
        check("profile round-trips", loaded?.goal == .feelStronger)
        check("primary barrier is stored", loaded?.primaryBarrier == .notEnoughTime)
        check("other barriers are stored", loaded?.barriers == [.guilt, .notEnoughTime])
        check(
            "companion key is separate from strength onboarding",
            defaults.object(forKey: OnboardingStore.storageKey) == nil
        )
        check("strength completion flag was not changed", OnboardingStore.hasCompletedOnboarding == strengthFlagBefore)

        let orphan = CompanionProfile(barriers: [.guilt], primaryBarrier: .notEnoughTime)
        CompanionProfileStore.save(orphan, defaults: defaults)
        check(
            "primary barrier must be one of the selected barriers",
            CompanionProfileStore.load(defaults: defaults)?.primaryBarrier == .guilt
        )

        check(
            "new user sees companion onboarding",
            AppEntryPolicy.entry(strengthOnboardingCompleted: false, companionResolved: false) == .companionOnboarding
        )
        check(
            "companion answers skip the old strength intro",
            AppEntryPolicy.entry(strengthOnboardingCompleted: false, companionResolved: true) == .main
        )
        check(
            "existing strength user reaches home without a companion profile",
            AppEntryPolicy.entry(strengthOnboardingCompleted: true, companionResolved: false) == .main
        )

        let workouts = [SavedStrengthOption(id: workoutID, name: "Upper body")]
        let base = CompanionProfile(goal: .feelStronger, formats: [.strength])
        func first(barrier: MovementBarrier?, minutes: MovementMinutes, energy: MovementEnergy, setting: MovementSetting) -> [MovementSuggestion] {
            var sample = base
            sample.primaryBarrier = barrier
            if let barrier { sample.barriers = [barrier] }
            return MovementRecommendationEngine.suggest(
                profile: sample,
                checkIn: MovementCheckIn(minutes: minutes, energy: energy, setting: setting),
                workouts: workouts
            )
        }

        let shortOnTime = first(barrier: .notEnoughTime, minutes: .twenty, energy: .high, setting: .home)
        let stronger = first(barrier: nil, minutes: .twenty, energy: .high, setting: .home)
        check("lack of time does not lead with a full workout", shortOnTime.first?.kind == .walk)
        check("feeling stronger can lead with a saved workout", stronger.first?.kind == .strengthWorkout)
        check("those two barriers do not make the same first suggestion", shortOnTime.first?.kind != stronger.first?.kind)

        let starting = first(barrier: .difficultyStarting, minutes: .ten, energy: .okay, setting: .home)
        check("difficulty starting offers one next step", starting.count == 1)

        let flexible = first(barrier: .unpredictableSchedule, minutes: .twenty, energy: .okay, setting: .home)
        check("an unpredictable schedule offers more than one option", flexible.count >= 2)
        check("one flexible option is a walk", flexible.contains { $0.kind == .walk })
        check("one flexible option is the saved workout", flexible.contains { $0.kind == .strengthWorkout })

        let guilt = first(barrier: .guilt, minutes: .ten, energy: .low, setting: .home)
        check("guilt uses supportive copy", guilt.first?.reason.contains("This time is yours") == true)
        check("guilt copy is not a command to train", guilt.first?.reason.localizedCaseInsensitiveContains("you should") == false)

        let returning = first(barrier: .returningAfterBreak, minutes: .twenty, energy: .high, setting: .home)
        check("a return after a break does not assign catch-up work", returning.first?.reason.contains("nothing to catch up") == true)
        check("a return after a break prefers a walk at home", returning.first?.kind == .walk)

        let fiveMinutes = first(barrier: nil, minutes: .five, energy: .high, setting: .gym)
        check("five minutes does not start a saved workout", fiveMinutes.allSatisfy { !$0.isActionable })
        check("five minutes does not claim the workout duration", fiveMinutes.allSatisfy { $0.detail.contains("lasts 5") == false })

        let outdoors = first(barrier: nil, minutes: .twenty, energy: .high, setting: .outdoors)
        check("outdoors does not offer the saved workout as the session", outdoors.allSatisfy { $0.kind != .strengthWorkout })

        let gymWithoutLeaving = first(barrier: .cantGetToGym, minutes: .twenty, energy: .high, setting: .home)
        check("can't get to the gym stays with a home walk", gymWithoutLeaving.first?.kind == .walk)
        let alreadyAtGym = first(barrier: .cantGetToGym, minutes: .twenty, energy: .high, setting: .gym)
        check("already at the gym can use the saved workout", alreadyAtGym.first?.kind == .strengthWorkout)

        let videos = CompanionProfile(formats: [.videos])
        let videoSuggestions = MovementRecommendationEngine.suggest(
            profile: videos,
            checkIn: MovementCheckIn(minutes: .ten, energy: .okay, setting: .home),
            workouts: [],
            savedVideos: []
        )
        check("a missing video is named honestly", videoSuggestions.contains { $0.kind == .video })
        check(
            "no video address is invented",
            videoSuggestions.allSatisfy { !$0.detail.localizedCaseInsensitiveContains("http") && !$0.title.localizedCaseInsensitiveContains("youtube.com") }
        )

        profile.skipped = true
        CompanionProfileStore.save(profile, defaults: defaults)
        check("a skipped profile still counts as resolved", CompanionProfileStore.isResolved(defaults: defaults))

        let legacyJSON = """
        {"goal":"feelStronger","barriers":["notEnoughTime","guilt"],"primaryBarrier":"notEnoughTime","formats":["strength","walking"],"skipped":false,"updatedAt":0}
        """.data(using: .utf8)!
        let legacy = try? JSONDecoder().decode(CompanionProfile.self, from: legacyJSON)
        check("an older companion profile still decodes", legacy?.goal == .feelStronger)
        check("older barrier raw values still decode", legacy?.primaryBarrier == .notEnoughTime && legacy?.barriers == [.notEnoughTime, .guilt])

        var editable = CompanionProfile(formats: [.walking])
        CompanionProfileStore.save(editable, defaults: defaults)
        editable.formats = [.dancing, .withBaby, .yoga]
        CompanionProfileStore.save(editable, defaults: defaults)
        let changed = CompanionProfileStore.load(defaults: defaults)
        check("preferences can change to the new categories", changed?.formats == [.dancing, .withBaby, .yoga])
        let oldFormats = """
        {"goal":"findRhythm","barriers":[],"formats":["walking","yoga"],"skipped":false,"updatedAt":0}
        """.data(using: .utf8)!
        let oldFormatsProfile = try? JSONDecoder().decode(CompanionProfile.self, from: oldFormats)
        check("older movement preferences still decode", oldFormatsProfile?.formats == [.walking, .yoga])

        let yogaProfile = CompanionProfile(
            barriers: [.notEnoughTime],
            primaryBarrier: .notEnoughTime,
            formats: [.yoga, .dancing]
        )
        let yogaSuggestions = MovementRecommendationEngine.suggest(
            profile: yogaProfile,
            checkIn: MovementCheckIn(minutes: .ten, energy: .okay, setting: .home),
            workouts: workouts
        )
        check("a preferred yoga option is offered", yogaSuggestions.contains { $0.kind == .selfDirected && $0.format == .yoga })
        check("a preferred dancing option is offered", yogaSuggestions.contains { $0.format == .dancing })
        check("lack of time still leads with a walk when other categories are preferred", yogaSuggestions.first?.kind == .walk)
        check(
            "a self-directed suggestion does not prescribe a pose",
            yogaSuggestions.allSatisfy { !$0.detail.localizedCaseInsensitiveContains("downward dog") }
        )

        let babyProfile = CompanionProfile(formats: [.withBaby])
        let babySuggestions = MovementRecommendationEngine.suggest(
            profile: babyProfile,
            checkIn: MovementCheckIn(minutes: .ten, energy: .okay, setting: .home),
            workouts: []
        )
        let babyDetail = babySuggestions.first { $0.format == .withBaby }?.detail ?? ""
        check("movement with baby can be recorded", babySuggestions.contains { $0.format == .withBaby })
        check("movement with baby does not say to lift the baby", !babyDetail.localizedCaseInsensitiveContains("lift your baby"))
        check("movement with baby does not say to carry the baby", !babyDetail.localizedCaseInsensitiveContains("carry your baby"))
        check("baby notice declines medical and childcare advice", BabyMovementCopy.notice.contains("not medical or childcare advice"))

        let lowEnergy = first(barrier: .lowEnergy, minutes: .ten, energy: .low, setting: .home)
        check("low energy prefers a walk at home", lowEnergy.first?.kind == .walk)
        check("low energy copy does not shame", lowEnergy.first?.reason.localizedCaseInsensitiveContains("no excuses") == false)

        return Outcome(passed: passed, failed: failed, lines: lines)
    }
}
#endif
