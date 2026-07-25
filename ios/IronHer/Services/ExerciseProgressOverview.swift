import Foundation

/// Meaningful long-term progress for one exercise — started → current, not session logs.
struct ExerciseProgressOverview: Identifiable, Equatable {
    let exerciseId: String
    let exerciseName: String
    let startedValue: String
    let currentValue: String
    let firstDate: Date
    let lastDate: Date

    var id: String { exerciseId }

    var dateRangeLabel: String {
        Self.formatDateRange(from: firstDate, to: lastDate)
    }

    static func formatDateRange(from first: Date, to last: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDate(first, equalTo: last, toGranularity: .month) {
            return first.formatted(.dateTime.month(.wide).year())
        }
        if calendar.component(.year, from: first) == calendar.component(.year, from: last) {
            let start = first.formatted(.dateTime.month(.wide))
            let end = last.formatted(.dateTime.month(.wide))
            return "\(start) → \(end)"
        }
        let start = first.formatted(.dateTime.month(.wide).year())
        let end = last.formatted(.dateTime.month(.wide).year())
        return "\(start) → \(end)"
    }
}

enum ExerciseProgressOverviewBuilder {
    static func overviews(
        from historyItems: [ExerciseSessionHistoryItem],
        weightHistory: [WeightHistoryEntry],
        unitResolver: (String) -> WeightUnit
    ) -> [ExerciseProgressOverview] {
        let grouped = Dictionary(grouping: historyItems, by: \.exercise.exerciseId)

        return grouped.compactMap { exerciseId, items in
            guard let exercise = ExerciseCatalog.exercise(id: exerciseId) else { return nil }
            let ordered = items.sorted { $0.completedAt < $1.completedAt }
            guard let first = ordered.first, let last = ordered.last else { return nil }

            let unit = unitResolver(exerciseId)
            let weightEntries = weightHistory
                .filter { $0.exerciseId == exerciseId }
                .sorted { $0.date < $1.date }

            let started: String
            let current: String
            let firstDate: Date
            let lastDate: Date

            if let weightProgress = weightProgressLabels(
                exercise: exercise,
                weightEntries: weightEntries,
                firstSession: first,
                lastSession: last,
                unit: unit
            ) {
                started = weightProgress.started
                current = weightProgress.current
                firstDate = weightProgress.firstDate
                lastDate = weightProgress.lastDate
            } else if let repProgress = repProgressLabels(
                exercise: exercise,
                weightEntries: weightEntries,
                firstSession: first,
                lastSession: last
            ) {
                started = repProgress.started
                current = repProgress.current
                firstDate = repProgress.firstDate
                lastDate = repProgress.lastDate
            } else {
                started = primaryMetricLabel(for: exercise, performance: first.exercise, unit: unit)
                current = primaryMetricLabel(for: exercise, performance: last.exercise, unit: unit)
                firstDate = first.completedAt
                lastDate = last.completedAt
            }

            return ExerciseProgressOverview(
                exerciseId: exerciseId,
                exerciseName: exercise.name,
                startedValue: started,
                currentValue: current,
                firstDate: firstDate,
                lastDate: lastDate
            )
        }
        .sorted { $0.lastDate > $1.lastDate }
    }

    private static func weightProgressLabels(
        exercise: Exercise,
        weightEntries: [WeightHistoryEntry],
        firstSession: ExerciseSessionHistoryItem,
        lastSession: ExerciseSessionHistoryItem,
        unit: WeightUnit
    ) -> (started: String, current: String, firstDate: Date, lastDate: Date)? {
        guard exercise.showsWeightDuringSession else { return nil }

        let weightEvents = weightEntries.filter {
            ($0.event == .initial || $0.event == .progression) && $0.weightKg > 0
        }

        if let first = weightEvents.first, let last = weightEvents.last {
            return (
                formatWeight(first.weightKg, unit: unit, perHand: exercise.displaysWeightPerHand),
                formatWeight(last.weightKg, unit: unit, perHand: exercise.displaysWeightPerHand),
                first.date,
                last.date
            )
        }

        let startedKg = representativeWeightKg(firstSession.exercise)
        let currentKg = representativeWeightKg(lastSession.exercise)
        guard startedKg > 0 || currentKg > 0 else { return nil }

        return (
            formatWeight(startedKg, unit: unit, perHand: exercise.displaysWeightPerHand),
            formatWeight(currentKg, unit: unit, perHand: exercise.displaysWeightPerHand),
            firstSession.completedAt,
            lastSession.completedAt
        )
    }

    private static func repProgressLabels(
        exercise: Exercise,
        weightEntries: [WeightHistoryEntry],
        firstSession: ExerciseSessionHistoryItem,
        lastSession: ExerciseSessionHistoryItem
    ) -> (started: String, current: String, firstDate: Date, lastDate: Date)? {
        guard exercise.showsRepsDuringSession,
              !exercise.showsWeightDuringSession || representativeWeightKg(lastSession.exercise) <= 0
        else { return nil }

        let repEvents = weightEntries.filter { $0.event == .repProgression }

        if let firstEvent = repEvents.first {
            let startedReps = firstEvent.previousReps ?? firstEvent.reps ?? representativeReps(firstSession.exercise)
            let currentReps = repEvents.last?.reps
                ?? representativeReps(lastSession.exercise)
            return (
                "\(startedReps) reps",
                "\(currentReps) reps",
                firstEvent.previousReps != nil
                    ? firstEvent.date
                    : firstSession.completedAt,
                repEvents.last?.date ?? lastSession.completedAt
            )
        }

        return (
            "\(representativeReps(firstSession.exercise)) reps",
            "\(representativeReps(lastSession.exercise)) reps",
            firstSession.completedAt,
            lastSession.completedAt
        )
    }

    private static func primaryMetricLabel(
        for exercise: Exercise,
        performance: LoggedExercisePerformance,
        unit: WeightUnit
    ) -> String {
        let completed = performance.sets.filter(\.completed)
        guard !completed.isEmpty else { return "—" }

        switch exercise.measurementUnit {
        case .weight:
            return formatWeight(
                representativeWeightKg(performance),
                unit: unit,
                perHand: exercise.displaysWeightPerHand
            )
        case .repsWithOptionalWeight:
            if completed.contains(where: { $0.weightKg > 0 }) {
                return formatWeight(
                    representativeWeightKg(performance),
                    unit: unit,
                    perHand: exercise.displaysWeightPerHand
                )
            }
            return "\(representativeReps(performance)) reps"
        case .reps, .bodyweight:
            return "\(representativeReps(performance)) reps"
        case .weightAndTime:
            let weight = formatWeight(
                representativeWeightKg(performance),
                unit: unit,
                perHand: exercise.displaysWeightPerHand
            )
            let duration = ExerciseTrackingFormatter.formatDuration(
                seconds: completed.map(\.durationSeconds).max() ?? 0
            )
            return "\(weight) · \(duration)"
        case .time:
            return ExerciseTrackingFormatter.formatDuration(
                seconds: completed.map(\.durationSeconds).max() ?? 0
            )
        case .distance:
            return ExerciseTrackingFormatter.formatDistance(
                meters: completed.map(\.distanceMeters).max() ?? 0,
                unit: unit
            )
        }
    }

    private static func representativeWeightKg(_ performance: LoggedExercisePerformance) -> Double {
        let completed = performance.sets.filter(\.completed)
        return completed.last?.weightKg
            ?? completed.map(\.weightKg).max()
            ?? performance.plannedWeightKg
    }

    private static func representativeReps(_ performance: LoggedExercisePerformance) -> Int {
        let completed = performance.sets.filter(\.completed)
        return completed.map(\.reps).max() ?? performance.plannedReps
    }

    private static func formatWeight(_ kg: Double, unit: WeightUnit, perHand: Bool) -> String {
        let formatted = WeightFormatter.format(kg: kg, unit: unit)
        return perHand ? "\(formatted) per hand" : formatted
    }
}
