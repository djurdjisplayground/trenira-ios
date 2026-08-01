import Foundation

/// Time window for exercise progress charts.
enum ExerciseProgressTimeRange: String, CaseIterable, Identifiable, Hashable {
    case fourWeeks
    case threeMonths
    case sixMonths
    case allTime

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fourWeeks: return "4 weeks"
        case .threeMonths: return "3 months"
        case .sixMonths: return "6 months"
        case .allTime: return "All time"
        }
    }

    /// Default product choice.
    static let `default`: ExerciseProgressTimeRange = .threeMonths

    func startDate(relativeTo now: Date = .now, calendar: Calendar = .current) -> Date? {
        switch self {
        case .fourWeeks:
            return calendar.date(byAdding: .weekOfYear, value: -4, to: now)
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: now)
        case .sixMonths:
            return calendar.date(byAdding: .month, value: -6, to: now)
        case .allTime:
            return nil
        }
    }
}

/// Primary Y-axis metric for one exercise series (never mixed on one line).
enum ExerciseProgressMetricKind: String, Equatable {
    case estimatedStrength
    case bestReps
    case longestDuration

    var chartAccessibilityNoun: String {
        switch self {
        case .estimatedStrength: return "estimated strength"
        case .bestReps: return "best reps"
        case .longestDuration: return "longest duration"
        }
    }
}

/// Best relevant set retained for chart selection / history rows.
struct ExerciseProgressBestSet: Equatable, Hashable {
    let weightKg: Double
    let reps: Int
    let durationSeconds: Int
    /// Graphed numeric value (kg estimated strength, reps, or seconds).
    let metricValue: Double
}

/// One graph point = one completed workout session for an exercise.
struct ExerciseProgressPoint: Identifiable, Equatable, Hashable {
    /// Stable session identity (`LoggedWorkoutPerformance.id`).
    let sessionId: UUID
    let workoutId: UUID
    let workoutName: String
    let completedAt: Date
    let bestSet: ExerciseProgressBestSet
    let completedSetCount: Int

    var id: UUID { sessionId }

    var metricValue: Double { bestSet.metricValue }
}

struct ExerciseProgressSeries: Equatable {
    let exerciseId: String
    let metric: ExerciseProgressMetricKind
    let range: ExerciseProgressTimeRange
    /// Chronological (oldest → newest) unique session points.
    let points: [ExerciseProgressPoint]
    let summaryText: String?

    var isEmpty: Bool { points.isEmpty }
    var hasTrend: Bool { points.count >= 2 }
}

/// Pure helpers for estimated-strength progress charts (no persistence).
enum ExerciseProgressSeriesBuilder {
    // MARK: - Public API

    static func series(
        exerciseId: String,
        exercise: Exercise,
        logs: [LoggedWorkoutPerformance],
        range: ExerciseProgressTimeRange,
        weightUnit: WeightUnit,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> ExerciseProgressSeries {
        let metric = metricKind(for: exercise, logs: logs)
        let sessions = sessionPoints(
            exerciseId: exerciseId,
            logs: logs,
            metric: metric
        )
        let filtered = filter(sessions, range: range, now: now, calendar: calendar)
        let summary = summaryText(
            points: filtered,
            metric: metric,
            exercise: exercise,
            weightUnit: weightUnit
        )
        return ExerciseProgressSeries(
            exerciseId: exerciseId,
            metric: metric,
            range: range,
            points: filtered,
            summaryText: summary
        )
    }

    /// Epley estimated 1RM-style strength. Returns `nil` when inputs are invalid.
    static func estimatedStrength(weightKg: Double, reps: Int) -> Double? {
        guard weightKg > 0, reps > 0 else { return nil }
        return weightKg * (1 + Double(reps) / 30.0)
    }

    static func metricKind(for exercise: Exercise, logs: [LoggedWorkoutPerformance]) -> ExerciseProgressMetricKind {
        switch exercise.measurementUnit {
        case .time, .weightAndTime:
            return .longestDuration
        case .reps, .bodyweight:
            return .bestReps
        case .distance:
            // Distance-only work is not part of the strength/reps/time graph set.
            // Prefer duration if any timed sets exist; otherwise fall back to reps semantics unused.
            return .longestDuration
        case .weight:
            return .estimatedStrength
        case .repsWithOptionalWeight:
            let hasExternalLoad = logs.contains { log in
                log.exercises.contains { entry in
                    entry.exerciseId == exercise.id
                        && entry.sets.contains { $0.completed && $0.weightKg > 0 && $0.reps > 0 }
                }
            }
            return hasExternalLoad ? .estimatedStrength : .bestReps
        }
    }

    // MARK: - Session aggregation

    /// Builds one point per workout session, merging duplicate exercise entries in the same log
    /// and collapsing duplicate completions of the same workout on the same calendar day.
    static func sessionPoints(
        exerciseId: String,
        logs: [LoggedWorkoutPerformance],
        metric: ExerciseProgressMetricKind
    ) -> [ExerciseProgressPoint] {
        var bySession: [UUID: ExerciseProgressPoint] = [:]

        for log in logs {
            let entries = log.exercises.filter { $0.exerciseId == exerciseId }
            guard !entries.isEmpty else { continue }

            let completedSets = entries.flatMap { $0.sets.filter(\.completed) }
            guard !completedSets.isEmpty else { continue }
            guard let best = bestSet(from: completedSets, metric: metric) else { continue }

            let point = ExerciseProgressPoint(
                sessionId: log.id,
                workoutId: log.workoutId,
                workoutName: log.workoutName,
                completedAt: log.completedAt,
                bestSet: best,
                completedSetCount: completedSets.count
            )
            bySession[log.id] = point
        }

        let uniqueSessions = Array(bySession.values)
        return dedupeSameWorkoutSameDay(uniqueSessions)
            .sorted { $0.completedAt < $1.completedAt }
    }

    static func bestSet(
        from completedSets: [LoggedSetPerformance],
        metric: ExerciseProgressMetricKind
    ) -> ExerciseProgressBestSet? {
        switch metric {
        case .estimatedStrength:
            var best: ExerciseProgressBestSet?
            for set in completedSets {
                guard let value = estimatedStrength(weightKg: set.weightKg, reps: set.reps) else { continue }
                let candidate = ExerciseProgressBestSet(
                    weightKg: set.weightKg,
                    reps: set.reps,
                    durationSeconds: set.durationSeconds,
                    metricValue: value
                )
                if best == nil || candidate.metricValue > best!.metricValue {
                    best = candidate
                }
            }
            return best

        case .bestReps:
            guard let set = completedSets.filter({ $0.reps > 0 }).max(by: { $0.reps < $1.reps }) else {
                return nil
            }
            return ExerciseProgressBestSet(
                weightKg: set.weightKg,
                reps: set.reps,
                durationSeconds: set.durationSeconds,
                metricValue: Double(set.reps)
            )

        case .longestDuration:
            guard let set = completedSets.filter({ $0.durationSeconds > 0 })
                .max(by: { $0.durationSeconds < $1.durationSeconds }) else {
                return nil
            }
            return ExerciseProgressBestSet(
                weightKg: set.weightKg,
                reps: set.reps,
                durationSeconds: set.durationSeconds,
                metricValue: Double(set.durationSeconds)
            )
        }
    }

    static func filter(
        _ points: [ExerciseProgressPoint],
        range: ExerciseProgressTimeRange,
        now: Date,
        calendar: Calendar
    ) -> [ExerciseProgressPoint] {
        guard let start = range.startDate(relativeTo: now, calendar: calendar) else {
            return points
        }
        return points.filter { $0.completedAt >= start && $0.completedAt <= now }
    }

    // MARK: - Summary

    static func summaryText(
        points: [ExerciseProgressPoint],
        metric: ExerciseProgressMetricKind,
        exercise _: Exercise,
        weightUnit _: WeightUnit
    ) -> String? {
        guard points.count >= 2,
              let first = points.first,
              let last = points.last else {
            return nil
        }

        let start = first.metricValue
        let end = last.metricValue
        guard start > 0 else { return nil }

        let changeRatio = (end - start) / start
        let percent = abs(changeRatio) * 100

        switch metric {
        case .estimatedStrength:
            if end >= start {
                return String(
                    format: "Estimated strength increased by %.1f%%",
                    percent
                )
            }
            return String(
                format: "Current value is %.1f%% below the start of this period",
                percent
            )

        case .bestReps:
            let startReps = Int(start.rounded())
            let endReps = Int(end.rounded())
            if end >= start {
                return "Best set improved from \(startReps) to \(endReps) reps"
            }
            return "Current value is \(endReps) reps, below \(startReps) at the start of this period"

        case .longestDuration:
            let startLabel = formatDurationWords(seconds: Int(start.rounded()))
            let endLabel = formatDurationWords(seconds: Int(end.rounded()))
            if end >= start {
                return "Longest hold increased from \(startLabel) to \(endLabel)"
            }
            return "Current value is \(endLabel), below \(startLabel) at the start of this period"
        }
    }

    // MARK: - Formatting

    static func formatMetricValue(
        _ value: Double,
        metric: ExerciseProgressMetricKind,
        weightUnit: WeightUnit
    ) -> String {
        switch metric {
        case .estimatedStrength:
            return WeightFormatter.format(kg: value, unit: weightUnit)
        case .bestReps:
            return "\(Int(value.rounded())) reps"
        case .longestDuration:
            return formatDurationClock(seconds: Int(value.rounded()))
        }
    }

    static func formatPointDetail(
        point: ExerciseProgressPoint,
        metric: ExerciseProgressMetricKind,
        exercise: Exercise,
        weightUnit: WeightUnit
    ) -> (dateLine: String, primaryLine: String, secondaryLine: String?) {
        let dateLine = point.completedAt.formatted(.dateTime.day().month(.abbreviated).year())
        let set = point.bestSet

        switch metric {
        case .estimatedStrength:
            let load = WeightFormatter.format(kg: set.weightKg, unit: weightUnit)
            let primary = "\(load) × \(set.reps) reps"
            let estimated = WeightFormatter.format(kg: set.metricValue, unit: weightUnit)
            return (dateLine, primary, "Estimated strength: \(estimated)")

        case .bestReps:
            return (dateLine, "\(set.reps) reps", nil)

        case .longestDuration:
            let primary = formatDurationClock(seconds: set.durationSeconds)
            if exercise.measurementUnit == .weightAndTime, set.weightKg > 0 {
                let load = WeightFormatter.format(kg: set.weightKg, unit: weightUnit)
                return (dateLine, primary, load)
            }
            return (dateLine, primary, nil)
        }
    }

    static func formatHistoryBestSet(
        point: ExerciseProgressPoint,
        metric: ExerciseProgressMetricKind,
        exercise: Exercise,
        weightUnit: WeightUnit
    ) -> String {
        let detail = formatPointDetail(
            point: point,
            metric: metric,
            exercise: exercise,
            weightUnit: weightUnit
        )
        if let secondary = detail.secondaryLine {
            return "\(detail.primaryLine) · \(secondary)"
        }
        return detail.primaryLine
    }

    /// mm:ss clock for timed point details.
    static func formatDurationClock(seconds: Int) -> String {
        let clamped = max(0, seconds)
        let minutes = clamped / 60
        let remainder = clamped % 60
        return String(format: "%02d:%02d", minutes, remainder)
    }

    static func formatDurationWords(seconds: Int) -> String {
        let clamped = max(0, seconds)
        if clamped < 60 {
            return "\(clamped) sec"
        }
        let minutes = clamped / 60
        let remainder = clamped % 60
        if remainder == 0 {
            return minutes == 1 ? "1 min" : "\(minutes) min"
        }
        return "\(minutes) min \(remainder) sec"
    }

    static func yAxisDomain(values: [Double]) -> ClosedRange<Double>? {
        guard let minValue = values.min(), let maxValue = values.max() else { return nil }
        if values.count == 1 || abs(maxValue - minValue) < 0.000_1 {
            let center = minValue
            let pad = max(abs(center) * 0.15, center == 0 ? 1 : 1)
            return (center - pad)...(center + pad)
        }
        let span = maxValue - minValue
        let pad = max(span * 0.12, abs(maxValue) * 0.04, 0.5)
        return (minValue - pad)...(maxValue + pad)
    }

    // MARK: - Deduping

    /// Keeps the latest log when the same workout template is saved more than once on one day.
    private static func dedupeSameWorkoutSameDay(
        _ points: [ExerciseProgressPoint],
        calendar: Calendar = .current
    ) -> [ExerciseProgressPoint] {
        var best: [String: ExerciseProgressPoint] = [:]
        for point in points {
            let day = calendar.startOfDay(for: point.completedAt)
            let key = "\(point.workoutId.uuidString)-\(day.timeIntervalSinceReferenceDate)"
            if let existing = best[key] {
                if point.completedAt >= existing.completedAt {
                    best[key] = point
                }
            } else {
                best[key] = point
            }
        }
        return Array(best.values)
    }
}
