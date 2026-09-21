import Foundation

/// Coarse strength families used to estimate untested exercises from calibration.
enum StrengthProfileFamily: String, CaseIterable, Equatable {
    case lowerSquat
    case lowerHinge
    case lowerGlute
    case pushHorizontal
    case pushVertical
    case pullHorizontal
    case pullVertical
    case biceps
    case triceps
    case carry
}

struct StrengthExerciseRelation: Equatable {
    let family: StrengthProfileFamily
    /// Load relative to the family baseline (calibration exercise ≈ 1.0).
    let coefficient: Double
}

/// Central metadata for strength-profile inference. Not used by SwiftUI views directly.
enum StrengthProfileCatalog {
    /// When a family was not tested, borrow a related baseline with this scale.
    static let relatedFamilyScale: [StrengthProfileFamily: [(StrengthProfileFamily, Double)]] = [
        .lowerSquat: [(.lowerHinge, 0.9), (.lowerGlute, 1.05)],
        .lowerHinge: [(.lowerSquat, 0.9), (.lowerGlute, 0.95)],
        .lowerGlute: [(.lowerSquat, 0.9), (.lowerHinge, 0.85)],
        .pushHorizontal: [(.pushVertical, 1.15)],
        .pushVertical: [(.pushHorizontal, 0.7)],
        .pullHorizontal: [(.pullVertical, 0.9)],
        .pullVertical: [(.pullHorizontal, 1.1)],
        .biceps: [(.pullHorizontal, 0.4), (.pullVertical, 0.35)],
        .triceps: [(.pushHorizontal, 0.4), (.pushVertical, 0.45)],
        .carry: [(.lowerHinge, 0.5), (.lowerSquat, 0.45)]
    ]

    static func relation(for exerciseId: String) -> StrengthExerciseRelation? {
        guard let exercise = ExerciseCatalog.exercise(id: exerciseId) else { return nil }
        return relation(for: exercise)
    }

    static func relation(for exercise: Exercise) -> StrengthExerciseRelation? {
        if let override = idOverrides[exercise.id] {
            return override
        }
        guard let family = family(for: exercise) else { return nil }

        var coefficient = 1.0
        if exercise.laterality == .unilateral {
            coefficient *= 0.55
        }
        switch exercise.equipment {
        case .barbell:
            coefficient *= 2.15
        case .machine, .cable:
            coefficient *= 1.55
        case .kettlebell:
            coefficient *= 0.9
        case .dumbbell, .bodyweight:
            break
        }

        switch exercise.movementFamily {
        case .chestFly:
            coefficient *= 0.45
        case .lateralRaise:
            coefficient *= 0.28
        case .legCurl, .legExtension:
            coefficient *= 0.5
        default:
            break
        }

        return StrengthExerciseRelation(family: family, coefficient: max(0.12, coefficient))
    }

    static func roundingIncrementKg(for exercise: Exercise) -> Double {
        switch exercise.equipment {
        case .dumbbell, .kettlebell:
            return 1.0
        case .barbell, .machine, .cable:
            return 2.5
        case .bodyweight:
            return 1.0
        }
    }

    static func shouldEstimateExternalLoad(for exercise: Exercise) -> Bool {
        guard exercise.showsWeightDuringSession else { return false }
        switch exercise.measurementUnit {
        case .time, .distance, .reps, .bodyweight:
            return false
        case .weight, .weightAndTime, .repsWithOptionalWeight:
            break
        }
        switch exercise.weightInterpretation {
        case .bodyweight, .none:
            return false
        case .totalLoad, .perHand, .perArm, .machineSetting:
            break
        }
        if exercise.equipment == .bodyweight, exercise.measurementUnit != .repsWithOptionalWeight {
            return false
        }
        return relation(for: exercise) != nil
    }

    static func family(for exercise: Exercise) -> StrengthProfileFamily? {
        switch exercise.movementFamily {
        case .squat, .lunge, .legExtension:
            return .lowerSquat
        case .hinge, .legCurl:
            return .lowerHinge
        case .hipThrust:
            return .lowerGlute
        case .benchPress, .inclinePress, .declinePress, .chestFly:
            return .pushHorizontal
        case .overheadPress, .lateralRaise:
            return .pushVertical
        case .row:
            return .pullHorizontal
        case .pulldown, .pullUp:
            return .pullVertical
        case .bicepCurl:
            return .biceps
        case .skullCrusher, .tricepExtension, .tricepPushdown:
            return .triceps
        case .carry:
            return .carry
        case .calfRaise, .core, .other:
            return family(fromPattern: exercise.movementPattern)
        }
    }

    private static func family(fromPattern pattern: MovementPattern) -> StrengthProfileFamily? {
        switch pattern {
        case .squat, .lunge: return .lowerSquat
        case .hinge: return .lowerHinge
        case .horizontalPush: return .pushHorizontal
        case .verticalPush: return .pushVertical
        case .horizontalPull: return .pullHorizontal
        case .verticalPull: return .pullVertical
        case .carry: return .carry
        case .isolation, .rotation, .olympic, .conditioning, .core:
            return nil
        }
    }

    /// Explicit coefficients for calibration anchors and the required proof exercises.
    private static let idOverrides: [String: StrengthExerciseRelation] = [
        "goblet-squat": .init(family: .lowerSquat, coefficient: 1.0),
        "dumbbell-rdl": .init(family: .lowerHinge, coefficient: 1.0),
        "dumbbell-bench-press": .init(family: .pushHorizontal, coefficient: 1.0),
        "one-arm-dumbbell-row": .init(family: .pullHorizontal, coefficient: 1.0),
        "dumbbell-shoulder-press": .init(family: .pushVertical, coefficient: 1.0),
        "lat-pulldown": .init(family: .pullVertical, coefficient: 1.0),
        "incline-dumbbell-press": .init(family: .pushHorizontal, coefficient: 0.85),
        "bulgarian-split-squat": .init(family: .lowerSquat, coefficient: 0.55)
    ]
}
