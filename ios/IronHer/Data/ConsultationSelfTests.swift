import Foundation

#if DEBUG
/// DEBUG self-tests for Founder Consultation validation, mail outcomes, drafts, and brand copy.
enum ConsultationSelfTests {
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

        let previous = UserDefaults.standard.data(forKey: ConsultationDraftStore.storageKey)
        defer {
            if let previous {
                UserDefaults.standard.set(previous, forKey: ConsultationDraftStore.storageKey)
            } else {
                UserDefaults.standard.removeObject(forKey: ConsultationDraftStore.storageKey)
            }
        }
        ConsultationDraftStore.clear()

        // Required-field validation
        let emptyErrors = Set(ConsultationService.validate(ConsultationRequest(), disclaimerAccepted: true))
        check(
            "empty required fields fail validation",
            emptyErrors == Set([.emptyName, .emptyEmail, .emptyHelpWith])
        )

        // Disclaimer acceptance
        let valid = validSample()
        check(
            "disclaimer required when unchecked",
            ConsultationService.validate(valid, disclaimerAccepted: false) == [.disclaimerNotAccepted]
        )
        check(
            "valid form with disclaimer passes",
            ConsultationService.validate(valid, disclaimerAccepted: true).isEmpty
        )

        // Invalid email
        var badEmail = validSample()
        badEmail.email = "not-an-email"
        check(
            "invalid email fails validation",
            ConsultationService.validate(badEmail, disclaimerAccepted: true) == [.invalidEmail]
        )

        // Brand lowercase in consultation UI strings
        for sample in ConsultationConfig.userFacingCopySamples {
            check(
                "consultation copy has no incorrect brand casing",
                !ConsultationService.containsIncorrectBrandCapitalization(sample)
            )
        }
        check(
            "consultation email uses AppConfiguration value",
            AppConfiguration.consultationEmail == "trenira@trenira.info"
                && ConsultationConfig.contactEmail == AppConfiguration.consultationEmail
        )

        // Subject / body
        let subject = ConsultationService.emailSubject(for: valid)
        check(
            "subject uses name",
            subject == "trenira consultation request — Alex Example"
        )
        let body = ConsultationService.emailBody(for: valid)
        check("body greets and requests consultation", body.contains("I would like to request a trenira founder consultation."))
        check("body includes name block", body.contains("Name:\nAlex Example"))
        check("body includes email block", body.contains("Email:\nalex@example.com"))
        check("body includes timezone", body.contains("Timezone:\nCET"))
        check("body includes experience", body.contains("Training experience:\nIntermediate"))
        check("body includes help with", body.contains("What I would like help with:\nProgression and travel weeks"))
        check("body uses None for empty notes", body.contains("Additional notes:\nNone"))
        check("body recipient config is central", !body.lowercased().contains("durdijatunguz"))

        // Mailto / clipboard
        let mailto = ConsultationService.mailtoURL(for: valid)
        check("mailto builds", mailto != nil)
        check(
            "mailto recipient is consultation email",
            mailto?.absoluteString.contains(AppConfiguration.consultationEmail) == true
        )
        let clipboard = ConsultationService.clipboardRequestPayload(for: valid)
        check("clipboard payload includes recipient", clipboard.contains("To: \(AppConfiguration.consultationEmail)"))
        check("clipboard payload includes body", clipboard.contains(body))

        // Mail outcome effects — no false success
        let sent = ConsultationService.effect(for: .sent)
        check("sent clears draft and shows success", sent.clearDraft && sent.showSentSuccess)

        let saved = ConsultationService.effect(for: .saved)
        check("saved keeps draft and does not claim sent", !saved.clearDraft && !saved.showSentSuccess)
        check("saved status is draft message", saved.statusMessage == ConsultationConfig.mailSavedMessage)

        let cancelled = ConsultationService.effect(for: .cancelled)
        check("cancelled has no success and no status", !cancelled.clearDraft && !cancelled.showSentSuccess && cancelled.statusMessage == nil)

        let failedEffect = ConsultationService.effect(for: .failed)
        check("failed has no success", !failedEffect.clearDraft && !failedEffect.showSentSuccess)
        check("failed status message", failedEffect.statusMessage == ConsultationConfig.mailFailedMessage)

        let copied = ConsultationService.effect(for: .copiedRequest)
        check("copy request does not claim sent", !copied.clearDraft && !copied.showSentSuccess)
        check("copy request status", copied.statusMessage == ConsultationConfig.requestCopiedMessage)

        let copiedEmail = ConsultationService.effect(for: .copiedEmailAddress)
        check("copy email address does not claim sent", !copiedEmail.clearDraft && !copiedEmail.showSentSuccess)
        check(
            "copy email address status",
            copiedEmail.statusMessage == ConsultationConfig.emailAddressCopiedMessage
        )

        // Draft retention / deletion
        ConsultationDraftStore.save(valid)
        check("draft save round-trip", ConsultationDraftStore.load()?.trimmedName == valid.trimmedName)

        // Simulate cancel retention
        _ = ConsultationService.effect(for: .cancelled)
        check("draft retained after cancellation effect", ConsultationDraftStore.load() != nil)

        // Simulate successful send clearing
        if ConsultationService.effect(for: .sent).clearDraft {
            ConsultationDraftStore.clear()
        }
        check("draft deleted after successful send", ConsultationDraftStore.load() == nil)

        // Erasure inventory
        check(
            "erasure inventory contains consultation draft key",
            LocalDataErasureService.userContentUserDefaultsKeys.contains(ConsultationDraftStore.storageKey)
        )

        ConsultationDraftStore.save(valid)
        UserDefaults.standard.removeObject(forKey: ConsultationDraftStore.storageKey)
        check("consultation draft removed like account/data deletion", ConsultationDraftStore.load() == nil)

        // Length clamping
        var long = validSample()
        long.name = String(repeating: "a", count: 200)
        long.clampFieldLengths()
        check("name clamped to max length", long.name.count == ConsultationRequest.maxNameLength)

        return Outcome(passed: passed, failed: failed, lines: lines)
    }

    private static func validSample() -> ConsultationRequest {
        ConsultationRequest(
            name: "Alex Example",
            email: "alex@example.com",
            mainGoal: "",
            experience: .intermediate,
            helpWith: "Progression and travel weeks",
            preferredTimezone: "CET",
            optionalNotes: "",
            updatedAt: .now
        )
    }
}
#endif
