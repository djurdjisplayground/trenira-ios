import SwiftUI

/// Today's training — start a session or open this week's progress.
struct HomeView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(WorkoutStore.self) private var workoutStore
    @Environment(WorkoutSessionStore.self) private var sessionStore
    @Environment(LocalizationStore.self) private var l10n
    @Environment(TestingTimeStore.self) private var testingTimeStore
    @Environment(UserDataCoordinator.self) private var dataCoordinator
    @State private var showSignOutConfirm = false

    private var startableWorkouts: [Workout] {
        workoutStore.workouts.filter { !$0.isDraft && !$0.exercises.isEmpty }
    }

    private var hasWorkouts: Bool {
        !startableWorkouts.isEmpty
    }

    private var hasInProgressSession: Bool {
        guard let activeId = sessionStore.activeSession?.workoutId else { return false }
        return startableWorkouts.contains { $0.id == activeId }
    }

    private var hasCompletedWorkoutThisWeek: Bool {
        startableWorkouts.contains { sessionStore.isCompletedThisWeek(workoutId: $0.id) }
    }

    private var primaryTitle: String {
        if hasInProgressSession {
            return l10n.t(.continue_workout)
        }
        if hasWorkouts, hasCompletedWorkoutThisWeek {
            return l10n.t(.start_again)
        }
        return l10n.t(.start_workout)
    }

    private var primarySubtitle: String {
        if !hasWorkouts {
            return l10n.t(.home_start_empty_subtitle)
        }
        if hasInProgressSession {
            return l10n.t(.continue_workout_subtitle)
        }
        if hasCompletedWorkoutThisWeek {
            return l10n.t(.start_again_subtitle)
        }
        return l10n.t(.start_workout_subtitle)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: IronHerTheme.sectionSpacing) {
                TestModeBanner()
                headerSection
                primaryAction
                trackThisWeekCard
            }
            .padding(.horizontal, IronHerTheme.screenPadding)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(IronHerTheme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BrandLogoMark(size: 24)
            }
            ToolbarItem(placement: .topBarTrailing) {
                authToolbarButton
            }
        }
        .id("\(testingTimeStore.revision)-\(sessionStore.activeSession?.id.uuidString ?? "none")")
        .confirmationDialog(
            l10n.t(.sign_out_confirm_title),
            isPresented: $showSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button(l10n.t(.log_out), role: .destructive) {
                authManager.signOut(preparing: dataCoordinator)
            }
            Button(l10n.t(.cancel), role: .cancel) {}
        } message: {
            Text(l10n.t(.sign_out_confirm_message))
        }
    }

    private var headerSection: some View {
        VStack(spacing: 0) {
            BrandWordmark(size: 36, weight: .semibold)

            BrandTagline(
                size: 15,
                line2Size: 15,
                weight: .light,
                lineSpacing: 4,
                color: IronHerTheme.brandSecondary.opacity(0.92)
            )
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
    }

    private var primaryAction: some View {
        NavigationLink(value: WorkoutRoute.start) {
            HomeActionCard(
                title: primaryTitle,
                subtitle: primarySubtitle,
                icon: "play.fill",
                style: .primary,
                minHeight: 148
            )
        }
        .buttonStyle(SheLiftsPressStyle())
    }

    private var trackThisWeekCard: some View {
        NavigationLink(value: WorkoutRoute.trackThisWeek) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(l10n.t(.track_this_week))
                        .font(SheLiftsFont.cardLabel)
                        .foregroundStyle(IronHerTheme.primaryText)
                    Text(l10n.t(.home_track_week_cta))
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(IronHerTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(IronHerTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous)
                    .stroke(IronHerTheme.separator.opacity(0.55), lineWidth: 0.5)
            }
        }
        .buttonStyle(SheLiftsPressStyle())
    }

    @ViewBuilder
    private var authToolbarButton: some View {
        if authManager.authState.isGuest {
            Button(l10n.t(.sign_in_title)) {
                authManager.signOut(preparing: dataCoordinator)
            }
            .font(SheLiftsFont.subheadline)
            .foregroundStyle(IronHerTheme.secondaryText)
        } else if authManager.authState != .signedOut {
            Button(l10n.t(.log_out)) {
                showSignOutConfirm = true
            }
            .font(SheLiftsFont.subheadline)
            .foregroundStyle(IronHerTheme.secondaryText)
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .treniraNavigationDestinations()
            .environment(AuthenticationManager())
            .environment(WorkoutStore())
            .environment(WorkoutSessionStore())
            .environment(LocalizationStore())
            .environment(TestingTimeStore())
            .environment(
                UserDataCoordinator(
                    workoutStore: WorkoutStore(),
                    historyStore: WeightHistoryStore(),
                    sessionStore: WorkoutSessionStore(),
                    customExerciseStore: CustomExerciseStore(),
                    progressionStore: ExerciseProgressionStore(),
                    globalProgressStore: GlobalExerciseProgressStore(),
                    settingsStore: UserSettingsStore()
                )
            )
    }
}
