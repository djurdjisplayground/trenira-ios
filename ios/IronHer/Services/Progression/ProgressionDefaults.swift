import Foundation

/// How an exercise progresses — separate from increment size.
enum ProgressionDimension: String, Codable, CaseIterable, Identifiable, Hashable {
    case weight
    case reps
    case sets
    case time
    case distance

    var id: String { rawValue }

    var label: String {
        switch self {
        case .weight: return "Increase weight"
        case .reps: return "Increase repetitions"
        case .sets: return "Increase sets"
        case .time: return "Increase hold time"
        case .distance: return "Increase distance"
        }
    }

    var asMeasurementMetric: MeasurementMetric {
        switch self {
        case .weight: return .weight
        case .reps: return .reps
        case .sets: return .sets
        case .time: return .time
        case .distance: return .distance
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
        case .strength: return "Weighted exercises"
        case .bodyweight: return "Bodyweight exercises"
        case .timed: return "Timed exercises"
        }
    }

    var allowedDimensions: [ProgressionDimension] {
        switch self {
        case .strength: return [.weight, .reps, .sets, .distance]
        case .bodyweight: return [.reps, .sets, .time]
        case .timed: return [.time, .sets]
        }
    }

    static func category(for exercise: Exercise) -> ProgressionTrainingCategory {
        let profile = exercise.trackingProfile
        // Duration-first tracking (planks, holds, Farmer's Carry) — not strength reps.
        if profile.supports(.time),
           profile.primaryProgressionMetric == .time,
           !profile.supports(.reps) {
            return .timed
        }
        if profile.supports(.time), !profile.supports(.weight), !profile.supports(.reps), !profile.supports(.distance) {
            return .timed
        }
        if profile.supports(.reps), !profile.supports(.weight) {
            return .bodyweight
        }
        if profile.supports(.time), !profile.supports(.weight), !profile.supports(.reps) {
            return .timed
        }
        switch exercise.measurementUnit {
        case .weight, .repsWithOptionalWeight, .distance:
            return .strength
        case .weightAndTime:
            return .timed
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
    /// Default +meters when progressing by distance.
    var defaultDistanceIncrementMeters: Double

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
        defaultDistanceIncrementMeters: 5,
        strengthTargetSets: 3,
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
        if !ProgressionTrainingCategory.timed.allowedDimensions.contains(copy.timedRule) {
            copy.timedRule = .time
        }
        copy.defaultWeightIncrementKg = max(0.25, copy.defaultWeightIncrementKg)
        copy.defaultRepIncrement = min(10, max(1, copy.defaultRepIncrement))
        copy.defaultDurationIncrementSeconds = min(60, max(1, copy.defaultDurationIncrementSeconds))
        copy.defaultDistanceIncrementMeters = max(1, copy.defaultDistanceIncrementMeters)
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

    private enum CodingKeys: String, CodingKey {
        case strengthRule, bodyweightRule, timedRule
        case defaultWeightIncrementKg, defaultRepIncrement, defaultDurationIncrementSeconds
        case defaultDistanceIncrementMeters
        case strengthTargetSets, strengthStartingReps, strengthThresholdReps
    }

    init(
        strengthRule: ProgressionDimension,
        bodyweightRule: ProgressionDimension,
        timedRule: ProgressionDimension,
        defaultWeightIncrementKg: Double,
        defaultRepIncrement: Int,
        defaultDurationIncrementSeconds: Int,
        defaultDistanceIncrementMeters: Double,
        strengthTargetSets: Int,
        strengthStartingReps: Int,
        strengthThresholdReps: Int
    ) {
        self.strengthRule = strengthRule
        self.bodyweightRule = bodyweightRule
        self.timedRule = timedRule
        self.defaultWeightIncrementKg = defaultWeightIncrementKg
        self.defaultRepIncrement = defaultRepIncrement
        self.defaultDurationIncrementSeconds = defaultDurationIncrementSeconds
        self.defaultDistanceIncrementMeters = defaultDistanceIncrementMeters
        self.strengthTargetSets = strengthTargetSets
        self.strengthStartingReps = strengthStartingReps
        self.strengthThresholdReps = strengthThresholdReps
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        strengthRule = try container.decodeIfPresent(ProgressionDimension.self, forKey: .strengthRule) ?? .weight
        bodyweightRule = try container.decodeIfPresent(ProgressionDimension.self, forKey: .bodyweightRule) ?? .reps
        timedRule = try container.decodeIfPresent(ProgressionDimension.self, forKey: .timedRule) ?? .time
        defaultWeightIncrementKg = try container.decodeIfPresent(Double.self, forKey: .defaultWeightIncrementKg) ?? 2.5
        defaultRepIncrement = try container.decodeIfPresent(Int.self, forKey: .defaultRepIncrement) ?? 1
        defaultDurationIncrementSeconds = try container.decodeIfPresent(Int.self, forKey: .defaultDurationIncrementSeconds) ?? 5
        defaultDistanceIncrementMeters = try container.decodeIfPresent(Double.self, forKey: .defaultDistanceIncrementMeters) ?? 5
        strengthTargetSets = try container.decodeIfPresent(Int.self, forKey: .strengthTargetSets) ?? 3
        strengthStartingReps = try container.decodeIfPresent(Int.self, forKey: .strengthStartingReps) ?? 8
        strengthThresholdReps = try container.decodeIfPresent(Int.self, forKey: .strengthThresholdReps) ?? 15
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(strengthRule, forKey: .strengthRule)
        try container.encode(bodyweightRule, forKey: .bodyweightRule)
        try container.encode(timedRule, forKey: .timedRule)
        try container.encode(defaultWeightIncrementKg, forKey: .defaultWeightIncrementKg)
        try container.encode(defaultRepIncrement, forKey: .defaultRepIncrement)
        try container.encode(defaultDurationIncrementSeconds, forKey: .defaultDurationIncrementSeconds)
        try container.encode(defaultDistanceIncrementMeters, forKey: .defaultDistanceIncrementMeters)
        try container.encode(strengthTargetSets, forKey: .strengthTargetSets)
        try container.encode(strengthStartingReps, forKey: .strengthStartingReps)
        try container.encode(strengthThresholdReps, forKey: .strengthThresholdReps)
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
        case .distance:
            return ExerciseProgressionRule(
                method: .distanceProgression,
                targetSets: max(1, d.strengthTargetSets),
                repSteps: [d.strengthStartingReps],
                weightIncrementKg: 0,
                durationSteps: [30, 45, 60],
                increaseWeightAfterDurationCycle: false,
                repIncrement: 0,
                durationIncrementSeconds: 0,
                setIncrement: 1,
                distanceIncrementMeters: d.defaultDistanceIncrementMeters
            )
        }
    }
}
