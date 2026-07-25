import SwiftUI

struct PremiumUpgradeView: View {
    @Environment(SubscriptionStore.self) private var subscriptionStore
    @Environment(LocalizationStore.self) private var l10n
    @Environment(\.dismiss) private var dismiss

    let highlightFeature: SubscriptionFeature?

    init(highlightFeature: SubscriptionFeature? = nil) {
        self.highlightFeature = highlightFeature
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                headerSection
                planComparison
                reassuranceSection
                actionSection
                footnoteSection
            }
            .padding(.horizontal, IronHerTheme.screenPadding)
            .padding(.vertical, 24)
        }
        .background(IronHerTheme.background)
        .navigationTitle(l10n.t(.premium))
        .navigationBarTitleDisplayMode(.inline)
        .id(subscriptionStore.revision)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(headerTitle)
                .font(SheLiftsFont.largeTitle)
                .foregroundStyle(IronHerTheme.primaryText)

            Text(headerBody)
                .font(SheLiftsFont.subheadline)
                .foregroundStyle(IronHerTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var headerTitle: String {
        if let highlightFeature {
            return highlightFeature.upgradeHeadline
        }
        return l10n.t(.progress_with_less_thinking)
    }

    private var headerBody: String {
        if let highlightFeature {
            return highlightFeature.upgradeBody
        }
        return l10n.t(.premium_header_body)
    }

    private var planComparison: some View {
        VStack(spacing: 16) {
            planCard(
                title: l10n.t(.free),
                subtitle: BrandIdentity.freePlanSubtitle,
                features: SubscriptionFeature.freeFeatures,
                isHighlighted: !subscriptionStore.isPremium
            )

            planCard(
                title: l10n.t(.premium),
                subtitle: BrandIdentity.premiumPlanSubtitle,
                features: SubscriptionFeature.premiumFeatures,
                isHighlighted: subscriptionStore.isPremium || highlightFeature != nil
            )
        }
    }

    private func planCard(
        title: String,
        subtitle: String,
        features: [SubscriptionFeature],
        isHighlighted: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(SheLiftsFont.section)
                    .foregroundStyle(IronHerTheme.primaryText)

                Text(subtitle)
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(features, id: \.self) { feature in
                    featureRow(feature)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(IronHerTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous)
                .stroke(
                    isHighlighted ? IronHerTheme.primaryText.opacity(0.35) : IronHerTheme.separator.opacity(0.55),
                    lineWidth: isHighlighted ? 1 : 0.5
                )
        }
    }

    private func featureRow(_ feature: SubscriptionFeature) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(IronHerTheme.primaryText)
                .frame(width: 16, height: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(SheLiftsFont.bodyMedium)
                    .foregroundStyle(IronHerTheme.primaryText)

                if let detail = feature.detail {
                    Text(detail)
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)
                }
            }
        }
    }

    private var reassuranceSection: some View {
        Text(BrandIdentity.philosophy)
            .font(SheLiftsFont.subheadline)
            .foregroundStyle(IronHerTheme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .notesCard(padding: 18)
    }

    private var actionSection: some View {
        VStack(spacing: 12) {
            if subscriptionStore.isPremium {
                Text(l10n.t(.you_have_premium))
                    .font(SheLiftsFont.section)
                    .foregroundStyle(IronHerTheme.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                Button {
                    subscriptionStore.upgradeToPremium()
                } label: {
                    if subscriptionStore.isProcessingPurchase {
                        ProgressView()
                            .tint(IronHerTheme.accentForeground)
                    } else {
                        Text(l10n.t(.upgrade_to_premium))
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(subscriptionStore.isProcessingPurchase)

                Button("Stay on Free") {
                    dismiss()
                }
                .font(SheLiftsFont.subheadline)
                .foregroundStyle(IronHerTheme.secondaryText)
                .frame(maxWidth: .infinity)
            }

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

            Button("Restore purchases") {
                subscriptionStore.restorePurchases()
            }
            .font(SheLiftsFont.caption)
            .foregroundStyle(IronHerTheme.secondaryText)
            .disabled(subscriptionStore.isProcessingPurchase)
        }
    }

    private var footnoteSection: some View {
        Text("trenira helps you organize and adapt — it does not replace your judgment. \(BrandIdentity.taglineInline)")
            .font(SheLiftsFont.caption)
            .foregroundStyle(IronHerTheme.secondaryText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
    }
}

#Preview {
    NavigationStack {
        PremiumUpgradeView(highlightFeature: .unlimitedWorkoutPlans)
            .environment(SubscriptionStore())
            .environment(LocalizationStore())
    }
}
