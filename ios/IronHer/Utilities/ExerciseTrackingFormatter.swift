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

    static func defaultDurationSeconds(for exercise: Exercise) -> Int {
        exercise.trackingProfile.supports(.time) ? 60 : 0
    }

    static func defaultDistanceMeters(for measurement: MeasurementUnit) -> Double {
        measurement == .distance ? 40 : 0
    }

    static func defaultDistanceMeters(for exercise: Exercise) -> Double {
        exercise.trackingProfile.supports(.distance) ? 40 : 0
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

        var parts: [String] = []
        let profile = exercise.trackingProfile
        if profile.supports(.sets) {
            parts.append("\(sets) sets")
        }
        if profile.supports(.reps) {
            parts.append("\(reps) reps")
        }
        if profile.supports(.weight) {
            if exercise.tracksOptionalWeight, weightKg <= 0 {
                parts.append("Bodyweight")
            } else {
                parts.append("\(weightText)\(perHand)")
            }
        }
        if profile.supports(.time) {
            parts.append(formatDuration(seconds: durationSeconds))
        }
        if profile.supports(.distance) {
            parts.append(formatDistance(meters: distanceMeters, unit: weightUnit))
        }
        return parts.isEmpty ? "\(sets) sets" : parts.joined(separator: " · ")
    }

    static func trackingLabel(for exercise: Exercise) -> String {
        let labels: [(MeasurementMetric, String)] = [
            (.sets, "Sets"),
            (.reps, "Reps"),
            (.weight, "Weight"),
            (.time, "Duration"),
            (.distance, "Distance"),
        ]
        let parts = labels.compactMap { metric, label in
            exercise.trackingProfile.supports(metric) ? label : nil
        }
        return parts.isEmpty ? "Sets" : parts.joined(separator: " × ")
    }
}
