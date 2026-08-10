import Foundation

/// First-launch onboarding completion — device-local, not personal data.
enum OnboardingStore {
    static let storageKey = "trenira.hasCompletedOnboarding"

    static var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: storageKey) }
        set { UserDefaults.standard.set(newValue, forKey: storageKey) }
    }

    static func markCompleted() {
        hasCompletedOnboarding = true
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
