import Foundation

// MARK: - Progression configurations (user-defined presets)

/// A reusable progression philosophy the user can apply as default or per exercise.
struct ProgressionConfiguration: Codable, Equatable, Identifiable, Hashable {
    var id: UUID
    var name: String
    /// How many sets this configuration expects for progression.
    var targetSets: Int
    /// Reps to restart at after a weight increase.
    var startingReps: Int
    /// Reps that trigger a weight increase when hit on all required sets.
    var thresholdReps: Int
    /// How much to add when the threshold is reached (kg).
    var weightIncrementKg: Double

    static func makeDefault() -> ProgressionConfiguration {
        ProgressionConfiguration(
            id: UUID(),
            name: "Default Strength",
            targetSets: 4,
            startingReps: 8,
            thresholdReps: 15,
            weightIncrementKg: 2.5
        )
    }

    static func makeHigherRep() -> ProgressionConfiguration {
        ProgressionConfiguration(
            id: UUID(),
            name: "Higher Rep",
            targetSets: 3,
            startingReps: 10,
            thresholdReps: 15,
            weightIncrementKg: 2.5
        )
    }

    var normalized: ProgressionConfiguration {
        var copy = self
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.name = trimmed.isEmpty ? "Progression" : trimmed
        copy.targetSets = min(10, max(1, targetSets))
        copy.startingReps = min(50, max(1, startingReps))
        copy.thresholdReps = min(50, max(copy.startingReps, thresholdReps))
        copy.weightIncrementKg = max(0.25, weightIncrementKg)
        return copy
    }

    /// Discrete ladder (e.g. 8 → 10 → 12 → 15), never contiguous +1 steps.
    var repSteps: [Int] {
        Self.discreteRepLadder(from: normalized.startingReps, to: normalized.thresholdReps)
    }

    /// Builds a practical strength ladder between endpoints.
    /// Prefer common stages (8, 10, 12, 15) instead of 8→9→10→11→12.
    static func discreteRepLadder(from start: Int, to end: Int) -> [Int] {
        let lo = max(1, min(start, end))
        let hi = max(1, max(start, end))
        guard hi > lo else { return [lo] }

        let preferred = [6, 8, 10, 12, 15, 20, 25]
        var steps = preferred.filter { $0 > lo && $0 < hi }
        steps.insert(lo, at: 0)
        steps.append(hi)

        var unique: [Int] = []
        for step in steps where unique.last != step {
            unique.append(step)
        }
        return unique
    }

    var compactSummary: String {
        let rule = normalized
        let ladder = repSteps.map(String.init).joined(separator: " → ")
        return "\(rule.targetSets) sets · \(ladder) · +\(String(format: "%g", rule.weightIncrementKg)) kg"
    }

    var ladderSummary: String {
        repSteps.map(String.init).joined(separator: " → ") + " reps"
    }

    func explanation(weightUnit: WeightUnit) -> String {
        let rule = normalized
        let increment = WeightFormatter.format(kg: rule.weightIncrementKg, unit: weightUnit)
        let ladder = ladderSummary
        return "Climb \(ladder) across \(rule.targetSets) sets. When you complete every set at \(rule.thresholdReps) reps, increase weight by \(increment) and restart at \(rule.startingReps) reps."
    }

    /// Maps this configuration onto an exercise. Duration/distance stay on defaults for now.
    func exerciseRule(
        for exercise: Exercise,
        fallbackIncrementKg: Double
    ) -> ExerciseProgressionRule {
        let rule = normalized
        let increment = rule.weightIncrementKg > 0 ? rule.weightIncrementKg : max(0.25, fallbackIncrementKg)

        switch exercise.measurementUnit {
        case .weight, .repsWithOptionalWeight:
            return ExerciseProgressionRule(
                method: .doubleProgression,
                targetSets: rule.targetSets,
                repSteps: rule.repSteps,
                weightIncrementKg: increment,
                durationSteps: [30, 45, 60],
                increaseWeightAfterDurationCycle: false
            )
        case .reps, .bodyweight:
            return ExerciseProgressionRule(
                method: .repsOnly,
                targetSets: rule.targetSets,
                repSteps: rule.repSteps,
                weightIncrementKg: 0,
                durationSteps: [30, 45, 60],
                increaseWeightAfterDurationCycle: false
            )
        case .time, .weightAndTime, .distance:
            return ExerciseProgressionRule.recommended(
                for: exercise,
                weightIncrementKg: fallbackIncrementKg
            )
        }
    }
}

/// Legacy single-rule shape — kept for migration from earlier builds.
struct GlobalProgressionRule: Codable, Equatable, Hashable {
    var targetSets: Int
    var startingReps: Int
    var thresholdReps: Int
    var weightIncrementKg: Double

    static let `default` = GlobalProgressionRule(
        targetSets: 4,
        startingReps: 8,
        thresholdReps: 15,
        weightIncrementKg: 2.5
    )

    var asConfiguration: ProgressionConfiguration {
        ProgressionConfiguration(
            id: UUID(),
            name: "Default Strength",
            targetSets: targetSets,
            startingReps: startingReps,
            thresholdReps: thresholdReps,
            weightIncrementKg: weightIncrementKg
        ).normalized
    }
}

// MARK: - Method

enum ProgressionMethodChoice: String, Codable, CaseIterable, Identifiable {
    /// Weight + reps double progression: climb rep ladder, then +weight and reset to first step.
    case doubleProgression
    /// Reps-only ladder or open-ended +rep increment.
    case repsOnly
    /// Duration ladder or open-ended +duration increment; optional weight bump after cycle.
    case durationCycle
    /// Increase planned set count after successful completion.
    case setsProgression
    /// User manages everything manually.
    case manual

    var id: String { rawValue }

    var label: String {
        switch self {
        case .doubleProgression: return "Weight + repetitions"
        case .repsOnly: return "Increase repetitions"
        case .durationCycle: return "Increase duration"
        case .setsProgression: return "Increase sets"
        case .manual: return "Manual / custom"
        }
    }
}

enum ProgressionPreset: String, CaseIterable, Identifiable {
    case double815
    case simple812
    case highRep1015
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .double815: return "Double Progression"
        case .simple812: return "Simple Rep Progression"
        case .highRep1015: return "High Rep Progression"
        case .manual: return "Manual"
        }
    }

    var subtitle: String {
        switch self {
        case .double815: return "8 → 12 → 15, then +weight and restart at 8"
        case .simple812: return "8 → 10 → 12, then +weight and restart at 8"
        case .highRep1015: return "10 → 12 → 15, then +weight and restart at 10"
        case .manual: return "You control weight and reps yourself"
        }
    }
}

/// User-defined automatic progression cycle for one exercise.
struct ExerciseProgressionRule: Codable, Equatable, Hashable {
    var method: ProgressionMethodChoice
    var targetSets: Int
    /// Ordered rep targets, e.g. [8, 12, 15]. For open-ended +reps, often just the starting value.
    var repSteps: [Int]
    var weightIncrementKg: Double
    /// Ordered duration targets in seconds, e.g. [30, 45, 60].
    var durationSteps: [Int]
    /// For weight+duration: after final duration step, increase weight and reset duration.
    var increaseWeightAfterDurationCycle: Bool
    /// When > 0 and no higher ladder step remains, advance by this many reps (e.g. push-ups +2).
    var repIncrement: Int
    /// When > 0 and no higher duration step remains, advance by this many seconds.
    var durationIncrementSeconds: Int
    /// For sets progression: how many sets to add after a successful session.
    var setIncrement: Int

    var automaticProgression: Bool { method != .manual }

    var startingReps: Int { repSteps.first ?? 8 }
    var maximumReps: Int { repSteps.last ?? 15 }

    static func recommended(
        for exercise: Exercise,
        weightIncrementKg: Double
    ) -> ExerciseProgressionRule {
        let increment = max(weightIncrementKg, EquipmentDefaults.defaultIncrementKg(for: exercise.equipment))
        switch exercise.measurementUnit {
        case .weight, .repsWithOptionalWeight:
            return .preset(.double815, sets: 3, weightIncrementKg: increment, method: .doubleProgression)
        case .reps, .bodyweight:
            return ExerciseProgressionRule(
                method: .repsOnly,
                targetSets: 3,
                repSteps: [8],
                weightIncrementKg: 0,
                durationSteps: [30, 45, 60],
                increaseWeightAfterDurationCycle: false,
                repIncrement: 2,
                durationIncrementSeconds: 0,
                setIncrement: 1
            )
        case .time:
            return ExerciseProgressionRule(
                method: .durationCycle,
                targetSets: 3,
                repSteps: [8, 12, 15],
                weightIncrementKg: 0,
                durationSteps: [30, 45, 60],
                increaseWeightAfterDurationCycle: false,
                repIncrement: 0,
                durationIncrementSeconds: 15,
                setIncrement: 1
            )
        case .weightAndTime:
            return ExerciseProgressionRule(
                method: .durationCycle,
                targetSets: 3,
                repSteps: [8, 12, 15],
                weightIncrementKg: increment,
                durationSteps: [30, 45, 60],
                increaseWeightAfterDurationCycle: true,
                repIncrement: 0,
                durationIncrementSeconds: 0,
                setIncrement: 1
            )
        case .distance:
            return .manualDefault(sets: 3)
        }
    }

    static func preset(
        _ preset: ProgressionPreset,
        sets: Int,
        weightIncrementKg: Double,
        method: ProgressionMethodChoice? = nil
    ) -> ExerciseProgressionRule {
        switch preset {
        case .double815:
            return ExerciseProgressionRule(
                method: method ?? .doubleProgression,
                targetSets: sets,
                repSteps: [8, 12, 15],
                weightIncrementKg: weightIncrementKg,
                durationSteps: [30, 45, 60],
                increaseWeightAfterDurationCycle: method == .durationCycle,
                repIncrement: 0,
                durationIncrementSeconds: 0,
                setIncrement: 1
            )
        case .simple812:
            return ExerciseProgressionRule(
                method: method ?? .doubleProgression,
                targetSets: sets,
                repSteps: [8, 10, 12],
                weightIncrementKg: weightIncrementKg,
                durationSteps: [30, 45, 60],
                increaseWeightAfterDurationCycle: false,
                repIncrement: 0,
                durationIncrementSeconds: 0,
                setIncrement: 1
            )
        case .highRep1015:
            return ExerciseProgressionRule(
                method: method ?? .doubleProgression,
                targetSets: sets,
                repSteps: [10, 12, 15],
                weightIncrementKg: weightIncrementKg,
                durationSteps: [30, 45, 60],
                increaseWeightAfterDurationCycle: false,
                repIncrement: 0,
                durationIncrementSeconds: 0,
                setIncrement: 1
            )
        case .manual:
            return .manualDefault(sets: sets)
        }
    }

    static func manualDefault(sets: Int) -> ExerciseProgressionRule {
        ExerciseProgressionRule(
            method: .manual,
            targetSets: sets,
            repSteps: [8, 12, 15],
            weightIncrementKg: 2.5,
            durationSteps: [30, 45, 60],
            increaseWeightAfterDurationCycle: false,
            repIncrement: 0,
            durationIncrementSeconds: 0,
            setIncrement: 1
        )
    }

    var normalizedRepSteps: [Int] {
        let cleaned = Array(Set(repSteps.filter { $0 > 0 })).sorted()
        return cleaned.isEmpty ? [8, 12, 15] : cleaned
    }

    var normalizedDurationSteps: [Int] {
        let cleaned = Array(Set(durationSteps.filter { $0 > 0 })).sorted()
        return cleaned.isEmpty ? [30, 45, 60] : cleaned
    }

    var recommendedSummary: String {
        switch method {
        case .manual:
            return "Manual — you control progression yourself."
        case .doubleProgression:
            let ladder = normalizedRepSteps.map(String.init).joined(separator: " → ")
            return "\(targetSets) sets · \(ladder) · then +\(String(format: "%g", weightIncrementKg)) kg and restart at \(startingReps)"
        case .repsOnly:
            if repIncrement > 0 {
                return "\(targetSets) sets · start \(startingReps) · +\(repIncrement) reps"
            }
            let ladder = normalizedRepSteps.map(String.init).joined(separator: " → ")
            return "\(targetSets) sets · \(ladder)"
        case .durationCycle:
            let ladder = normalizedDurationSteps
                .map { ExerciseTrackingFormatter.formatDuration(seconds: $0) }
                .joined(separator: " → ")
            if increaseWeightAfterDurationCycle {
                return "\(targetSets) sets · \(ladder) · then +\(String(format: "%g", weightIncrementKg)) kg and restart"
            }
            if durationIncrementSeconds > 0 {
                return "\(targetSets) sets · start \(ExerciseTrackingFormatter.formatDuration(seconds: normalizedDurationSteps.first ?? 30)) · +\(durationIncrementSeconds) sec"
            }
            return "\(targetSets) sets · \(ladder)"
        case .setsProgression:
            return "Start at \(targetSets) sets · +\(max(1, setIncrement)) set after success"
        }
    }

    /// Visual cycle preview lines for the configure UI (e.g. `10 kg × 3 × 8`).
    func cyclePreviewLines(
        startingWeightKg: Double,
        weightUnit: WeightUnit,
        measurement: MeasurementUnit,
        maxLines: Int = 7
    ) -> [String] {
        guard automaticProgression else { return [] }

        switch method {
        case .manual:
            return []
        case .doubleProgression:
            var lines: [String] = []
            var weight = max(0, startingWeightKg)
            outer: for _ in 0..<3 {
                for reps in normalizedRepSteps {
                    let weightLabel = WeightFormatter.format(kg: weight, unit: weightUnit)
                    lines.append("\(weightLabel) × \(targetSets) × \(reps)")
                    if lines.count >= maxLines { break outer }
                }
                weight += weightIncrementKg
            }
            return lines
        case .repsOnly:
            var lines: [String] = []
            if repIncrement > 0 {
                var reps = startingReps
                for _ in 0..<maxLines {
                    lines.append("\(targetSets) × \(reps)")
                    reps += repIncrement
                }
            } else {
                for _ in 0..<2 {
                    for reps in normalizedRepSteps {
                        lines.append("\(targetSets) × \(reps)")
                        if lines.count >= maxLines { break }
                    }
                    if lines.count >= maxLines { break }
                }
            }
            return lines
        case .durationCycle:
            var lines: [String] = []
            var weight = max(0, startingWeightKg)
            let includeWeight = measurement == .weightAndTime || increaseWeightAfterDurationCycle
            if durationIncrementSeconds > 0, !increaseWeightAfterDurationCycle {
                var seconds = normalizedDurationSteps.first ?? 30
                for _ in 0..<maxLines {
                    let duration = ExerciseTrackingFormatter.formatDuration(seconds: seconds)
                    lines.append("\(targetSets) × \(duration)")
                    seconds += durationIncrementSeconds
                }
                return lines
            }
            outer: for _ in 0..<3 {
                for seconds in normalizedDurationSteps {
                    let duration = ExerciseTrackingFormatter.formatDuration(seconds: seconds)
                    if includeWeight && weight > 0 {
                        let weightLabel = WeightFormatter.format(kg: weight, unit: weightUnit)
                        lines.append("\(weightLabel) · \(targetSets) × \(duration)")
                    } else {
                        lines.append("\(targetSets) × \(duration)")
                    }
                    if lines.count >= maxLines { break outer }
                }
                if increaseWeightAfterDurationCycle {
                    weight += weightIncrementKg
                } else {
                    break
                }
            }
            return lines
        case .setsProgression:
            var lines: [String] = []
            var sets = targetSets
            for _ in 0..<min(maxLines, 5) {
                lines.append("\(sets) sets")
                sets += max(1, setIncrement)
            }
            return lines
        }
    }

    // MARK: Codable (with legacy migration)

    private enum CodingKeys: String, CodingKey {
        case method, targetSets, repSteps, weightIncrementKg, durationSteps, increaseWeightAfterDurationCycle
        case startingReps, targetReps, repIncrement, targetDurationSeconds, durationIncrementSeconds, setIncrement
        case successfulWorkoutsRequired, automaticRecommendations, primaryAction
    }

    init(
        method: ProgressionMethodChoice,
        targetSets: Int,
        repSteps: [Int],
        weightIncrementKg: Double,
        durationSteps: [Int],
        increaseWeightAfterDurationCycle: Bool,
        repIncrement: Int = 0,
        durationIncrementSeconds: Int = 0,
        setIncrement: Int = 1
    ) {
        self.method = method
        self.targetSets = max(1, targetSets)
        self.repSteps = repSteps
        self.weightIncrementKg = max(0, weightIncrementKg)
        self.durationSteps = durationSteps
        self.increaseWeightAfterDurationCycle = increaseWeightAfterDurationCycle
        self.repIncrement = max(0, repIncrement)
        self.durationIncrementSeconds = max(0, durationIncrementSeconds)
        self.setIncrement = max(1, setIncrement)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        repIncrement = try container.decodeIfPresent(Int.self, forKey: .repIncrement) ?? 0
        durationIncrementSeconds = try container.decodeIfPresent(Int.self, forKey: .durationIncrementSeconds) ?? 0
        setIncrement = max(1, try container.decodeIfPresent(Int.self, forKey: .setIncrement) ?? 1)

        if let steps = try container.decodeIfPresent([Int].self, forKey: .repSteps), !steps.isEmpty {
            repSteps = steps
        } else {
            let start = try container.decodeIfPresent(Int.self, forKey: .startingReps) ?? 8
            let target = try container.decodeIfPresent(Int.self, forKey: .targetReps) ?? 15
            let increment = repIncrement > 0 ? repIncrement : 2
            var built = [start]
            var value = start
            while value < target {
                value = min(value + increment, target)
                built.append(value)
                if value >= target { break }
            }
            if built.last != target { built.append(target) }
            repSteps = built
        }

        if let durations = try container.decodeIfPresent([Int].self, forKey: .durationSteps), !durations.isEmpty {
            durationSteps = durations
        } else {
            let target = try container.decodeIfPresent(Int.self, forKey: .targetDurationSeconds) ?? 30
            let bump = durationIncrementSeconds > 0 ? durationIncrementSeconds : 15
            durationSteps = [target, target + bump, target + bump * 2]
        }

        targetSets = try container.decodeIfPresent(Int.self, forKey: .targetSets) ?? 3
        weightIncrementKg = try container.decodeIfPresent(Double.self, forKey: .weightIncrementKg) ?? 2.5
        increaseWeightAfterDurationCycle = try container.decodeIfPresent(Bool.self, forKey: .increaseWeightAfterDurationCycle) ?? false

        if let raw = try container.decodeIfPresent(String.self, forKey: .method) {
            self.method = Self.mapLegacyMethod(raw)
        } else {
            let automatic = try container.decodeIfPresent(Bool.self, forKey: .automaticRecommendations) ?? true
            self.method = automatic ? .doubleProgression : .manual
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(method, forKey: .method)
        try container.encode(targetSets, forKey: .targetSets)
        try container.encode(normalizedRepSteps, forKey: .repSteps)
        try container.encode(weightIncrementKg, forKey: .weightIncrementKg)
        try container.encode(normalizedDurationSteps, forKey: .durationSteps)
        try container.encode(increaseWeightAfterDurationCycle, forKey: .increaseWeightAfterDurationCycle)
        try container.encode(repIncrement, forKey: .repIncrement)
        try container.encode(durationIncrementSeconds, forKey: .durationIncrementSeconds)
        try container.encode(setIncrement, forKey: .setIncrement)
    }

    private static func mapLegacyMethod(_ raw: String) -> ProgressionMethodChoice {
        switch raw {
        case "increaseRepsThenWeight", "increaseWeightAfterTarget", "doubleProgression":
            return .doubleProgression
        case "increaseRepsOnly", "repsOnly":
            return .repsOnly
        case "increaseDuration", "durationCycle":
            return .durationCycle
        case "setsProgression", "increaseSets":
            return .setsProgression
        case "manual":
            return .manual
        default:
            return .doubleProgression
        }
    }
}

// MARK: - State

struct ExerciseProgressionState: Codable, Equatable {
    var consecutiveSuccesses: Int

    init(consecutiveSuccesses: Int = 0) {
        self.consecutiveSuccesses = consecutiveSuccesses
    }

    private enum CodingKeys: String, CodingKey {
        case consecutiveSuccesses, consecutiveSuccessesAt12, consecutiveSuccessesAt15
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try container.decodeIfPresent(Int.self, forKey: .consecutiveSuccesses) {
            consecutiveSuccesses = value
        } else {
            let at12 = try container.decodeIfPresent(Int.self, forKey: .consecutiveSuccessesAt12) ?? 0
            let at15 = try container.decodeIfPresent(Int.self, forKey: .consecutiveSuccessesAt15) ?? 0
            consecutiveSuccesses = max(at12, at15)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(consecutiveSuccesses, forKey: .consecutiveSuccesses)
    }
}

// MARK: - Applied update (auto, informational)

struct AppliedProgressionUpdate: Equatable {
    enum Kind: Equatable {
        case nextRepTarget
        case weightIncreaseAndRepReset
        case nextDurationTarget
        case weightIncreaseAndDurationReset
        case repCycleRestart
        case durationCycleRestart
        case nextSetTarget
    }

    let kind: Kind
    let exerciseId: String
    let exerciseName: String
    let targetSets: Int
    let completedTargetLabel: String
    let nextWeightKg: Double?
    let nextReps: Int?
    let nextDurationSeconds: Int?
    let previousWeightKg: Double?
    let previousReps: Int?
    let previousDurationSeconds: Int?

    var headline: String {
        switch kind {
        case .nextRepTarget, .nextDurationTarget, .nextSetTarget:
            return "Target complete."
        case .weightIncreaseAndRepReset, .weightIncreaseAndDurationReset:
            return "You've reached your target."
        case .repCycleRestart, .durationCycleRestart:
            return "Cycle complete."
        }
    }
}

enum ProgressionOutcome: Equatable {
    case noChange
    case applied(AppliedProgressionUpdate)
}

struct ProgressionSessionResult: Equatable {
    let exerciseId: String
    let currentWeightKg: Double
    let currentPlannedReps: Int
    let plannedDurationSeconds: Int
    let completedSetReps: [Int]
    let completedSetDurations: [Int]
    let allPlannedSetsCompleted: Bool

    func met(sets requiredSets: Int, reps requiredReps: Int) -> Bool {
        guard completedSetReps.count >= requiredSets else { return false }
        return completedSetReps.prefix(requiredSets).allSatisfy { $0 >= requiredReps }
    }

    func met(sets requiredSets: Int, durationSeconds requiredDuration: Int) -> Bool {
        guard completedSetDurations.count >= requiredSets, requiredDuration > 0 else { return false }
        return completedSetDurations.prefix(requiredSets).allSatisfy { $0 >= requiredDuration }
    }
}

// MARK: - Engine

enum ProgressionEngine {
    static func evaluate(
        session: ProgressionSessionResult,
        exercise: Exercise,
        rule: ExerciseProgressionRule,
        state: ExerciseProgressionState
    ) -> (outcome: ProgressionOutcome, updatedState: ExerciseProgressionState) {
        var state = state
        guard rule.automaticProgression else {
            return (.noChange, state)
        }

        switch rule.method {
        case .manual:
            return (.noChange, state)
        case .doubleProgression:
            return evaluateDoubleProgression(session: session, exercise: exercise, rule: rule, state: &state)
        case .repsOnly:
            return evaluateRepsOnly(session: session, exercise: exercise, rule: rule, state: &state)
        case .durationCycle:
            return evaluateDurationCycle(session: session, exercise: exercise, rule: rule, state: &state)
        case .setsProgression:
            return evaluateSetsProgression(session: session, exercise: exercise, rule: rule, state: &state)
        }
    }

    private static func evaluateDoubleProgression(
        session: ProgressionSessionResult,
        exercise: Exercise,
        rule: ExerciseProgressionRule,
        state: inout ExerciseProgressionState
    ) -> (ProgressionOutcome, ExerciseProgressionState) {
        let steps = rule.normalizedRepSteps
        let currentTarget = session.currentPlannedReps

        guard session.met(sets: rule.targetSets, reps: currentTarget) else {
            state.consecutiveSuccesses = 0
            return (.noChange, state)
        }

        if let next = steps.first(where: { $0 > currentTarget }) {
            state.consecutiveSuccesses = 0
            let update = AppliedProgressionUpdate(
                kind: .nextRepTarget,
                exerciseId: exercise.id,
                exerciseName: exercise.name,
                targetSets: rule.targetSets,
                completedTargetLabel: "\(rule.targetSets) sets × \(currentTarget) reps",
                nextWeightKg: session.currentWeightKg,
                nextReps: next,
                nextDurationSeconds: nil,
                previousWeightKg: session.currentWeightKg,
                previousReps: currentTarget,
                previousDurationSeconds: nil
            )
            return (.applied(update), state)
        }

        // Completed the maximum rep step → increase weight and reset.
        let newWeight = session.currentWeightKg + rule.weightIncrementKg
        let resetReps = steps.first ?? rule.startingReps
        state.consecutiveSuccesses = 0
        let update = AppliedProgressionUpdate(
            kind: .weightIncreaseAndRepReset,
            exerciseId: exercise.id,
            exerciseName: exercise.name,
            targetSets: rule.targetSets,
            completedTargetLabel: "\(rule.targetSets) sets × \(currentTarget) reps",
            nextWeightKg: newWeight,
            nextReps: resetReps,
            nextDurationSeconds: nil,
            previousWeightKg: session.currentWeightKg,
            previousReps: currentTarget,
            previousDurationSeconds: nil
        )
        return (.applied(update), state)
    }

    private static func evaluateRepsOnly(
        session: ProgressionSessionResult,
        exercise: Exercise,
        rule: ExerciseProgressionRule,
        state: inout ExerciseProgressionState
    ) -> (ProgressionOutcome, ExerciseProgressionState) {
        let steps = rule.normalizedRepSteps
        let currentTarget = session.currentPlannedReps

        guard session.met(sets: rule.targetSets, reps: currentTarget) else {
            state.consecutiveSuccesses = 0
            return (.noChange, state)
        }

        let nextReps: Int?
        let kind: AppliedProgressionUpdate.Kind
        if let next = steps.first(where: { $0 > currentTarget }) {
            nextReps = next
            kind = .nextRepTarget
        } else if rule.repIncrement > 0 {
            nextReps = currentTarget + rule.repIncrement
            kind = .nextRepTarget
        } else {
            nextReps = steps.first ?? rule.startingReps
            kind = .repCycleRestart
        }

        state.consecutiveSuccesses = 0
        let update = AppliedProgressionUpdate(
            kind: kind,
            exerciseId: exercise.id,
            exerciseName: exercise.name,
            targetSets: rule.targetSets,
            completedTargetLabel: "\(rule.targetSets) sets × \(currentTarget) reps",
            nextWeightKg: nil,
            nextReps: nextReps,
            nextDurationSeconds: nil,
            previousWeightKg: nil,
            previousReps: currentTarget,
            previousDurationSeconds: nil
        )
        return (.applied(update), state)
    }

    private static func evaluateDurationCycle(
        session: ProgressionSessionResult,
        exercise: Exercise,
        rule: ExerciseProgressionRule,
        state: inout ExerciseProgressionState
    ) -> (ProgressionOutcome, ExerciseProgressionState) {
        let steps = rule.normalizedDurationSteps
        let currentTarget = max(session.plannedDurationSeconds, steps.first ?? 30)

        guard session.met(sets: rule.targetSets, durationSeconds: currentTarget) else {
            state.consecutiveSuccesses = 0
            return (.noChange, state)
        }

        if let next = steps.first(where: { $0 > currentTarget }) {
            state.consecutiveSuccesses = 0
            let update = AppliedProgressionUpdate(
                kind: .nextDurationTarget,
                exerciseId: exercise.id,
                exerciseName: exercise.name,
                targetSets: rule.targetSets,
                completedTargetLabel: "\(rule.targetSets) × \(ExerciseTrackingFormatter.formatDuration(seconds: currentTarget))",
                nextWeightKg: session.currentWeightKg > 0 ? session.currentWeightKg : nil,
                nextReps: nil,
                nextDurationSeconds: next,
                previousWeightKg: session.currentWeightKg > 0 ? session.currentWeightKg : nil,
                previousReps: nil,
                previousDurationSeconds: currentTarget
            )
            return (.applied(update), state)
        }

        if rule.durationIncrementSeconds > 0, !rule.increaseWeightAfterDurationCycle {
            state.consecutiveSuccesses = 0
            let next = currentTarget + rule.durationIncrementSeconds
            let update = AppliedProgressionUpdate(
                kind: .nextDurationTarget,
                exerciseId: exercise.id,
                exerciseName: exercise.name,
                targetSets: rule.targetSets,
                completedTargetLabel: "\(rule.targetSets) × \(ExerciseTrackingFormatter.formatDuration(seconds: currentTarget))",
                nextWeightKg: session.currentWeightKg > 0 ? session.currentWeightKg : nil,
                nextReps: nil,
                nextDurationSeconds: next,
                previousWeightKg: session.currentWeightKg > 0 ? session.currentWeightKg : nil,
                previousReps: nil,
                previousDurationSeconds: currentTarget
            )
            return (.applied(update), state)
        }

        let resetDuration = steps.first ?? 30
        state.consecutiveSuccesses = 0

        if rule.increaseWeightAfterDurationCycle, rule.weightIncrementKg > 0 {
            let newWeight = session.currentWeightKg + rule.weightIncrementKg
            let update = AppliedProgressionUpdate(
                kind: .weightIncreaseAndDurationReset,
                exerciseId: exercise.id,
                exerciseName: exercise.name,
                targetSets: rule.targetSets,
                completedTargetLabel: "\(rule.targetSets) × \(ExerciseTrackingFormatter.formatDuration(seconds: currentTarget))",
                nextWeightKg: newWeight,
                nextReps: nil,
                nextDurationSeconds: resetDuration,
                previousWeightKg: session.currentWeightKg,
                previousReps: nil,
                previousDurationSeconds: currentTarget
            )
            return (.applied(update), state)
        }

        let update = AppliedProgressionUpdate(
            kind: .durationCycleRestart,
            exerciseId: exercise.id,
            exerciseName: exercise.name,
            targetSets: rule.targetSets,
            completedTargetLabel: "\(rule.targetSets) × \(ExerciseTrackingFormatter.formatDuration(seconds: currentTarget))",
            nextWeightKg: session.currentWeightKg > 0 ? session.currentWeightKg : nil,
            nextReps: nil,
            nextDurationSeconds: resetDuration,
            previousWeightKg: session.currentWeightKg > 0 ? session.currentWeightKg : nil,
            previousReps: nil,
            previousDurationSeconds: currentTarget
        )
        return (.applied(update), state)
    }

    private static func evaluateSetsProgression(
        session: ProgressionSessionResult,
        exercise: Exercise,
        rule: ExerciseProgressionRule,
        state: inout ExerciseProgressionState
    ) -> (ProgressionOutcome, ExerciseProgressionState) {
        let requiredSets = rule.targetSets
        let minReps = rule.startingReps
        let completedEnough: Bool = {
            if exercise.showsRepsDuringSession {
                return session.met(sets: requiredSets, reps: minReps)
            }
            if session.plannedDurationSeconds > 0 {
                return session.met(sets: requiredSets, durationSeconds: session.plannedDurationSeconds)
            }
            return session.completedSetReps.count >= requiredSets
                || session.completedSetDurations.count >= requiredSets
                || session.allPlannedSetsCompleted
        }()

        guard completedEnough else {
            state.consecutiveSuccesses = 0
            return (.noChange, state)
        }

        let nextSets = requiredSets + max(1, rule.setIncrement)
        state.consecutiveSuccesses = 0
        let update = AppliedProgressionUpdate(
            kind: .nextSetTarget,
            exerciseId: exercise.id,
            exerciseName: exercise.name,
            targetSets: nextSets,
            completedTargetLabel: "\(requiredSets) sets",
            nextWeightKg: session.currentWeightKg > 0 ? session.currentWeightKg : nil,
            nextReps: session.currentPlannedReps,
            nextDurationSeconds: session.plannedDurationSeconds > 0 ? session.plannedDurationSeconds : nil,
            previousWeightKg: session.currentWeightKg > 0 ? session.currentWeightKg : nil,
            previousReps: session.currentPlannedReps,
            previousDurationSeconds: session.plannedDurationSeconds > 0 ? session.plannedDurationSeconds : nil
        )
        return (.applied(update), state)
    }
}

// MARK: - In-workout progress

enum ProgressionTargetProgress {
    static func summary(
        rule: ExerciseProgressionRule,
        state: ExerciseSessionState,
        currentPlannedReps: Int,
        currentPlannedDuration: Int
    ) -> String? {
        guard rule.automaticProgression else { return nil }

        switch rule.method {
        case .manual:
            return nil
        case .doubleProgression, .repsOnly:
            let meeting = state.setPerformances.indices.filter { index in
                state.completedSetFlags.indices.contains(index)
                    && state.completedSetFlags[index]
                    && state.setPerformances[index].reps >= currentPlannedReps
            }.count
            return "Target: \(rule.targetSets) × \(currentPlannedReps) — \(meeting) of \(rule.targetSets) sets reached"
        case .durationCycle:
            let target = max(currentPlannedDuration, rule.normalizedDurationSteps.first ?? 30)
            let meeting = state.setPerformances.indices.filter { index in
                state.completedSetFlags.indices.contains(index)
                    && state.completedSetFlags[index]
                    && state.setPerformances[index].durationSeconds >= target
            }.count
            let label = ExerciseTrackingFormatter.formatDuration(seconds: target)
            return "Target: \(rule.targetSets) × \(label) — \(meeting) of \(rule.targetSets) sets reached"
        case .setsProgression:
            let meeting = state.completedSetFlags.filter(\.self).count
            return "Target: \(rule.targetSets) sets — \(meeting) of \(rule.targetSets) completed"
        }
    }

    /// Rep or duration ladder with the current target emphasized, e.g. `8 → 12 → 15`.
    static func pathLabels(
        rule: ExerciseProgressionRule,
        currentPlannedReps: Int,
        currentPlannedDuration: Int
    ) -> (labels: [String], currentIndex: Int)? {
        guard rule.automaticProgression else { return nil }

        switch rule.method {
        case .manual, .setsProgression:
            return nil
        case .doubleProgression, .repsOnly:
            if rule.repIncrement > 0 {
                let start = max(rule.startingReps, currentPlannedReps - rule.repIncrement * 2)
                let steps = [start, start + rule.repIncrement, start + rule.repIncrement * 2]
                    .filter { $0 > 0 }
                let index = steps.firstIndex(of: currentPlannedReps) ?? 0
                return (steps.map(String.init), index)
            }
            let steps = rule.normalizedRepSteps
            let index = steps.firstIndex(of: currentPlannedReps)
                ?? steps.lastIndex(where: { $0 <= currentPlannedReps })
                ?? 0
            return (steps.map(String.init), index)
        case .durationCycle:
            let steps = rule.normalizedDurationSteps
            let target = max(currentPlannedDuration, steps.first ?? 30)
            let index = steps.firstIndex(of: target)
                ?? steps.lastIndex(where: { $0 <= target })
                ?? 0
            return (steps.map { ExerciseTrackingFormatter.formatDuration(seconds: $0) }, index)
        }
    }
}
