import Foundation

#if DEBUG
/// DEBUG self-tests for exercise progress chart series logic.
enum ExerciseProgressSeriesSelfTests {
    struct Outcome: Sendable {
        var passed: Int
        var failed: Int
        var lines: [String]

        var summary: String {
            "\(passed) passed, \(failed) failed\n" + lines.joined(separator: "\n")
        }
    }

    static func runAll() -> Outcome {
        var passed = 0
        var failed = 0
        var lines: [String] = []

        func check(_ name: String, _ condition: @autoclosure () -> Bool) {
            if condition() {
                passed += 1
                lines.append("✓ \(name)")
            } else {
                failed += 1
                lines.append("✗ \(name)")
            }
        }

        // Epley
        check(
            "Epley 40kg × 10 = 53.333…",
            abs((ExerciseProgressSeriesBuilder.estimatedStrength(weightKg: 40, reps: 10) ?? -1) - (40 * (1 + 10.0 / 30.0))) < 0.0001
        )
        check("Epley rejects zero weight", ExerciseProgressSeriesBuilder.estimatedStrength(weightKg: 0, reps: 10) == nil)
        check("Epley rejects zero reps", ExerciseProgressSeriesBuilder.estimatedStrength(weightKg: 40, reps: 0) == nil)

        let weighted = sampleExercise(id: "test-squat", unit: .weight)
        let repsOnly = sampleExercise(id: "test-pushup", unit: .bodyweight)
        let timed = sampleExercise(id: "test-plank", unit: .time)
        let weightedTimed = sampleExercise(id: "test-farmers", unit: .weightAndTime)

        let day1 = date(2026, 6, 1)
        let day2 = date(2026, 6, 15)
        let day3 = date(2026, 7, 1)

        // Best estimated-strength set per workout (incomplete ignored)
        let strengthLog = log(
            workoutId: UUID(),
            name: "Lower A",
            at: day1,
            exerciseId: weighted.id,
            sets: [
                set(0, completed: false, weight: 50, reps: 5),
                set(1, completed: true, weight: 40, reps: 10), // 53.33
                set(2, completed: true, weight: 45, reps: 5),  // 52.5
                set(3, completed: true, weight: 0, reps: 10),  // invalid
            ]
        )
        let strengthPoints = ExerciseProgressSeriesBuilder.sessionPoints(
            exerciseId: weighted.id,
            logs: [strengthLog],
            metric: .estimatedStrength
        )
        check("selects highest Epley set", abs((strengthPoints.first?.metricValue ?? 0) - 53.333333) < 0.01)
        check("keeps actual weight/reps from best set", strengthPoints.first?.bestSet.weightKg == 40 && strengthPoints.first?.bestSet.reps == 10)
        check("counts only completed sets", strengthPoints.first?.completedSetCount == 3)

        // Repetition-only
        let repsLog = log(
            workoutId: UUID(),
            name: "Upper",
            at: day1,
            exerciseId: repsOnly.id,
            sets: [
                set(0, completed: true, weight: 0, reps: 12),
                set(1, completed: true, weight: 0, reps: 15),
                set(2, completed: false, weight: 0, reps: 20),
            ]
        )
        let repPoints = ExerciseProgressSeriesBuilder.sessionPoints(
            exerciseId: repsOnly.id,
            logs: [repsLog],
            metric: .bestReps
        )
        check("reps-only uses best completed reps", repPoints.first?.bestSet.reps == 15)

        // Timed
        let timedLog = log(
            workoutId: UUID(),
            name: "Core",
            at: day1,
            exerciseId: timed.id,
            sets: [
                set(0, completed: true, weight: 0, reps: 0, duration: 45),
                set(1, completed: true, weight: 0, reps: 0, duration: 90),
                set(2, completed: false, weight: 0, reps: 0, duration: 120),
            ]
        )
        let timedPoints = ExerciseProgressSeriesBuilder.sessionPoints(
            exerciseId: timed.id,
            logs: [timedLog],
            metric: .longestDuration
        )
        check("timed uses longest completed duration", timedPoints.first?.bestSet.durationSeconds == 90)
        check("duration formats as mm:ss", ExerciseProgressSeriesBuilder.formatDurationClock(seconds: 90) == "01:30")

        // Weighted timed defaults to duration metric
        check(
            "weighted timed metric is duration",
            ExerciseProgressSeriesBuilder.metricKind(for: weightedTimed, logs: []) == .longestDuration
        )

        // Duplicate exercise entries in one workout → one point
        let entryA = LoggedExercisePerformance(
            entryId: UUID(),
            exerciseId: weighted.id,
            plannedSets: 2,
            plannedReps: 8,
            plannedWeightKg: 40,
            sets: [set(0, completed: true, weight: 40, reps: 8)]
        )
        let entryB = LoggedExercisePerformance(
            entryId: UUID(),
            exerciseId: weighted.id,
            plannedSets: 2,
            plannedReps: 8,
            plannedWeightKg: 42,
            sets: [set(0, completed: true, weight: 42, reps: 8)]
        )
        let multiEntryLog = LoggedWorkoutPerformance(
            workoutId: UUID(),
            workoutName: "Full body",
            completedAt: day1,
            exercises: [entryA, entryB]
        )
        let merged = ExerciseProgressSeriesBuilder.sessionPoints(
            exerciseId: weighted.id,
            logs: [multiEntryLog],
            metric: .estimatedStrength
        )
        check("multiple entries in one workout produce one point", merged.count == 1)
        check(
            "merged point uses better Epley across entries",
            abs((merged.first?.metricValue ?? 0) - (42 * (1 + 8.0 / 30.0))) < 0.01
        )

        // Duplicate completion same workout same day → keep latest
        let workoutId = UUID()
        let firstSave = LoggedWorkoutPerformance(
            id: UUID(),
            workoutId: workoutId,
            workoutName: "Push",
            completedAt: day1.addingTimeInterval(100),
            exercises: [entryA]
        )
        let secondSave = LoggedWorkoutPerformance(
            id: UUID(),
            workoutId: workoutId,
            workoutName: "Push",
            completedAt: day1.addingTimeInterval(500),
            exercises: [entryB]
        )
        let deduped = ExerciseProgressSeriesBuilder.sessionPoints(
            exerciseId: weighted.id,
            logs: [firstSave, secondSave],
            metric: .estimatedStrength
        )
        check("duplicate same-day workout completions collapse to one point", deduped.count == 1)
        check("keeps later duplicate completion", deduped.first?.sessionId == secondSave.id)

        // Same exercise across templates
        let templateA = log(workoutId: UUID(), name: "A", at: day1, exerciseId: weighted.id, sets: [
            set(0, completed: true, weight: 40, reps: 8),
        ])
        let templateB = log(workoutId: UUID(), name: "B", at: day2, exerciseId: weighted.id, sets: [
            set(0, completed: true, weight: 45, reps: 8),
        ])
        let across = ExerciseProgressSeriesBuilder.sessionPoints(
            exerciseId: weighted.id,
            logs: [templateA, templateB],
            metric: .estimatedStrength
        )
        check("same exercise across templates combines", across.count == 2)

        // Renamed exercise retains history by id
        let renamed = sampleExercise(id: weighted.id, name: "Back Squat v2", unit: .weight)
        let renameSeries = ExerciseProgressSeriesBuilder.series(
            exerciseId: renamed.id,
            exercise: renamed,
            logs: [templateA, templateB],
            range: .allTime,
            weightUnit: .kilograms,
            now: day3
        )
        check("renamed exercise keeps history via id", renameSeries.points.count == 2)

        // Percentage increase / decrease summaries
        let upSeries = ExerciseProgressSeriesBuilder.series(
            exerciseId: weighted.id,
            exercise: weighted,
            logs: [templateA, templateB],
            range: .allTime,
            weightUnit: .kilograms,
            now: day3
        )
        check(
            "percentage increase summary",
            upSeries.summaryText?.contains("Estimated strength increased by") == true
        )

        let downA = log(workoutId: UUID(), name: "A", at: day1, exerciseId: weighted.id, sets: [
            set(0, completed: true, weight: 50, reps: 8),
        ])
        let downB = log(workoutId: UUID(), name: "B", at: day2, exerciseId: weighted.id, sets: [
            set(0, completed: true, weight: 40, reps: 8),
        ])
        let downSeries = ExerciseProgressSeriesBuilder.series(
            exerciseId: weighted.id,
            exercise: weighted,
            logs: [downA, downB],
            range: .allTime,
            weightUnit: .kilograms,
            now: day3
        )
        check(
            "percentage decrease uses neutral wording",
            downSeries.summaryText?.contains("below the start of this period") == true
        )

        let repUp = ExerciseProgressSeriesBuilder.series(
            exerciseId: repsOnly.id,
            exercise: repsOnly,
            logs: [
                log(workoutId: UUID(), name: "A", at: day1, exerciseId: repsOnly.id, sets: [
                    set(0, completed: true, weight: 0, reps: 10),
                ]),
                log(workoutId: UUID(), name: "B", at: day2, exerciseId: repsOnly.id, sets: [
                    set(0, completed: true, weight: 0, reps: 15),
                ]),
            ],
            range: .allTime,
            weightUnit: .kilograms,
            now: day3
        )
        check(
            "reps summary wording",
            repUp.summaryText == "Best set improved from 10 to 15 reps"
        )

        // Empty / one-point
        let empty = ExerciseProgressSeriesBuilder.series(
            exerciseId: weighted.id,
            exercise: weighted,
            logs: [],
            range: .allTime,
            weightUnit: .kilograms,
            now: day3
        )
        check("empty dataset has no points", empty.isEmpty && empty.summaryText == nil)

        let one = ExerciseProgressSeriesBuilder.series(
            exerciseId: weighted.id,
            exercise: weighted,
            logs: [templateA],
            range: .allTime,
            weightUnit: .kilograms,
            now: day3
        )
        check("one-point dataset has no trend summary", one.points.count == 1 && one.summaryText == nil)
        check("one-point y-domain is padded", ExerciseProgressSeriesBuilder.yAxisDomain(values: [53.3]) != nil)

        // Time-range filtering
        let old = log(workoutId: UUID(), name: "Old", at: date(2025, 1, 1), exerciseId: weighted.id, sets: [
            set(0, completed: true, weight: 30, reps: 8),
        ])
        let recent = log(workoutId: UUID(), name: "New", at: day2, exerciseId: weighted.id, sets: [
            set(0, completed: true, weight: 40, reps: 8),
        ])
        let filtered = ExerciseProgressSeriesBuilder.series(
            exerciseId: weighted.id,
            exercise: weighted,
            logs: [old, recent],
            range: .threeMonths,
            weightUnit: .kilograms,
            now: day3
        )
        check("three-month filter excludes older sessions", filtered.points.count == 1)
        check("three-month filter keeps recent session", filtered.points.first?.workoutName == "New")

        let all = ExerciseProgressSeriesBuilder.series(
            exerciseId: weighted.id,
            exercise: weighted,
            logs: [old, recent],
            range: .allTime,
            weightUnit: .kilograms,
            now: day3
        )
        check("all-time includes older sessions", all.points.count == 2)

        return Outcome(passed: passed, failed: failed, lines: lines)
    }

    // MARK: - Fixtures

    private static func sampleExercise(
        id: String,
        name: String = "Test Exercise",
        unit: MeasurementUnit
    ) -> Exercise {
        Exercise(
            id: id,
            name: name,
            primaryMuscleGroup: .quads,
            equipment: .barbell,
            category: .squat,
            movementPattern: .squat,
            measurementUnit: unit
        )
    }

    private static func set(
        _ index: Int,
        completed: Bool,
        weight: Double,
        reps: Int,
        duration: Int = 0
    ) -> LoggedSetPerformance {
        LoggedSetPerformance(
            setIndex: index,
            completed: completed,
            weightKg: weight,
            reps: reps,
            durationSeconds: duration,
            distanceMeters: 0
        )
    }

    private static func log(
        workoutId: UUID,
        name: String,
        at: Date,
        exerciseId: String,
        sets: [LoggedSetPerformance]
    ) -> LoggedWorkoutPerformance {
        LoggedWorkoutPerformance(
            workoutId: workoutId,
            workoutName: name,
            completedAt: at,
            exercises: [
                LoggedExercisePerformance(
                    entryId: UUID(),
                    exerciseId: exerciseId,
                    plannedSets: sets.count,
                    plannedReps: sets.map(\.reps).max() ?? 0,
                    plannedWeightKg: sets.map(\.weightKg).max() ?? 0,
                    sets: sets
                ),
            ]
        )
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return Calendar(identifier: .gregorian).date(from: components) ?? .now
    }
}
#endif
