import Foundation

/// Pure starting-weight priority for generated workouts.
/// Does not mutate progression rules, ladders, or completed-session logic.
enum StrengthCalibrationResolver {
    enum Source: Equatable {
        /// Actual workouts, logged performance, or an already assigned working weight.
        case establishedProgress(weightKg: Double)
        case calibration(weightKg: Double)
        case fallback
    }

    /// Workout / progression history outranks calibration. Calibration outranks an unassigned start.
    static func source(
        exerciseId: String,
        progress: GlobalExerciseProgress?,
        historyEntries: [WeightHistoryEntry],
        calibration: ExerciseCalibration?
    ) -> Source {
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

        if let calibration,
           calibration.exerciseId == exerciseId,
           calibration.weightKg > 0,
           calibration.matchingVersion == 1 {
            return .calibration(weightKg: calibration.weightKg)
        }

        return .fallback
    }

    static func startingWeightKg(
        exerciseId: String,
        progress: GlobalExerciseProgress?,
        historyEntries: [WeightHistoryEntry],
        calibration: ExerciseCalibration?
    ) -> Double {
        switch source(
            exerciseId: exerciseId,
            progress: progress,
            historyEntries: historyEntries,
            calibration: calibration
        ) {
        case .establishedProgress(let weightKg), .calibration(let weightKg):
            return weightKg
        case .fallback:
            return 0
        }
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
        calibrationFor: (String) -> ExerciseCalibration?
    ) -> [Workout] {
        workouts.map { workout in
            var copy = workout
            copy.exercises = copy.exercises.map { entry in
                var next = entry
                next.startingWeight = startingWeightKg(
                    exerciseId: entry.exerciseId,
                    progress: progressFor(entry.exerciseId),
                    historyEntries: historyFor(entry.exerciseId),
                    calibration: calibrationFor(entry.exerciseId)
                )
                return next
            }
            return copy
        }
    }
}
