import Foundation

enum WorkoutEncouragement {
    static func message(
        completedSets: Int,
        plannedSets: Int
    ) -> String? {
        guard plannedSets > 0, completedSets > 0, completedSets <= plannedSets else { return nil }

        if completedSets == plannedSets {
            return "Last set."
        }

        let remaining = plannedSets - completedSets
        if remaining == 1 {
            return "One set left."
        }

        let fraction = Double(completedSets) / Double(plannedSets)
        if fraction >= 0.5 && Double(completedSets - 1) / Double(plannedSets) < 0.5 {
            return "Halfway."
        }
        if abs(fraction - 0.25) < 0.01 || (plannedSets >= 4 && completedSets == max(1, plannedSets / 4)) {
            return "Getting started."
        }
        if completedSets == 1, plannedSets >= 3 {
            return "Nice start."
        }
        return nil
    }
}

enum WorkoutCompletionCopy {
    private static let messages = [
        "You showed up. That matters.",
        "Strong work today.",
        "Session complete. See you next time.",
        "Another workout in the books.",
        "You got a little stronger today.",
        "Well done. Come back when you're ready.",
        "Consistency compounds.",
        BrandIdentity.taglineInline,
    ]

    static func randomMessage() -> String {
        messages.randomElement() ?? "Session complete."
    }
}

struct WorkoutSessionSummary: Equatable {
    let exercisesCompleted: Int
    let totalSets: Int
    let totalReps: Int
    let volumeKg: Double

    var hasVolume: Bool { volumeKg > 0 }

    /// Builds from actual set performance when available; falls back to planned values.
    static func build(
        workoutId: UUID,
        exercises: [WorkoutExerciseEntry],
        session: ActiveWorkoutSession?
    ) -> WorkoutSessionSummary {
        var exercisesCompleted = 0
        var totalSets = 0
        var totalReps = 0
        var volumeKg = 0.0

        for entry in exercises {
            guard let state = session?.state(for: entry.id) else { continue }
            let completed = state.completedSetCount
            guard completed > 0 else { continue }

            if state.isFullyCompleted {
                exercisesCompleted += 1
            }
            totalSets += completed

            let exercise = ExerciseCatalog.exercise(id: entry.exerciseId)

            for index in state.completedSetFlags.indices where state.completedSetFlags[index] {
                let performance = state.performance(at: index) ?? SetPerformance(from: entry)
                let reps = performance.reps > 0 ? performance.reps : entry.reps
                let weight = performance.weightKg > 0 ? performance.weightKg : entry.startingWeight

                switch exercise?.measurementUnit {
                case .weight, .repsWithOptionalWeight:
                    totalReps += reps
                    if weight > 0 {
                        let multiplier = (exercise?.displaysWeightPerHand == true) ? 2.0 : 1.0
                        volumeKg += Double(reps) * weight * multiplier
                    }
                case .bodyweight, .reps:
                    totalReps += reps
                case .weightAndTime:
                    if weight > 0 {
                        let multiplier = (exercise?.displaysWeightPerHand == true) ? 2.0 : 1.0
                        volumeKg += weight * multiplier
                    }
                default:
                    break
                }
            }
        }

        return WorkoutSessionSummary(
            exercisesCompleted: exercisesCompleted,
            totalSets: totalSets,
            totalReps: totalReps,
            volumeKg: volumeKg
        )
    }
}

/// Formats actual set performance for Progress History based on exercise tracking type.
enum PerformanceHistoryFormatter {
    static func summaryLine(
        for exercise: Exercise,
        performance: LoggedExercisePerformance,
        unit: WeightUnit
    ) -> String {
        let completed = performance.sets.filter(\.completed)
        guard !completed.isEmpty else { return "No sets logged" }

        switch exercise.measurementUnit {
        case .weight:
            return weightRepsSummary(completed, unit: unit, perHand: exercise.displaysWeightPerHand)
        case .reps, .bodyweight:
            return repsOnlySummary(completed)
        case .repsWithOptionalWeight:
            if completed.contains(where: { $0.weightKg > 0 }) {
                return weightRepsSummary(completed, unit: unit, perHand: exercise.displaysWeightPerHand)
            }
            return repsOnlySummary(completed)
        case .weightAndTime:
            return weightDurationSummary(completed, unit: unit, perHand: exercise.displaysWeightPerHand)
        case .time:
            return durationOnlySummary(completed)
        case .distance:
            return distanceSummary(completed, unit: unit)
        }
    }

    static func setLines(
        for exercise: Exercise,
        performance: LoggedExercisePerformance,
        unit: WeightUnit
    ) -> [String] {
        performance.sets.filter(\.completed).map { set in
            setLine(for: exercise, set: set, unit: unit)
        }
    }

    static func setLine(
        for exercise: Exercise,
        set: LoggedSetPerformance,
        unit: WeightUnit
    ) -> String {
        switch exercise.measurementUnit {
        case .weight:
            let weight = set.formattedWeight(fallbackUnit: unit)
            let suffix = exercise.displaysWeightPerHand ? " per hand" : ""
            return "\(weight)\(suffix) × \(set.reps) reps"
        case .reps, .bodyweight:
            return "\(set.reps) reps"
        case .repsWithOptionalWeight:
            if set.weightKg > 0 {
                let weight = set.formattedWeight(fallbackUnit: unit)
                let suffix = exercise.displaysWeightPerHand ? " per hand" : ""
                return "\(weight)\(suffix) × \(set.reps) reps"
            }
            return "\(set.reps) reps"
        case .weightAndTime:
            let weight = set.formattedWeight(fallbackUnit: unit)
            let suffix = exercise.displaysWeightPerHand ? " per hand" : ""
            let duration = ExerciseTrackingFormatter.formatDuration(seconds: set.durationSeconds)
            return "\(weight)\(suffix) · \(duration)"
        case .time:
            return ExerciseTrackingFormatter.formatDuration(seconds: set.durationSeconds)
        case .distance:
            return ExerciseTrackingFormatter.formatDistance(meters: set.distanceMeters, unit: unit)
        }
    }

    private static func repsOnlySummary(_ sets: [LoggedSetPerformance]) -> String {
        let reps = sets.map(\.reps)
        if Set(reps).count == 1, let only = reps.first {
            return "\(only) reps × \(sets.count) sets"
        }
        return reps.map(String.init).joined(separator: " / ") + " reps"
    }

    private static func weightRepsSummary(
        _ sets: [LoggedSetPerformance],
        unit: WeightUnit,
        perHand: Bool
    ) -> String {
        let suffix = perHand ? " per hand" : ""
        let formatted = sets.map { set in
            let weight = set.formattedWeight(fallbackUnit: unit)
            return "\(weight)\(suffix) × \(set.reps)"
        }
        if Set(formatted).count == 1, let only = formatted.first {
            return "\(only) × \(sets.count) sets"
        }
        return formatted.joined(separator: " / ")
    }

    private static func weightDurationSummary(
        _ sets: [LoggedSetPerformance],
        unit: WeightUnit,
        perHand: Bool
    ) -> String {
        let suffix = perHand ? " per hand" : ""
        if sets.count == 1, let set = sets.first {
            let weight = set.formattedWeight(fallbackUnit: unit)
            let duration = ExerciseTrackingFormatter.formatDuration(seconds: set.durationSeconds)
            return "\(weight)\(suffix) · \(duration)"
        }
        return sets.map { set in
            let weight = set.formattedWeight(fallbackUnit: unit)
            let duration = ExerciseTrackingFormatter.formatDuration(seconds: set.durationSeconds)
            return "\(weight)\(suffix) · \(duration)"
        }.joined(separator: " · ")
    }

    private static func durationOnlySummary(_ sets: [LoggedSetPerformance]) -> String {
        if sets.count == 1, let set = sets.first {
            return ExerciseTrackingFormatter.formatDuration(seconds: set.durationSeconds)
        }
        return sets
            .map { ExerciseTrackingFormatter.formatDuration(seconds: $0.durationSeconds) }
            .joined(separator: " · ")
    }

    private static func distanceSummary(_ sets: [LoggedSetPerformance], unit: WeightUnit) -> String {
        if sets.count == 1, let set = sets.first {
            return ExerciseTrackingFormatter.formatDistance(meters: set.distanceMeters, unit: unit)
        }
        return sets
            .map { ExerciseTrackingFormatter.formatDistance(meters: $0.distanceMeters, unit: unit) }
            .joined(separator: " · ")
    }
}
