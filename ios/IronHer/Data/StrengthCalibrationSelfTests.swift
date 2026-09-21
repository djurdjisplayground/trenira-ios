import Foundation

#if DEBUG
/// DEBUG assertions for starting-weight calibration priority.
enum StrengthCalibrationSelfTests {
    struct Outcome: Sendable {
        var passed: Int
        var failed: Int
        var lines: [String]

        var summary: String {
            "\(passed) passed, \(failed) failed\n" + lines.joined(separator: "\n")
        }
    }

    @MainActor
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

        let goblet = "goblet-squat"
        let splitSquat = "bulgarian-split-squat"
        let calibration = ExerciseCalibration(exerciseId: goblet, weightKg: 20, reps: 10)

        // 1. New user calibrates → generated workout receives calibrated weight
        let generated = StrengthCalibrationResolver.startingWeightKg(
            exerciseId: goblet,
            progress: nil,
            historyEntries: [],
            calibration: calibration
        )
        check("calibrated exercise seeds generated starting weight", generated == 20)

        // 2. Skip calibration → unchanged fallback
        let skipped = StrengthCalibrationResolver.startingWeightKg(
            exerciseId: goblet,
            progress: nil,
            historyEntries: [],
            calibration: nil
        )
        check("skipped calibration keeps unassigned fallback", skipped == 0)

        // 3. Later progressed weight is not overwritten by calibration
        let progressed = GlobalExerciseProgress(workingWeightKg: 25, lastPerformedAt: .now)
        let afterProgress = StrengthCalibrationResolver.startingWeightKg(
            exerciseId: goblet,
            progress: progressed,
            historyEntries: [],
            calibration: calibration
        )
        check("progressed weight outranks calibration", afterProgress == 25)
        check(
            "source is established after progress",
            StrengthCalibrationResolver.source(
                exerciseId: goblet,
                progress: progressed,
                historyEntries: [],
                calibration: calibration
            ) == .establishedProgress(weightKg: 25)
        )

        // 4. Existing workout history outranks calibration
        let history = [
            WeightHistoryEntry(exerciseId: goblet, weightKg: 22.5, event: .initial)
        ]
        let withHistory = StrengthCalibrationResolver.startingWeightKg(
            exerciseId: goblet,
            progress: GlobalExerciseProgress(workingWeightKg: 22.5),
            historyEntries: history,
            calibration: ExerciseCalibration(exerciseId: goblet, weightKg: 40, reps: 8)
        )
        check("workout history outranks recalibration", withHistory == 22.5)
        check(
            "history without a global record still outranks calibration",
            StrengthCalibrationResolver.startingWeightKg(
                exerciseId: goblet,
                progress: nil,
                historyEntries: history,
                calibration: ExerciseCalibration(exerciseId: goblet, weightKg: 40, reps: 8)
            ) == 22.5
        )

        // 5. Recalibrating does not erase history (resolver still prefers history)
        let recalibrated = ExerciseCalibration(exerciseId: goblet, weightKg: 50, reps: 8)
        check(
            "recalibration does not replace history",
            StrengthCalibrationResolver.hasEstablishedProgress(
                progress: GlobalExerciseProgress(workingWeightKg: 22.5, lastActual: nil),
                historyEntries: history
            )
        )
        check(
            "recalibration stored separately from history",
            StrengthCalibrationResolver.startingWeightKg(
                exerciseId: goblet,
                progress: GlobalExerciseProgress(workingWeightKg: 22.5),
                historyEntries: history,
                calibration: recalibrated
            ) == 22.5
        )

        // 6. Related exercises infer from the family baseline
        let workouts = [
            Workout(
                name: "Test",
                exercises: [
                    WorkoutExerciseEntry(exerciseId: goblet, sets: 3, reps: 10, startingWeight: 0, order: 0),
                    WorkoutExerciseEntry(exerciseId: splitSquat, sets: 3, reps: 10, startingWeight: 0, order: 1),
                ]
            )
        ]
        let stamped = StrengthCalibrationResolver.applyStartingWeights(
            to: workouts,
            progressFor: { _ in nil },
            historyFor: { _ in [] },
            calibrations: [goblet: calibration]
        )
        let inferredSplit = stamped[0].exercises.first { $0.exerciseId == splitSquat }?.startingWeight ?? 0
        check(
            "bulgarian split squat infers a positive load from goblet squat",
            inferredSplit > 0
        )
        check(
            "calibrated exercise stamped",
            stamped[0].exercises.first { $0.exerciseId == goblet }?.startingWeight == 20
        )

        let bench = "dumbbell-bench-press"
        let incline = "incline-dumbbell-press"
        let benchCalibration = ExerciseCalibration(exerciseId: bench, weightKg: 8, reps: 10)
        let inferredIncline = StrengthCalibrationResolver.startingWeightKg(
            exerciseId: incline,
            targetReps: 10,
            progress: nil,
            historyEntries: [],
            calibrations: [bench: benchCalibration]
        )
        check("incline dumbbell press infers from db bench", inferredIncline == 6)
        check(
            "bulgarian split squat infers 11 kg from 20 kg goblet squat",
            inferredSplit == 11
        )
        check(
            "incline source is inferred",
            StrengthCalibrationResolver.source(
                exerciseId: incline,
                targetReps: 10,
                progress: nil,
                historyEntries: [],
                calibrations: [bench: benchCalibration]
            ) == .inferred(weightKg: inferredIncline)
        )

        check(
            "explicit user weight wins over inference",
            StrengthCalibrationResolver.startingWeightKg(
                exerciseId: incline,
                targetReps: 10,
                explicitWeightKg: 14,
                progress: nil,
                historyEntries: [],
                calibrations: [bench: benchCalibration]
            ) == 14
        )

        let eightRepEquivalent = StrengthLoadNormalizer.tenRepEquivalentKg(weightKg: 20, reps: 8)
        let twelveRepEquivalent = StrengthLoadNormalizer.tenRepEquivalentKg(weightKg: 20, reps: 12)
        check("20kg x 8 is not treated as 20kg x 12", eightRepEquivalent != twelveRepEquivalent)

        check(
            "no relevant calibration falls back",
            StrengthCalibrationResolver.startingWeightKg(
                exerciseId: incline,
                targetReps: 10,
                progress: nil,
                historyEntries: [],
                calibrations: [:]
            ) == 0
        )

        check(
            "bodyweight exercise does not get an inferred load",
            StrengthCalibrationResolver.startingWeightKg(
                exerciseId: "incline-push-up",
                targetReps: 10,
                progress: nil,
                historyEntries: [],
                calibrations: [bench: benchCalibration]
            ) == 0
        )

        check(
            "duration exercise does not get an inferred load",
            StrengthCalibrationResolver.startingWeightKg(
                exerciseId: "plank",
                targetReps: 10,
                progress: nil,
                historyEntries: [],
                calibrations: [goblet: calibration]
            ) == 0
        )

        // 7. Partial calibration persists independently of onboarding
        let suite = "trenira.calibrationSelfTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = StrengthCalibrationStore(defaults: defaults)
        store.saveCalibration(exerciseId: goblet, weightKg: 16, reps: 9)
        store.skipExercise(id: "lat-pulldown")
        let reloaded = StrengthCalibrationStore(defaults: defaults)
        check("partial calibration survives relaunch", reloaded.calibration(for: goblet)?.weightKg == 16)
        check("skipped exercise persisted", reloaded.skippedExerciseIds.contains("lat-pulldown"))
        check("partial save does not finish calibration flow", !reloaded.hasFinishedOrSkippedFlow)

        // 8. Existing users are not forced through the new first-launch journey
        let previousOnboarding = UserDefaults.standard.object(forKey: OnboardingStore.storageKey)
        defer {
            if let flag = previousOnboarding as? Bool {
                OnboardingStore.hasCompletedOnboarding = flag
            } else if previousOnboarding == nil {
                OnboardingStore.clear()
            } else {
                UserDefaults.standard.set(previousOnboarding, forKey: OnboardingStore.storageKey)
            }
        }

        OnboardingStore.markCompleted()
        check("existing onboarding stays complete without calibration flow", OnboardingStore.hasCompletedOnboarding)
        check("setup card can stay optional", !store.hasDismissedSetupCard && !store.hasFinishedOrSkippedFlow)

        OnboardingStore.clear()
        OnboardingStore.migrateExistingUsersIfNeeded(hasExistingUserData: true)
        check("existing workout data migrates onboarding complete", OnboardingStore.hasCompletedOnboarding)
        OnboardingStore.clear()
        OnboardingStore.migrateExistingUsersIfNeeded(hasExistingUserData: false)
        check("new user without data is not auto-completed", !OnboardingStore.hasCompletedOnboarding)
        OnboardingStore.markCompleted()
        OnboardingStore.migrateExistingUsersIfNeeded(hasExistingUserData: false)
        check("stored completion flag is not reset", OnboardingStore.hasCompletedOnboarding)

        check(
            "recorded calibration hides home setup nag",
            !store.showsWorkoutsSetupCard
        )
        check(
            "recorded calibration hides create-workout nag",
            !store.showsCreateWorkoutSetupPrompt
        )

        let emptySuite = "trenira.calibrationSelfTests.empty.\(UUID().uuidString)"
        let emptyDefaults = UserDefaults(suiteName: emptySuite)!
        emptyDefaults.removePersistentDomain(forName: emptySuite)
        let emptyStore = StrengthCalibrationStore(defaults: emptyDefaults)
        check("empty store shows home setup card", emptyStore.showsHomeSetupCard)
        emptyStore.dismissSetupCard()
        check("explicit dismiss hides workouts card", !emptyStore.showsWorkoutsSetupCard)
        check("explicit dismiss hides home card", !emptyStore.showsHomeSetupCard)
        check(
            "create-workout prompt remains after dismiss until a sample exists",
            emptyStore.showsCreateWorkoutSetupPrompt
        )
        emptyDefaults.removePersistentDomain(forName: emptySuite)

        // 9. Priority: history > calibration > fallback
        check(
            "fallback when nothing is saved",
            StrengthCalibrationResolver.source(
                exerciseId: goblet,
                progress: nil,
                historyEntries: [],
                calibration: nil
            ) == .fallback
        )
        check(
            "calibration when no history",
            StrengthCalibrationResolver.source(
                exerciseId: goblet,
                progress: nil,
                historyEntries: [],
                calibration: calibration
            ) == .calibration(weightKg: 20)
        )

        // Related exercises must not inherit V1 weights
        check(
            "related exercise infers from goblet squat calibration",
            StrengthCalibrationResolver.startingWeightKg(
                exerciseId: splitSquat,
                targetReps: 10,
                progress: nil,
                historyEntries: [],
                calibrations: [goblet: calibration]
            ) > 0
        )

        check(
            "catalog uses existing exercise IDs",
            StrengthCalibrationCatalog.exercises.count == StrengthCalibrationCatalog.exerciseIds.count
        )

        defaults.removePersistentDomain(forName: suite)
        return Outcome(passed: passed, failed: failed, lines: lines)
    }
}
#endif
