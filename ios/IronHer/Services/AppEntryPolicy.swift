import Foundation

/// Where the app goes after welcome. The strength-onboarding flag keeps its old meaning.
enum AppEntry: Equatable {
    /// New install, or anyone who has neither finished strength onboarding nor saved a companion profile.
    case companionOnboarding
    /// Existing strength users, and new users who finished or skipped the companion questions.
    case main
}

enum AppEntryPolicy {
    /// Strength onboarding is no longer a second required gate.
    /// A completed strength flag still means "do not show the old strength intro."
    /// A resolved companion profile lets a new user into the app without setting that flag.
    static func entry(strengthOnboardingCompleted: Bool, companionResolved: Bool) -> AppEntry {
        if strengthOnboardingCompleted || companionResolved {
            return .main
        }
        return .companionOnboarding
    }
}
