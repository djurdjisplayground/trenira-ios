import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(WorkoutStore.self) private var workoutStore
    @Environment(WorkoutSessionStore.self) private var sessionStore
    @Environment(AppTabRouter.self) private var tabRouter

    @State private var showBrandIntroduction = true
    @State private var brandOpacity = 1.0
    @State private var onboardingCompleted = OnboardingStore.hasCompletedOnboarding
    @State private var showResearchInvitation = false
    @State private var researchInvitationDidAppear = false
    @State private var researchInvitationAttempt = 0
    @State private var researchInvitationForced = false
    @State private var researchInvitationDismissAction: String?
    @State private var didCaptureResearchInvitationShown = false

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
        // The invitation lives on this stable root. A cover attached to TabView,
        // or requested while the splash transition is still running, is dropped.
        .sheet(isPresented: $showResearchInvitation, onDismiss: {
            let action = researchInvitationDismissAction
            let wasShown = researchInvitationDidAppear
            #if DEBUG
            FeedbackInvitationLog.line("sheet dismissed action=\(action ?? "dismissed without a choice")")
            #endif
            researchInvitationDismissAction = nil
            researchInvitationDidAppear = false
            researchInvitationForced = false
            didCaptureResearchInvitationShown = false
            if wasShown, action != "openedForm", action != "interrupted" {
                AnalyticsService.capture(.researchInvitationDismissed)
            }
        }) {
            ResearchInvitationView(
                onPresented: researchInvitationDidPresent,
                onLater: {
                    researchInvitationDismissAction = "maybeLater"
                    #if DEBUG
                    FeedbackInvitationLog.line("action=maybeLater")
                    #endif
                    showResearchInvitation = false
                },
                onFinished: { action in
                    researchInvitationDismissAction = action
                    #if DEBUG
                    if action == "openedForm" {
                        FeedbackInvitationLog.line("action=openedForm")
                    }
                    #endif
                    showResearchInvitation = false
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(IronHerTheme.background)
        }
        .onChange(of: mainShellVisible) { _, visible in
            if visible { scheduleResearchInvitation(trigger: "homeReady") }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            scheduleResearchInvitation(trigger: "foreground")
        }
        .onChange(of: tabRouter.selectedTab) { _, _ in
            scheduleResearchInvitation(trigger: "tabChanged")
        }
        .onChange(of: tabRouter.invitationCheck) { _, _ in
            scheduleResearchInvitation(trigger: "debugRequest")
        }
        .onChange(of: tabRouter.isWorkoutFlowPresented) { _, presented in
            if presented {
                researchInvitationAttempt += 1
                #if DEBUG
                FeedbackInvitationLog.line("trigger=workoutOpened result=skip reason=a workout is active")
                #endif
                if showResearchInvitation {
                    researchInvitationDismissAction = "interrupted"
                    showResearchInvitation = false
                }
            } else {
                scheduleResearchInvitation(trigger: "workoutClosed")
            }
        }
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
            scheduleResearchInvitation(trigger: "coldLaunch")
        }
    }

    private var mainShellVisible: Bool {
        !showBrandIntroduction && authManager.canAccessApp && onboardingCompleted
    }

    /// Waits until the splash transition has finished, then shows the invitation
    /// only if it is actually on screen. A dropped sheet does not consume today's chance.
    private func scheduleResearchInvitation(trigger: String) {
        researchInvitationAttempt += 1
        let attempt = researchInvitationAttempt
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            guard attempt == researchInvitationAttempt else {
                #if DEBUG
                FeedbackInvitationLog.line("trigger=\(trigger) check cancelled before presentation")
                #endif
                return
            }
            presentResearchInvitationIfNeeded(attempt: attempt, trigger: trigger)
        }
    }

    private func presentResearchInvitationIfNeeded(attempt: Int, trigger: String) {
        Task { @MainActor in
            // Retry briefly. A cover requested while another modal is up, or while
            // Home is still transitioning, is dropped and must be asked for again.
            for iteration in 0..<12 {
                #if !DEBUG
                _ = (trigger, iteration)
                #endif
                guard attempt == researchInvitationAttempt else { return }
                if researchInvitationDidAppear { return }
                let reason = researchInvitationBlockReason
                #if DEBUG
                logResearchInvitationCheck(trigger: trigger, iteration: iteration, reason: reason)
                #endif
                guard reason == "present" else { return }
                if showResearchInvitation {
                    try? await Task.sleep(for: .milliseconds(700))
                    guard attempt == researchInvitationAttempt else { return }
                    if researchInvitationDidAppear { return }
                    showResearchInvitation = false
                    try? await Task.sleep(for: .milliseconds(250))
                    continue
                }
                researchInvitationDidAppear = false
                #if DEBUG
                researchInvitationForced = ResearchInvitationStore.isImmediatePresentationArmed
                FeedbackInvitationLog.line("presentation requested forced=\(researchInvitationForced)")
                #else
                researchInvitationForced = false
                #endif
                showResearchInvitation = true
                try? await Task.sleep(for: .milliseconds(700))
            }
        }
    }

    private var researchInvitationBlockReason: String {
        ResearchInvitationPolicy.blockReason(
            homeReady: mainShellVisible,
            onHomeTab: tabRouter.selectedTab == .home,
            workoutInterfaceVisible: tabRouter.isWorkoutFlowPresented
        )
    }

    private func researchInvitationDidPresent() {
        let firstAppearance = !didCaptureResearchInvitationShown
        researchInvitationDidAppear = true
        if firstAppearance {
            didCaptureResearchInvitationShown = true
            AnalyticsService.capture(.researchInvitationShown)
        }
        #if DEBUG
        FeedbackInvitationLog.line("sheet appeared")
        #endif
        if researchInvitationForced {
            #if DEBUG
            ResearchInvitationStore.consumeImmediatePresentation()
            FeedbackInvitationLog.line("debug force did not change the saved shown date")
            #endif
            return
        }
        ResearchInvitationStore.notePresented()
    }

    #if DEBUG
    private func logResearchInvitationCheck(trigger: String, iteration: Int, reason: String) {
        let status = ResearchInvitationStore.status()?.rawValue ?? "eligible"
        let last = ResearchInvitationStore.lastPresentedAt().map(ResearchInvitationStore.debugTimestamp) ?? "never"
        let now = ResearchInvitationStore.debugTimestamp(.now)
        let shownToday = ResearchInvitationStore.lastPresentedAt().map { Calendar.current.isDateInToday($0) } ?? false
        FeedbackInvitationLog.line(
            "trigger=\(trigger) check=\(iteration) status=\(status) lastShown=\(last) now=\(now) shownToday=\(shownToday) workout=\(tabRouter.isWorkoutFlowPresented) otherModal=\(anotherModalIsPresented) homeReady=\(mainShellVisible) onHome=\(tabRouter.selectedTab == .home) result=\(reason == "present" ? "present" : "skip") reason=\(reason)"
        )
    }

    private var anotherModalIsPresented: Bool {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let root = scenes.flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController else {
            return false
        }
        return root.presentedViewController != nil
    }
    #endif

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
        .environment(LocalizationStore())
}
