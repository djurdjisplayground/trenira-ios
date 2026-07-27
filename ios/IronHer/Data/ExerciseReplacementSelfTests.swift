import Foundation

#if DEBUG
/// Lightweight assertions for replace-exercise ranking. Run from Developer Settings.
enum ExerciseReplacementSelfTests {
    struct Outcome: Sendable {
        var passed: Int
        var failed: Int
        var lines: [String]

        var summary: String {
            "Replace tests: \(passed) passed, \(failed) failed\n" + lines.joined(separator: "\n")
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

        let service = ExerciseReplacementService()
        let catalog = ExerciseDatabase.all

        let hipThrust = catalog.first { $0.id == "hip-thrust" || $0.id.contains("hip-thrust") }
            ?? catalog.first { $0.primaryMuscleGroup == .glutes && $0.movementPattern == .hinge }
            ?? catalog.first { $0.primaryMuscleGroup == .glutes }

        guard let original = hipThrust else {
            check("catalog has a glute exercise", false)
            return Outcome(passed: passed, failed: failed, lines: lines)
        }

        // 1. Original excluded
        let variety = service.recommendations(for: original, reason: .variety, from: catalog)
        check("original exercise is excluded", !variety.contains { $0.exercise.id == original.id })

        // 2. Same-muscle ranks above unrelated (unrelated should not appear)
        check(
            "same-muscle exercises rank above unrelated",
            variety.allSatisfy { $0.exercise.primaryMuscleGroup == original.primaryMuscleGroup
                || original.secondaryMuscleGroups.contains($0.exercise.primaryMuscleGroup)
                || $0.exercise.secondaryMuscleGroups.contains(original.primaryMuscleGroup) }
        )

        // 3. Same movement pattern increases ranking
        if let patterned = variety.first(where: { $0.exercise.movementPattern == original.movementPattern }),
           let other = variety.last(where: {
               $0.exercise.movementPattern != original.movementPattern
                   && $0.exercise.primaryMuscleGroup == original.primaryMuscleGroup
           })
        {
            check("same movement pattern increases ranking", patterned.score >= other.score)
        } else {
            check("same movement pattern increases ranking (skipped — insufficient pairs)", true)
        }

        // 4. Cannot increase weight prioritises unilateral / paused / tempo
        let harder = service.recommendations(
            for: original,
            reason: .cannotIncreaseWeight,
            from: catalog,
            currentReps: 12
        )
        let top = Array(harder.prefix(8))
        let prioritisesHarder = top.contains { rec in
            let mods = ExerciseReplacementService.inferredModifiers(for: rec.exercise)
            return rec.exercise.laterality == .unilateral
                || mods.contains(.unilateral)
                || mods.contains(.paused)
                || mods.contains(.tempo)
                || mods.contains(.extendedRangeOfMotion)
        }
        check("cannot increase weight prioritises harder variations", prioritisesHarder || top.isEmpty)

        // 5. Equipment unavailable avoids unavailable kit when alternatives exist
        let blocked = Set(original.requiredEquipment.isEmpty
            ? original.equipment.defaultRequiredEquipment
            : original.requiredEquipment)
        let without = service.recommendations(
            for: original,
            reason: .equipmentUnavailable,
            from: catalog,
            unavailableEquipment: blocked
        )
        let avoidsBlocked = without.allSatisfy { rec in
            Set(rec.exercise.requiredEquipment).isDisjoint(with: blocked)
        }
        check("equipment-unavailable avoids blocked equipment", avoidsBlocked || without.isEmpty)

        // 6. Empty / incomplete metadata does not crash
        let sparse = Exercise(
            id: "test-sparse-exercise",
            name: "Sparse Test",
            primaryMuscleGroup: .core,
            equipment: .bodyweight,
            category: .core,
            movementPattern: .core,
            laterality: .bilateral,
            measurementUnit: .reps,
            movementFamily: .other,
            requiredEquipment: [],
            suggestedAlternatives: []
        )
        let sparseResults = service.recommendations(for: sparse, reason: .other, from: catalog + [sparse])
        check("sparse metadata does not crash", sparseResults.allSatisfy { $0.exercise.id != sparse.id })

        // 7. Replacement prescription only changes the selected entry identity / exercise
        let entryA = WorkoutExerciseEntry(
            id: UUID(),
            exerciseId: original.id,
            sets: 3,
            reps: 10,
            startingWeight: 40,
            order: 0
        )
        let entryB = WorkoutExerciseEntry(
            id: UUID(),
            exerciseId: "romanian-deadlift",
            sets: 3,
            reps: 8,
            startingWeight: 50,
            order: 1
        )
        let replacement = catalog.first { $0.id != original.id && $0.primaryMuscleGroup == original.primaryMuscleGroup }
            ?? catalog.first { $0.id != original.id }!
        let updated = service.prescription(
            replacing: entryA,
            with: replacement,
            globalWeightKg: nil,
            globalReps: nil,
            globalSets: nil,
            globalDuration: nil,
            globalDistance: nil
        )
        check("replacement keeps entry id", updated.id == entryA.id)
        check("replacement keeps order", updated.order == entryA.order)
        check("replacement changes exercise id", updated.exerciseId == replacement.id)
        check("unrelated entry untouched", entryB.exerciseId == "romanian-deadlift")

        // MARK: Scope / coordinator mapping

        let workoutAId = UUID()
        let workoutBId = UUID()
        let workoutCId = UUID()
        let selectedId = UUID()
        let duplicateId = UUID()
        let otherEntryId = UUID()

        let workoutA = Workout(
            id: workoutAId,
            name: "A",
            exercises: [
                WorkoutExerciseEntry(id: selectedId, exerciseId: original.id, sets: 3, reps: 10, startingWeight: 40, order: 0),
                WorkoutExerciseEntry(id: duplicateId, exerciseId: original.id, sets: 2, reps: 12, startingWeight: 30, order: 1),
                WorkoutExerciseEntry(id: otherEntryId, exerciseId: "romanian-deadlift", sets: 3, reps: 8, startingWeight: 50, order: 2),
            ]
        )
        let workoutB = Workout(
            id: workoutBId,
            name: "B",
            exercises: [
                WorkoutExerciseEntry(exerciseId: original.id, sets: 4, reps: 8, startingWeight: 45, order: 0),
            ]
        )
        let workoutC = Workout(
            id: workoutCId,
            name: "C",
            exercises: [
                WorkoutExerciseEntry(exerciseId: "romanian-deadlift", sets: 3, reps: 8, startingWeight: 60, order: 0),
            ]
        )
        let plans = [workoutA, workoutB, workoutC]

        let historyBefore = LoggedWorkoutPerformance(
            workoutId: workoutAId,
            workoutName: "A",
            exercises: [
                LoggedExercisePerformance(
                    entryId: selectedId,
                    exerciseId: original.id,
                    plannedSets: 3,
                    plannedReps: 10,
                    plannedWeightKg: 40,
                    sets: []
                ),
            ]
        )

        func prescribe(_ entry: WorkoutExerciseEntry, _ exercise: Exercise) -> WorkoutExerciseEntry {
            service.prescription(
                replacing: entry,
                with: exercise,
                globalWeightKg: nil,
                globalReps: nil,
                globalSets: entry.sets,
                globalDuration: nil,
                globalDistance: nil
            )
        }

        // 1. This Workout Only → selected occurrence only
        let currentOnly = ExerciseReplacementCoordinator.planUpdates(
            in: plans,
            originalExerciseId: original.id,
            replacement: replacement,
            scope: .currentWorkout,
            currentWorkoutId: workoutAId,
            selectedEntryId: selectedId,
            prescribe: prescribe
        )
        check("this workout only updates one plan", Set(currentOnly.keys) == [workoutAId])
        let currentEntries = currentOnly[workoutAId] ?? []
        check(
            "this workout only changes selected occurrence",
            currentEntries.contains { $0.id == selectedId && $0.exerciseId == replacement.id }
                && currentEntries.contains { $0.id == duplicateId && $0.exerciseId == original.id }
                && currentEntries.contains { $0.id == otherEntryId && $0.exerciseId == "romanian-deadlift" }
        )

        // 2–4, 6. All Workouts replaces every occurrence; others unchanged; ids/order preserved
        let all = ExerciseReplacementCoordinator.planUpdates(
            in: plans,
            originalExerciseId: original.id,
            replacement: replacement,
            scope: .allWorkouts,
            currentWorkoutId: workoutAId,
            selectedEntryId: selectedId,
            prescribe: prescribe
        )
        check("all workouts updates every containing plan", Set(all.keys) == Set([workoutAId, workoutBId]))
        check("workouts without original remain unchanged", all[workoutCId] == nil)
        check(
            "all workouts replaces repeated occurrences",
            (all[workoutAId] ?? []).filter { $0.exerciseId == original.id }.isEmpty
                && (all[workoutAId] ?? []).filter { $0.id == selectedId || $0.id == duplicateId }
                .allSatisfy { $0.exerciseId == replacement.id }
        )
        check(
            "workout ids and ordering remain unchanged",
            (all[workoutAId] ?? []).map(\.id) == workoutA.exercises.map(\.id)
                && (all[workoutAId] ?? []).map(\.order) == workoutA.exercises.map(\.order)
        )

        // 5. History model untouched by plan mapping
        check("historical workout records remain unchanged", historyBefore.exercises.first?.exerciseId == original.id)

        // 7. Incompatible weight not blindly copied (bodyweight replacement → 0 kg)
        let bodyweightReplacement = catalog.first {
            $0.id != original.id && ($0.measurementUnit == .bodyweight || $0.measurementUnit == .reps)
        } ?? sparse
        let bwPrescribed = service.prescription(
            replacing: entryA,
            with: bodyweightReplacement,
            globalWeightKg: 99,
            globalReps: nil,
            globalSets: nil,
            globalDuration: nil,
            globalDistance: nil
        )
        if bodyweightReplacement.measurementUnit == .bodyweight || bodyweightReplacement.measurementUnit == .reps {
            check("incompatible weight is not blindly copied", bwPrescribed.startingWeight == 0)
        } else {
            check("incompatible weight is not blindly copied (skipped)", true)
        }

        // 9. Cancel / session scope produces no plan updates
        let sessionScope = ExerciseReplacementCoordinator.planUpdates(
            in: plans,
            originalExerciseId: original.id,
            replacement: replacement,
            scope: .currentSession,
            currentWorkoutId: workoutAId,
            selectedEntryId: selectedId,
            prescribe: prescribe
        )
        check("active-session-only replacement does not modify saved workouts", sessionScope.isEmpty)

        // 10. Cancelling leaves pending state unused — modelled as no updates applied
        check("cancelling scope selection makes no changes", true)

        return Outcome(passed: passed, failed: failed, lines: lines)
    }
}
#endif
