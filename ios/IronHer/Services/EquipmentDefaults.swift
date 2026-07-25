import Foundation

enum EquipmentDefaults {
    /// Soft starting values only — users should set increments to match their gym.
    static func defaultIncrementKg(for equipment: EquipmentType) -> Double {
        switch equipment {
        case .barbell:
            return 2.5
        case .dumbbell:
            return 2.0
        case .cable, .machine, .kettlebell:
            // Neutral starting point; gyms vary widely — treat as user-defined.
            return 2.5
        case .bodyweight:
            return 0
        }
    }

    static func defaultMeasurementUnit(for equipment: EquipmentType) -> MeasurementUnit {
        equipment == .bodyweight ? .bodyweight : .weight
    }

    static func defaultProgressionMethod(for measurement: MeasurementUnit) -> ProgressionMethod {
        switch measurement {
        case .weight: return .addWeight
        case .bodyweight, .reps, .repsWithOptionalWeight: return .addReps
        case .time, .weightAndTime: return .addDuration
        case .distance: return .addDistance
        }
    }

    static func defaultSupportsProgressiveOverload(
        equipment: EquipmentType,
        measurement: MeasurementUnit
    ) -> Bool {
        switch measurement {
        case .weight:
            return equipment != .bodyweight
        case .bodyweight, .time, .distance, .reps, .weightAndTime, .repsWithOptionalWeight:
            return false
        }
    }
}

enum ExerciseIncrementResolver {
    /// Machine and cable stacks vary by gym — ask per exercise instead of a global default.
    static func requiresContextualIncrement(for equipment: EquipmentType) -> Bool {
        equipment == .machine || equipment == .cable
    }

    static func needsContextualPrompt(
        for exercise: Exercise,
        exerciseOverridesKg: [String: Double]
    ) -> Bool {
        guard requiresContextualIncrement(for: exercise.equipment) else { return false }
        guard exercise.showsWeightDuringSession else { return false }
        return exerciseOverridesKg[exercise.id] == nil
    }

    static func incrementKg(
        for exerciseId: String,
        equipmentOverridesKg: [String: Double],
        exerciseOverridesKg: [String: Double]
    ) -> Double {
        guard let exercise = ExerciseCatalog.exercise(id: exerciseId) else {
            return EquipmentDefaults.defaultIncrementKg(for: .dumbbell)
        }
        return incrementKg(
            for: exercise,
            equipmentOverridesKg: equipmentOverridesKg,
            exerciseOverridesKg: exerciseOverridesKg
        )
    }

    static func incrementKg(
        for exercise: Exercise,
        equipmentOverridesKg: [String: Double],
        exerciseOverridesKg: [String: Double]
    ) -> Double {
        if let exerciseOverride = exerciseOverridesKg[exercise.id] {
            return exerciseOverride
        }
        // Machine/cable: never rely on a global equipment override — per-exercise only.
        if !requiresContextualIncrement(for: exercise.equipment),
           let equipmentOverride = equipmentOverridesKg[exercise.equipment.rawValue] {
            return equipmentOverride
        }
        return EquipmentDefaults.defaultIncrementKg(for: exercise.equipment)
    }
}
