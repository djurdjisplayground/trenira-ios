import Foundation

/// Detects training gaps for a supportive "Welcome Back" experience.
/// Based on calendar time since the last completed workout — not skipped sessions.
/// Does not mutate progression rules or prescribed state.
enum ReturnAfterBreak {
    enum Severity: Equatable {
        /// 0–6 days — no prompt.
        case none
        /// 7–13 days — optional gentle welcome.
        case mild
        /// 14–27 days — full Welcome Back with Continue / Start lighter.
        case suggestLighter
        /// 28+ days — stronger lighter recommendation; user stays in control.
        case stronglySuggest

        var shouldPrompt: Bool { self != .none }
    }

    struct ExerciseWeightSummary: Equatable, Identifiable {
        var id: String { exerciseId }
        let exerciseId: String
        let name: String
        let weightKg: Double
    }

    struct Evaluation: Equatable {
        let severity: Severity
        let daysSinceLastWorkout: Int
        let lastCompletedAt: Date?
        let effectiveNow: Date
        /// Representative / highest weight in the workout (kg).
        let referenceWeightKg: Double?
        /// Per-exercise planned weights for the workout about to start.
        let exerciseSummaries: [ExerciseWeightSummary]

        var shouldPrompt: Bool { severity.shouldPrompt }
    }

    /// Most recent completion across performance logs and weekly completion markers.
    static func lastCompletedWorkoutDate(
        performanceLogs: [LoggedWorkoutPerformance],
        weeklyCompletions: [WorkoutWeeklyCompletion] = []
    ) -> Date? {
        let fromLogs = performanceLogs.map(\.completedAt).max()
        let fromWeekly = weeklyCompletions.map(\.completedAt).max()
        return [fromLogs, fromWeekly].compactMap { $0 }.max()
    }

    /// Calendar days since last completed session. `nil` if never completed a workout.
    static func daysSinceLastCompletedWorkout(
        performanceLogs: [LoggedWorkoutPerformance],
        weeklyCompletions: [WorkoutWeeklyCompletion] = [],
        now: Date = .now
    ) -> Int? {
        guard let last = lastCompletedWorkoutDate(
            performanceLogs: performanceLogs,
            weeklyCompletions: weeklyCompletions
        ) else { return nil }

        let start = Calendar.current.startOfDay(for: last)
        let end = Calendar.current.startOfDay(for: now)
        return Calendar.current.dateComponents([.day], from: start, to: end).day
    }

    static func severity(daysSince: Int) -> Severity {
        if daysSince < 7 { return .none }
        if daysSince < 14 { return .mild }
        if daysSince < 28 { return .suggestLighter }
        return .stronglySuggest
    }

    @MainActor
    static func evaluate(
        performanceLogs: [LoggedWorkoutPerformance],
        weeklyCompletions: [WorkoutWeeklyCompletion] = [],
        workout: Workout,
        globalProgress: GlobalExerciseProgressStore,
        localization: LocalizationStore? = nil,
        now: Date = .now
    ) -> Evaluation {
        let lastCompleted = lastCompletedWorkoutDate(
            performanceLogs: performanceLogs,
            weeklyCompletions: weeklyCompletions
        )
        let summaries = exerciseSummaries(
            for: workout,
            globalProgress: globalProgress,
            localization: localization
        )
        let reference = summaries.map(\.weightKg).max()

        guard let days = daysSinceLastCompletedWorkout(
            performanceLogs: performanceLogs,
            weeklyCompletions: weeklyCompletions,
            now: now
        ) else {
            return Evaluation(
                severity: .none,
                daysSinceLastWorkout: 0,
                lastCompletedAt: lastCompleted,
                effectiveNow: now,
                referenceWeightKg: reference,
                exerciseSummaries: summaries
            )
        }

        return Evaluation(
            severity: severity(daysSince: days),
            daysSinceLastWorkout: days,
            lastCompletedAt: lastCompleted,
            effectiveNow: now,
            referenceWeightKg: reference,
            exerciseSummaries: summaries
        )
    }

    @MainActor
    static func exerciseSummaries(
        for workout: Workout,
        globalProgress: GlobalExerciseProgressStore,
        localization: LocalizationStore?
    ) -> [ExerciseWeightSummary] {
        workout.exercises.compactMap { entry in
            guard let exercise = ExerciseCatalog.exercise(id: entry.exerciseId) else { return nil }
            guard exercise.tracksWeight else { return nil }
            let weight = globalProgress.resolvedWeight(for: entry.exerciseId, entryWeight: entry.startingWeight)
            guard weight > 0 else { return nil }
            let name = localization.map { exercise.localizedName(using: $0) } ?? exercise.name
            return ExerciseWeightSummary(
                exerciseId: entry.exerciseId,
                name: name,
                weightKg: weight
            )
        }
    }

    @MainActor
    static func referenceWeightKg(for workout: Workout, globalProgress: GlobalExerciseProgressStore) -> Double? {
        exerciseSummaries(for: workout, globalProgress: globalProgress, localization: nil)
            .map(\.weightKg)
            .max()
    }
}

extension Exercise {
    /// Whether this exercise typically carries a working weight in session UI.
    var tracksWeight: Bool {
        switch measurementUnit {
        case .weight, .repsWithOptionalWeight, .weightAndTime:
            return true
        case .bodyweight, .reps, .time, .distance:
            return false
        }
    }
}
