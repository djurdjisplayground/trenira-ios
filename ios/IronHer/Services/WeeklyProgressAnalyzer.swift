import Foundation

/// A single visible improvement for Track This Week.
struct WeeklyProgressHighlight: Identifiable, Equatable {
    enum Kind: Equatable {
        case weight(fromKg: Double, toKg: Double, unit: WeightUnit)
        case reps(from: Int, to: Int)
        case sets(from: Int, to: Int)
        case duration(fromSeconds: Int, toSeconds: Int)
        case milestone(fromKg: Double?, toKg: Double?, unit: WeightUnit, nextWorkoutLabel: String?)
    }

    let id: String
    let exerciseId: String
    let exerciseName: String
    let kind: Kind

    var symbol: String {
        switch kind {
        case .milestone:
            return "✓"
        case .weight, .reps, .sets, .duration:
            return "↑"
        }
    }

    var headline: String {
        switch kind {
        case .milestone:
            return "Progression completed"
        case .weight, .reps, .sets, .duration:
            return exerciseName
        }
    }

    var detailLabel: String? {
        switch kind {
        case .weight:
            return "Weight"
        case .reps:
            return "Reps"
        case .sets:
            return "Sets"
        case .duration:
            return "Duration"
        case .milestone:
            return exerciseName
        }
    }

    var changeLine: String? {
        switch kind {
        case .weight(let fromKg, let toKg, let unit):
            let from = WeightFormatter.format(kg: fromKg, unit: unit)
            let to = WeightFormatter.format(kg: toKg, unit: unit)
            return "\(from) → \(to)"
        case .reps(let from, let to):
            return "\(from) → \(to)"
        case .sets(let from, let to):
            return "\(from) → \(to)"
        case .duration(let from, let to):
            let fromText = ExerciseTrackingFormatter.formatDuration(seconds: from)
            let toText = ExerciseTrackingFormatter.formatDuration(seconds: to)
            return "\(fromText) → \(toText)"
        case .milestone(let fromKg, let toKg, let unit, _):
            guard let fromKg, let toKg, toKg > fromKg + 0.05 else { return nil }
            let from = WeightFormatter.format(kg: fromKg, unit: unit)
            let to = WeightFormatter.format(kg: toKg, unit: unit)
            return "\(from) → \(to)"
        }
    }

    /// Compact Home card line, e.g. "Bench Press +2.5 kg".
    var homeSummaryLine: String? {
        guard let delta = deltaOnlyLine else { return nil }
        return "\(exerciseName) \(delta)"
    }

    /// Delta only, e.g. "+2.5 kg" or "+2 reps".
    var deltaOnlyLine: String? {
        switch kind {
        case .weight(let fromKg, let toKg, let unit):
            let delta = toKg - fromKg
            guard delta > 0.05 else { return nil }
            return "+\(WeightFormatter.format(kg: delta, unit: unit))"
        case .reps(let from, let to):
            let delta = to - from
            guard delta > 0 else { return nil }
            let label = delta == 1 ? "rep" : "reps"
            return "+\(delta) \(label)"
        case .milestone(let fromKg, let toKg, let unit, _):
            guard let fromKg, let toKg else { return nil }
            let delta = toKg - fromKg
            guard delta > 0.05 else { return nil }
            return "+\(WeightFormatter.format(kg: delta, unit: unit))"
        case .sets, .duration:
            return nil
        }
    }

    var nextWorkoutLine: String? {
        if case .milestone(_, _, _, let label) = kind {
            return label
        }
        return nil
    }
}

struct WeeklyProgressReport: Equatable {
    var highlights: [WeeklyProgressHighlight]
    var weightIncreaseCount: Int
    var repIncreaseCount: Int
    var setIncreaseCount: Int
    var durationIncreaseCount: Int
    var milestoneCount: Int

    var isEmpty: Bool {
        highlights.isEmpty
            && weightIncreaseCount == 0
            && repIncreaseCount == 0
            && setIncreaseCount == 0
            && durationIncreaseCount == 0
            && milestoneCount == 0
    }

    var compactSummaryLines: [String] {
        var lines: [String] = []
        if weightIncreaseCount > 0 {
            lines.append("\(weightIncreaseCount) weight increase\(weightIncreaseCount == 1 ? "" : "s")")
        }
        if repIncreaseCount > 0 {
            lines.append("\(repIncreaseCount) repetition increase\(repIncreaseCount == 1 ? "" : "s")")
        }
        if setIncreaseCount > 0 {
            lines.append("\(setIncreaseCount) set increase\(setIncreaseCount == 1 ? "" : "s")")
        }
        if durationIncreaseCount > 0 {
            lines.append("\(durationIncreaseCount) duration increase\(durationIncreaseCount == 1 ? "" : "s")")
        }
        if milestoneCount > 0 {
            lines.append("\(milestoneCount) progression milestone\(milestoneCount == 1 ? "" : "s") reached")
        }
        return lines
    }
}

enum WeeklyProgressAnalyzer {
    private struct SessionSnapshot {
        let date: Date
        let plannedWeightKg: Double
        let plannedReps: Int
        let plannedSets: Int
        let actualWeightKg: Double
        let actualReps: Int
        let actualDurationSeconds: Int
    }

    /// Compares synchronized progression + session history to answer: what improved this week?
    @MainActor
    static func report(
        logs: [LoggedWorkoutPerformance],
        weightHistory: [WeightHistoryEntry],
        globalProgress: GlobalExerciseProgressStore,
        settings: UserSettingsStore,
        localization: LocalizationStore,
        now: Date = .now
    ) -> WeeklyProgressReport {
        let weekStart = WorkoutWeekCalendar.startOfWeek(for: now)

        var highlights: [WeeklyProgressHighlight] = []
        var weightCount = 0
        var repCount = 0
        var setCount = 0
        var durationCount = 0
        var milestoneCount = 0
        var coveredWeightTransitions = Set<String>()

        // 1) Progression events already recorded by the engine this week.
        let weekEvents = weightHistory
            .filter { $0.date >= weekStart && $0.date <= now }
            .sorted { $0.date < $1.date }

        for entry in weekEvents {
            let name = exerciseName(id: entry.exerciseId, localization: localization)
            let unit = globalProgress.resolvedWeightUnit(
                for: entry.exerciseId,
                defaultUnit: settings.weightUnit
            )

            switch entry.event {
            case .progression:
                guard let previous = entry.previousWeightKg, entry.weightKg > previous + 0.05 else { continue }
                let nextLabel = nextWorkoutLabel(
                    exerciseId: entry.exerciseId,
                    globalProgress: globalProgress,
                    unit: unit
                )
                highlights.append(
                    WeeklyProgressHighlight(
                        id: "milestone-\(entry.id.uuidString)",
                        exerciseId: entry.exerciseId,
                        exerciseName: name,
                        kind: .milestone(
                            fromKg: previous,
                            toKg: entry.weightKg,
                            unit: unit,
                            nextWorkoutLabel: nextLabel
                        )
                    )
                )
                weightCount += 1
                milestoneCount += 1
                coveredWeightTransitions.insert(
                    weightTransitionKey(entry.exerciseId, from: previous, to: entry.weightKg)
                )

            case .repProgression:
                guard let from = entry.previousReps, let to = entry.reps, to > from else { continue }
                highlights.append(
                    WeeklyProgressHighlight(
                        id: "reps-\(entry.id.uuidString)",
                        exerciseId: entry.exerciseId,
                        exerciseName: name,
                        kind: .reps(from: from, to: to)
                    )
                )
                repCount += 1

            case .setProgression:
                guard let from = entry.previousSets, let to = entry.sets, to > from else { continue }
                highlights.append(
                    WeeklyProgressHighlight(
                        id: "sets-\(entry.id.uuidString)",
                        exerciseId: entry.exerciseId,
                        exerciseName: name,
                        kind: .sets(from: from, to: to)
                    )
                )
                setCount += 1

            case .initial:
                continue
            }
        }

        var coveredRepTransitions = Set<String>()
        var coveredSetTransitions = Set<String>()
        for entry in weekEvents {
            if entry.event == .repProgression, let from = entry.previousReps, let to = entry.reps {
                coveredRepTransitions.insert("\(entry.exerciseId)|\(from)|\(to)")
            }
            if entry.event == .setProgression, let from = entry.previousSets, let to = entry.sets {
                coveredSetTransitions.insert("\(entry.exerciseId)|\(from)|\(to)")
            }
        }

        // 2) Compare consecutive session prescriptions / actuals for the rest.
        var timelineByExercise: [String: [SessionSnapshot]] = [:]
        for log in logs.sorted(by: { $0.completedAt < $1.completedAt }) {
            for exerciseLog in log.exercises {
                let completed = exerciseLog.sets.filter(\.completed)
                guard !completed.isEmpty else { continue }
                let snapshot = SessionSnapshot(
                    date: log.completedAt,
                    plannedWeightKg: exerciseLog.plannedWeightKg,
                    plannedReps: exerciseLog.plannedReps,
                    plannedSets: exerciseLog.plannedSets,
                    actualWeightKg: completed.map(\.weightKg).max() ?? 0,
                    actualReps: completed.map(\.reps).max() ?? 0,
                    actualDurationSeconds: completed.map(\.durationSeconds).max() ?? 0
                )
                timelineByExercise[exerciseLog.exerciseId, default: []].append(snapshot)
            }
        }

        for (exerciseId, timeline) in timelineByExercise.sorted(by: { $0.key < $1.key }) {
            guard timeline.count >= 2 else { continue }

            // Walk consecutive pairs where the later session falls in this week.
            for index in 1..<timeline.count {
                let current = timeline[index]
                let previous = timeline[index - 1]
                guard current.date >= weekStart, current.date <= now else { continue }

                let name = exerciseName(id: exerciseId, localization: localization)
                let unit = globalProgress.resolvedWeightUnit(
                    for: exerciseId,
                    defaultUnit: settings.weightUnit
                )

                let plannedWeightUp = current.plannedWeightKg > previous.plannedWeightKg + 0.05
                let actualWeightUp = current.actualWeightKg > previous.actualWeightKg + 0.05
                let weightKey = weightTransitionKey(
                    exerciseId,
                    from: plannedWeightUp ? previous.plannedWeightKg : previous.actualWeightKg,
                    to: plannedWeightUp ? current.plannedWeightKg : current.actualWeightKg
                )

                if plannedWeightUp || actualWeightUp {
                    let fromKg = plannedWeightUp ? previous.plannedWeightKg : previous.actualWeightKg
                    let toKg = plannedWeightUp ? current.plannedWeightKg : current.actualWeightKg
                    let transitionKey = weightTransitionKey(exerciseId, from: fromKg, to: toKg)

                    if !coveredWeightTransitions.contains(transitionKey) {
                        let repsReset = current.plannedReps < previous.plannedReps
                        if plannedWeightUp && repsReset {
                            let nextLabel = nextWorkoutLabel(
                                exerciseId: exerciseId,
                                globalProgress: globalProgress,
                                unit: unit
                            )
                            highlights.append(
                                WeeklyProgressHighlight(
                                    id: "\(exerciseId)-milestone-\(index)",
                                    exerciseId: exerciseId,
                                    exerciseName: name,
                                    kind: .milestone(
                                        fromKg: fromKg,
                                        toKg: toKg,
                                        unit: unit,
                                        nextWorkoutLabel: nextLabel
                                    )
                                )
                            )
                            weightCount += 1
                            milestoneCount += 1
                        } else {
                            highlights.append(
                                WeeklyProgressHighlight(
                                    id: "\(exerciseId)-weight-\(index)",
                                    exerciseId: exerciseId,
                                    exerciseName: name,
                                    kind: .weight(fromKg: fromKg, toKg: toKg, unit: unit)
                                )
                            )
                            weightCount += 1
                        }
                        coveredWeightTransitions.insert(transitionKey)
                        coveredWeightTransitions.insert(weightKey)
                    }
                }

                let plannedRepsUp = current.plannedReps > previous.plannedReps
                let actualRepsUp = current.actualReps > previous.actualReps
                // Skip rep-down that accompanies a weight milestone (reset).
                let isRepResetWithWeight = plannedWeightUp && current.plannedReps < previous.plannedReps
                if !isRepResetWithWeight {
                    if plannedRepsUp {
                        let key = "\(exerciseId)|\(previous.plannedReps)|\(current.plannedReps)"
                        if !coveredRepTransitions.contains(key) {
                            highlights.append(
                                WeeklyProgressHighlight(
                                    id: "\(exerciseId)-reps-\(index)",
                                    exerciseId: exerciseId,
                                    exerciseName: name,
                                    kind: .reps(from: previous.plannedReps, to: current.plannedReps)
                                )
                            )
                            repCount += 1
                            coveredRepTransitions.insert(key)
                        }
                    } else if actualRepsUp {
                        let key = "\(exerciseId)|\(previous.actualReps)|\(current.actualReps)"
                        if !coveredRepTransitions.contains(key) {
                            highlights.append(
                                WeeklyProgressHighlight(
                                    id: "\(exerciseId)-reps-actual-\(index)",
                                    exerciseId: exerciseId,
                                    exerciseName: name,
                                    kind: .reps(from: previous.actualReps, to: current.actualReps)
                                )
                            )
                            repCount += 1
                            coveredRepTransitions.insert(key)
                        }
                    }
                }

                if current.plannedSets > previous.plannedSets {
                    let key = "\(exerciseId)|\(previous.plannedSets)|\(current.plannedSets)"
                    if !coveredSetTransitions.contains(key) {
                        highlights.append(
                            WeeklyProgressHighlight(
                                id: "\(exerciseId)-sets-\(index)",
                                exerciseId: exerciseId,
                                exerciseName: name,
                                kind: .sets(from: previous.plannedSets, to: current.plannedSets)
                            )
                        )
                        setCount += 1
                        coveredSetTransitions.insert(key)
                    }
                }

                if current.actualDurationSeconds > previous.actualDurationSeconds + 4 {
                    highlights.append(
                        WeeklyProgressHighlight(
                            id: "\(exerciseId)-duration-\(index)",
                            exerciseId: exerciseId,
                            exerciseName: name,
                            kind: .duration(
                                fromSeconds: previous.actualDurationSeconds,
                                toSeconds: current.actualDurationSeconds
                            )
                        )
                    )
                    durationCount += 1
                }
            }
        }

        // Prefer newest improvements first; keep the list meaningful and readable.
        let ordered = highlights.reversed().filter { highlight in
            switch highlight.kind {
            case .weight, .reps, .milestone:
                break
            case .sets, .duration:
                return false
            }
            guard let exercise = ExerciseCatalog.exercise(id: highlight.exerciseId) else {
                return false
            }
            return isMeaningfulProgressExercise(exercise)
        }
        let capped = Array(ordered.prefix(12))

        return WeeklyProgressReport(
            highlights: capped,
            weightIncreaseCount: weightCount,
            repIncreaseCount: repCount,
            setIncreaseCount: setCount,
            durationIncreaseCount: durationCount,
            milestoneCount: milestoneCount
        )
    }

    /// Compounds and primary lifts users typically care about tracking.
    static func isMeaningfulProgressExercise(_ exercise: Exercise) -> Bool {
        switch exercise.category {
        case .push, .pull, .squat, .hinge, .lunge, .olympic, .carry:
            return true
        case .core, .isolation, .conditioning:
            return false
        }
    }

    @MainActor
    private static func exerciseName(id: String, localization: LocalizationStore) -> String {
        let exercise = ExerciseCatalog.exercise(id: id)
        return exercise?.localizedName(using: localization)
            ?? localization.exerciseName(
                id: id,
                englishFallback: exercise?.name ?? id,
                isCustom: false
            )
    }

    @MainActor
    private static func nextWorkoutLabel(
        exerciseId: String,
        globalProgress: GlobalExerciseProgressStore,
        unit: WeightUnit
    ) -> String? {
        guard let progress = globalProgress.progress(for: exerciseId) else { return nil }
        var parts: [String] = []
        if progress.workingWeightKg > 0 {
            parts.append(WeightFormatter.format(kg: progress.workingWeightKg, unit: unit))
        }
        if progress.targetReps > 0 {
            parts.append("\(progress.targetReps) reps")
        } else if progress.targetDurationSeconds > 0 {
            parts.append(ExerciseTrackingFormatter.formatDuration(seconds: progress.targetDurationSeconds))
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " × ")
    }

    private static func weightTransitionKey(_ exerciseId: String, from: Double, to: Double) -> String {
        let fromRounded = (from * 100).rounded() / 100
        let toRounded = (to * 100).rounded() / 100
        return "\(exerciseId)|\(fromRounded)|\(toRounded)"
    }
}
