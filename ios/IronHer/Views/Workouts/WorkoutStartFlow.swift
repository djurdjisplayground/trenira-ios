import SwiftUI

/// Coordinates Welcome Back → Active Workout as a single full-screen flow.
/// Presenting Welcome Back in a fullScreenCover (not a post-navigation sheet)
/// ensures the UI is actually visible.
enum WorkoutStartFlow: Identifiable, Equatable {
    case welcome(evaluation: ReturnAfterBreak.Evaluation, workoutId: UUID, forceFresh: Bool)
    case training(workoutId: UUID, preferLighterStart: Bool, forceFresh: Bool)

    /// Stable id so SwiftUI keeps the cover open while switching welcome → training.
    var id: String {
        switch self {
        case .welcome(_, let workoutId, _), .training(let workoutId, _, _):
            return workoutId.uuidString
        }
    }

    var workoutId: UUID {
        switch self {
        case .welcome(_, let workoutId, _), .training(let workoutId, _, _):
            return workoutId
        }
    }
}

enum WorkoutStartCoordinator {
    /// Builds the correct start flow for a workout tap.
    @MainActor
    static func begin(
        workout: Workout,
        sessionStore: WorkoutSessionStore,
        globalProgress: GlobalExerciseProgressStore,
        testingTime: TestingTimeStore,
        localization: LocalizationStore,
        forceFreshSession: Bool = false
    ) -> WorkoutStartFlow {
        // Resume in-progress sessions without Welcome Back (unless explicitly restarting).
        if !forceFreshSession, sessionStore.activeSession?.workoutId == workout.id {
            return .training(workoutId: workout.id, preferLighterStart: false, forceFresh: false)
        }

        let evaluation = ReturnAfterBreak.evaluate(
            performanceLogs: sessionStore.performanceLogs,
            weeklyCompletions: sessionStore.weeklyCompletions,
            workout: workout,
            globalProgress: globalProgress,
            localization: localization,
            now: testingTime.now
        )

        if evaluation.shouldPrompt {
            return .welcome(evaluation: evaluation, workoutId: workout.id, forceFresh: forceFreshSession)
        }

        return .training(workoutId: workout.id, preferLighterStart: false, forceFresh: forceFreshSession)
    }
}

struct WorkoutStartFlowCover: View {
    @Binding var flow: WorkoutStartFlow?

    var body: some View {
        Group {
            switch flow {
            case .welcome(let evaluation, let workoutId, let forceFresh):
                WelcomeBackView(
                    evaluation: evaluation,
                    onContinue: {
                        flow = .training(workoutId: workoutId, preferLighterStart: false, forceFresh: forceFresh)
                    },
                    onStartLighter: {
                        flow = .training(workoutId: workoutId, preferLighterStart: true, forceFresh: forceFresh)
                    }
                )
            case .training(let workoutId, let preferLighterStart, let forceFresh):
                NavigationStack {
                    ActiveWorkoutView(
                        workoutId: workoutId,
                        preferLighterStart: preferLighterStart,
                        forceFreshSession: forceFresh,
                        onRequestClose: { flow = nil }
                    )
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") {
                                flow = nil
                            }
                            .foregroundStyle(IronHerTheme.secondaryText)
                        }
                    }
                }
            case .none:
                Color.clear
            }
        }
    }
}
