import SwiftUI

/// Today is the home. Settings holds preferences. Workout, progress, and adapt stay off this bar.
struct MainTabView: View {
    @Environment(TestingTimeStore.self) private var testingTimeStore
    @Environment(AppTabRouter.self) private var tabRouter

    var body: some View {
        @Bindable var router = tabRouter

        TabView(selection: $router.selectedTab) {
            NavigationStack {
                TodayView()
            }
            .tabItem {
                Label("Today", systemImage: "house")
            }
            .tag(AppTab.home)

            NavigationStack {
                MomentsDiaryView()
            }
            .tabItem {
                Label("My Moments", systemImage: "book")
            }
            .tag(AppTab.moments)

            NavigationStack {
                ExploreMovementView()
            }
            .tabItem {
                Label("Explore", systemImage: "leaf")
            }
            .tag(AppTab.explore)
        }
        .tint(IronHerTheme.primaryText)
        #if DEBUG
        .fullScreenCover(isPresented: $router.showsCirclePreview) {
            NavigationStack {
                YourCirclePreviewView()
            }
        }
        #endif
        .id(testingTimeStore.revision)
        .sheet(item: $router.reminderDestination) { _ in
            NavigationStack {
                WeeklyReflectionView()
            }
        }
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
        .environment(StrengthCalibrationStore())
        .environment(CustomExerciseStore())
        .environment(AppTabRouter())
}
