import SwiftUI

/// Choose how to create a workout — manual first, AI as an optional enhancement.
struct CreateWorkoutOptionsView: View {
    @Environment(SubscriptionStore.self) private var subscriptionStore
    @Environment(LocalizationStore.self) private var l10n

    var body: some View {
        List {
            Section {
                NavigationLink(value: WorkoutRoute.create) {
                    optionRow(
                        title: l10n.t(.create_manually),
                        subtitle: l10n.t(.create_manually_subtitle),
                        systemImage: "square.and.pencil",
                        showsPremium: false
                    )
                }

                NavigationLink(value: WorkoutRoute.generate) {
                    optionRow(
                        title: l10n.t(.generate_with_ai),
                        subtitle: l10n.t(.generate_workout_subtitle),
                        systemImage: "sparkles",
                        showsPremium: !subscriptionStore.hasAccess(to: .generateWorkout)
                    )
                }
            } footer: {
                Text(l10n.t(.create_workout_options_footer))
                    .font(SheLiftsFont.caption)
            }
        }
        .listStyle(.insetGrouped)
        .background(IronHerTheme.groupedBackground)
        .navigationTitle(l10n.t(.create_workout))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func optionRow(
        title: String,
        subtitle: String,
        systemImage: String,
        showsPremium: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(IronHerTheme.primaryText)
                .frame(width: 28, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(SheLiftsFont.bodyMedium)
                        .foregroundStyle(IronHerTheme.primaryText)
                    if showsPremium {
                        PremiumBadge()
                    }
                }
                Text(subtitle)
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        CreateWorkoutOptionsView()
            .treniraNavigationDestinations()
            .environment(SubscriptionStore())
            .environment(LocalizationStore())
    }
}
