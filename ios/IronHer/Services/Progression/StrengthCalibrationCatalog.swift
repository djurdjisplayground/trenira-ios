import Foundation

/// Representative movement patterns for V1 starting-weight calibration.
/// Uses existing catalog IDs only — never a parallel exercise database.
enum StrengthCalibrationCatalog {
    static let targetReps = 8...12

    static let exerciseIds: [String] = [
        "goblet-squat",
        "dumbbell-rdl",
        "dumbbell-bench-press",
        "one-arm-dumbbell-row",
        "dumbbell-shoulder-press",
        "lat-pulldown",
    ]

    static var exercises: [Exercise] {
        exerciseIds.compactMap { ExerciseCatalog.exercise(id: $0) }
    }
}
