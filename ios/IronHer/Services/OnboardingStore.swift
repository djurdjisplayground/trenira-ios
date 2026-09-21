import Foundation

/// First-launch onboarding completion — device-local, not personal data.
enum OnboardingStore {
    static let storageKey = "trenira.hasCompletedOnboarding"

    static var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: storageKey) }
        set { UserDefaults.standard.set(newValue, forKey: storageKey) }
    }

    static var hasStoredCompletionFlag: Bool {
        UserDefaults.standard.object(forKey: storageKey) != nil
    }

    static func markCompleted() {
        hasCompletedOnboarding = true
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    /// Existing installs with training data must not be sent through the new journey.
    /// Users who already finished the previous intro keep that stored flag.
    static func migrateExistingUsersIfNeeded(hasExistingUserData: Bool) {
        if hasStoredCompletionFlag { return }
        guard hasExistingUserData else { return }
        markCompleted()
    }
}
