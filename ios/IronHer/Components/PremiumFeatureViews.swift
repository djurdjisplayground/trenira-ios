import SwiftUI

struct PremiumBadge: View {
    @Environment(LocalizationStore.self) private var l10n

    var body: some View {
        Text(l10n.t(.premium_badge))
            .font(SheLiftsFont.caption)
            .foregroundStyle(IronHerTheme.secondaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(IronHerTheme.groupedBackground)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(IronHerTheme.separator.opacity(0.6), lineWidth: 0.5)
            }
    }
}

struct PremiumFeatureLabel: View {
    let title: String
    let systemImage: String
    let locked: Bool

    var body: some View {
        HStack(spacing: 12) {
            Label(title, systemImage: systemImage)
            Spacer()
            if locked {
                PremiumBadge()
            }
        }
    }
}

struct PremiumFeatureRow: View {
    @Environment(SubscriptionStore.self) private var subscriptionStore

    let feature: SubscriptionFeature
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage ?? feature.systemImage)
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(IronHerTheme.primaryText)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(SheLiftsFont.bodyMedium)
                        .foregroundStyle(IronHerTheme.primaryText)
                    Spacer()
                    if !subscriptionStore.hasAccess(to: feature) {
                        PremiumBadge()
                    }
                }

                if let subtitle {
                    Text(subtitle)
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct PremiumFeatureLink<Destination: View>: View {
    @Environment(SubscriptionStore.self) private var subscriptionStore

    let feature: SubscriptionFeature
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        Group {
            if subscriptionStore.hasAccess(to: feature) {
                NavigationLink {
                    destination()
                } label: {
                    linkLabel
                }
            } else {
                NavigationLink(value: WorkoutRoute.premium(feature)) {
                    linkLabel
                }
            }
        }
    }

    private var linkLabel: some View {
        PremiumFeatureRow(
            feature: feature,
            title: title,
            subtitle: subtitle,
            systemImage: systemImage
        )
    }
}

#Preview {
    List {
        PremiumFeatureRow(
            feature: .generateWorkout,
            title: "Generate Workout",
            subtitle: "Build a plan from your goals"
        )
    }
    .environment(SubscriptionStore())
    .environment(LocalizationStore())
}
