import Foundation

/// Persistent starting-weight sample for one catalog exercise.
/// V1 matching is exact `exerciseId` only. `movementPattern` / `movementFamily`
/// are stored so related-exercise estimation can be added later without a rewrite.
struct ExerciseCalibration: Codable, Equatable, Hashable, Identifiable {
    var exerciseId: String
    var weightKg: Double
    var reps: Int
    var date: Date
    var movementPattern: MovementPattern?
    var movementFamily: MovementFamily?
    /// Optional gym-session feel. Unused by progression.
    var effort: CalibrationEffort?
    /// `1` = exact exercise ID only. Bump when related-exercise matching ships.
    var matchingVersion: Int

    var id: String { exerciseId }

    init(
        exerciseId: String,
        weightKg: Double,
        reps: Int,
        date: Date = .now,
        movementPattern: MovementPattern? = nil,
        movementFamily: MovementFamily? = nil,
        effort: CalibrationEffort? = nil,
        matchingVersion: Int = 1
    ) {
        self.exerciseId = exerciseId
        self.weightKg = max(0, weightKg)
        self.reps = max(1, min(50, reps))
        self.date = date
        self.movementPattern = movementPattern
        self.movementFamily = movementFamily
        self.effort = effort
        self.matchingVersion = matchingVersion
    }
}

enum CalibrationEffort: String, Codable, CaseIterable, Identifiable {
    case tooEasy
    case aboutRight
    case tooHard

    var id: String { rawValue }

    var label: String {
        switch self {
        case .tooEasy: return "Too easy"
        case .aboutRight: return "About right"
        case .tooHard: return "Too hard"
        }
    }
}

struct StrengthCalibrationState: Codable, Equatable {
    var records: [String: ExerciseCalibration]
    var skippedExerciseIds: [String]
    var hasFinishedOrSkippedFlow: Bool
    var hasDismissedHomePrompt: Bool

    static let empty = StrengthCalibrationState(
        records: [:],
        skippedExerciseIds: [],
        hasFinishedOrSkippedFlow: false,
        hasDismissedHomePrompt: false
    )
}
