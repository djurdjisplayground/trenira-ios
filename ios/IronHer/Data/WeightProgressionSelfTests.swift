import Foundation

#if DEBUG
/// DEBUG self-tests for weight progression math and the one-time increment repair.
enum WeightProgressionSelfTests {
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

        // Defaults
        check(
            "default increment is 2.5 kg",
            WeightProgressionCalculator.defaultIncrementKg == 2.5
        )
        check(
            "dumbbell soft default is 2.5 kg",
            EquipmentDefaults.defaultIncrementKg(for: .dumbbell) == 2.5
        )

        // Exact addition
        check(
            "17.5 + 2.5 = 20.0",
            WeightProgressionCalculator.addIncrement(currentKg: 17.5, incrementKg: 2.5) == 20.0
        )
        check(
            "20.0 + 2.5 = 22.5",
            WeightProgressionCalculator.addIncrement(currentKg: 20.0, incrementKg: 2.5) == 22.5
        )
        check(
            "15.0 + 2.5 = 17.5",
            WeightProgressionCalculator.addIncrement(currentKg: 15.0, incrementKg: 2.5) == 17.5
        )

        // No Int truncation
        let raw = 2.5
        check("2.5 is not truncated via Int", Int(raw) == 2 && raw == 2.5)
        check(
            "calculator keeps 2.5 (not Int-truncated 2)",
            WeightProgressionCalculator.addIncrement(currentKg: 17.5, incrementKg: raw) == 20.0
        )

        // Custom increments preserved by resolver
        let dumbbell = Exercise(
            id: "test-db-press",
            name: "Test DB Press",
            primaryMuscleGroup: .chest,
            equipment: .dumbbell,
            category: .push,
            movementPattern: .horizontalPush,
            measurementUnit: .weight
        )
        let custom2 = WeightProgressionCalculator.resolveIncrementKg(
            exercise: dumbbell,
            exerciseOverridesKg: [dumbbell.id: 2.0],
            equipmentOverridesKg: [:],
            categoryDefaultKg: 2.5
        )
        check("custom 2.0 kg exercise override preserved", custom2 == 2.0)

        let custom125 = WeightProgressionCalculator.resolveIncrementKg(
            exercise: dumbbell,
            exerciseOverridesKg: [dumbbell.id: 1.25],
            equipmentOverridesKg: [:],
            categoryDefaultKg: 2.5
        )
        check("custom 1.25 kg exercise override preserved", custom125 == 1.25)

        let bodyweight = Exercise(
            id: "test-pushup",
            name: "Test Push-up",
            primaryMuscleGroup: .chest,
            equipment: .bodyweight,
            category: .push,
            movementPattern: .horizontalPush,
            measurementUnit: .bodyweight
        )
        let bwInc = WeightProgressionCalculator.resolveIncrementKg(
            exercise: bodyweight,
            exerciseOverridesKg: [:],
            equipmentOverridesKg: [:],
            categoryDefaultKg: 2.5
        )
        check("bodyweight soft default remains 0", bwInc == 0)

        let timed = Exercise(
            id: "test-plank",
            name: "Test Plank",
            primaryMuscleGroup: .core,
            equipment: .bodyweight,
            category: .core,
            movementPattern: .core,
            measurementUnit: .time
        )
        check("timed exercise measurement unaffected", timed.measurementUnit == .time)

        // Bug detection / repair candidates
        check(
            "19.5 looks like buggy +2 from 17.5 with 2.5 config",
            WeightProgressionCalculator.looksLikeBuggyPlusTwoKilogramStep(
                previousKg: 17.5,
                currentKg: 19.5,
                configuredIncrementKg: 2.5
            )
        )
        check(
            "legitimate 19.5 after 17.0 + 2.5 is not buggy",
            !WeightProgressionCalculator.looksLikeBuggyPlusTwoKilogramStep(
                previousKg: 17.0,
                currentKg: 19.5,
                configuredIncrementKg: 2.5
            )
        )
        check(
            "intentional +2.0 with 2.0 config is not buggy",
            !WeightProgressionCalculator.looksLikeBuggyPlusTwoKilogramStep(
                previousKg: 17.5,
                currentKg: 19.5,
                configuredIncrementKg: 2.0
            )
        )

        let exerciseId = "test-repair-split-squat"
        let history = [
            WeightHistoryEntry(
                exerciseId: exerciseId,
                weightKg: 19.5,
                previousWeightKg: 17.5,
                event: .progression
            ),
        ]
        let records = [
            exerciseId: GlobalExerciseProgress(workingWeightKg: 19.5),
        ]
        let found = WeightIncrementRepairMigration.candidates(
            records: records,
            historyEntries: history,
            configuredIncrement: { _ in 2.5 }
        )
        check("repair finds 19.5 → 20.0 candidate", found.count == 1 && found.first?.correctedKg == 20.0)

        let manual = WeightIncrementRepairMigration.candidates(
            records: [exerciseId: GlobalExerciseProgress(workingWeightKg: 19.5)],
            historyEntries: [],
            configuredIncrement: { _ in 2.5 }
        )
        check("manual 19.5 without history is not repaired", manual.isEmpty)

        // Formatting
        check(
            "whole kg formats without trailing .0",
            WeightFormatter.format(kg: 20.0, unit: .kilograms) == "20 kg"
        )
        check(
            "half kg formats with one decimal",
            WeightFormatter.format(kg: 17.5, unit: .kilograms) == "17.5 kg"
        )

        // Migration once
        let owner = "selftest-weight-repair"
        let key = WeightIncrementRepairMigration.storageKey(ownerRawValue: owner)
        let previousFlag = UserDefaults.standard.object(forKey: key)
        defer {
            if let previousFlag {
                UserDefaults.standard.set(previousFlag, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        UserDefaults.standard.removeObject(forKey: key)
        check("migration not completed initially", !WeightIncrementRepairMigration.hasCompleted(ownerRawValue: owner))
        WeightIncrementRepairMigration.markCompleted(ownerRawValue: owner)
        check("migration marked completed", WeightIncrementRepairMigration.hasCompleted(ownerRawValue: owner))
        WeightIncrementRepairMigration.markCompleted(ownerRawValue: owner)
        check("marking completed twice stays completed", WeightIncrementRepairMigration.hasCompleted(ownerRawValue: owner))

        // Category default preferred over legacy soft path
        let resolved = WeightProgressionCalculator.resolveIncrementKg(
            exercise: dumbbell,
            exerciseOverridesKg: [:],
            equipmentOverridesKg: [:],
            categoryDefaultKg: 2.5
        )
        check("category default 2.5 used without overrides", resolved == 2.5)

        return Outcome(passed: passed, failed: failed, lines: lines)
    }
}
#endif
