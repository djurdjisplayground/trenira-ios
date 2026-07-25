import SwiftUI

/// Modify existing workouts for different situations — not creation.
struct AdaptWorkoutsView: View {
    @Environment(SubscriptionStore.self) private var subscriptionStore
    @Environment(LocalizationStore.self) private var l10n

    var body: some View {
        List {
            Section {
                PremiumFeatureLink(
                    feature: .adaptWorkout,
                    title: l10n.t(.adapt_workout_manual),
                    subtitle: l10n.t(.adapt_existing_workout_subtitle),
                    systemImage: "arrow.triangle.swap"
                ) {
                    AdaptWorkoutView()
                }

                PremiumFeatureLink(
                    feature: .regenerateWorkout,
                    title: l10n.t(.regenerate_workout),
                    subtitle: l10n.t(.regenerate_workout_ai_subtitle),
                    systemImage: "arrow.triangle.2.circlepath"
                ) {
                    RegenerateWorkoutView()
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
        .id(subscriptionStore.revision)
    }
}

#Preview {
    NavigationStack {
        AdaptWorkoutsView()
            .environment(SubscriptionStore())
            .environment(LocalizationStore())
    }
}
