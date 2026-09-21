import SwiftUI

struct RootView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(WorkoutStore.self) private var workoutStore
    @Environment(WorkoutSessionStore.self) private var sessionStore

    @State private var showBrandIntroduction = true
    @State private var brandOpacity = 1.0
    @State private var onboardingCompleted = OnboardingStore.hasCompletedOnboarding

    var body: some View {
        ZStack {
            Group {
                if showBrandIntroduction {
                    BrandIntroductionView()
                        .opacity(brandOpacity)
                } else if !authManager.canAccessApp {
                    WelcomeAuthView()
                } else if !onboardingCompleted {
                    FirstLaunchOnboardingView {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            onboardingCompleted = true
                        }
                    }
                } else {
                    MainTabView()
                }
            }
        }
        .animation(.easeInOut(duration: 0.7), value: showBrandIntroduction)
        .animation(.easeInOut(duration: 0.35), value: onboardingCompleted)
        .animation(.easeInOut(duration: 0.35), value: authManager.canAccessApp)
        .onChange(of: authManager.canAccessApp) { _, canAccess in
            migrateOnboardingIfNeeded()
            onboardingCompleted = OnboardingStore.hasCompletedOnboarding
            if !canAccess && !OnboardingStore.hasCompletedOnboarding {
                onboardingCompleted = false
            }
        }
        .task {
            await authManager.restoreSessionIfNeeded()
            migrateOnboardingIfNeeded()
            onboardingCompleted = OnboardingStore.hasCompletedOnboarding

            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(.easeInOut(duration: 0.7)) {
                brandOpacity = 0
            }
            try? await Task.sleep(for: .seconds(0.7))
            showBrandIntroduction = false
        }
    }

    private func migrateOnboardingIfNeeded() {
        let hasData = workoutStore.workouts.contains { !$0.isDraft && !$0.exercises.isEmpty }
            || !sessionStore.performanceLogs.isEmpty
        OnboardingStore.migrateExistingUsersIfNeeded(hasExistingUserData: hasData)
    }
}

#Preview {
    RootView()
        .environment(AuthenticationManager())
        .environment(WorkoutStore())
        .environment(WeightHistoryStore())
        .environment(UserSettingsStore())
        .environment(SubscriptionStore())
        .environment(StrengthCalibrationStore())
        .environment(WorkoutSessionStore())
        .environment(AppTabRouter())
}
