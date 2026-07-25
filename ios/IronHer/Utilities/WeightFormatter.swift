import Foundation

enum WeightFormatter {
    static let poundsPerKilogram = 2.2046226218

    static func format(kg: Double, unit: WeightUnit, includeUnit: Bool = true) -> String {
        formatDisplay(displayValue(kg: kg, unit: unit), unit: unit, includeUnit: includeUnit)
    }

    /// Formats a value already expressed in `unit` (e.g. 70 for 70 lb).
    static func formatDisplay(_ value: Double, unit: WeightUnit, includeUnit: Bool = true) -> String {
        let number = isWholeNumber(value)
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
        guard includeUnit else { return number }
        return "\(number) \(unit.shortLabel)"
    }

    /// Display value without unit (preserves one decimal when needed).
    static func formatNumber(kg: Double, unit: WeightUnit) -> String {
        format(kg: kg, unit: unit, includeUnit: false)
    }

    static func displayValue(kg: Double, unit: WeightUnit) -> Double {
        switch unit {
        case .kilograms: return roundToTenth(kg)
        case .pounds: return roundToTenth(kg * poundsPerKilogram)
        }
    }

    static func kilograms(from displayValue: Double, unit: WeightUnit) -> Double {
        switch unit {
        case .kilograms: return roundToTenth(displayValue)
        case .pounds: return roundToTenth(displayValue / poundsPerKilogram)
        }
    }

    /// Convert a display number from one unit to another (e.g. 30 kg → 66.1 lb).
    static func convertDisplay(_ value: Double, from: WeightUnit, to: WeightUnit) -> Double {
        guard from != to else { return roundToTenth(value) }
        let kg = kilograms(from: value, unit: from)
        return displayValue(kg: kg, unit: to)
    }

    static func isWholeNumber(_ value: Double) -> Bool {
        abs(value.rounded() - value) < 0.001
    }

    /// Keeps values like 12.5 exact; avoids float noise.
    static func roundToTenth(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    /// Preferred increment presets in the given unit (display values).
    static func commonIncrements(for unit: WeightUnit) -> [Double] {
        switch unit {
        case .kilograms: return [0.5, 1, 2.5, 5]
        case .pounds: return [2.5, 5, 10]
        }
    }

    /// Contextual presets for machine/cable first-time setup (display values).
    static func contextualIncrements(for equipment: EquipmentType, unit: WeightUnit) -> [Double] {
        switch (equipment, unit) {
        case (.machine, .kilograms):
            return [2.5, 5, 10]
        case (.cable, .kilograms):
            return [2, 2.5, 5]
        case (.machine, .pounds):
            return [5, 10, 25]
        case (.cable, .pounds):
            return [5, 10, 15]
        default:
            return commonIncrements(for: unit)
        }
    }
}
