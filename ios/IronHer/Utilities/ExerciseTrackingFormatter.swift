import Foundation

enum ExerciseTrackingFormatter {
    static func defaultSets(for measurement: MeasurementUnit) -> Int { 3 }

    static func defaultReps(for measurement: MeasurementUnit) -> Int {
        switch measurement {
        case .weight: return 8
        case .reps, .bodyweight, .repsWithOptionalWeight: return 8
        default: return 10
        }
    }

    static func defaultDurationSeconds(for measurement: MeasurementUnit) -> Int {
        switch measurement {
        case .time, .weightAndTime: return 60
        default: return 0
        }
    }

    static func defaultDistanceMeters(for measurement: MeasurementUnit) -> Double {
        measurement == .distance ? 40 : 0
    }

    static func formatDuration(seconds: Int) -> String {
        if seconds >= 60 {
            let minutes = seconds / 60
            let remainder = seconds % 60
            if remainder == 0 { return "\(minutes) min" }
            return "\(minutes)m \(remainder)s"
        }
        return "\(seconds)s"
    }

    static func formatDistance(meters: Double, unit: WeightUnit) -> String {
        switch unit {
        case .kilograms:
            if meters >= 1000 {
                return String(format: "%.1f km", meters / 1000)
            }
            return String(format: "%.0f m", meters)
        case .pounds:
            let feet = meters * 3.28084
            if feet >= 5280 {
                return String(format: "%.1f mi", feet / 5280)
            }
            return String(format: "%.0f ft", feet)
        }
    }

    static func formatOptionalWeight(kg: Double, unit: WeightUnit) -> String? {
        guard kg > 0 else { return nil }
        return WeightFormatter.format(kg: kg, unit: unit)
    }

    static func summary(
        exercise: Exercise,
        sets: Int,
        reps: Int,
        weightKg: Double,
        durationSeconds: Int,
        distanceMeters: Double,
        weightUnit: WeightUnit
    ) -> String {
        let weightText = WeightFormatter.format(kg: weightKg, unit: weightUnit)
        let perHand: String
        switch exercise.weightInterpretation {
        case .perHand: perHand = " per hand"
        case .perArm: perHand = " per arm"
        case .machineSetting: perHand = " machine"
        default: perHand = ""
        }

        switch exercise.measurementUnit {
        case .weight:
            return "\(sets) sets · \(reps) reps · \(weightText)\(perHand)"
        case .bodyweight:
            return "\(sets) sets · \(reps) reps · Bodyweight"
        case .time:
            return "\(sets) sets · \(formatDuration(seconds: durationSeconds))"
        case .distance:
            return "\(sets) sets · \(formatDistance(meters: distanceMeters, unit: weightUnit))"
        case .reps:
            return "\(sets) sets · \(reps) reps"
        case .weightAndTime:
            return "\(sets) sets · \(weightText)\(perHand) · \(formatDuration(seconds: durationSeconds))"
        case .repsWithOptionalWeight:
            if weightKg > 0 {
                return "\(sets) sets · \(reps) reps · \(weightText)\(perHand)"
            }
            return "\(sets) sets · \(reps) reps · Bodyweight"
        }
    }

    static func trackingLabel(for exercise: Exercise) -> String {
        switch exercise.measurementUnit {
        case .weight: return "Sets × Reps × Weight"
        case .bodyweight: return "Sets × Reps"
        case .time: return "Sets × Duration"
        case .distance: return "Sets × Distance"
        case .reps: return "Sets × Reps"
        case .weightAndTime: return "Sets × Weight × Duration"
        case .repsWithOptionalWeight: return "Sets × Reps · Optional Weight"
        }
    }
}
