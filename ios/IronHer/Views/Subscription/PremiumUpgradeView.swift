import StoreKit
import SwiftUI

/// Minimal trenira Premium paywall. Prices and periods come from StoreKit.
struct PremiumUpgradeView: View {
    @Environment(SubscriptionStore.self) private var subscriptionStore
    @Environment(LocalizationStore.self) private var l10n
    @Environment(\.dismiss) private var dismiss

    let highlightFeature: SubscriptionFeature?

    @State private var showManageSubscriptions = false

    init(highlightFeature: SubscriptionFeature? = nil) {
        self.highlightFeature = highlightFeature
    }

    var body: some View {
        Group {
            if BetaConfig.hidesMonetization {
                betaUnlockedContent
            } else {
                paywallContent
            }
        }
    }

    /// Closed beta: no pricing, purchases, or upgrade CTA.
    private var betaUnlockedContent: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 10) {
                Text("Full access unlocked")
                    .font(SheLiftsFont.title)
                    .foregroundStyle(IronHerTheme.primaryText)

                Text("Premium features are available to all testers during closed beta. Thanks for helping test trenira.")
                    .font(SheLiftsFont.subheadline)
                    .foregroundStyle(IronHerTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            Spacer()

            Button("Close") {
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, IronHerTheme.screenPadding)
            .padding(.bottom, 32)
        }
        .background(IronHerTheme.background)
        .navigationTitle("Beta")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            PaywallDebug.log("Paywall suppressed (closed beta unlock)")
        }
    }

    private var paywallContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                headerSection
                benefitsSection

                if subscriptionStore.isPremium {
                    premiumActiveSection
                } else {
                    productsSection
                    purchaseSection
                }

                legalSection
            }
            .padding(.horizontal, IronHerTheme.screenPadding)
            .padding(.vertical, 24)
        }
        .background(IronHerTheme.background)
        .navigationTitle("trenira premium")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Close") {
                    PaywallDebug.log("Paywall dismissed (Close tapped)")
                    dismiss()
                }
                .foregroundStyle(IronHerTheme.secondaryText)
            }
        }
        .task {
            PaywallDebug.log("Paywall presented (feature=\(highlightFeature.map(String.init(describing:)) ?? "none"), isPremium=\(subscriptionStore.isPremium))")
            // Always refresh — keep paywall visible with loading / retry UI; never auto-dismiss.
            await subscriptionStore.loadProducts()
        }
        .onDisappear {
            PaywallDebug.log("Paywall dismissed (view disappeared)")
        }
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
        .onChange(of: showManageSubscriptions) { wasShowing, isShowing in
            if wasShowing && !isShowing {
                Task { await subscriptionStore.refreshEntitlements() }
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("trenira premium")
                .font(SheLiftsFont.largeTitle)
                .foregroundStyle(IronHerTheme.primaryText)
                .textCase(nil)

            Text(supportingCopy)
                .font(SheLiftsFont.subheadline)
                .foregroundStyle(IronHerTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if let highlightFeature, highlightFeature != .unlimitedWorkoutPlans {
                Text(highlightFeature.upgradeBody)
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
                    .padding(.top, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var supportingCopy: String {
        if highlightFeature == .unlimitedWorkoutPlans {
            return "The free plan includes up to 3 saved workouts. Premium unlocks unlimited plans — plus create and adapt around real life."
        }
        return "Train without limits.\nCreate and adapt workouts around real life."
    }

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            benefitRow("Unlimited workout plans")
            benefitRow("Automatically generate workout plans")
            benefitRow("Adapt workouts to your available equipment")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(IronHerTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous)
                .stroke(IronHerTheme.separator.opacity(0.55), lineWidth: 0.5)
        }
    }

    private func benefitRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(IronHerTheme.primaryText)
                .frame(width: 16, height: 18)

            Text(text)
                .font(SheLiftsFont.bodyMedium)
                .foregroundStyle(IronHerTheme.primaryText)
        }
    }

    private var productsSection: some View {
        VStack(spacing: 12) {
            if subscriptionStore.isLoadingProducts && subscriptionStore.orderedProducts.isEmpty {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Loading subscription options…")
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if subscriptionStore.orderedProducts.isEmpty {
                VStack(spacing: 12) {
                    Text(subscriptionStore.purchaseErrorMessage
                          ?? "No subscription products were returned.")
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)
                        .multilineTextAlignment(.center)

                    Button("Try Again") {
                        Task { await subscriptionStore.loadProducts() }
                    }
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.primaryText)
                    .disabled(subscriptionStore.isLoadingProducts)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                ForEach(subscriptionStore.orderedProducts, id: \.id) { product in
                    productOption(product)
                }

                if subscriptionStore.isLoadingProducts {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
            }
        }
    }

    private func productOption(_ product: Product) -> some View {
        let selected = subscriptionStore.selectedProductID == product.id
        let bestValue = SubscriptionProductFormatting.isBestValue(product)
        let eligible = subscriptionStore.isEligibleForIntroOffer(productID: product.id)
        let introLine = SubscriptionProductFormatting.introductoryOfferLine(
            for: product,
            isEligible: eligible
        )

        return Button {
            subscriptionStore.selectedProductID = product.id
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(product.displayName)
                        .font(SheLiftsFont.section)
                        .foregroundStyle(IronHerTheme.primaryText)

                    Spacer()

                    if bestValue {
                        Text("Best value")
                            .font(SheLiftsFont.caption)
                            .foregroundStyle(IronHerTheme.secondaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(IronHerTheme.groupedBackground)
                            .clipShape(Capsule())
                    }

                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? IronHerTheme.primaryText : IronHerTheme.secondaryText)
                }

                Text(SubscriptionProductFormatting.priceAndPeriodLine(for: product))
                    .font(SheLiftsFont.bodyMedium)
                    .foregroundStyle(IronHerTheme.primaryText)

                Text(SubscriptionProductFormatting.autoRenewLine(for: product))
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)

                if let introLine {
                    Text(introLine)
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.primaryText)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(IronHerTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous)
                    .stroke(
                        selected || bestValue
                            ? IronHerTheme.primaryText.opacity(bestValue ? 0.45 : 0.35)
                            : IronHerTheme.separator.opacity(0.55),
                        lineWidth: selected || bestValue ? 1.25 : 0.5
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private var purchaseSection: some View {
        VStack(spacing: 14) {
            Button {
                Task {
                    let outcome = await subscriptionStore.purchaseSelected()
                    if outcome == .success {
                        PaywallDebug.log("Paywall dismissed (purchase succeeded)")
                        dismiss()
                    }
                }
            } label: {
                if subscriptionStore.isProcessingPurchase && !subscriptionStore.isRestoring {
                    ProgressView()
                        .tint(IronHerTheme.accentForeground)
                } else {
                    Text("Continue")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(
                subscriptionStore.isProcessingPurchase
                    || subscriptionStore.selectedProduct == nil
            )

            Button {
                Task {
                    await subscriptionStore.restorePurchases()
                    // Only leave the paywall when Premium was actually restored.
                    if subscriptionStore.isPremium {
                        PaywallDebug.log("Paywall dismissed (restore restored Premium)")
                        dismiss()
                    }
                }
            } label: {
                if subscriptionStore.isRestoring {
                    ProgressView()
                } else {
                    Text("Restore Purchases")
                }
            }
            .font(SheLiftsFont.caption)
            .foregroundStyle(IronHerTheme.secondaryText)
            .disabled(subscriptionStore.isProcessingPurchase)

            if let purchaseStatusMessage = subscriptionStore.purchaseStatusMessage {
                Text(purchaseStatusMessage)
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }

            if let restoreStatusMessage = subscriptionStore.restoreStatusMessage {
                Text(restoreStatusMessage)
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }

            if let purchaseErrorMessage = subscriptionStore.purchaseErrorMessage,
               !subscriptionStore.orderedProducts.isEmpty || !subscriptionStore.isLoadingProducts {
                Text(purchaseErrorMessage)
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var premiumActiveSection: some View {
        VStack(spacing: 14) {
            Text(l10n.t(.you_have_premium))
                .font(SheLiftsFont.section)
                .foregroundStyle(IronHerTheme.primaryText)
                .frame(maxWidth: .infinity)

            Button("Manage Subscription") {
                showManageSubscriptions = true
            }
            .buttonStyle(PrimaryButtonStyle())

            Button {
                Task { await subscriptionStore.restorePurchases() }
            } label: {
                if subscriptionStore.isRestoring {
                    ProgressView()
                } else {
                    Text("Restore Purchases")
                }
            }
            .font(SheLiftsFont.caption)
            .foregroundStyle(IronHerTheme.secondaryText)
            .disabled(subscriptionStore.isProcessingPurchase)

            if let restoreStatusMessage = subscriptionStore.restoreStatusMessage {
                Text(restoreStatusMessage)
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }

            if let purchaseErrorMessage = subscriptionStore.purchaseErrorMessage {
                Text(purchaseErrorMessage)
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var legalSection: some View {
        VStack(spacing: 10) {
            Text("Payment is charged to your Apple ID. Subscriptions renew automatically unless canceled at least 24 hours before the end of the current period.")
                .font(SheLiftsFont.caption)
                .foregroundStyle(IronHerTheme.secondaryText)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                if let privacy = LegalLinks.privacyPolicy {
                    Link("Privacy Policy", destination: privacy)
                } else {
                    NavigationLink("Privacy Policy") {
                        PrivacyPolicyView()
                    }
                }
                Text("·")
                    .foregroundStyle(IronHerTheme.secondaryText)
                if let terms = LegalLinks.termsOfUse {
                    Link("Terms of Use", destination: terms)
                } else {
                    NavigationLink("Terms of Use") {
                        TermsAndConditionsView()
                    }
                }
            }
            .font(SheLiftsFont.caption)
            .foregroundStyle(IronHerTheme.secondaryText)

            if !LegalLinks.areConfigured {
                Text("Full legal documents are available in Settings → Legal & Privacy.")
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}

#Preview {
    NavigationStack {
        PremiumUpgradeView(highlightFeature: .unlimitedWorkoutPlans)
            .environment(SubscriptionStore())
            .environment(LocalizationStore())
    }
}
