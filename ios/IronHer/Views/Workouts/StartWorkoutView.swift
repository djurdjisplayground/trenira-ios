import SwiftUI

/// Choose a workout and begin an active training session.
struct StartWorkoutView: View {
    @Environment(WorkoutStore.self) private var workoutStore
    @Environment(WorkoutSessionStore.self) private var sessionStore
    @Environment(GlobalExerciseProgressStore.self) private var globalProgressStore
    @Environment(LocalizationStore.self) private var l10n
    @Environment(TestingTimeStore.self) private var testingTimeStore

    @State private var startFlow: WorkoutStartFlow?
    @State private var completedPrompt: CompletedWorkoutPrompt?

    var body: some View {
        Group {
            if workoutStore.workouts.isEmpty {
                ContentUnavailableView(
                    "No workouts yet",
                    systemImage: "dumbbell",
                    description: Text("Create a workout in My Workouts, then come back to start training.")
                )
            } else {
                List {
                    if DevelopmentConfig.isDevelopmentMode, testingTimeStore.isSimulating {
                        Section {
                            TestModeBanner()
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                        }
                    }

                    Section {
                        ForEach(workoutStore.workouts) { workout in
                            if workout.exercises.isEmpty {
                                Text(workout.name)
                                    .font(SheLiftsFont.bodyMedium)
                                    .foregroundStyle(IronHerTheme.secondaryText)
                            } else {
                                Button {
                                    handleTap(workout)
                                } label: {
                                    workoutNameRow(for: workout)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } footer: {
                        Text(l10n.t(.choose_workout_footer))
                            .font(SheLiftsFont.caption)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .background(IronHerTheme.groupedBackground)
        .navigationTitle(l10n.t(.choose_workout))
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $startFlow) { _ in
            WorkoutStartFlowCover(flow: $startFlow)
        }
        .sheet(item: $completedPrompt) { prompt in
            CompletedWorkoutSheet(
                workoutName: prompt.workout.name,
                latestLog: sessionStore.latestPerformance(for: prompt.workout.id),
                onRestart: {
                    begin(prompt.workout, forceFresh: true)
                }
            )
        }
        .onAppear {
            globalProgressStore.applyAll(to: workoutStore)
        }
        .id(testingTimeStore.revision)
    }

    private func handleTap(_ workout: Workout) {
        let completedThisWeek = sessionStore.isCompletedThisWeek(workoutId: workout.id)
        let isInProgress = sessionStore.activeSession?.workoutId == workout.id

        if completedThisWeek, !isInProgress {
            completedPrompt = CompletedWorkoutPrompt(workout: workout)
            return
        }

        begin(workout, forceFresh: false)
    }

    private func begin(_ workout: Workout, forceFresh: Bool) {
        startFlow = WorkoutStartCoordinator.begin(
            workout: workout,
            sessionStore: sessionStore,
            globalProgress: globalProgressStore,
            testingTime: testingTimeStore,
            localization: l10n,
            forceFreshSession: forceFresh
        )
    }

    private func workoutNameRow(for workout: Workout) -> some View {
        let completedThisWeek = sessionStore.isCompletedThisWeek(workoutId: workout.id)
        let isInProgress = sessionStore.activeSession?.workoutId == workout.id

        return HStack {
            Text(workout.name)
                .font(SheLiftsFont.bodyMedium)
                .foregroundStyle(IronHerTheme.primaryText)

            Spacer()

            if isInProgress {
                Text(l10n.t(.in_progress))
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
            } else if completedThisWeek {
                Text(l10n.t(.start_again))
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

private struct CompletedWorkoutPrompt: Identifiable {
    let workout: Workout
    var id: UUID { workout.id }
}

#Preview {
    NavigationStack {
        StartWorkoutView()
            .environment(WorkoutStore())
            .environment(WorkoutSessionStore())
            .environment(GlobalExerciseProgressStore())
            .environment(LocalizationStore())
            .environment(UserSettingsStore())
            .environment(TestingTimeStore())
    }
}
