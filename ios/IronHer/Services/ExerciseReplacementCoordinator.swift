import Foundation

/// Coordinates single-occurrence, session-only, and global exercise replacements.
/// Persistence goes through `WorkoutStore` in one batch save — not from SwiftUI views.
@MainActor
struct ExerciseReplacementCoordinator {
    let workoutStore: WorkoutStore
    let sessionStore: WorkoutSessionStore
    let globalProgressStore: GlobalExerciseProgressStore
    var replacementService: ExerciseReplacementService = ExerciseReplacementService()

    func savedPlanCount(containing exerciseId: String) -> Int {
        workoutStore.savedWorkoutsContaining(exerciseId: exerciseId).count
    }

    /// Applies a replacement for the given scope. Does not touch history or other sessions.
    @discardableResult
    func replace(
        originalExerciseId: String,
        replacement: Exercise,
        scope: ExerciseReplacementScope,
        currentWorkoutId: UUID,
        selectedEntryId: UUID
    ) -> ExerciseReplacementResult {
        let originalName = ExerciseCatalog.exercise(id: originalExerciseId)?.name ?? "Exercise"
        let replacementName = replacement.name

        switch scope {
        case .currentSession:
            sessionStore.setExerciseIdOverride(entryId: selectedEntryId, exerciseId: replacement.id)
            return ExerciseReplacementResult(
                scope: .currentSession,
                updatedWorkoutCount: 0,
                originalExerciseName: originalName,
                replacementExerciseName: replacementName
            )

        case .currentWorkout, .allWorkouts:
            let updates = Self.planUpdates(
                in: workoutStore.workouts.filter { !$0.isDraft },
                originalExerciseId: originalExerciseId,
                replacement: replacement,
                scope: scope,
                currentWorkoutId: currentWorkoutId,
                selectedEntryId: selectedEntryId,
                prescribe: { entry, exercise in
                    prescription(for: entry, replacement: exercise)
                }
            )
            let count = workoutStore.applyExerciseListUpdates(updates)
            sessionStore.clearExerciseIdOverride(entryId: selectedEntryId)
            return ExerciseReplacementResult(
                scope: scope,
                updatedWorkoutCount: count,
                originalExerciseName: originalName,
                replacementExerciseName: replacementName
            )
        }
    }

    /// Pure plan-mapping helper (unit-testable without UserDefaults).
    nonisolated static func planUpdates(
        in workouts: [Workout],
        originalExerciseId: String,
        replacement: Exercise,
        scope: ExerciseReplacementScope,
        currentWorkoutId: UUID,
        selectedEntryId: UUID,
        prescribe: (WorkoutExerciseEntry, Exercise) -> WorkoutExerciseEntry
    ) -> [UUID: [WorkoutExerciseEntry]] {
        switch scope {
        case .currentSession:
            return [:]

        case .currentWorkout:
            guard let workout = workouts.first(where: { $0.id == currentWorkoutId && !$0.isDraft }) else {
                return [:]
            }
            let exercises = workout.exercises.map { entry -> WorkoutExerciseEntry in
                guard entry.id == selectedEntryId, entry.exerciseId == originalExerciseId else { return entry }
                return prescribe(entry, replacement)
            }
            return [workout.id: exercises]

        case .allWorkouts:
            var updates: [UUID: [WorkoutExerciseEntry]] = [:]
            for workout in workouts where !workout.isDraft {
                guard workout.exercises.contains(where: { $0.exerciseId == originalExerciseId }) else { continue }
                updates[workout.id] = workout.exercises.map { entry in
                    guard entry.exerciseId == originalExerciseId else { return entry }
                    return prescribe(entry, replacement)
                }
            }
            return updates
        }
    }

    private func prescription(
        for entry: WorkoutExerciseEntry,
        replacement: Exercise
    ) -> WorkoutExerciseEntry {
        let progress = globalProgressStore.progress(for: replacement.id)
        return replacementService.prescription(
            replacing: entry,
            with: replacement,
            globalWeightKg: progress?.workingWeightKg,
            globalReps: progress?.targetReps,
            globalSets: progress?.targetSets ?? entry.sets,
            globalDuration: progress?.targetDurationSeconds,
            globalDistance: progress?.targetDistanceMeters
        )
    }
}
