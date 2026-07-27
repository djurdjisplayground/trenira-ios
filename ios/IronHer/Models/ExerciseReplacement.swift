import Foundation

/// Why the athlete wants to swap one exercise in a plan or active session.
enum ExerciseReplacementReason: String, CaseIterable, Codable, Identifiable, Hashable {
    case equipmentUnavailable
    case cannotIncreaseWeight
    case discomfort
    case variety
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .equipmentUnavailable:
            return "Equipment unavailable"
        case .cannotIncreaseWeight:
            return "Cannot increase the weight"
        case .discomfort:
            return "Exercise feels uncomfortable"
        case .variety:
            return "Want some variety"
        case .other:
            return "Other"
        }
    }
}

/// Progression-style adjustments when load cannot increase further.
enum ExerciseHarderMethod: String, CaseIterable, Identifiable, Hashable {
    case unilateralVariation
    case addPause
    case slowerTempo
    case increaseRangeOfMotion
    case increaseReps

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unilateralVariation: return "Use a unilateral variation"
        case .addPause: return "Add a pause"
        case .slowerTempo: return "Use a slower tempo"
        case .increaseRangeOfMotion: return "Increase range of motion"
        case .increaseReps: return "Increase repetitions"
        }
    }
}

/// Heuristic difficulty tags inferred from name / laterality — not persisted on `Exercise`.
enum ExerciseDifficultyModifier: String, Codable, CaseIterable, Hashable {
    case bilateral
    case unilateral
    case tempo
    case paused
    case extendedRangeOfMotion
    case standard

    var label: String {
        switch self {
        case .bilateral: return "Bilateral"
        case .unilateral: return "Unilateral"
        case .tempo: return "Tempo"
        case .paused: return "Paused"
        case .extendedRangeOfMotion: return "Extended ROM"
        case .standard: return "Standard"
        }
    }
}

struct ExerciseRecommendation: Identifiable, Hashable {
    let id: String
    let exercise: Exercise
    let suitabilityReason: String
    let score: Int
    /// True when match is only same primary muscle (broader fallback).
    let isBroaderAlternative: Bool

    init(
        exercise: Exercise,
        suitabilityReason: String,
        score: Int,
        isBroaderAlternative: Bool = false
    ) {
        self.id = exercise.id
        self.exercise = exercise
        self.suitabilityReason = suitabilityReason
        self.score = score
        self.isBroaderAlternative = isBroaderAlternative
    }
}

/// Common rest-duration choices used in Settings and per-exercise overrides.
enum RestDurationOption: Int, CaseIterable, Identifiable, Hashable {
    case thirty = 30
    case fortyFive = 45
    case sixty = 60
    case ninety = 90
    case oneTwenty = 120
    case oneEighty = 180

    var id: Int { rawValue }

    var timeInterval: TimeInterval { TimeInterval(rawValue) }

    var label: String {
        if rawValue < 60 {
            return "\(rawValue) sec"
        }
        let minutes = rawValue / 60
        let seconds = rawValue % 60
        if seconds == 0 {
            return minutes == 1 ? "1 min" : "\(minutes) min"
        }
        return "\(rawValue) sec"
    }

    static func closest(to interval: TimeInterval) -> RestDurationOption {
        let seconds = Int(interval.rounded())
        return allCases.min(by: { abs($0.rawValue - seconds) < abs($1.rawValue - seconds) }) ?? .ninety
    }
}

/// Where a chosen replacement should be applied.
enum ExerciseReplacementScope: String, Codable, CaseIterable, Identifiable, Hashable {
    /// Active session override only — saved plans unchanged.
    case currentSession
    /// Selected occurrence in the current saved workout plan.
    case currentWorkout
    /// Every occurrence of the original exercise in every saved (non-draft) plan.
    case allWorkouts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .currentSession: return "This Session Only"
        case .currentWorkout: return "This Workout Only"
        case .allWorkouts: return "All Workouts"
        }
    }
}

struct ExerciseReplacementResult: Equatable {
    let scope: ExerciseReplacementScope
    let updatedWorkoutCount: Int
    let originalExerciseName: String
    let replacementExerciseName: String

    var feedbackMessage: String {
        switch scope {
        case .currentSession:
            return "Updated this session only."
        case .currentWorkout:
            return "Updated this workout plan."
        case .allWorkouts:
            let n = updatedWorkoutCount
            return n == 1 ? "Updated 1 workout plan." : "Updated \(n) workout plans."
        }
    }
}

struct RestTimerSettings: Codable, Equatable {
    var isEnabled: Bool
    var defaultDuration: TimeInterval
    var soundEnabled: Bool
    var hapticsEnabled: Bool

    init(
        isEnabled: Bool = true,
        defaultDuration: TimeInterval = 90,
        soundEnabled: Bool = false,
        hapticsEnabled: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.defaultDuration = defaultDuration
        self.soundEnabled = soundEnabled
        self.hapticsEnabled = hapticsEnabled
    }

    static let `default` = RestTimerSettings()
}
