import Foundation

#if DEBUG
/// DEBUG self-tests for TestFlight onboarding, legal config, feedback and brand rules.
enum TestFlightPrepSelfTests {
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

        // Onboarding flag isolation
        let previous = UserDefaults.standard.object(forKey: OnboardingStore.storageKey)
        defer {
            if let flag = previous as? Bool {
                OnboardingStore.hasCompletedOnboarding = flag
            } else if previous == nil {
                OnboardingStore.clear()
            } else {
                UserDefaults.standard.set(previous, forKey: OnboardingStore.storageKey)
            }
        }

        OnboardingStore.clear()
        check("onboarding incomplete on first launch", !OnboardingStore.hasCompletedOnboarding)
        OnboardingStore.markCompleted()
        check("onboarding complete after journey finishes", OnboardingStore.hasCompletedOnboarding)
        // View Introduction must not clear the flag
        check("view introduction leaves completion flag set", OnboardingStore.hasCompletedOnboarding)
        OnboardingStore.clear()
        check("clearing restores first-launch onboarding", !OnboardingStore.hasCompletedOnboarding)
        check(
            "erasure inventory includes onboarding key",
            LocalDataErasureService.userContentUserDefaultsKeys.contains(OnboardingStore.storageKey)
        )
        check(
            "erasure inventory includes calibration key",
            LocalDataErasureService.userContentUserDefaultsKeys.contains(StrengthCalibrationStore.storageKey)
        )

        // Legal / configuration
        check("operator is Durdija Tunguz", AppConfiguration.operatorName == "Durdija Tunguz")
        check("support email is trenira@trenira.info", AppConfiguration.supportEmail == "trenira@trenira.info")
        check("consultation email matches support", AppConfiguration.consultationEmail == AppConfiguration.supportEmail)
        check("feedback email matches support", AppConfiguration.feedbackEmail == AppConfiguration.supportEmail)
        check("ProductAccessConfig feedback uses AppConfiguration", ProductAccessConfig.feedbackEmail == AppConfiguration.feedbackEmail)
        check("minimum user age is 16", AppConfiguration.minimumUserAge == 16)
        check("consultation age is 18", AppConfiguration.minimumConsultationAge == 18)
        check("app name is lowercase trenira", AppConfiguration.appName == "trenira")
        check("display name stays lowercase trenira", BrandIdentity.displayName == "trenira")
        check("tagline is the movement line", BrandIdentity.taglineInline == "Movement that fits your life.")

        let privacy = LegalDocumentContent.privacyMarkdown
        let terms = LegalDocumentContent.termsMarkdown
        check("privacy contains operator", privacy.contains(AppConfiguration.operatorName))
        check("privacy contains contact email", privacy.contains(AppConfiguration.supportEmail))
        check("privacy states minimum age 16", privacy.contains("\(AppConfiguration.minimumUserAge)"))
        check("privacy states consultation age 18", privacy.contains("\(AppConfiguration.minimumConsultationAge)"))
        check("terms contain health disclaimer heading", terms.contains("Health Disclaimer"))
        check("terms reject symptom prescriptions", terms.contains("does not prescribe exercise for symptoms"))
        check("terms do not claim universal postpartum safety", !terms.localizedCaseInsensitiveContains("medically safe for all"))
        check("terms mention account deletion", terms.lowercased().contains("delete account"))
        check("privacy mentions delete account", privacy.lowercased().contains("delete account"))
        check("privacy has no beta branding", !privacy.localizedCaseInsensitiveContains("testflight") && !privacy.localizedCaseInsensitiveContains("early beta"))
        check("terms have no beta branding", !terms.localizedCaseInsensitiveContains("testflight") && !terms.localizedCaseInsensitiveContains("closed beta"))
        check("privacy has no incorrect brand casing", !containsBadBrand(privacy))
        check("terms have no incorrect brand casing", !containsBadBrand(terms))
        check("privacy does not claim GDPR certification", !privacy.lowercased().contains("fully gdpr compliant"))
        check(
            "privacy has no lawyer-review note",
            !privacy.localizedCaseInsensitiveContains("lawyer review")
        )
        check(
            "terms have no lawyer-review note",
            !terms.localizedCaseInsensitiveContains("lawyer review")
        )
        check(
            "privacy has no internal-note marker",
            !privacy.localizedCaseInsensitiveContains("internal note")
        )
        check(
            "terms have no internal-note marker",
            !terms.localizedCaseInsensitiveContains("internal note")
        )
        check(
            "privacy keeps effective date",
            privacy.contains(AppConfiguration.legalEffectiveDate)
        )
        let parsedPrivacy = LegalDocumentParser.parse(privacy)
        check("privacy parser extracts title", parsedPrivacy.title == "Privacy Policy")
        check("privacy parser extracts effective date", parsedPrivacy.effectiveDate == AppConfiguration.legalEffectiveDate)
        check("privacy parser has sections", parsedPrivacy.sections.count >= 10)
        let parsedTerms = LegalDocumentParser.parse(terms)
        check("terms parser extracts title", parsedTerms.title == "Terms & Conditions")
        check("terms parser has health disclaimer", parsedTerms.sections.contains { $0.heading.contains("Health Disclaimer") })

        // Feedback / email
        check("feedback recipient correct", FeedbackService.recipient == "trenira@trenira.info")
        check("feedback subject correct", FeedbackService.subject == "trenira feedback")
        let body = FeedbackService.emailBody()
        check("feedback body has version", body.contains("App version:"))
        check("feedback body has build", body.contains("Build:"))
        check("feedback body has iOS version", body.contains("iOS version:"))
        check("feedback body has device", body.contains("Device:"))
        check("feedback body excludes workout keywords", !body.lowercased().contains("workout id"))
        check("feedback body is not beta-branded", !body.localizedCaseInsensitiveContains("i'm testing") && !body.localizedCaseInsensitiveContains("i’m testing"))
        check("feedback clipboard includes recipient", FeedbackService.clipboardPayload().contains("To: \(AppConfiguration.feedbackEmail)"))
        check("feedback mailto builds", FeedbackService.mailtoURL() != nil)

        // Consultation outcomes still correct
        check("consultation cancel is not success", !ConsultationService.effect(for: .cancelled).showSentSuccess)
        check("consultation failure is not success", !ConsultationService.effect(for: .failed).showSentSuccess)
        check("consultation sent is success", ConsultationService.effect(for: .sent).showSentSuccess)
        check(
            "consultation draft in erasure inventory",
            LocalDataErasureService.userContentUserDefaultsKeys.contains(ConsultationDraftStore.storageKey)
        )

        // Progression still 2.5
        check("default increment remains 2.5", WeightProgressionCalculator.defaultIncrementKg == 2.5)
        check(
            "17.5 + 2.5 = 20",
            WeightProgressionCalculator.addIncrement(currentKg: 17.5, incrementKg: 2.5) == 20.0
        )

        // Obsolete emails
        check("no hello@trenira.app in support config", !AppConfiguration.supportEmail.contains("hello@"))
        check("no durdija gmail as feedback", ProductAccessConfig.feedbackEmail == "trenira@trenira.info")

        return Outcome(passed: passed, failed: failed, lines: lines)
    }

    private static func containsBadBrand(_ text: String) -> Bool {
        ["Trenira", "TRENIRA", "TRENiRA", "Trainera", "trainera", "Turnira", "turnira"].contains { text.contains($0) }
    }
}

enum PilotMovementSelfTests {
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

        let short = PilotSuggestions.make(minutes: 2, energy: nil)
        let longer = PilotSuggestions.make(minutes: 20, energy: .low)
        check("a short moment still offers guided movement", short.contains { $0.action == .guided })
        check("a short moment still offers something else", short.contains { $0.action == .manual })
        check("energy is not required to see choices", short.count == 4)
        check("low energy does not remove a choice", longer.count == 4)
        check("something else is one of the choices", longer.contains { $0.action == .manual })

        var clock = MovementSessionClock()
        let start = Date(timeIntervalSince1970: 1_000)
        clock.start(at: start)
        clock.pause(at: start.addingTimeInterval(12))
        clock.resume(at: start.addingTimeInterval(40))
        clock.pause(at: start.addingTimeInterval(47))
        check("paused time is not counted", clock.elapsed(at: start.addingTimeInterval(80)) == 19)
        clock.settleAfterRestore()
        check("restore does not keep the clock running", !clock.isRunning)

        let immediate = MomentRecordBuilder.record(
            kind: .guided,
            title: "Gentle guided movement",
            elapsed: 0,
            plannedMinutes: 5,
            ownerId: "guest:pilot"
        )
        check("an immediate finish stays at zero seconds", immediate.actualDurationSeconds == 0)
        check("an immediate finish is not stored as one minute", immediate.actualMinutes == 0)

        let eight = MomentRecordBuilder.record(
            kind: .stretching,
            title: "Dance or stretch",
            elapsed: 8.9,
            plannedMinutes: 5,
            ownerId: "guest:pilot"
        )
        check("seconds are kept exactly", eight.actualDurationSeconds == 8.9)
        check("seconds are not rounded up to a minute", eight.actualMinutes == 0)
        check("finishing early still counts as a saved duration", eight.finishedEarlier)

        let legacy = """
        {"id":"11111111-1111-1111-1111-111111111111","kind":"walking","title":"Old walk","completedAt":0,"actualMinutes":6,"ownerId":"guest:pilot"}
        """.data(using: .utf8)!
        let decoded = try? JSONDecoder().decode(MovementRecord.self, from: legacy)
        check("an older minute record still decodes", decoded?.actualMinutes == 6 && decoded?.actualDurationSeconds == nil)

        let summary = MovementJournal.weekSummary(items: MovementJournal.items(records: [eight], strengthLogs: []))
        let line = MovementJournal.weekLine(summary)
        check("a few seconds are not described as zero minutes", !line.contains("0 minutes"))
        check("a few seconds are not described as one minute", !line.contains("1 minute"))
        check("the journal can say seconds", line.contains("8 seconds"))

        let defaults = UserDefaults(suiteName: "trenira.pilotSelfTests.\(UUID().uuidString)")!
        let draft = PausedMovementDraft(
            ownerId: "guest:pilot",
            kind: .walking,
            title: "Walk",
            plannedMinutes: 5,
            movementIDs: [],
            movementIndex: 0,
            accumulatedSeconds: 15
        )
        PausedMovementDraftStore.save(draft, defaults: defaults)
        check("a paused moment stays with its account", PausedMovementDraftStore.load(ownerId: "guest:pilot", defaults: defaults)?.accumulatedSeconds == 15)
        check("another account does not see the paused moment", PausedMovementDraftStore.load(ownerId: "guest:other", defaults: defaults) == nil)
        PausedMovementDraftStore.clear(ownerId: "guest:pilot", defaults: defaults)
        check("letting a paused moment go removes it", PausedMovementDraftStore.load(ownerId: "guest:pilot", defaults: defaults) == nil)
        check(
            "erasure inventory contains a paused moment",
            LocalDataErasureService.userContentUserDefaultsKeys.contains("trenira.pausedMovement.v1")
        )
        check("guided movement uses its own activity type", MovementRecordKind.guided.analyticsActivityType == "guided")
        check("stretching uses its own activity type", MovementRecordKind.stretching.analyticsActivityType == "stretching")
        check(
            "pilot illustrations use named asset slots",
            PilotMovementCatalog.illustrationAssetNames == [
                "gentle_reach_start", "gentle_reach_reach", "gentle_reach_relax",
                "side_stretch_start", "side_stretch_middle", "side_stretch_finish",
                "shoulder_rolls_start", "shoulder_rolls_middle", "shoulder_rolls_finish"
            ]
        )

        return Outcome(passed: passed, failed: failed, lines: lines)
    }
}

/// Debug-only. `xcrun simctl launch … -treniraSelfTests` prints the suites and exits.
enum TreniraSelfTestLaunch {
    static func runIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-treniraSelfTests") else { return }

        var failed = 0
        func report(_ name: String, _ failedCount: Int, _ summary: String) {
            print("SELFTEST \(name)\n\(summary)")
            fflush(stdout)
            if failedCount > 0 { failed += failedCount }
        }

        let companion = CompanionSelfTests.runAll()
        report("companion", companion.failed, companion.summary)
        let movement = MovementActivitySelfTests.runAll()
        report("movement", movement.failed, movement.summary)
        let analytics = AnalyticsSelfTests.runAll()
        report("analytics", analytics.failed, analytics.summary)
        let migration = UserDataMigrationSelfTests.runAll()
        report("account-migration", migration.failed, migration.summary)
        let reminders = MovementReminderSelfTests.runAll()
        report("reminders", reminders.failed, reminders.summary)
        let pilot = PilotMovementSelfTests.runAll()
        report("pilot-movement", pilot.failed, pilot.summary)
        let blueprint = BlueprintSelfTests.runAll()
        report("blueprint", blueprint.failed, blueprint.summary)

        exit(Int32(failed == 0 ? 0 : 1))
    }
}
#endif
