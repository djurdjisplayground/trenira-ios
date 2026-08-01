import Foundation

/// Validation and email payload helpers for Founder Consultation requests.
/// Does not transmit data — the UI presents Mail or a copy fallback.
enum ConsultationService {
    static func validate(
        _ request: ConsultationRequest,
        disclaimerAccepted: Bool
    ) -> [ConsultationValidationError] {
        var errors: [ConsultationValidationError] = []
        if request.trimmedName.isEmpty { errors.append(.emptyName) }
        if request.trimmedEmail.isEmpty {
            errors.append(.emptyEmail)
        } else if !isValidEmail(request.trimmedEmail) {
            errors.append(.invalidEmail)
        }
        if request.trimmedHelpWith.isEmpty { errors.append(.emptyHelpWith) }
        if !disclaimerAccepted { errors.append(.disclaimerNotAccepted) }
        return errors
    }

    static func isValidEmail(_ raw: String) -> Bool {
        let email = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard email.count >= 5, email.count <= ConsultationRequest.maxEmailLength else { return false }
        let pattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        return email.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    static func emailSubject(for request: ConsultationRequest) -> String {
        let name = request.trimmedName
        if name.isEmpty {
            return "trenira consultation request"
        }
        return "trenira consultation request — \(name)"
    }

    static func emailBody(for request: ConsultationRequest) -> String {
        let timezone = request.trimmedTimezone.isEmpty ? "Not specified" : request.trimmedTimezone
        let notes = request.trimmedNotes.isEmpty ? "None" : request.trimmedNotes

        return """
        Hello,

        I would like to request a trenira founder consultation.

        Name:
        \(request.trimmedName)

        Email:
        \(request.trimmedEmail)

        Timezone:
        \(timezone)

        Training experience:
        \(request.experience.label)

        What I would like help with:
        \(request.trimmedHelpWith)

        Additional notes:
        \(notes)

        I understand that this consultation provides educational and organisational support based on lived training experience. It is not medical advice, physiotherapy, injury rehabilitation or professional nutritional treatment.

        Thank you.
        """
    }

    /// Full clipboard payload for the Mail-unavailable fallback (body only is also acceptable; include routing hints).
    static func clipboardRequestPayload(for request: ConsultationRequest) -> String {
        """
        To: \(AppConfiguration.consultationEmail)
        Subject: \(emailSubject(for: request))

        \(emailBody(for: request))
        """
    }

    static func mailtoURL(for request: ConsultationRequest) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = AppConfiguration.consultationEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: emailSubject(for: request)),
            URLQueryItem(name: "body", value: emailBody(for: request)),
        ]
        return components.url
    }

    static func contactMailtoURL() -> URL? {
        URL(string: "mailto:\(AppConfiguration.consultationEmail)")
    }

    /// Maps mail / fallback outcomes to UX effects. Never treats cancel, failure, or copy as “sent”.
    static func effect(for outcome: ConsultationMailOutcome) -> ConsultationMailOutcomeEffect {
        switch outcome {
        case .sent:
            return ConsultationMailOutcomeEffect(
                clearDraft: true,
                showSentSuccess: true,
                statusMessage: ConsultationConfig.successTitle
            )
        case .saved:
            return ConsultationMailOutcomeEffect(
                clearDraft: false,
                showSentSuccess: false,
                statusMessage: ConsultationConfig.mailSavedMessage
            )
        case .cancelled:
            return ConsultationMailOutcomeEffect(
                clearDraft: false,
                showSentSuccess: false,
                statusMessage: nil
            )
        case .failed:
            return ConsultationMailOutcomeEffect(
                clearDraft: false,
                showSentSuccess: false,
                statusMessage: ConsultationConfig.mailFailedMessage
            )
        case .copiedRequest:
            return ConsultationMailOutcomeEffect(
                clearDraft: false,
                showSentSuccess: false,
                statusMessage: ConsultationConfig.requestCopiedMessage
            )
        case .copiedEmailAddress:
            return ConsultationMailOutcomeEffect(
                clearDraft: false,
                showSentSuccess: false,
                statusMessage: ConsultationConfig.emailAddressCopiedMessage
            )
        }
    }

    /// Brand rule helper for tests: user-facing consultation copy must not contain capitalized brand variants.
    static func containsIncorrectBrandCapitalization(_ text: String) -> Bool {
        let banned = ["Trenira", "TRENiRA", "TRENIRA", "Trainera", "trainera", "Turnira", "turnira"]
        return banned.contains { text.contains($0) }
    }
}
