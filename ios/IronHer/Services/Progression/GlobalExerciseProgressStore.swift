import Foundation

/// Snapshot of the last completed performance for an exercise (immutable reference on the progression record).
struct ExerciseActualSnapshot: Codable, Equatable, Hashable {
    let completedAt: Date
    let workoutName: String
    let sets: [LoggedSetPerformance]

    var completedSets: [LoggedSetPerformance] {
        sets.filter(\.completed)
    }

    var completedSetCount: Int {
        completedSets.count
    }
}

/// Single source of truth for an exercise's current prescription across all workout plans.
struct GlobalExerciseProgress: Codable, Equatable, Hashable {
    var workingWeightKg: Double
    var targetReps: Int
    var targetSets: Int
    var targetDurationSeconds: Int
    var targetDistanceMeters: Double
    /// Display/input unit for this exercise. `.useDefault` follows Settings.
    /// Future gym profiles can layer equipment-specific overrides on top of this exercise preference.
    var weightUnitPreference: ExerciseWeightUnitPreference
    var lastPerformedAt: Date?
    var lastActual: ExerciseActualSnapshot?
    var lastUpdated: Date

    init(
        workingWeightKg: Double = 0,
        targetReps: Int = 8,
        targetSets: Int = 3,
        targetDurationSeconds: Int = 0,
        targetDistanceMeters: Double = 0,
        weightUnitPreference: ExerciseWeightUnitPreference = .useDefault,
        lastPerformedAt: Date? = nil,
        lastActual: ExerciseActualSnapshot? = nil,
        lastUpdated: Date = .now
    ) {
        self.workingWeightKg = workingWeightKg
        self.targetReps = targetReps
        self.targetSets = max(1, targetSets)
        self.targetDurationSeconds = targetDurationSeconds
        self.targetDistanceMeters = targetDistanceMeters
        self.weightUnitPreference = weightUnitPreference
        self.lastPerformedAt = lastPerformedAt
        self.lastActual = lastActual
        self.lastUpdated = lastUpdated
    }

    private enum CodingKeys: String, CodingKey {
        case workingWeightKg
        case targetReps
        case targetSets
        case targetDurationSeconds
        case targetDistanceMeters
        case weightUnitPreference
        case lastPerformedAt
        case lastActual
        case lastUpdated
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        workingWeightKg = try container.decode(Double.self, forKey: .workingWeightKg)
        targetReps = try container.decode(Int.self, forKey: .targetReps)
        targetSets = try container.decodeIfPresent(Int.self, forKey: .targetSets) ?? 3
        targetDurationSeconds = try container.decodeIfPresent(Int.self, forKey: .targetDurationSeconds) ?? 0
        targetDistanceMeters = try container.decodeIfPresent(Double.self, forKey: .targetDistanceMeters) ?? 0
        weightUnitPreference = try container.decodeIfPresent(
            ExerciseWeightUnitPreference.self,
            forKey: .weightUnitPreference
        ) ?? .useDefault
        lastPerformedAt = try container.decodeIfPresent(Date.self, forKey: .lastPerformedAt)
        lastActual = try container.decodeIfPresent(ExerciseActualSnapshot.self, forKey: .lastActual)
        lastUpdated = try container.decodeIfPresent(Date.self, forKey: .lastUpdated) ?? .now
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(workingWeightKg, forKey: .workingWeightKg)
        try container.encode(targetReps, forKey: .targetReps)
        try container.encode(targetSets, forKey: .targetSets)
        try container.encode(targetDurationSeconds, forKey: .targetDurationSeconds)
        try container.encode(targetDistanceMeters, forKey: .targetDistanceMeters)
        try container.encode(weightUnitPreference, forKey: .weightUnitPreference)
        try container.encodeIfPresent(lastPerformedAt, forKey: .lastPerformedAt)
        try container.encodeIfPresent(lastActual, forKey: .lastActual)
        try container.encode(lastUpdated, forKey: .lastUpdated)
    }
}

/// Single shared progression record per exercise — weight, reps, and sets stay in sync across all workouts.
@Observable
@MainActor
final class GlobalExerciseProgressStore {
    private(set) var records: [String: GlobalExerciseProgress] = [:]

    private let storageKey = "globalExerciseProgress"

    init() {
        load()
    }

    func progress(for exerciseId: String) -> GlobalExerciseProgress? {
        records[exerciseId]
    }

    func workingWeightKg(for exerciseId: String) -> Double? {
        records[exerciseId]?.workingWeightKg
    }

    func weightUnitPreference(for exerciseId: String) -> ExerciseWeightUnitPreference {
        records[exerciseId]?.weightUnitPreference ?? .useDefault
    }

    func resolvedWeightUnit(for exerciseId: String, defaultUnit: WeightUnit) -> WeightUnit {
        weightUnitPreference(for: exerciseId).resolved(defaultUnit: defaultUnit)
    }

    @discardableResult
    func setWeightUnitPreference(
        _ preference: ExerciseWeightUnitPreference,
        for exerciseId: String
    ) -> GlobalExerciseProgress {
        var record = records[exerciseId] ?? GlobalExerciseProgress()
        record.weightUnitPreference = preference
        record.lastUpdated = .now
        records[exerciseId] = record
        save()
        return record
    }

    func targetReps(for exerciseId: String) -> Int? {
        records[exerciseId]?.targetReps
    }

    func targetSets(for exerciseId: String) -> Int? {
        records[exerciseId]?.targetSets
    }

    /// Prefer global values when present; otherwise fall back to the workout entry.
    func resolvedWeight(for exerciseId: String, entryWeight: Double) -> Double {
        workingWeightKg(for: exerciseId) ?? entryWeight
    }

    func resolvedReps(for exerciseId: String, entryReps: Int) -> Int {
        targetReps(for: exerciseId) ?? entryReps
    }

    func resolvedSets(for exerciseId: String, entrySets: Int) -> Int {
        targetSets(for: exerciseId) ?? entrySets
    }

    func resolvedDurationSeconds(for exerciseId: String, entryDurationSeconds: Int) -> Int {
        if let value = records[exerciseId]?.targetDurationSeconds, value > 0 {
            return value
        }
        return entryDurationSeconds
    }

    func resolvedDistanceMeters(for exerciseId: String, entryDistanceMeters: Double) -> Double {
        if let value = records[exerciseId]?.targetDistanceMeters, value > 0 {
            return value
        }
        return entryDistanceMeters
    }

    /// Template / edit-workflow sync: writes the single progression SoT and fans out to every plan.
    @discardableResult
    func syncFromTemplateEdit(
        exerciseId: String,
        measurement: MeasurementUnit,
        weightKg: Double,
        reps: Int,
        sets: Int,
        durationSeconds: Int,
        distanceMeters: Double,
        into workoutStore: WorkoutStore
    ) -> GlobalExerciseProgress {
        let normalizedWeight: Double
        switch measurement {
        case .reps, .bodyweight:
            normalizedWeight = 0
        default:
            normalizedWeight = max(0, weightKg)
        }

        return sync(
            exerciseId: exerciseId,
            weightKg: normalizedWeight,
            reps: max(1, reps),
            sets: max(1, sets),
            durationSeconds: max(0, durationSeconds),
            distanceMeters: max(0, distanceMeters),
            into: workoutStore
        )
    }

    @discardableResult
    func sync(
        exerciseId: String,
        weightKg: Double,
        reps: Int,
        sets: Int? = nil,
        durationSeconds: Int? = nil,
        distanceMeters: Double? = nil,
        into workoutStore: WorkoutStore
    ) -> GlobalExerciseProgress {
        var record = records[exerciseId] ?? GlobalExerciseProgress()
        record.workingWeightKg = weightKg
        record.targetReps = reps
        if let sets {
            record.targetSets = max(1, sets)
        }
        if let durationSeconds {
            record.targetDurationSeconds = durationSeconds
        }
        if let distanceMeters {
            record.targetDistanceMeters = distanceMeters
        }
        record.lastUpdated = .now
        records[exerciseId] = record
        save()
        apply(record, for: exerciseId, into: workoutStore)
        return record
    }

    @discardableResult
    func updateReps(
        for exerciseId: String,
        reps: Int,
        into workoutStore: WorkoutStore
    ) -> GlobalExerciseProgress {
        var record = records[exerciseId] ?? GlobalExerciseProgress(targetReps: reps)
        record.targetReps = reps
        record.lastUpdated = .now
        records[exerciseId] = record
        save()
        apply(record, for: exerciseId, into: workoutStore)
        return record
    }

    @discardableResult
    func updateWeight(
        for exerciseId: String,
        weightKg: Double,
        into workoutStore: WorkoutStore
    ) -> GlobalExerciseProgress {
        var record = records[exerciseId] ?? GlobalExerciseProgress(workingWeightKg: weightKg)
        record.workingWeightKg = weightKg
        record.lastUpdated = .now
        records[exerciseId] = record
        save()
        apply(record, for: exerciseId, into: workoutStore)
        return record
    }

    /// Updates the global progression record from actual set performance, then fans out to all plans.
    /// Historical session logs are never modified — only the current prescription moves forward.
    /// - Parameter updatePrescription: When false, only `lastActual` is updated (used after the user
    ///   already accepted/declined an in-exercise progression recommendation).
    @discardableResult
    func recordActualPerformance(
        exerciseId: String,
        workoutName: String,
        planned: WorkoutExerciseEntry,
        state: ExerciseSessionState,
        into workoutStore: WorkoutStore,
        historyStore: WeightHistoryStore? = nil,
        updatePrescription: Bool = true,
        displayUnit: WeightUnit = .kilograms
    ) -> GlobalExerciseProgress? {
        let completedFlags = state.completedSetFlags
        guard completedFlags.contains(true) else { return nil }

        let loggedSets: [LoggedSetPerformance] = completedFlags.indices.map { index in
            let performance = state.performance(at: index) ?? SetPerformance(from: planned)
            let entered = performance.weightKg > 0
                ? WeightFormatter.displayValue(kg: performance.weightKg, unit: displayUnit)
                : nil
            return LoggedSetPerformance(
                setIndex: index,
                completed: completedFlags[index],
                weightKg: performance.weightKg,
                reps: performance.reps,
                durationSeconds: performance.durationSeconds,
                distanceMeters: performance.distanceMeters,
                enteredWeight: entered,
                enteredWeightUnit: entered != nil ? displayUnit : nil
            )
        }

        let completed = loggedSets.filter(\.completed)
        guard !completed.isEmpty else { return nil }

        let exercise = ExerciseCatalog.exercise(id: exerciseId)
        let measurement = exercise?.measurementUnit ?? .weight

        let previousWeight = records[exerciseId]?.workingWeightKg ?? planned.startingWeight
        let next = Self.nextPrescription(from: completed, measurement: measurement, planned: planned)

        var record = records[exerciseId] ?? GlobalExerciseProgress(
            workingWeightKg: planned.startingWeight,
            targetReps: planned.reps,
            targetSets: planned.sets,
            targetDurationSeconds: planned.durationSeconds,
            targetDistanceMeters: planned.distanceMeters
        )

        record.lastPerformedAt = .now
        record.lastActual = ExerciseActualSnapshot(
            completedAt: .now,
            workoutName: workoutName,
            sets: loggedSets
        )
        record.lastUpdated = .now

        if updatePrescription {
            // Push-ups / reps-only: never store a display weight.
            if measurement == .reps || measurement == .bodyweight {
                record.workingWeightKg = 0
            } else {
                record.workingWeightKg = next.weightKg
            }
            record.targetReps = next.reps
            record.targetSets = next.sets
            record.targetDurationSeconds = next.durationSeconds
            record.targetDistanceMeters = next.distanceMeters
        }

        records[exerciseId] = record
        save()
        apply(record, for: exerciseId, into: workoutStore)

        if updatePrescription,
           let historyStore,
           Self.tracksWeight(measurement),
           next.weightKg > 0 {
            if previousWeight <= 0 {
                historyStore.recordInitial(exerciseId: exerciseId, weightKg: next.weightKg)
            } else if next.weightKg > previousWeight + 0.001 {
                historyStore.recordProgression(
                    exerciseId: exerciseId,
                    from: previousWeight,
                    to: next.weightKg
                )
            } else if historyStore.entries(for: exerciseId).isEmpty {
                historyStore.recordInitial(exerciseId: exerciseId, weightKg: next.weightKg)
            }
        }

        return record
    }

    /// Seed missing records from the newest workout data available.
    func seed(from workoutStore: WorkoutStore) {
        var candidates: [String: (weight: Double, reps: Int, sets: Int, duration: Int, distance: Double, updatedAt: Date)] = [:]

        for workout in workoutStore.workouts {
            for entry in workout.exercises {
                let existing = candidates[entry.exerciseId]
                if existing == nil || workout.updatedAt > existing!.updatedAt {
                    candidates[entry.exerciseId] = (
                        weight: entry.startingWeight,
                        reps: entry.reps,
                        sets: entry.sets,
                        duration: entry.durationSeconds,
                        distance: entry.distanceMeters,
                        updatedAt: workout.updatedAt
                    )
                }
            }
        }

        var didChange = false
        for (exerciseId, values) in candidates {
            if records[exerciseId] == nil {
                let measurement = ExerciseCatalog.exercise(id: exerciseId)?.measurementUnit
                let weight = (measurement == .reps || measurement == .bodyweight) ? 0 : values.weight
                records[exerciseId] = GlobalExerciseProgress(
                    workingWeightKg: weight,
                    targetReps: values.reps,
                    targetSets: values.sets,
                    targetDurationSeconds: values.duration,
                    targetDistanceMeters: values.distance,
                    lastUpdated: values.updatedAt
                )
                didChange = true
            }
        }

        if didChange {
            save()
            applyAll(to: workoutStore)
        }
    }

    /// Push every global record onto all matching workout entries.
    func applyAll(to workoutStore: WorkoutStore) {
        for (exerciseId, record) in records {
            apply(record, for: exerciseId, into: workoutStore)
        }
    }

    /// Align planned set counts for specific exercises (e.g. after changing a preset).
    func applyTargetSets(_ sets: Int, for exerciseIds: [String], into workoutStore: WorkoutStore) {
        let normalized = max(1, sets)
        var didChange = false
        for exerciseId in Set(exerciseIds) {
            if var record = records[exerciseId] {
                guard record.targetSets != normalized else { continue }
                record.targetSets = normalized
                record.lastUpdated = .now
                records[exerciseId] = record
                apply(record, for: exerciseId, into: workoutStore)
                didChange = true
            } else {
                let weight = workoutStore.knownStartingWeight(for: exerciseId) ?? 0
                let reps = workoutStore.knownReps(for: exerciseId) ?? 8
                _ = workoutStore.applyPrescription(
                    for: exerciseId,
                    weightKg: weight,
                    reps: reps,
                    sets: normalized,
                    durationSeconds: 0,
                    distanceMeters: 0
                )
            }
        }
        if didChange {
            save()
        }
    }

    /// Align planned set counts across all tracked exercises.
    func applyTargetSets(_ sets: Int, into workoutStore: WorkoutStore) {
        applyTargetSets(sets, for: Array(records.keys), into: workoutStore)
    }

    func clearAll() {
        records = [:]
        save()
    }

    // MARK: - Private

    private func apply(
        _ record: GlobalExerciseProgress,
        for exerciseId: String,
        into workoutStore: WorkoutStore
    ) {
        let measurement = ExerciseCatalog.exercise(id: exerciseId)?.measurementUnit
        let weight = (measurement == .reps || measurement == .bodyweight) ? 0 : record.workingWeightKg
        workoutStore.applyPrescription(
            for: exerciseId,
            weightKg: weight,
            reps: record.targetReps,
            sets: record.targetSets,
            durationSeconds: record.targetDurationSeconds,
            distanceMeters: record.targetDistanceMeters
        )
    }

    static func tracksWeight(_ measurement: MeasurementUnit) -> Bool {
        switch measurement {
        case .weight, .weightAndTime, .repsWithOptionalWeight:
            return true
        default:
            return false
        }
    }

    /// Derives a fallback next prescription from completed sets.
    /// Does not invent progression — keeps planned reps/sets/duration unless weight/time actually changed.
    /// Progression engine remains the only path that advances rep stages or weight increments.
    static func nextPrescription(
        from completed: [LoggedSetPerformance],
        measurement: MeasurementUnit,
        planned: WorkoutExerciseEntry
    ) -> (weightKg: Double, reps: Int, sets: Int, durationSeconds: Int, distanceMeters: Double) {
        let last = completed.last!

        switch measurement {
        case .weight, .repsWithOptionalWeight:
            return (
                weightKg: last.weightKg > 0 ? last.weightKg : planned.startingWeight,
                reps: max(1, planned.reps),
                sets: max(1, planned.sets),
                durationSeconds: planned.durationSeconds,
                distanceMeters: planned.distanceMeters
            )
        case .reps, .bodyweight:
            return (
                weightKg: 0,
                reps: max(1, planned.reps),
                sets: max(1, planned.sets),
                durationSeconds: 0,
                distanceMeters: 0
            )
        case .weightAndTime:
            return (
                weightKg: last.weightKg > 0 ? last.weightKg : planned.startingWeight,
                reps: planned.reps,
                sets: max(1, planned.sets),
                durationSeconds: max(
                    1,
                    last.durationSeconds > 0 ? last.durationSeconds : planned.durationSeconds
                ),
                distanceMeters: 0
            )
        case .time:
            return (
                weightKg: 0,
                reps: planned.reps,
                sets: max(1, planned.sets),
                durationSeconds: max(
                    1,
                    last.durationSeconds > 0 ? last.durationSeconds : planned.durationSeconds
                ),
                distanceMeters: 0
            )
        case .distance:
            return (
                weightKg: 0,
                reps: planned.reps,
                sets: max(1, planned.sets),
                durationSeconds: 0,
                distanceMeters: last.distanceMeters > 0 ? last.distanceMeters : planned.distanceMeters
            )
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: GlobalExerciseProgress].self, from: data) else {
            records = [:]
            return
        }
        records = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
