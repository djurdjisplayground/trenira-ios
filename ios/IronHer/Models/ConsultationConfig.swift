import Foundation

/// Contact and product copy for the optional Founder Consultation (not a StoreKit product).
enum ConsultationConfig {
    /// Prefer `AppConfiguration.consultationEmail` — kept as a single alias for consultation UI.
    static var contactEmail: String { AppConfiguration.consultationEmail }

    static let title = "Founder Consultation"
    static let subtitle =
        "Get help simplifying your workout routine, structuring progression and setting up your training inside trenira."
    static let priceLabel = "€39 · 30 minutes"
    static let priceAmount = "€39"
    static let durationLabel = "30 minutes"

    static let bullets: [String] = [
        "Review your current workout routine",
        "Simplify exercise selection",
        "Discuss progression and consistency",
        "Adapt training around travel or changing gyms",
        "Set up your routine inside trenira",
        "Receive a short written recap",
    ]

    static let serviceDescription = """
    A one-to-one conversation focused on organising your training in a clear, sustainable way — and setting it up inside trenira so you can continue on your own.
    """

    static let included: [String] = [
        "30-minute video or voice call",
        "Review of your current routine and goals",
        "Practical suggestions for exercise selection and progression",
        "Help adapting training for travel or changing gyms",
        "Guidance setting up or refining your plan in trenira",
        "A short written recap after the session",
    ]

    static let notIncluded: [String] = [
        "Medical advice or diagnosis",
        "Physiotherapy or injury rehabilitation",
        "Professional nutritional treatment or meal plans",
        "Ongoing coaching or weekly check-ins",
        "Guaranteed strength or physique outcomes",
    ]

    static let founderBlurb = """
    Sessions are with trenira’s founder — sharing practical experience with workout organisation, progressive overload and staying consistent.
    """

    static let scopeNotice = """
    This consultation provides educational and organisational support based on lived training experience. It is not medical advice, physiotherapy, injury rehabilitation, diagnosis or professional nutritional treatment. Please consult an appropriately qualified professional for medical, injury-related or individual dietary concerns.
    """

    static let formExplainer = """
    Requesting a session prepares an email to \(AppConfiguration.consultationEmail). Nothing is sent until you review the message and tap Send in Mail — or copy the request if Mail isn’t available.
    """

    static let disclaimerCheckboxLabel = "I understand the scope of the consultation."

    static let successTitle = "Your request was sent."
    static let successBody = "We’ll confirm availability and send booking and payment details separately."

    static let mailSavedMessage = "Your email was saved as a draft."
    static let mailFailedMessage = "The email could not be sent."
    static let requestCopiedMessage = "Request copied"
    static let emailAddressCopiedMessage = "Email address copied"

    static let mailUnavailableTitle = "Mail is not configured"
    static let mailUnavailableBody = """
    Mail is not configured on this device. You can copy the consultation request and send it to \(AppConfiguration.consultationEmail) using your preferred email app.
    """

    static let draftStorageDescription = """
    Local drafts are stored on this device only under UserDefaults key “\(ConsultationDraftStore.storageKey)”. They are never uploaded. Drafts clear after a successfully sent email, when you tap Clear saved draft, or when you erase all local data.
    """

    /// UI / email strings that must keep the brand lowercase.
    static var userFacingCopySamples: [String] {
        [
            title,
            subtitle,
            serviceDescription,
            founderBlurb,
            scopeNotice,
            formExplainer,
            successTitle,
            successBody,
        ] + bullets + included
    }
}
