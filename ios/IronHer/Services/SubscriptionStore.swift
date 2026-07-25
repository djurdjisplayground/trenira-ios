import Foundation

@Observable
@MainActor
final class SubscriptionStore {
    static let freeWorkoutPlanLimit = 3

    private(set) var currentTier: SubscriptionTier = .free
    private(set) var isProcessingPurchase = false
    private(set) var revision = 0
    var purchaseErrorMessage: String?
    var restoreStatusMessage: String?

    private let tierDefaultsKey = "subscriptionTier"
    private let premiumEntitlementKey = "premiumEntitlementActive"

    init() {
        restoreSavedTier()
    }

    var isPremium: Bool { currentTier == .premium }

    func canCreateWorkoutPlan(currentCount: Int) -> Bool {
        isPremium || currentCount < Self.freeWorkoutPlanLimit
    }

    func remainingFreeWorkoutPlans(currentCount: Int) -> Int {
        max(0, Self.freeWorkoutPlanLimit - currentCount)
    }

    func hasAccess(to feature: SubscriptionFeature) -> Bool {
        switch feature {
        case .workoutPlans, .exerciseTracking, .workoutLibrary,
             .weeklyTracking, .basicHistory, .exerciseLibrary,
             .exerciseSync, .progressionAutomation, .customProgression,
             .multipleLanguages, .appearanceModes:
            return true
        case .unlimitedWorkoutPlans, .smartProgressHistory,
             .progressTrends, .smarterProgressionAnalysis,
             .adaptWorkout, .replaceExercise,
             .generateWorkout, .regenerateWorkout:
            return isPremium
        }
    }

    func setTier(_ tier: SubscriptionTier) {
        guard currentTier != tier else { return }
        currentTier = tier
        persistTier()
        revision += 1
    }

    func upgradeToPremium() {
        isProcessingPurchase = true
        purchaseErrorMessage = nil
        restoreStatusMessage = nil

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            recordPremiumEntitlement()
            setTier(.premium)
            isProcessingPurchase = false
        }
    }

    func downgradeToFree() {
        purchaseErrorMessage = nil
        restoreStatusMessage = nil
        setTier(.free)
    }

    func restorePurchases() {
        isProcessingPurchase = true
        purchaseErrorMessage = nil
        restoreStatusMessage = nil

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))

            if hasPremiumEntitlement {
                setTier(.premium)
                restoreStatusMessage = "Premium restored."
            } else {
                setTier(.free)
                purchaseErrorMessage = "No previous Premium purchase was found."
            }

            revision += 1
            isProcessingPurchase = false
        }
    }

    func unlockPremiumForTesting() {
        purchaseErrorMessage = nil
        restoreStatusMessage = nil
        recordPremiumEntitlement()
        setTier(.premium)
    }

    func resetToFreeForTesting() {
        clearPremiumEntitlement()
        setTier(.free)
    }

    private var hasPremiumEntitlement: Bool {
        UserDefaults.standard.bool(forKey: premiumEntitlementKey)
    }

    private func recordPremiumEntitlement() {
        UserDefaults.standard.set(true, forKey: premiumEntitlementKey)
    }

    private func clearPremiumEntitlement() {
        UserDefaults.standard.removeObject(forKey: premiumEntitlementKey)
    }

    private func restoreSavedTier() {
        if let raw = UserDefaults.standard.string(forKey: tierDefaultsKey),
           let tier = SubscriptionTier(rawValue: raw) {
            currentTier = tier
        } else if hasPremiumEntitlement {
            currentTier = .premium
        } else {
            currentTier = .free
        }
    }

    private func persistTier() {
        UserDefaults.standard.set(currentTier.rawValue, forKey: tierDefaultsKey)
    }
}
