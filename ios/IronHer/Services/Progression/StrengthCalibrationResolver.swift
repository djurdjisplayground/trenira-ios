import Foundation

/// Starting-weight priority for generated and manually created workouts.
/// Does not mutate progression rules, ladders, or completed-session logic.
enum StrengthCalibrationResolver {
    enum Source: Equatable {
        /// User typed a positive weight in the current form.
        case explicit(weightKg: Double)
        /// Actual workouts, logged performance, or an already assigned working weight.
        case establishedProgress(weightKg: Double)
        case calibration(weightKg: Double)
        case inferred(weightKg: Double)
        case fallback
    }

    /// Priority: explicit → history/progress → exact calibration → inferred profile → blank.
    static func source(
        exerciseId: String,
        targetReps: Int = 10,
        explicitWeightKg: Double? = nil,
        progress: GlobalExerciseProgress?,
        historyEntries: [WeightHistoryEntry],
        calibrations: [String: ExerciseCalibration]
    ) -> Source {
        if let explicitWeightKg, explicitWeightKg > 0 {
            return .explicit(weightKg: explicitWeightKg)
        }

        if hasEstablishedProgress(progress: progress, historyEntries: historyEntries) {
            if let weight = progress?.workingWeightKg, weight > 0 {
                return .establishedProgress(weightKg: weight)
            }
            if let historical = historyEntries.last(where: {
                $0.event == .initial || $0.event == .progression
            }), historical.weightKg > 0 {
                return .establishedProgress(weightKg: historical.weightKg)
            }
            return .establishedProgress(weightKg: 0)
        }

        if let exact = calibrations[exerciseId], exact.weightKg > 0 {
            let ten = StrengthLoadNormalizer.tenRepEquivalentKg(
                weightKg: exact.weightKg,
                reps: exact.reps
            )
            let adjusted = StrengthLoadNormalizer.workingWeightKg(
                tenRepEquivalentKg: ten,
                targetReps: max(1, targetReps)
            )
            let increment = ExerciseCatalog.exercise(id: exerciseId).map {
                StrengthProfileCatalog.roundingIncrementKg(for: $0)
            } ?? 1.0
            let rounded = StrengthProfileInference.roundDown(adjusted, incrementKg: increment)
            if rounded > 0 {
                return .calibration(weightKg: rounded)
            }
        }

        let inferred = StrengthProfileInference.inferredWeightKg(
            exerciseId: exerciseId,
            targetReps: targetReps,
            calibrations: calibrations
        )
        if inferred > 0 {
            return .inferred(weightKg: inferred)
        }

        return .fallback
    }

    static func startingWeightKg(
        exerciseId: String,
        targetReps: Int = 10,
        explicitWeightKg: Double? = nil,
        progress: GlobalExerciseProgress?,
        historyEntries: [WeightHistoryEntry],
        calibrations: [String: ExerciseCalibration]
    ) -> Double {
        switch source(
            exerciseId: exerciseId,
            targetReps: targetReps,
            explicitWeightKg: explicitWeightKg,
            progress: progress,
            historyEntries: historyEntries,
            calibrations: calibrations
        ) {
        case .explicit(let weightKg),
             .establishedProgress(let weightKg),
             .calibration(let weightKg),
             .inferred(let weightKg):
            return weightKg
        case .fallback:
            return 0
        }
    }

    /// Compatibility wrapper for call sites that only have one calibration record.
    static func startingWeightKg(
        exerciseId: String,
        progress: GlobalExerciseProgress?,
        historyEntries: [WeightHistoryEntry],
        calibration: ExerciseCalibration?
    ) -> Double {
        var records: [String: ExerciseCalibration] = [:]
        if let calibration {
            records[calibration.exerciseId] = calibration
        }
        return startingWeightKg(
            exerciseId: exerciseId,
            targetReps: 10,
            progress: progress,
            historyEntries: historyEntries,
            calibrations: records
        )
    }

    static func source(
        exerciseId: String,
        progress: GlobalExerciseProgress?,
        historyEntries: [WeightHistoryEntry],
        calibration: ExerciseCalibration?
    ) -> Source {
        var records: [String: ExerciseCalibration] = [:]
        if let calibration {
            records[calibration.exerciseId] = calibration
        }
        return source(
            exerciseId: exerciseId,
            targetReps: 10,
            progress: progress,
            historyEntries: historyEntries,
            calibrations: records
        )
    }

    /// True when later workout or progression data should own the working weight.
    static func hasEstablishedProgress(
        progress: GlobalExerciseProgress?,
        historyEntries: [WeightHistoryEntry]
    ) -> Bool {
        if let progress {
            if progress.workingWeightKg > 0 { return true }
            if progress.lastPerformedAt != nil { return true }
            if progress.lastActual != nil { return true }
        }
        return historyEntries.contains { entry in
            switch entry.event {
            case .initial, .progression:
                return true
            default:
                return false
            }
        }
    }

    static func applyStartingWeights(
        to workouts: [Workout],
        progressFor: (String) -> GlobalExerciseProgress?,
        historyFor: (String) -> [WeightHistoryEntry],
        calibrations: [String: ExerciseCalibration]
    ) -> [Workout] {
        workouts.map { workout in
            var copy = workout
            copy.exercises = copy.exercises.map { entry in
                var next = entry
                next.startingWeight = startingWeightKg(
                    exerciseId: entry.exerciseId,
                    targetReps: max(1, entry.reps),
                    progress: progressFor(entry.exerciseId),
                    historyEntries: historyFor(entry.exerciseId),
                    calibrations: calibrations
                )
                return next
            }
            return copy
        }
    }

    static func applyStartingWeights(
        to workouts: [Workout],
        progressFor: (String) -> GlobalExerciseProgress?,
        historyFor: (String) -> [WeightHistoryEntry],
        calibrationFor: (String) -> ExerciseCalibration?
    ) -> [Workout] {
        var records: [String: ExerciseCalibration] = [:]
        for workout in workouts {
            for entry in workout.exercises {
                if let calibration = calibrationFor(entry.exerciseId) {
                    records[entry.exerciseId] = calibration
                }
            }
        }
        // Include every known record the callback can see by also merging explicit calibrations
        // already passed for generated IDs. Callers that have the full store should use
        // `calibrations:` instead.
        return applyStartingWeights(
            to: workouts,
            progressFor: progressFor,
            historyFor: historyFor,
            calibrations: records
        )
    }
}
