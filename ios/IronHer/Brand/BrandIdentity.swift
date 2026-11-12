import SwiftUI

/// Single source of truth for product branding.
/// Change `displayName` / tagline lines here to update branding everywhere in UI.
enum BrandIdentity {
    /// Official product name — always lowercase in UI.
    static let displayName = "trenira"

    /// Official tagline — two lines, exact formatting for brand surfaces.
    static let taglineLine1 = "Movement that"
    static let taglineLine2 = "fits your life."

    /// Single-line form for inline copy (celebration, footnotes, etc.).
    static var taglineInline: String {
        "\(taglineLine1) \(taglineLine2)"
    }

    /// Brand philosophy for longer surfaces.
    static let philosophy =
        "A flexible movement companion for moms who want to return to movement, find their rhythm, and build routines around real life. Movement should adapt to motherhood, not the other way around."

    // MARK: - Contextual copy

    static var welcomeSignedIn: String {
        taglineInline
    }

    static var welcomeSignedOut: String {
        "Welcome to \(displayName)."
    }

    static var progressionRemembers: String {
        "You define how you progress. \(displayName) remembers and quietly updates your next strength workout."
    }

    static var freePlanSubtitle: String {
        "Everything you need to keep your workouts."
    }

    static var premiumPlanSubtitle: String {
        "Go beyond tracking."
    }

    /// Slight tracking keeps the lowercase wordmark open and modern.
    static let wordmarkTracking: CGFloat = 1.4
}
