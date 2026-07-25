import Foundation

/// Atomic measurement a workout can record for an exercise.
/// An exercise may support one or many of these.
enum MeasurementMetric: String, Codable, CaseIterable, Identifiable, Hashable {
    case weight
    case reps
    case sets
    case time
    case distance

    var id: String { rawValue }

    var label: String {
        switch self {
        case .weight: return "Weight"
        case .reps: return "Reps"
        case .sets: return "Sets"
        case .time: return "Time"
        case .distance: return "Distance"
        }
    }

    var incrementLabel: String {
        switch self {
        case .weight: return "Weight Increment"
        case .reps: return "Rep Increment"
        case .sets: return "Set Increment"
        case .time: return "Time Increment"
        case .distance: return "Distance Increment"
        }
    }

    var progressionChoiceLabel: String {
        switch self {
        case .weight: return "Increase weight"
        case .reps: return "Increase reps"
        case .sets: return "Increase sets"
        case .time: return "Increase time"
        case .distance: return "Increase distance"
        }
    }
}

/// Which configured progression metrics advance after a successful session.
enum MultiMetricProgressionMode: String, Codable, CaseIterable, Identifiable, Hashable {
    /// Advance only the primary metric.
    case primary
    /// Advance only the secondary metric.
    case secondary
    /// Advance primary and secondary together.
    case both

    var id: String { rawValue }

    var label: String {
        switch self {
        case .primary: return "Primary only"
        case .secondary: return "Secondary only"
        case .both: return "Progress both"
        }
    }
}

/// Separates what is recorded, what progresses, and by how much.
/// Designed so new metric combinations do not need special-case enums.
struct ExerciseTrackingProfile: Codable, Equatable, Hashable {
    /// Metrics recorded during a session (order is display order).
    var metrics: [MeasurementMetric]
    /// Metric that drives automatic progression by default.
    var primaryProgressionMetric: MeasurementMetric
    /// Optional second metric the user may progress instead of, or together with, primary.
    var secondaryProgressionMetric: MeasurementMetric?
    /// Whether primary, secondary, or both advance after success.
    var progressionMode: MultiMetricProgressionMode

    /// Catalog / custom defaults (nil → fall back to app/category defaults).
    var defaultWeightIncrementKg: Double?
    var defaultRepIncrement: Int?
    var defaultDurationIncrementSeconds: Int?
    var defaultDistanceIncrementMeters: Double?
    var defaultSetIncrement: Int?

    init(
        metrics: [MeasurementMetric],
        primaryProgressionMetric: MeasurementMetric,
        secondaryProgressionMetric: MeasurementMetric? = nil,
        progressionMode: MultiMetricProgressionMode = .primary,
        defaultWeightIncrementKg: Double? = nil,
        defaultRepIncrement: Int? = nil,
        defaultDurationIncrementSeconds: Int? = nil,
        defaultDistanceIncrementMeters: Double? = nil,
        defaultSetIncrement: Int? = nil
    ) {
        let unique = Self.normalizedMetrics(metrics)
        self.metrics = unique
        let primary = unique.contains(primaryProgressionMetric)
            ? primaryProgressionMetric
            : (unique.first(where: { $0 != .sets }) ?? unique.first ?? .reps)
        self.primaryProgressionMetric = primary
        if let secondary = secondaryProgressionMetric,
           unique.contains(secondary),
           secondary != primary {
            self.secondaryProgressionMetric = secondary
        } else {
            self.secondaryProgressionMetric = nil
        }
        if self.secondaryProgressionMetric == nil, progressionMode != .primary {
            self.progressionMode = .primary
        } else {
            self.progressionMode = progressionMode
        }
        self.defaultWeightIncrementKg = defaultWeightIncrementKg
        self.defaultRepIncrement = defaultRepIncrement
        self.defaultDurationIncrementSeconds = defaultDurationIncrementSeconds
        self.defaultDistanceIncrementMeters = defaultDistanceIncrementMeters
        self.defaultSetIncrement = defaultSetIncrement
    }

    func supports(_ metric: MeasurementMetric) -> Bool {
        metrics.contains(metric)
    }

    /// Metrics the user may choose as a progression target (includes sets when selected).
    var selectableProgressionMetrics: [MeasurementMetric] {
        metrics
    }

    var activeProgressionMetrics: [MeasurementMetric] {
        switch progressionMode {
        case .primary:
            return [primaryProgressionMetric]
        case .secondary:
            if let secondary = secondaryProgressionMetric {
                return [secondary]
            }
            return [primaryProgressionMetric]
        case .both:
            var result = [primaryProgressionMetric]
            if let secondary = secondaryProgressionMetric {
                result.append(secondary)
            }
            return result
        }
    }

    mutating func setMetrics(_ newMetrics: [MeasurementMetric]) {
        metrics = Self.normalizedMetrics(newMetrics)
        if !metrics.contains(primaryProgressionMetric) {
            primaryProgressionMetric = metrics.first(where: { $0 != .sets }) ?? metrics.first ?? .reps
        }
        if let secondary = secondaryProgressionMetric, !metrics.contains(secondary) || secondary == primaryProgressionMetric {
            secondaryProgressionMetric = nil
            progressionMode = .primary
        }
    }

    // MARK: - Legacy bridge

    /// Maps the historical single `MeasurementUnit` into a multi-metric profile.
    static func migrated(from unit: MeasurementUnit) -> ExerciseTrackingProfile {
        switch unit {
        case .weight:
            return ExerciseTrackingProfile(
                metrics: [.weight, .reps, .sets],
                primaryProgressionMetric: .weight
            )
        case .bodyweight, .reps:
            return ExerciseTrackingProfile(
                metrics: [.reps, .sets],
                primaryProgressionMetric: .reps,
                defaultRepIncrement: 2
            )
        case .time:
            return ExerciseTrackingProfile(
                metrics: [.time, .sets],
                primaryProgressionMetric: .time,
                defaultDurationIncrementSeconds: 5
            )
        case .distance:
            return ExerciseTrackingProfile(
                metrics: [.distance, .sets],
                primaryProgressionMetric: .distance,
                defaultDistanceIncrementMeters: 5
            )
        case .weightAndTime:
            return ExerciseTrackingProfile(
                metrics: [.weight, .time, .sets],
                primaryProgressionMetric: .time,
                secondaryProgressionMetric: .weight,
                progressionMode: .primary,
                defaultWeightIncrementKg: 2.5,
                defaultDurationIncrementSeconds: 5
            )
        case .repsWithOptionalWeight:
            return ExerciseTrackingProfile(
                metrics: [.weight, .reps, .sets],
                primaryProgressionMetric: .reps,
                secondaryProgressionMetric: .weight,
                progressionMode: .primary,
                defaultRepIncrement: 2
            )
        }
    }

    /// Best-effort legacy unit for older code paths that still switch on `MeasurementUnit`.
    var legacyMeasurementUnit: MeasurementUnit {
        let hasWeight = supports(.weight)
        let hasReps = supports(.reps)
        let hasTime = supports(.time)
        let hasDistance = supports(.distance)

        if hasWeight && hasTime {
            return .weightAndTime
        }
        if hasWeight && hasReps && primaryProgressionMetric == .reps {
            return .repsWithOptionalWeight
        }
        if hasWeight && hasReps {
            return .weight
        }
        if hasWeight && hasDistance {
            // No dedicated legacy case — weight+distance surfaces as weight for old switches,
            // while UI/engine use `metrics` directly.
            return .weight
        }
        if hasDistance && hasTime {
            return .distance
        }
        if hasTime {
            return .time
        }
        if hasDistance {
            return .distance
        }
        if hasReps {
            return .reps
        }
        if hasWeight {
            return .weight
        }
        return .reps
    }

    var compactSummary: String {
        metrics.map(\.label).joined(separator: " · ")
    }

    private static func normalizedMetrics(_ metrics: [MeasurementMetric]) -> [MeasurementMetric] {
        var seen = Set<MeasurementMetric>()
        var result: [MeasurementMetric] = []
        for metric in metrics where seen.insert(metric).inserted {
            result.append(metric)
        }
        if result.isEmpty {
            return [.reps, .sets]
        }
        // Sets are almost always useful for session structure.
        if !result.contains(.sets) {
            result.append(.sets)
        }
        return result
    }

    // MARK: Catalog helpers

    static func weightRepsSets(primary: MeasurementMetric = .weight) -> ExerciseTrackingProfile {
        ExerciseTrackingProfile(metrics: [.weight, .reps, .sets], primaryProgressionMetric: primary)
    }

    static func repsSets(repIncrement: Int = 2) -> ExerciseTrackingProfile {
        ExerciseTrackingProfile(
            metrics: [.reps, .sets],
            primaryProgressionMetric: .reps,
            defaultRepIncrement: repIncrement
        )
    }

    static func timeSets(seconds: Int = 5) -> ExerciseTrackingProfile {
        ExerciseTrackingProfile(
            metrics: [.time, .sets],
            primaryProgressionMetric: .time,
            defaultDurationIncrementSeconds: seconds
        )
    }

    static func weightTimeSets(
        primary: MeasurementMetric = .time,
        mode: MultiMetricProgressionMode = .primary,
        weightKg: Double = 2.5,
        seconds: Int = 5
    ) -> ExerciseTrackingProfile {
        ExerciseTrackingProfile(
            metrics: [.weight, .time, .sets],
            primaryProgressionMetric: primary,
            secondaryProgressionMetric: primary == .weight ? .time : .weight,
            progressionMode: mode,
            defaultWeightIncrementKg: weightKg,
            defaultDurationIncrementSeconds: seconds
        )
    }

    static func weightDistanceSets(
        primary: MeasurementMetric = .distance,
        meters: Double = 5,
        weightKg: Double = 2.5
    ) -> ExerciseTrackingProfile {
        ExerciseTrackingProfile(
            metrics: [.weight, .distance, .sets],
            primaryProgressionMetric: primary,
            secondaryProgressionMetric: primary == .weight ? .distance : .weight,
            progressionMode: .primary,
            defaultWeightIncrementKg: weightKg,
            defaultDistanceIncrementMeters: meters
        )
    }

    static func distanceTimeSets(
        primary: MeasurementMetric = .distance,
        meters: Double = 100,
        seconds: Int = 5
    ) -> ExerciseTrackingProfile {
        ExerciseTrackingProfile(
            metrics: [.distance, .time, .sets],
            primaryProgressionMetric: primary,
            secondaryProgressionMetric: primary == .distance ? .time : .distance,
            progressionMode: .primary,
            defaultDurationIncrementSeconds: seconds,
            defaultDistanceIncrementMeters: meters
        )
    }

    static func distanceSets(meters: Double = 5) -> ExerciseTrackingProfile {
        ExerciseTrackingProfile(
            metrics: [.distance, .sets],
            primaryProgressionMetric: .distance,
            defaultDistanceIncrementMeters: meters
        )
    }
}
