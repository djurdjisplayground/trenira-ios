import Foundation
import Observation
import StoreKit

/// StoreKit 2 subscription manager.
/// Verified App Store entitlements are the only source of truth for Premium.
@Observable
@MainActor
final class SubscriptionStore {
    static let freeWorkoutPlanLimit = 3

    private(set) var products: [Product] = []
    /// Always reflects the latest verified StoreKit entitlement check — never UserDefaults.
    private(set) var isPremium = false
    private(set) var isLoadingProducts = false
    private(set) var isProcessingPurchase = false
    private(set) var isRestoring = false
    /// True after the first finished entitlement scan (avoids trusting a stale UI flash).
    private(set) var hasResolvedEntitlements = false
    private(set) var revision = 0
    private(set) var introOfferEligibility: [String: Bool] = [:]
    private(set) var activeEntitlementProductIDs: [String] = []

    /// Currently selected paywall product (defaults to yearly when available).
    var selectedProductID: String?

    var purchaseErrorMessage: String?
    var restoreStatusMessage: String?
    var purchaseStatusMessage: String?

    private var transactionListener: Task<Void, Never>?
    private let legacyTierKey = "subscriptionTier"
    private let legacyEntitlementKey = "premiumEntitlementActive"
    private let legacyPremiumCacheKey = "cachedPremiumUIState"

    init() {
        // Never unlock from disk — wait for verified StoreKit entitlements.
        isPremium = false
        clearPersistedPremiumFlags()
        transactionListener = listenForTransactions()
        Task { await bootstrap() }
    }

    /// Effective Premium for product access — StoreKit entitlement **or** closed beta unlock.
    /// `isPremium` remains StoreKit-only so beta can be turned off without lying about purchases.
    var hasPremiumAccess: Bool {
        BetaConfig.unlocksPremium || isPremium
    }

    var currentTier: SubscriptionTier {
        hasPremiumAccess ? .premium : .free
    }

    var yearlyProduct: Product? {
        products.first { $0.id == PremiumProductID.yearly }
    }

    var monthlyProduct: Product? {
        products.first { $0.id == PremiumProductID.monthly }
    }

    var selectedProduct: Product? {
        guard let selectedProductID else { return nil }
        return products.first { $0.id == selectedProductID }
    }

    var orderedProducts: [Product] {
        PremiumProductID.ordered.compactMap { id in
            products.first { $0.id == id }
        }
    }

    func canCreateWorkoutPlan(currentCount: Int) -> Bool {
        hasPremiumAccess || currentCount < Self.freeWorkoutPlanLimit
    }

    func remainingFreeWorkoutPlans(currentCount: Int) -> Int {
        max(0, Self.freeWorkoutPlanLimit - currentCount)
    }

    func hasAccess(to feature: SubscriptionFeature) -> Bool {
        if BetaConfig.unlocksPremium { return true }

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

    func isEligibleForIntroOffer(productID: String) -> Bool {
        introOfferEligibility[productID] ?? false
    }

    // MARK: - StoreKit

    func bootstrap() async {
        await loadProducts()
        await refreshEntitlements()
    }

    /// Call whenever the app returns to the foreground so expired / deleted
    /// StoreKit Testing transactions drop Premium immediately.
    func handleAppBecameActive() async {
        PaywallDebug.log("App became active — refreshing entitlements")
        await refreshEntitlements()
    }

    func loadProducts() async {
        isLoadingProducts = true
        let requested = Array(PremiumProductID.ordered)
        PaywallDebug.log("Requested product identifiers: \(requested)")
        defer { isLoadingProducts = false }

        do {
            let storeProducts = try await Product.products(for: Set(requested))
            PaywallDebug.log(
                "Products returned by StoreKit: \(storeProducts.map { "\($0.id) \($0.displayPrice)" })"
            )

            products = requested.compactMap { id in
                storeProducts.first { $0.id == id }
            }

            if products.isEmpty {
                purchaseErrorMessage = "No subscription products were returned. Check that the StoreKit Configuration is selected for this scheme, then try again."
                PaywallDebug.log("Products returned by StoreKit: [] (empty)")
            } else if purchaseErrorMessage?.contains("subscription") == true {
                purchaseErrorMessage = nil
            }

            if selectedProductID == nil || selectedProduct == nil {
                selectedProductID = yearlyProduct?.id ?? monthlyProduct?.id ?? products.first?.id
            }

            await refreshIntroOfferEligibility()
        } catch {
            if products.isEmpty {
                purchaseErrorMessage = "Couldn't load subscription options. Check your StoreKit Configuration and try again."
            } else {
                purchaseErrorMessage = "Couldn't refresh subscription options. You can still use the loaded products or retry."
            }
            PaywallDebug.log("Products loading failed: \(error.localizedDescription)")
        }
    }

    /// Starts the system App Store purchase sheet for the selected subscription.
    @discardableResult
    func purchase(_ product: Product) async -> PurchaseOutcome {
        isProcessingPurchase = true
        purchaseErrorMessage = nil
        restoreStatusMessage = nil
        purchaseStatusMessage = nil
        PaywallDebug.log("Purchase started (product=\(product.id), price=\(product.displayPrice))")
        defer { isProcessingPurchase = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try Self.checkVerified(verification)
                PaywallDebug.log(
                    "Purchase result: success verified (product=\(transaction.productID), id=\(transaction.id))"
                )

                // Deliver content from the verified transaction first.
                // StoreKit Testing / currentEntitlements can lag behind purchase(),
                // which previously left isPremium=false after a successful buy.
                applyPremiumFromPurchaseTransaction(transaction)
                await transaction.finish()
                await refreshEntitlements()

                // One short retry — entitlements sometimes appear a moment later.
                if !isPremium {
                    try? await Task.sleep(for: .milliseconds(400))
                    await refreshEntitlements()
                    if !isPremium {
                        applyPremiumFromPurchaseTransaction(transaction)
                    }
                }

                if isPremium {
                    purchaseStatusMessage = "Premium is active."
                    return .success
                } else {
                    purchaseErrorMessage = "Purchase completed, but Premium isn't active yet. Try Restore Purchases."
                    return .unverified
                }

            case .userCancelled:
                PaywallDebug.log("Purchase result: cancelled")
                return .cancelled

            case .pending:
                purchaseStatusMessage = "Purchase is pending approval. Premium unlocks when it's approved."
                PaywallDebug.log("Purchase result: pending")
                return .pending

            @unknown default:
                purchaseErrorMessage = "Something unexpected happened. Please try again."
                PaywallDebug.log("Purchase result: unknown")
                return .failed
            }
        } catch StoreKitError.userCancelled {
            PaywallDebug.log("Purchase result: cancelled")
            return .cancelled
        } catch {
            purchaseErrorMessage = error.localizedDescription
            PaywallDebug.log("Purchase result: failed (\(error.localizedDescription))")
            return .failed
        }
    }

    @discardableResult
    func purchaseSelected() async -> PurchaseOutcome {
        guard let product = selectedProduct else {
            purchaseErrorMessage = "No subscription option is selected."
            PaywallDebug.log("Purchase result: failed (no product selected)")
            return .failed
        }
        return await purchase(product)
    }

    /// Resynchronizes purchases with the App Store, then re-reads verified entitlements.
    /// Does not open account settings and does not dismiss the current screen.
    func restorePurchases() async {
        isRestoring = true
        isProcessingPurchase = true
        purchaseErrorMessage = nil
        restoreStatusMessage = nil
        purchaseStatusMessage = nil
        PaywallDebug.log("AppStore.sync() started")
        defer {
            isRestoring = false
            isProcessingPurchase = false
        }

        do {
            try await AppStore.sync()
            PaywallDebug.log("AppStore.sync() succeeded")
            await refreshEntitlements()

            if isPremium {
                restoreStatusMessage = "Your Premium subscription has been restored."
            } else {
                restoreStatusMessage = "No active purchases were found."
            }
        } catch {
            PaywallDebug.log("AppStore.sync() failed: \(error.localizedDescription)")
            restoreStatusMessage = nil
            purchaseErrorMessage = "Purchases could not be restored. Please try again."
        }
    }

    /// Single source of truth: scans verified `Transaction.currentEntitlements`.
    /// Sets Free when no active monthly/yearly Premium subscription exists.
    func refreshEntitlements() async {
        var activePremium = false
        var activeIDs: [String] = []

        for await entitlement in Transaction.currentEntitlements {
            guard let transaction = try? Self.checkVerified(entitlement) else {
                PaywallDebug.log("Entitlement skipped: unverified")
                continue
            }

            guard PremiumProductID.all.contains(transaction.productID) else { continue }

            let expiration = transaction.expirationDate.map { String(describing: $0) } ?? "nil"
            let revocation = transaction.revocationDate.map { String(describing: $0) } ?? "nil"
            PaywallDebug.log(
                "Entitlement candidate product=\(transaction.productID) expiration=\(expiration) revocation=\(revocation)"
            )

            if let revocationDate = transaction.revocationDate {
                PaywallDebug.log(
                    "Entitlement ignored (revoked) product=\(transaction.productID) at \(revocationDate)"
                )
                continue
            }

            if let expirationDate = transaction.expirationDate, expirationDate < Date() {
                PaywallDebug.log(
                    "Entitlement ignored (expired) product=\(transaction.productID) at \(expirationDate)"
                )
                continue
            }

            activePremium = true
            activeIDs.append(transaction.productID)
        }

        PaywallDebug.log(
            "Current entitlement product IDs: \(activeIDs.isEmpty ? "[]" : activeIDs.description)"
        )
        applyPremiumState(activePremium, activeProductIDs: activeIDs)
        hasResolvedEntitlements = true
    }

    // MARK: - Private

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try Self.checkVerified(update)
                    let expiration = transaction.expirationDate.map { String(describing: $0) } ?? "nil"
                    let revocation = transaction.revocationDate.map { String(describing: $0) } ?? "nil"
                    PaywallDebug.log(
                        "Transaction updates: product=\(transaction.productID) id=\(transaction.id) expiration=\(expiration) revocation=\(revocation)"
                    )
                    await transaction.finish()
                    await self.refreshEntitlements()
                } catch {
                    PaywallDebug.log("Transaction updates: unverified (\(error.localizedDescription))")
                    // Still re-check — a failed verify shouldn't leave stale Premium.
                    await self.refreshEntitlements()
                }
            }
        }
    }

    private func refreshIntroOfferEligibility() async {
        var eligibility: [String: Bool] = [:]
        for product in products {
            if let subscription = product.subscription {
                eligibility[product.id] = await subscription.isEligibleForIntroOffer
            } else {
                eligibility[product.id] = false
            }
        }
        introOfferEligibility = eligibility
    }

    private func applyPremiumState(_ premium: Bool, activeProductIDs: [String]) {
        let previous = isPremium
        isPremium = premium
        activeEntitlementProductIDs = activeProductIDs

        if previous != premium {
            revision += 1
            PaywallDebug.log(
                "Membership state change: \(previous ? "Premium" : "Free") → \(premium ? "Premium" : "Free")"
            )
        } else {
            PaywallDebug.log(
                "Membership state unchanged: \(premium ? "Premium" : "Free")"
            )
        }
    }

    /// Activates Premium from a just-purchased verified transaction when product IDs match.
    private func applyPremiumFromPurchaseTransaction(_ transaction: Transaction) {
        guard PremiumProductID.all.contains(transaction.productID) else {
            PaywallDebug.log(
                "Purchase transaction product \(transaction.productID) is not a known Premium ID"
            )
            return
        }
        if let revocationDate = transaction.revocationDate {
            PaywallDebug.log("Purchase transaction revoked at \(revocationDate)")
            return
        }
        if let expirationDate = transaction.expirationDate, expirationDate < Date() {
            PaywallDebug.log("Purchase transaction already expired at \(expirationDate)")
            return
        }
        applyPremiumState(true, activeProductIDs: [transaction.productID])
    }

    nonisolated private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    /// Removes any legacy / cached Premium flags so disk state cannot unlock access.
    private func clearPersistedPremiumFlags() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: legacyEntitlementKey)
        defaults.removeObject(forKey: legacyTierKey)
        defaults.removeObject(forKey: legacyPremiumCacheKey)
        PaywallDebug.log("Cleared persisted Premium flags from UserDefaults")
    }
}

enum PurchaseOutcome: Equatable {
    case success
    case pending
    case cancelled
    case failed
    case unverified
}

enum SubscriptionError: LocalizedError {
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            "Subscription verification failed."
        }
    }
}
