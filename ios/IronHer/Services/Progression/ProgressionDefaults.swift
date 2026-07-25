import Foundation

/// How an exercise progresses — separate from increment size.
enum ProgressionDimension: String, Codable, CaseIterable, Identifiable, Hashable {
    case weight
    case reps
    case sets
    case time

    var id: String { rawValue }

    var label: String {
        switch self {
        case .weight: return "Weight"
        case .reps: return "Reps"
        case .sets: return "Sets"
        case .time: return "Time"
        }
    }
}

/// Training categories for default progression rules.
enum ProgressionTrainingCategory: String, Codable, CaseIterable, Identifiable {
    case strength
    case bodyweight
    case timed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .strength: return "Strength"
        case .bodyweight: return "Bodyweight"
        case .timed: return "Timed Exercises"
        }
    }

    var allowedDimensions: [ProgressionDimension] {
        switch self {
        case .strength: return [.weight, .reps, .sets]
        case .bodyweight: return [.reps, .sets]
        case .timed: return [.time]
        }
    }

    static func category(for exercise: Exercise) -> ProgressionTrainingCategory {
        switch exercise.measurementUnit {
        case .weight, .repsWithOptionalWeight, .weightAndTime, .distance:
            return .strength
        case .reps, .bodyweight:
            return .bodyweight
        case .time:
            return .timed
        }
    }
}

/// App-wide defaults: HOW each category progresses + default increment sizes.
struct ProgressionCategoryDefaults: Codable, Equatable {
    var strengthRule: ProgressionDimension
    var bodyweightRule: ProgressionDimension
    var timedRule: ProgressionDimension

    /// Default weight step for strength / weight-based progression (kg).
    var defaultWeightIncrementKg: Double
    /// Default +reps when progressing by reps.
    var defaultRepIncrement: Int
    /// Default +seconds when progressing by time.
    var defaultDurationIncrementSeconds: Int

    /// Ladder used when strength progresses by weight (double progression).
    var strengthTargetSets: Int
    var strengthStartingReps: Int
    var strengthThresholdReps: Int

    static let `default` = ProgressionCategoryDefaults(
        strengthRule: .weight,
        bodyweightRule: .reps,
        timedRule: .time,
        defaultWeightIncrementKg: 2.5,
        defaultRepIncrement: 1,
        defaultDurationIncrementSeconds: 5,
        strengthTargetSets: 4,
        strengthStartingReps: 8,
        strengthThresholdReps: 15
    )

    var normalized: ProgressionCategoryDefaults {
        var copy = self
        if !ProgressionTrainingCategory.strength.allowedDimensions.contains(copy.strengthRule) {
            copy.strengthRule = .weight
        }
        if !ProgressionTrainingCategory.bodyweight.allowedDimensions.contains(copy.bodyweightRule) {
            copy.bodyweightRule = .reps
        }
        copy.timedRule = .time
        copy.defaultWeightIncrementKg = max(0.25, copy.defaultWeightIncrementKg)
        copy.defaultRepIncrement = min(10, max(1, copy.defaultRepIncrement))
        copy.defaultDurationIncrementSeconds = min(60, max(1, copy.defaultDurationIncrementSeconds))
        copy.strengthTargetSets = min(10, max(1, copy.strengthTargetSets))
        copy.strengthStartingReps = min(50, max(1, copy.strengthStartingReps))
        copy.strengthThresholdReps = min(
            50,
            max(copy.strengthStartingReps, copy.strengthThresholdReps)
        )
        return copy
    }

    func rule(for category: ProgressionTrainingCategory) -> ProgressionDimension {
        switch category {
        case .strength: return strengthRule
        case .bodyweight: return bodyweightRule
        case .timed: return timedRule
        }
    }

    mutating func setRule(_ dimension: ProgressionDimension, for category: ProgressionTrainingCategory) {
        guard category.allowedDimensions.contains(dimension) else { return }
        switch category {
        case .strength: strengthRule = dimension
        case .bodyweight: bodyweightRule = dimension
        case .timed: timedRule = dimension
        }
    }
}

extension ExerciseProgressionRule {
    /// Builds an engine rule from a progression dimension + default increment sizes.
    static func from(
        dimension: ProgressionDimension,
        defaults: ProgressionCategoryDefaults,
        weightIncrementKg: Double
    ) -> ExerciseProgressionRule {
        let d = defaults.normalized
        let weightInc = max(0.25, weightIncrementKg > 0 ? weightIncrementKg : d.defaultWeightIncrementKg)
        let ladder = ProgressionConfiguration.discreteRepLadder(
            from: d.strengthStartingReps,
            to: d.strengthThresholdReps
        )

        switch dimension {
        case .weight:
            return ExerciseProgressionRule(
                method: .doubleProgression,
                targetSets: d.strengthTargetSets,
                repSteps: ladder,
                weightIncrementKg: weightInc,
                durationSteps: [30, 45, 60],
                increaseWeightAfterDurationCycle: false,
                repIncrement: 0,
                durationIncrementSeconds: 0,
                setIncrement: 1
            )
        case .reps:
            return ExerciseProgressionRule(
                method: .repsOnly,
                targetSets: d.strengthTargetSets,
                repSteps: [d.strengthStartingReps],
                weightIncrementKg: 0,
                durationSteps: [30, 45, 60],
                increaseWeightAfterDurationCycle: false,
                repIncrement: d.defaultRepIncrement,
                durationIncrementSeconds: 0,
                setIncrement: 1
            )
        case .sets:
            return ExerciseProgressionRule(
                method: .setsProgression,
                targetSets: d.strengthTargetSets,
                repSteps: [d.strengthStartingReps],
                weightIncrementKg: 0,
                durationSteps: [30, 45, 60],
                increaseWeightAfterDurationCycle: false,
                repIncrement: 0,
                durationIncrementSeconds: 0,
                setIncrement: 1
            )
        case .time:
            return ExerciseProgressionRule(
                method: .durationCycle,
                targetSets: max(1, d.strengthTargetSets),
                repSteps: [d.strengthStartingReps],
                weightIncrementKg: 0,
                durationSteps: [30, 45, 60],
                increaseWeightAfterDurationCycle: false,
                repIncrement: 0,
                durationIncrementSeconds: d.defaultDurationIncrementSeconds,
                setIncrement: 1
            )
        }
    }
}
