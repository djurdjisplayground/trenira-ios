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
    static let legalEffectiveDate = "31 July 2026"

    /// Optional hosted pages — when nil, Settings shows native in-app documents.
    static let privacyPolicyURL: URL? = nil
    static let termsURL: URL? = nil
    static let supportURL: URL? = nil
    static let websiteURL: URL? = URL(string: "https://trenira.app")

    static let serviceAvailability = "Worldwide"
}
