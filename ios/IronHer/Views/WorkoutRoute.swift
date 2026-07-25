import SwiftUI

enum WorkoutRoute: Hashable {
    case createOptions
    case create
    case edit
    case delete
    case start
    case myProgression
    case myWorkouts
    case trackThisWeek
    case history
    case settings
    case adaptHub
    case generate
    case regenerate
    case adapt
    case replaceExercise(workoutId: UUID, entryId: UUID)
    case premium(SubscriptionFeature?)
}

struct WorkoutRouteDestination: View {
    @Environment(SubscriptionStore.self) private var subscriptionStore

    let route: WorkoutRoute

    var body: some View {
        switch route {
        case .createOptions:
            CreateWorkoutOptionsView()
        case .create:
            CreateWorkoutView()
        case .edit:
            EditWorkoutView()
        case .delete:
            DeleteWorkoutView()
        case .start:
            StartWorkoutView()
        case .myProgression:
            MyProgressionView()
        case .myWorkouts:
            MyWorkoutsView()
        case .trackThisWeek:
            TrackThisWeekView()
        case .history:
            HistoryView()
        case .settings:
            SettingsView()
        case .adaptHub:
            AdaptWorkoutsView()
        case .generate:
            gated(.generateWorkout) { GenerateWorkoutView() }
        case .regenerate:
            gated(.regenerateWorkout) { RegenerateWorkoutView() }
        case .adapt:
            gated(.adaptWorkout) { AdaptWorkoutView() }
        case .replaceExercise(let workoutId, let entryId):
            if subscriptionStore.hasAccess(to: .replaceExercise) {
                ReplaceExerciseView(workoutId: workoutId, entryId: entryId)
            } else {
                PremiumUpgradeView(highlightFeature: .replaceExercise)
            }
        case .premium(let feature):
            PremiumUpgradeView(highlightFeature: feature)
        }
    }

    @ViewBuilder
    private func gated<Content: View>(
        _ feature: SubscriptionFeature,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if subscriptionStore.hasAccess(to: feature) {
            content()
        } else {
            PremiumUpgradeView(highlightFeature: feature)
        }
    }
}

extension View {
    func treniraNavigationDestinations() -> some View {
        navigationDestination(for: WorkoutRoute.self) { route in
            WorkoutRouteDestination(route: route)
        }
    }
}
