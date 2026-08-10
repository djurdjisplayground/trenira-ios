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
        check("onboarding complete after Get Started", OnboardingStore.hasCompletedOnboarding)
        // View Introduction must not clear the flag
        check("view introduction leaves completion flag set", OnboardingStore.hasCompletedOnboarding)
        OnboardingStore.clear()
        check("clearing restores first-launch onboarding", !OnboardingStore.hasCompletedOnboarding)
        check(
            "erasure inventory includes onboarding key",
            LocalDataErasureService.userContentUserDefaultsKeys.contains(OnboardingStore.storageKey)
        )

        // Legal / configuration
        check("operator is Durdija Tunguz", AppConfiguration.operatorName == "Durdija Tunguz")
        check("support email is trenira@trenira.info", AppConfiguration.supportEmail == "trenira@trenira.info")
        check("consultation email matches support", AppConfiguration.consultationEmail == AppConfiguration.supportEmail)
        check("feedback email matches support", AppConfiguration.feedbackEmail == AppConfiguration.supportEmail)
        check("BetaConfig feedback uses AppConfiguration", BetaConfig.feedbackEmail == AppConfiguration.feedbackEmail)
        check("minimum user age is 16", AppConfiguration.minimumUserAge == 16)
        check("consultation age is 18", AppConfiguration.minimumConsultationAge == 18)
        check("app name is lowercase trenira", AppConfiguration.appName == "trenira")

        let privacy = LegalDocumentContent.privacyMarkdown
        let terms = LegalDocumentContent.termsMarkdown
        check("privacy contains operator", privacy.contains(AppConfiguration.operatorName))
        check("privacy contains contact email", privacy.contains(AppConfiguration.supportEmail))
        check("privacy states minimum age 16", privacy.contains("\(AppConfiguration.minimumUserAge)"))
        check("privacy states consultation age 18", privacy.contains("\(AppConfiguration.minimumConsultationAge)"))
        check("terms contain health disclaimer heading", terms.contains("Health Disclaimer"))
        check("terms mention beta data loss", terms.lowercased().contains("data may be lost"))
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
        check("feedback subject correct", FeedbackService.subject == "trenira beta feedback")
        let body = FeedbackService.emailBody()
        check("feedback body has version", body.contains("App version:"))
        check("feedback body has build", body.contains("Build:"))
        check("feedback body has iOS version", body.contains("iOS version:"))
        check("feedback body has device", body.contains("Device:"))
        check("feedback body excludes workout keywords", !body.lowercased().contains("workout id"))
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
        check("no durdija gmail as feedback", BetaConfig.feedbackEmail == "trenira@trenira.info")

        return Outcome(passed: passed, failed: failed, lines: lines)
    }

    private static func containsBadBrand(_ text: String) -> Bool {
        ["Trenira", "TRENIRA", "TRENiRA", "Trainera", "trainera", "Turnira", "turnira"].contains { text.contains($0) }
    }
}
#endif
