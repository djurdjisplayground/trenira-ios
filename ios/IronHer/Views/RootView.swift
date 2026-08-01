import SwiftUI

struct RootView: View {
    @Environment(AuthenticationManager.self) private var authManager

    @State private var showBrandIntroduction = true
    @State private var brandOpacity = 1.0
    @State private var showOnboarding = !OnboardingStore.hasCompletedOnboarding

    var body: some View {
        ZStack {
            Group {
                if authManager.canAccessApp {
                    MainTabView()
                } else {
                    WelcomeAuthView()
                }
            }
            .opacity(showBrandIntroduction || showOnboarding ? 0 : 1)

            if showBrandIntroduction {
                BrandIntroductionView()
                    .opacity(brandOpacity)
                    .zIndex(2)
            } else if showOnboarding {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        showOnboarding = false
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.7), value: showBrandIntroduction)
        .animation(.easeInOut(duration: 0.35), value: showOnboarding)
        .animation(.easeInOut(duration: 0.35), value: authManager.canAccessApp)
        .onChange(of: authManager.canAccessApp) { _, canAccess in
            // After erase-all, onboarding completion is cleared — show intro again.
            if !canAccess && !OnboardingStore.hasCompletedOnboarding {
                showOnboarding = true
            }
        }
        .task {
            await authManager.restoreSessionIfNeeded()

            // Brand moment: hold ~2.5s, then smooth crossfade to onboarding or app.
            try? await Task.sleep(for: .seconds(2.5))

            withAnimation(.easeInOut(duration: 0.7)) {
                brandOpacity = 0
            }

            try? await Task.sleep(for: .seconds(0.7))
            showBrandIntroduction = false
        }
    }
}

#Preview {
    RootView()
        .environment(AuthenticationManager())
        .environment(WorkoutStore())
        .environment(WeightHistoryStore())
        .environment(UserSettingsStore())
        .environment(SubscriptionStore())
}
