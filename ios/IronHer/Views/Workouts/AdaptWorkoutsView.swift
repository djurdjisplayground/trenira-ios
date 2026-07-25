import SwiftUI

/// Modify existing workouts — one Adapt entry point (no separate Regenerate).
struct AdaptWorkoutsView: View {
    @Environment(SubscriptionStore.self) private var subscriptionStore
    @Environment(LocalizationStore.self) private var l10n

    var body: some View {
        List {
            Section {
                PremiumFeatureLink(
                    feature: .adaptWorkout,
                    title: l10n.t(.adapt_workout),
                    subtitle: l10n.t(.adapt_existing_workout_subtitle),
                    systemImage: "arrow.triangle.branch"
                ) {
                    AdaptWorkoutView()
                }
            } footer: {
                Text(l10n.t(.adapt_tab_footer))
                    .font(SheLiftsFont.caption)
            }
        }
        .listStyle(.insetGrouped)
        .background(IronHerTheme.groupedBackground)
        .navigationTitle(l10n.t(.adapt_tab))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AdaptWorkoutsView()
            .environment(SubscriptionStore())
            .environment(LocalizationStore())
    }
}
