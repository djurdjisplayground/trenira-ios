import Foundation

#if DEBUG
/// DEBUG checks for the feedback invitation.
/// Uses an isolated UserDefaults suite so running the tests does not change this install.
enum ResearchInvitationSelfTests {
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

        let suiteName = "trenira.researchInvitationSelfTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return Outcome(passed: 0, failed: 1, lines: ["✗ create isolated UserDefaults suite"])
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            ResearchInvitationStore.consumeImmediatePresentation()
        }

        ResearchInvitationStore.consumeImmediatePresentation()

        let calendar = Calendar(identifier: .gregorian)
        let today = Date(timeIntervalSince1970: 1_793_000_000)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today

        check("title copy", ResearchInvitationCopy.title == "Help shape trenira 💜")
        check(
            "message copy",
            ResearchInvitationCopy.message == "I'm the founder of trenira, and I'd love to hear about your experience using the app. Would you be open to sharing feedback or having a quick 15-minute conversation?"
        )
        check("accept copy", ResearchInvitationCopy.acceptTitle == "I'd love to help")
        check("later copy", ResearchInvitationCopy.laterTitle == "Maybe later")
        check("opt out copy", ResearchInvitationCopy.optOutTitle == "Don't ask again")
        check("settings title", ResearchInvitationCopy.settingsTitle == "Talk to the founder")
        check(
            "settings subtitle",
            ResearchInvitationCopy.settingsSubtitle == "Share feedback and help shape trenira"
        )

        let formURL = AppConfiguration.researchInvitationFormURL
        check("form url is set", formURL != nil)
        check(
            "form url matches the shared google form",
            formURL?.absoluteString == "https://docs.google.com/forms/d/e/1FAIpQLScM-Jaltf16kj9AkmVA71tryQJLPGZrgIkSxrJ7j6Y-5s_jRw/viewform"
        )

        check(
            "fresh install is offered on home",
            ResearchInvitationPolicy.shouldPresent(
                homeReady: true,
                onHomeTab: true,
                workoutInterfaceVisible: false,
                now: today,
                calendar: calendar,
                defaults: defaults
            )
        )
        check(
            "not offered before home is ready",
            !ResearchInvitationPolicy.shouldPresent(
                homeReady: false,
                onHomeTab: true,
                workoutInterfaceVisible: false,
                now: today,
                calendar: calendar,
                defaults: defaults
            )
        )
        check(
            "not offered away from home",
            !ResearchInvitationPolicy.shouldPresent(
                homeReady: true,
                onHomeTab: false,
                workoutInterfaceVisible: false,
                now: today,
                calendar: calendar,
                defaults: defaults
            )
        )
        check(
            "not offered over an active workout",
            !ResearchInvitationPolicy.shouldPresent(
                homeReady: true,
                onHomeTab: true,
                workoutInterfaceVisible: true,
                now: today,
                calendar: calendar,
                defaults: defaults
            )
        )
        check(
            "fresh home reason is present",
            ResearchInvitationPolicy.blockReason(
                homeReady: true,
                onHomeTab: true,
                workoutInterfaceVisible: false,
                now: today,
                calendar: calendar,
                defaults: defaults
            ) == "present"
        )
        check(
            "workout reason names the workout",
            ResearchInvitationPolicy.blockReason(
                homeReady: true,
                onHomeTab: true,
                workoutInterfaceVisible: true,
                now: today,
                calendar: calendar,
                defaults: defaults
            ) == "a workout is active"
        )

        ResearchInvitationStore.notePresented(at: yesterday, defaults: defaults)
        check(
            "a previous calendar day can be offered again",
            ResearchInvitationStore.canOfferAutomatically(now: today, calendar: calendar, defaults: defaults)
        )
        ResearchInvitationStore.notePresented(at: today, defaults: defaults)
        check(
            "same calendar day is not offered again",
            !ResearchInvitationStore.canOfferAutomatically(now: today, calendar: calendar, defaults: defaults)
        )
        check(
            "same calendar day names the reason",
            ResearchInvitationPolicy.blockReason(
                homeReady: true,
                onHomeTab: true,
                workoutInterfaceVisible: false,
                now: today,
                calendar: calendar,
                defaults: defaults
            ) == "already shown today"
        )
        check(
            "a later calendar day can be offered",
            ResearchInvitationStore.canOfferAutomatically(now: tomorrow, calendar: calendar, defaults: defaults)
        )

        let failedOpen = ResearchInvitationPolicy.recordOpenedForm(didOpen: false, defaults: defaults)
        check("failed open is not recorded", failedOpen == false)
        check("failed open leaves the install eligible", ResearchInvitationStore.status(in: defaults) == nil)
        check(
            "failed open can be offered again tomorrow",
            ResearchInvitationStore.canOfferAutomatically(now: tomorrow, calendar: calendar, defaults: defaults)
        )

        let missingURL = ResearchInvitationPolicy.recordOpenedForm(didOpen: true, formURL: nil, defaults: defaults)
        check("open without a url is not recorded", missingURL == false)
        check("missing url leaves the install eligible", ResearchInvitationStore.status(in: defaults) == nil)

        let opened = ResearchInvitationPolicy.recordOpenedForm(didOpen: true, defaults: defaults)
        check("successful open is recorded", opened)
        check("successful open is accepted", ResearchInvitationStore.status(in: defaults) == .accepted)
        check(
            "accepted reason names the form",
            ResearchInvitationPolicy.blockReason(
                homeReady: true,
                onHomeTab: true,
                workoutInterfaceVisible: false,
                now: tomorrow,
                calendar: calendar,
                defaults: defaults
            ) == "the form was already opened on this installation"
        )
        check(
            "accepted install is not offered again",
            !ResearchInvitationStore.canOfferAutomatically(now: tomorrow, calendar: calendar, defaults: defaults)
        )

        defaults.removeObject(forKey: ResearchInvitationStore.statusKey)
        ResearchInvitationStore.markOptedOut(in: defaults)
        check("don't ask again is stored", ResearchInvitationStore.status(in: defaults) == .optedOut)
        check(
            "opt out reason is don't ask again",
            ResearchInvitationPolicy.blockReason(
                homeReady: true,
                onHomeTab: true,
                workoutInterfaceVisible: false,
                now: tomorrow,
                calendar: calendar,
                defaults: defaults
            ) == "don't ask again"
        )
        check(
            "opted out install is not offered on a later day",
            !ResearchInvitationStore.canOfferAutomatically(now: tomorrow, calendar: calendar, defaults: defaults)
        )

        defaults.set(Data("workouts".utf8), forKey: "savedWorkouts")
        defaults.set("dismissed", forKey: ResearchInvitationStore.legacyResponseKey)
        defaults.set("newInstall", forKey: ResearchInvitationStore.legacyCohortKey)
        defaults.removeObject(forKey: ResearchInvitationStore.statusKey)
        ResearchInvitationStore.migrateLegacyStateIfNeeded(defaults: defaults)
        check("maybe later is not migrated into opt out", ResearchInvitationStore.status(in: defaults) == nil)
        check("legacy response is removed", defaults.string(forKey: ResearchInvitationStore.legacyResponseKey) == nil)
        check("legacy cohort is removed", defaults.string(forKey: ResearchInvitationStore.legacyCohortKey) == nil)
        check("migration leaves workout data alone", defaults.data(forKey: "savedWorkouts") == Data("workouts".utf8))
        check(
            "migrated maybe-later install can be offered",
            ResearchInvitationStore.canOfferAutomatically(now: tomorrow, calendar: calendar, defaults: defaults)
        )

        defaults.set("accepted", forKey: ResearchInvitationStore.legacyResponseKey)
        defaults.removeObject(forKey: ResearchInvitationStore.statusKey)
        ResearchInvitationStore.migrateLegacyStateIfNeeded(defaults: defaults)
        check("legacy acceptance stays accepted", ResearchInvitationStore.status(in: defaults) == .accepted)
        check("legacy acceptance key is removed", defaults.object(forKey: ResearchInvitationStore.legacyResponseKey) == nil)
        check(
            "legacy acceptance is not offered",
            !ResearchInvitationStore.canOfferAutomatically(now: tomorrow, calendar: calendar, defaults: defaults)
        )
        check("migration still leaves workout data alone", defaults.data(forKey: "savedWorkouts") == Data("workouts".utf8))

        ResearchInvitationStore.resetForTesting(in: defaults)
        check("reset clears status", ResearchInvitationStore.status(in: defaults) == nil)
        check("reset clears the presentation date", ResearchInvitationStore.lastPresentedAt(in: defaults) == nil)
        check("reset leaves workout data alone", defaults.data(forKey: "savedWorkouts") == Data("workouts".utf8))
        check(
            "reset install can be offered",
            ResearchInvitationPolicy.shouldPresent(
                homeReady: true,
                onHomeTab: true,
                workoutInterfaceVisible: false,
                now: today,
                calendar: calendar,
                defaults: defaults
            )
        )

        ResearchInvitationStore.notePresented(at: today, defaults: defaults)
        ResearchInvitationStore.markOptedOut(in: defaults)
        ResearchInvitationStore.armImmediatePresentation()
        check(
            "debug show-now bypasses today's date and opt out",
            ResearchInvitationStore.canOfferAutomatically(now: today, calendar: calendar, defaults: defaults)
        )
        check(
            "debug show-now still refuses an active workout",
            !ResearchInvitationPolicy.shouldPresent(
                homeReady: true,
                onHomeTab: true,
                workoutInterfaceVisible: true,
                now: today,
                calendar: calendar,
                defaults: defaults
            )
        )
        ResearchInvitationStore.consumeImmediatePresentation()
        check(
            "after the debug bypass is used, opt out applies again",
            !ResearchInvitationStore.canOfferAutomatically(now: tomorrow, calendar: calendar, defaults: defaults)
        )

        let domain = defaults.persistentDomain(forName: suiteName) ?? [:]
        check("reset domain can be cleared without touching unrelated keys", domain["savedWorkouts"] != nil)

        return Outcome(passed: passed, failed: failed, lines: lines)
    }
}
#endif
