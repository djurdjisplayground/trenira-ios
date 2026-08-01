import SwiftUI

/// Single source of truth for product branding.
/// Change `displayName` / tagline lines here to update branding everywhere in UI.
enum BrandIdentity {
    /// Official product name — always lowercase in UI.
    static let displayName = "trenira"

    /// Official tagline — two lines, exact formatting for brand surfaces.
    static let taglineLine1 = "Strength,"
    static let taglineLine2 = "on your own terms."

    /// Single-line form for inline copy (celebration, footnotes, etc.).
    static var taglineInline: String {
        "\(taglineLine1) \(taglineLine2)"
    }

    /// Brand philosophy for longer surfaces.
    static let philosophy =
        "A calm companion for strength training. Organize workouts, stay consistent, and get stronger — without unnecessary complexity. You stay in control."

    /// Default mark — thin ends + pronounced flowing S connector.
    static let defaultMarkStyle: BrandMarkStyle = .flowingS

    // MARK: - Contextual copy

    static var welcomeSignedIn: String {
        "Stay consistent. Get stronger. \(taglineInline)"
    }

    static var welcomeSignedOut: String {
        "Welcome to \(displayName)."
    }

    static var progressionRemembers: String {
        "You define how you progress. \(displayName) remembers and quietly updates your next workout."
    }

    static var freePlanSubtitle: String {
        "Everything you need to track your workouts."
    }

    static var premiumPlanSubtitle: String {
        "Go beyond tracking."
    }

    /// Slight tracking keeps the lowercase wordmark open and modern.
    static let wordmarkTracking: CGFloat = 1.4
}
