import Foundation

/// Central public product configuration for changeable beta / release values.
/// Keep secrets and API keys out of this file.
enum AppConfiguration {
    static let appName = "trenira"
    static let operatorName = "Durdija Tunguz"

    /// Primary beta contact for support, feedback, and consultations.
    static let supportEmail = "trenira@trenira.info"
    static let consultationEmail = supportEmail
    static let feedbackEmail = supportEmail

    static let minimumUserAge = 16
    static let minimumConsultationAge = 18

    /// Shown as the effective date on in-app Privacy Policy and Terms.
    static let legalEffectiveDate = "26 October 2026"

    /// Optional hosted pages — when nil, Settings shows native in-app documents.
    static let privacyPolicyURL: URL? = nil
    static let termsURL: URL? = nil
    static let supportURL: URL? = nil
    static let websiteURL: URL? = URL(string: "https://trenira.app")

    /// Research conversation form. Opened by the feedback invitation and by Settings.
    /// The app only opens this link. It does not attach workout data or any identity.
    static let researchInvitationFormURL: URL? = URL(
        string: "https://docs.google.com/forms/d/e/1FAIpQLScM-Jaltf16kj9AkmVA71tryQJLPGZrgIkSxrJ7j6Y-5s_jRw/viewform"
    )

    static let serviceAvailability = "Worldwide"

    /// Public PostHog project token (`phc_...`). Leave this empty to keep analytics off.
    /// This is a client ingestion token, not a personal API key.
    static let postHogProjectToken = "phc_pRrHtsDDvejTcm6qbU6FcbC5YhFimge5kS3braYrG8R8"

    /// PostHog ingestion host, such as `https://us.i.posthog.com` or `https://eu.i.posthog.com`.
    static let postHogHost = "https://eu.i.posthog.com"
}
