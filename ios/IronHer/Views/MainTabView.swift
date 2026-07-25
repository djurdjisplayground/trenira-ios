import SwiftUI

/// Home trains today · My Workouts manages · Progress reviews · Adapt modifies · Settings configures.
struct MainTabView: View {
    @Environment(TestingTimeStore.self) private var testingTimeStore
    @Environment(LocalizationStore.self) private var l10n
    @Environment(AppTabRouter.self) private var tabRouter

    var body: some View {
        @Bindable var router = tabRouter

        TabView(selection: $router.selectedTab) {
            NavigationStack {
                HomeView()
                    .treniraNavigationDestinations()
            }
            .tabItem {
                Label(l10n.t(.home_tab), systemImage: "house")
            }
            .tag(AppTab.home)

            NavigationStack {
                MyWorkoutsView()
                    .treniraNavigationDestinations()
            }
            .tabItem {
                Label(l10n.t(.my_workouts), systemImage: "list.bullet")
            }
            .tag(AppTab.myWorkouts)

            NavigationStack {
                ProgressHubView()
                    .treniraNavigationDestinations()
            }
            .tabItem {
                Label(l10n.t(.progress_tab), systemImage: "chart.line.uptrend.xyaxis")
            }
            .tag(AppTab.progress)

            NavigationStack {
                AdaptWorkoutsView()
                    .treniraNavigationDestinations()
            }
            .tabItem {
                Label(l10n.t(.adapt_tab), systemImage: "arrow.triangle.branch")
            }
            .tag(AppTab.adapt)

            NavigationStack {
                SettingsView()
                    .treniraNavigationDestinations()
            }
            .tabItem {
                Label(l10n.t(.settings), systemImage: "gearshape")
            }
            .tag(AppTab.settings)
        }
        .tint(IronHerTheme.primaryText)
        .id(testingTimeStore.revision)
    }
}

#Preview {
    MainTabView()
        .environment(AuthenticationManager())
        .environment(UserSettingsStore())
        .environment(WorkoutStore())
        .environment(WorkoutSessionStore())
        .environment(SubscriptionStore())
        .environment(LocalizationStore())
        .environment(TestingTimeStore())
        .environment(GlobalExerciseProgressStore())
        .environment(CustomExerciseStore())
        .environment(AppTabRouter())
}
