import Foundation

/// Central weight progression math — keep views and stores free of ad-hoc rounding.
enum WeightProgressionCalculator {
    /// Product default for weighted exercises when no explicit override exists.
    static let defaultIncrementKg: Double = 2.5

    /// Legacy soft default that caused 17.5 → 19.5 (dumbbell path).
    static let legacyBuggyDumbbellIncrementKg: Double = 2.0

    private static let toleranceKg: Double = 0.001

    /// Adds an increment using Decimal to avoid binary floating-point drift.
    static func addIncrement(currentKg: Double, incrementKg: Double) -> Double {
        let current = decimal(from: currentKg)
        let increment = decimal(from: max(0, incrementKg))
        let sum = current + increment
        return normalize(double(from: sum))
    }

    /// Expected next working weight after a successful progression step.
    static func expectedNext(after previousKg: Double, incrementKg: Double) -> Double {
        addIncrement(currentKg: previousKg, incrementKg: incrementKg)
    }

    /// Round to one decimal place (supports 2.5 kg plate steps without float noise).
    static func normalize(_ kg: Double) -> Double {
        let scaled = decimal(from: kg) * 10
        let rounded = NSDecimalNumber(decimal: scaled)
            .rounding(accordingToBehavior: NSDecimalNumberHandler(
                roundingMode: .plain,
                scale: 0,
                raiseOnExactness: false,
                raiseOnOverflow: false,
                raiseOnUnderflow: false,
                raiseOnDivideByZero: false
            ))
        return double(from: rounded.decimalValue / 10)
    }

    static func approximatelyEqual(_ lhs: Double, _ rhs: Double, tolerance: Double = toleranceKg) -> Bool {
        abs(lhs - rhs) <= tolerance
    }

    /// True when `current` looks like `previous + 2.0` while the configured increment is 2.5.
    static func looksLikeBuggyPlusTwoKilogramStep(
        previousKg: Double,
        currentKg: Double,
        configuredIncrementKg: Double
    ) -> Bool {
        guard approximatelyEqual(configuredIncrementKg, defaultIncrementKg) else { return false }
        guard previousKg > 0, currentKg > previousKg else { return false }

        let buggy = expectedNext(after: previousKg, incrementKg: legacyBuggyDumbbellIncrementKg)
        let expected = expectedNext(after: previousKg, incrementKg: defaultIncrementKg)
        guard approximatelyEqual(currentKg, buggy) else { return false }
        guard !approximatelyEqual(currentKg, expected) else { return false }
        return true
    }

    /// Resolves the increment used for progression evaluation.
    /// Order: per-exercise override → equipment override → category default → soft equipment default.
    static func resolveIncrementKg(
        exercise: Exercise,
        exerciseOverridesKg: [String: Double],
        equipmentOverridesKg: [String: Double],
        categoryDefaultKg: Double,
        softEquipmentDefaultKg: Double? = nil
    ) -> Double {
        if let exerciseOverride = exerciseOverridesKg[exercise.id], exerciseOverride > 0 {
            return normalize(exerciseOverride)
        }

        let needsPerExerciseOnly = exercise.equipment == .machine || exercise.equipment == .cable
        if !needsPerExerciseOnly,
           let equipmentOverride = equipmentOverridesKg[exercise.equipment.rawValue],
           equipmentOverride > 0 {
            return normalize(equipmentOverride)
        }

        if categoryDefaultKg > 0 {
            return normalize(categoryDefaultKg)
        }

        let soft = softEquipmentDefaultKg
            ?? EquipmentDefaults.defaultIncrementKg(for: exercise.equipment)
        return normalize(max(0, soft))
    }

    // MARK: - Decimal helpers

    private static func decimal(from value: Double) -> Decimal {
        // String round-trip keeps values like 2.5 / 17.5 exact.
        if let parsed = Decimal(string: String(format: "%.4f", value)) {
            return parsed
        }
        return Decimal(value)
    }

    private static func double(from value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }
}
