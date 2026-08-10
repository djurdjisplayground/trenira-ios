import Foundation

/// One-time repair for working weights advanced with the legacy 2.0 kg dumbbell soft default
/// while the product progression default was 2.5 kg (e.g. 17.5 → 19.5 instead of 20.0).
///
/// Identifier: `weightIncrementRepair_v1`
/// Does not rewrite completed workout performance logs.
enum WeightIncrementRepairMigration {
    static let identifier = "weightIncrementRepair_v1"
    static let userDefaultsKeyPrefix = "trenira.migrationDone.weightIncrementRepair_v1"

    struct Report: Equatable {
        var repairedExerciseIds: [String] = []
        var synchronizedTemplateTouchCount: Int = 0
        var repairedCustomRuleIds: [String] = []
        var skippedInsufficientEvidence: Int = 0
        var alreadyCompleted: Bool = false

        var didChange: Bool {
            !repairedExerciseIds.isEmpty || !repairedCustomRuleIds.isEmpty
        }
    }

    struct Candidate: Equatable {
        let exerciseId: String
        let previousKg: Double
        let storedKg: Double
        let correctedKg: Double
        let configuredIncrementKg: Double
    }

    static func storageKey(ownerRawValue: String) -> String {
        "\(userDefaultsKeyPrefix).\(ownerRawValue)"
    }

    static func hasCompleted(ownerRawValue: String) -> Bool {
        UserDefaults.standard.bool(forKey: storageKey(ownerRawValue: ownerRawValue))
    }

    static func markCompleted(ownerRawValue: String) {
        UserDefaults.standard.set(true, forKey: storageKey(ownerRawValue: ownerRawValue))
    }

    /// Pure evaluation — used by tests and the live migrator.
    static func candidates(
        records: [String: GlobalExerciseProgress],
        historyEntries: [WeightHistoryEntry],
        configuredIncrement: (String) -> Double
    ) -> [Candidate] {
        var results: [Candidate] = []

        for (exerciseId, record) in records {
            let increment = configuredIncrement(exerciseId)
            guard WeightProgressionCalculator.approximatelyEqual(
                increment,
                WeightProgressionCalculator.defaultIncrementKg
            ) else { continue }

            guard let previous = previousCompletedWeight(
                exerciseId: exerciseId,
                currentKg: record.workingWeightKg,
                historyEntries: historyEntries
            ) else { continue }

            let current = record.workingWeightKg
            guard WeightProgressionCalculator.looksLikeBuggyPlusTwoKilogramStep(
                previousKg: previous,
                currentKg: current,
                configuredIncrementKg: increment
            ) else { continue }

            let corrected = WeightProgressionCalculator.expectedNext(
                after: previous,
                incrementKg: WeightProgressionCalculator.defaultIncrementKg
            )
            results.append(
                Candidate(
                    exerciseId: exerciseId,
                    previousKg: previous,
                    storedKg: current,
                    correctedKg: corrected,
                    configuredIncrementKg: increment
                )
            )
        }

        return results.sorted { $0.exerciseId < $1.exerciseId }
    }

    @MainActor
    @discardableResult
    static func runIfNeeded(
        ownerRawValue: String,
        globalProgressStore: GlobalExerciseProgressStore,
        workoutStore: WorkoutStore,
        historyStore: WeightHistoryStore,
        progressionStore: ExerciseProgressionStore,
        settingsStore: UserSettingsStore
    ) -> Report {
        if hasCompleted(ownerRawValue: ownerRawValue) {
            return Report(alreadyCompleted: true)
        }

        var report = Report()
        let categoryDefault = progressionStore.categoryDefaults.normalized.defaultWeightIncrementKg

        let found = candidates(
            records: globalProgressStore.records,
            historyEntries: historyStore.entries,
            configuredIncrement: { exerciseId in
                if let exerciseOverride = settingsStore.exerciseIncrementOverridesKg[exerciseId] {
                    return exerciseOverride
                }
                if let exercise = ExerciseCatalog.exercise(id: exerciseId),
                   exercise.equipment != .machine,
                   exercise.equipment != .cable,
                   let equipmentOverride = settingsStore.equipmentIncrementOverridesKg[exercise.equipment.rawValue] {
                    return equipmentOverride
                }
                if let custom = progressionStore.ruleIfCustom(for: exerciseId),
                   custom.weightIncrementKg > 0,
                   !WeightProgressionCalculator.approximatelyEqual(
                    custom.weightIncrementKg,
                    WeightProgressionCalculator.legacyBuggyDumbbellIncrementKg
                   ) {
                    return custom.weightIncrementKg
                }
                return categoryDefault > 0
                    ? categoryDefault
                    : WeightProgressionCalculator.defaultIncrementKg
            }
        )

        for candidate in found {
            _ = globalProgressStore.updateWeight(
                for: candidate.exerciseId,
                weightKg: candidate.correctedKg,
                into: workoutStore
            )
            report.repairedExerciseIds.append(candidate.exerciseId)
            report.synchronizedTemplateTouchCount += workoutStore.workouts.reduce(0) { partial, workout in
                partial + workout.exercises.filter { $0.exerciseId == candidate.exerciseId }.count
            }

            if settingsStore.exerciseIncrementOverridesKg[candidate.exerciseId] == nil,
               var custom = progressionStore.ruleIfCustom(for: candidate.exerciseId),
               WeightProgressionCalculator.approximatelyEqual(
                custom.weightIncrementKg,
                WeightProgressionCalculator.legacyBuggyDumbbellIncrementKg
               ) {
                custom.weightIncrementKg = WeightProgressionCalculator.defaultIncrementKg
                progressionStore.updateRule(custom, for: candidate.exerciseId)
                report.repairedCustomRuleIds.append(candidate.exerciseId)
            }
        }

        let weightedIds = globalProgressStore.records.keys.filter { id in
            guard let exercise = ExerciseCatalog.exercise(id: id) else { return false }
            return exercise.showsWeightDuringSession
        }
        report.skippedInsufficientEvidence = max(0, weightedIds.count - found.count)

        markCompleted(ownerRawValue: ownerRawValue)
        return report
    }

    /// Previous weight for the buggy step — requires a progression history entry whose
    /// `to` matches the stored working weight.
    static func previousCompletedWeight(
        exerciseId: String,
        currentKg: Double,
        historyEntries: [WeightHistoryEntry]
    ) -> Double? {
        let progression = historyEntries
            .filter { $0.exerciseId == exerciseId && $0.event == .progression }
            .sorted { $0.date < $1.date }

        guard let latest = progression.last,
              WeightProgressionCalculator.approximatelyEqual(latest.weightKg, currentKg),
              let previous = latest.previousWeightKg else {
            return nil
        }
        return previous
    }
}
