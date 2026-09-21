import Foundation

/// Conservative 10-rep working-load equivalent. Not a 1RM calculator.
enum StrengthLoadNormalizer {
    private static let slope = 0.03

    static func tenRepEquivalentKg(weightKg: Double, reps: Int) -> Double {
        guard weightKg > 0 else { return 0 }
        let clampedReps = Double(min(20, max(1, reps)))
        return weightKg * (1 + (clampedReps - 10) * slope)
    }

    static func workingWeightKg(tenRepEquivalentKg: Double, targetReps: Int) -> Double {
        guard tenRepEquivalentKg > 0 else { return 0 }
        let clampedReps = Double(min(20, max(1, targetReps)))
        let denominator = 1 + (clampedReps - 10) * slope
        guard denominator > 0.25 else { return tenRepEquivalentKg }
        return tenRepEquivalentKg / denominator
    }
}

/// Derives family baselines from calibration samples and estimates untested exercises.
enum StrengthProfileInference {
    static func inferredWeightKg(
        exerciseId: String,
        targetReps: Int,
        calibrations: [String: ExerciseCalibration]
    ) -> Double {
        guard let exercise = ExerciseCatalog.exercise(id: exerciseId) else { return 0 }
        guard StrengthProfileCatalog.shouldEstimateExternalLoad(for: exercise) else { return 0 }
        guard let relation = StrengthProfileCatalog.relation(for: exercise) else { return 0 }

        let baselines = familyBaselines(from: calibrations)
        guard let baseline = baseline(for: relation.family, baselines: baselines) else { return 0 }

        let tenRepKg = baseline * relation.coefficient
        let raw = StrengthLoadNormalizer.workingWeightKg(
            tenRepEquivalentKg: tenRepKg,
            targetReps: max(1, targetReps)
        )
        return roundDown(raw, incrementKg: StrengthProfileCatalog.roundingIncrementKg(for: exercise))
    }

    static func familyBaselines(
        from calibrations: [String: ExerciseCalibration]
    ) -> [StrengthProfileFamily: Double] {
        var baselines: [StrengthProfileFamily: Double] = [:]
        for record in calibrations.values where record.weightKg > 0 {
            guard let exercise = ExerciseCatalog.exercise(id: record.exerciseId),
                  let relation = StrengthProfileCatalog.relation(for: exercise)
            else { continue }
            let ten = StrengthLoadNormalizer.tenRepEquivalentKg(
                weightKg: record.weightKg,
                reps: record.reps
            )
            let baseline = ten / max(relation.coefficient, 0.08)
            if let existing = baselines[relation.family] {
                baselines[relation.family] = max(existing, baseline)
            } else {
                baselines[relation.family] = baseline
            }
        }
        return baselines
    }

    private static func baseline(
        for family: StrengthProfileFamily,
        baselines: [StrengthProfileFamily: Double]
    ) -> Double? {
        if let direct = baselines[family], direct > 0 {
            return direct
        }
        guard let relatives = StrengthProfileCatalog.relatedFamilyScale[family] else {
            return nil
        }
        for (other, scale) in relatives {
            if let value = baselines[other], value > 0 {
                return value * scale
            }
        }
        return nil
    }

    static func roundDown(_ kg: Double, incrementKg: Double) -> Double {
        guard kg > 0 else { return 0 }
        let increment = max(0.25, incrementKg)
        let steps = floor((kg / increment) + 0.0001)
        let rounded = steps * increment
        if rounded <= 0, kg >= increment * 0.5 {
            return WeightProgressionCalculator.normalize(increment)
        }
        return WeightProgressionCalculator.normalize(max(0, rounded))
    }
}
