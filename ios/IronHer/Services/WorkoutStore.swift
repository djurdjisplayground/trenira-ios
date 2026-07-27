import Foundation

enum WorkoutProgression {
    static let weightIncrementKg = 2.5
    static let defaultIncrementKg = 2.5
}

@Observable
@MainActor
final class WorkoutStore {
    /// Active (non-deleted) workouts for the UI — includes drafts.
    private(set) var workouts: [Workout] = []
    /// Soft-deleted workouts retained for Recently Deleted (30 days) + sync.
    private(set) var deletedWorkouts: [Workout] = []

    var ownershipProvider: (() -> String)?
    var onMutation: (() -> Void)?
    var onCreate: (() -> Void)?
    var onDelete: ((UUID) -> Void)?

    private let storageKey = "savedWorkouts"
    private let deletedStorageKey = "savedWorkoutsDeleted"
    static let recentlyDeletedRetentionDays = 30

    /// Saved plans only — used for Premium free-tier limits.
    var savedWorkoutCount: Int {
        workouts.filter { !$0.isDraft }.count
    }

    var draftWorkouts: [Workout] {
        workouts.filter(\.isDraft).sorted { $0.updatedAt > $1.updatedAt }
    }

    var recentlyDeleted: [Workout] {
        deletedWorkouts.sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
    }

    init() {
        load()
        purgeExpiredDeletedIfNeeded()
    }

    @discardableResult
    func createWorkout(named name: String, exercises: [WorkoutExerciseEntry] = []) -> Workout {
        let workout = Workout(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            exercises: exercises,
            ownerId: ownershipProvider?() ?? "",
            isDraft: false
        )
        workouts.insert(workout, at: 0)
        save()
        onCreate?()
        onMutation?()
        return workout
    }

    /// Creates or updates a draft. Never overwrites a non-draft workout.
    @discardableResult
    func upsertDraft(
        id: UUID? = nil,
        name: String,
        exercises: [WorkoutExerciseEntry]
    ) -> Workout {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmed.isEmpty ? "Untitled draft" : trimmed

        if let id, let index = workouts.firstIndex(where: { $0.id == id }) {
            guard workouts[index].isDraft else {
                // Refuse to clobber a saved workout — create a new draft instead.
                return upsertDraft(id: nil, name: name, exercises: exercises)
            }
            workouts[index].name = resolvedName
            workouts[index].exercises = exercises
            workouts[index].updatedAt = .now
            save()
            onMutation?()
            return workouts[index]
        }

        let draft = Workout(
            id: id ?? UUID(),
            name: resolvedName,
            exercises: exercises,
            ownerId: ownershipProvider?() ?? "",
            isDraft: true
        )
        workouts.insert(draft, at: 0)
        save()
        onMutation?()
        return draft
    }

    /// Promotes a draft to a saved workout (or creates one). Counts toward free limit.
    @discardableResult
    func publishDraft(id: UUID, name: String, exercises: [WorkoutExerciseEntry]) -> Workout? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let index = workouts.firstIndex(where: { $0.id == id && $0.isDraft }) {
            workouts[index].name = trimmed
            workouts[index].exercises = exercises
            workouts[index].isDraft = false
            workouts[index].updatedAt = .now
            save()
            onCreate?()
            onMutation?()
            return workouts[index]
        }

        return createWorkout(named: trimmed, exercises: exercises)
    }

    func deleteDraft(id: UUID) {
        #if DEBUG
        print("[WorkoutDelete] deleteDraft id=\(id)")
        #endif
        guard let index = workouts.firstIndex(where: { $0.id == id && $0.isDraft }) else {
            #if DEBUG
            print("[WorkoutDelete] deleteDraft FAILED — draft not found id=\(id)")
            #endif
            return
        }
        workouts.remove(at: index)
        save()
        #if DEBUG
        print("[WorkoutDelete] draft permanently removed id=\(id) activeCount=\(workouts.count)")
        #endif
        onMutation?()
    }

    /// Creates a deep copy of a saved workout plan (new workout + entry IDs).
    /// Does not copy session history, Track This Week, or deleted/draft flags.
    /// Progression settings keyed by catalog `exerciseId` already apply to both plans.
    @discardableResult
    func duplicateWorkout(id: UUID) throws -> Workout {
        guard let source = workouts.first(where: { $0.id == id && !$0.isDraft }) else {
            #if DEBUG
            print("[WorkoutDuplicate] FAILED — source not found id=\(id)")
            #endif
            throw DuplicateWorkoutError.sourceNotFound
        }

        let existingNames = workouts.map(\.name) + deletedWorkouts.map(\.name)
        let copiedExercises = source.exercises
            .sorted { $0.order < $1.order }
            .enumerated()
            .map { index, entry in
                WorkoutExerciseEntry(
                    id: UUID(),
                    exerciseId: entry.exerciseId,
                    sets: entry.sets,
                    reps: entry.reps,
                    startingWeight: entry.startingWeight,
                    durationSeconds: entry.durationSeconds,
                    distanceMeters: entry.distanceMeters,
                    order: index,
                    restDurationOverride: entry.restDurationOverride
                )
            }

        let copy = Workout(
            id: UUID(),
            name: Self.uniqueCopyName(from: source.name, existingNames: existingNames),
            exercises: copiedExercises,
            createdAt: .now,
            updatedAt: .now,
            ownerId: ownershipProvider?() ?? source.ownerId,
            deletedAt: nil,
            isDraft: false
        )

        workouts.insert(copy, at: 0)
        do {
            try saveThrowing()
        } catch {
            // Roll back in-memory insert so the original list stays consistent.
            workouts.removeAll { $0.id == copy.id }
            #if DEBUG
            print("[WorkoutDuplicate] persistence error: \(error)")
            #endif
            throw DuplicateWorkoutError.persistenceFailed(error)
        }

        #if DEBUG
        print("[WorkoutDuplicate] ok source=\(source.id) copy=\(copy.id) name=\(copy.name) entries=\(copiedExercises.count)")
        #endif
        onCreate?()
        onMutation?()
        return copy
    }

    /// "Upper Body Copy", then "Upper Body Copy 2", "Upper Body Copy 3", …
    static func uniqueCopyName(from name: String, existingNames: [String]) -> String {
        let root = copyNameRoot(from: name)
        let normalizedExisting = Set(existingNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })

        let first = "\(root) Copy"
        if !normalizedExisting.contains(first.lowercased()) {
            return first
        }
        var n = 2
        while n < 10_000 {
            let candidate = "\(root) Copy \(n)"
            if !normalizedExisting.contains(candidate.lowercased()) {
                return candidate
            }
            n += 1
        }
        return "\(root) Copy \(UUID().uuidString.prefix(4))"
    }

    /// Strips trailing " Copy" / " Copy N" / " (Copy)" so renames stay clean.
    static func copyNameRoot(from name: String) -> String {
        var trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Workout" }

        if trimmed.hasSuffix(" (Copy)") {
            trimmed = String(trimmed.dropLast(" (Copy)".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // "Name Copy 12" → "Name"
        if let match = trimmed.range(of: #"\s+Copy(\s+\d+)?$"#, options: .regularExpression) {
            trimmed = String(trimmed[..<match.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return trimmed.isEmpty ? "Workout" : trimmed
    }

    @available(*, deprecated, message: "Use uniqueCopyName(from:existingNames:)")
    static func copyName(from name: String) -> String {
        uniqueCopyName(from: name, existingNames: [])
    }

    func updateWorkout(id: UUID, name: String) {
        updateWorkout(id: id, name: name, exercises: workouts.first { $0.id == id }?.exercises ?? [])
    }

    func updateWorkout(id: UUID, name: String, exercises: [WorkoutExerciseEntry]) {
        guard let index = workouts.firstIndex(where: { $0.id == id }) else { return }
        workouts[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        workouts[index].exercises = exercises
        workouts[index].updatedAt = .now
        if workouts[index].ownerId.isEmpty {
            workouts[index].ownerId = ownershipProvider?() ?? ""
        }
        save()
        onMutation?()
    }

    /// Applies exercise list updates to many workouts, then persists once.
    /// Skips unknown ids / drafts. Preserves workout ids, names, and list order.
    @discardableResult
    func applyExerciseListUpdates(_ updates: [UUID: [WorkoutExerciseEntry]]) -> Int {
        guard !updates.isEmpty else { return 0 }
        var changed = 0
        for (id, exercises) in updates {
            guard let index = workouts.firstIndex(where: { $0.id == id && !$0.isDraft }) else { continue }
            workouts[index].exercises = exercises
            workouts[index].updatedAt = .now
            if workouts[index].ownerId.isEmpty {
                workouts[index].ownerId = ownershipProvider?() ?? ""
            }
            changed += 1
        }
        guard changed > 0 else { return 0 }
        save()
        onMutation?()
        return changed
    }

    /// Saved (non-draft) plans that contain at least one entry with `exerciseId`.
    func savedWorkoutsContaining(exerciseId: String) -> [Workout] {
        workouts.filter { workout in
            !workout.isDraft && workout.exercises.contains { $0.exerciseId == exerciseId }
        }
    }

    func deleteWorkout(id: UUID) {
        #if DEBUG
        print("[WorkoutDelete] deleteWorkout triggered id=\(id)")
        #endif
        guard let index = workouts.firstIndex(where: { $0.id == id }) else {
            #if DEBUG
            print("[WorkoutDelete] deleteWorkout FAILED — workout not found id=\(id)")
            #endif
            return
        }
        var removed = workouts.remove(at: index)
        // Drafts are discarded immediately — they were never saved plans.
        if removed.isDraft {
            save()
            #if DEBUG
            print("[WorkoutDelete] draft path via deleteWorkout id=\(id) save ok")
            #endif
            onMutation?()
            return
        }
        removed.deletedAt = .now
        removed.updatedAt = .now
        deletedWorkouts.removeAll { $0.id == id }
        deletedWorkouts.append(removed)
        save()
        #if DEBUG
        print("[WorkoutDelete] marked soft-deleted id=\(id) deletedAt=\(String(describing: removed.deletedAt)) recentlyDeleted=\(deletedWorkouts.count) active=\(workouts.count)")
        #endif
        onDelete?(id)
        onMutation?()
    }

    func restoreWorkout(id: UUID) {
        guard let index = deletedWorkouts.firstIndex(where: { $0.id == id }) else { return }
        var restored = deletedWorkouts.remove(at: index)
        restored.deletedAt = nil
        restored.updatedAt = .now
        restored.isDraft = false
        workouts.insert(restored, at: 0)
        save()
        onMutation?()
    }

    func permanentlyDeleteWorkout(id: UUID) {
        deletedWorkouts.removeAll { $0.id == id }
        save()
        onMutation?()
    }

    @discardableResult
    func purgeExpiredDeletedIfNeeded(now: Date = .now) -> Int {
        let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -Self.recentlyDeletedRetentionDays,
            to: now
        ) ?? now
        let before = deletedWorkouts.count
        deletedWorkouts.removeAll { workout in
            guard let deletedAt = workout.deletedAt else { return false }
            return deletedAt < cutoff
        }
        let removed = before - deletedWorkouts.count
        if removed > 0 {
            save()
        }
        return removed
    }

    func exerciseCount(for workoutId: UUID) -> Int {
        workouts.first { $0.id == workoutId }?.exercises.count ?? 0
    }

    func workout(id: UUID) -> Workout? {
        workouts.first { $0.id == id }
    }

    func sortedExercises(for workoutId: UUID) -> [WorkoutExerciseEntry] {
        workout(id: workoutId)?.exercises.sorted { $0.order < $1.order } ?? []
    }

    /// Returns the saved starting weight if this exercise already exists in any workout.
    /// Prefers the most recently updated workout when values differ.
    func knownStartingWeight(for exerciseId: String) -> Double? {
        var best: (weight: Double, updatedAt: Date)?
        for workout in workouts {
            guard let entry = workout.exercises.first(where: { $0.exerciseId == exerciseId }) else { continue }
            if best == nil || workout.updatedAt > best!.updatedAt {
                best = (entry.startingWeight, workout.updatedAt)
            }
        }
        return best?.weight
    }

    func knownReps(for exerciseId: String) -> Int? {
        var best: (reps: Int, updatedAt: Date)?
        for workout in workouts {
            guard let entry = workout.exercises.first(where: { $0.exerciseId == exerciseId }) else { continue }
            if best == nil || workout.updatedAt > best!.updatedAt {
                best = (entry.reps, workout.updatedAt)
            }
        }
        return best?.reps
    }

    func hasKnownStartingWeight(for exerciseId: String) -> Bool {
        knownStartingWeight(for: exerciseId) != nil
    }

    @discardableResult
    func updateReps(for exerciseId: String, reps: Int) -> Bool {
        applyToAllEntries(exerciseId: exerciseId) { entry in
            entry.reps = reps
        }
    }

    @discardableResult
    func updateWeightAndReps(for exerciseId: String, weightKg: Double, reps: Int) -> Bool {
        applyToAllEntries(exerciseId: exerciseId) { entry in
            entry.startingWeight = weightKg
            entry.reps = reps
        }
    }

    /// Fans out the global prescription onto every plan that contains this exercise.
    @discardableResult
    func applyPrescription(
        for exerciseId: String,
        weightKg: Double,
        reps: Int,
        sets: Int,
        durationSeconds: Int,
        distanceMeters: Double
    ) -> Bool {
        applyToAllEntries(exerciseId: exerciseId) { entry in
            entry.startingWeight = weightKg
            entry.reps = reps
            entry.sets = max(1, sets)
            entry.durationSeconds = durationSeconds
            entry.distanceMeters = distanceMeters
        }
    }

    @discardableResult
    func applyWeight(for exerciseId: String, weightKg: Double) -> Bool {
        applyToAllEntries(exerciseId: exerciseId) { entry in
            entry.startingWeight = weightKg
        }
    }

    @discardableResult
    func applyToAllEntries(
        exerciseId: String,
        update: (inout WorkoutExerciseEntry) -> Void
    ) -> Bool {
        var didChange = false
        for workoutIndex in workouts.indices {
            var workoutChanged = false
            for exerciseIndex in workouts[workoutIndex].exercises.indices {
                if workouts[workoutIndex].exercises[exerciseIndex].exerciseId == exerciseId {
                    update(&workouts[workoutIndex].exercises[exerciseIndex])
                    workoutChanged = true
                }
            }
            if workoutChanged {
                workouts[workoutIndex].updatedAt = .now
                didChange = true
            }
        }
        if didChange {
            save()
            onMutation?()
        }
        return didChange
    }

    @discardableResult
    func increaseStartingWeight(
        for exerciseId: String,
        settings: UserSettingsStore,
        by amount: Double? = nil
    ) -> (from: Double, to: Double)? {
        guard let exercise = ExerciseCatalog.exercise(id: exerciseId),
              exercise.supportsProgressiveOverload else { return nil }

        let increment = amount ?? settings.incrementKg(for: exercise)
        guard increment > 0 else { return nil }
        guard let previous = knownStartingWeight(for: exerciseId) else { return nil }
        let newWeight = previous + increment

        guard applyWeight(for: exerciseId, weightKg: newWeight) else {
            return nil
        }
        return (previous, newWeight)
    }

    // MARK: - Sync / ownership

    func allRecordsForSync() -> [Workout] {
        workouts + deletedWorkouts
    }

    func replaceAllForSync(_ records: [Workout]) {
        workouts = records.filter { $0.deletedAt == nil }.sorted { $0.updatedAt > $1.updatedAt }
        deletedWorkouts = records.filter { $0.deletedAt != nil }
        save()
    }

    func stampMissingOwnership(_ ownerId: String) {
        var changed = false
        for index in workouts.indices where workouts[index].ownerId.isEmpty {
            workouts[index].ownerId = ownerId
            changed = true
        }
        for index in deletedWorkouts.indices where deletedWorkouts[index].ownerId.isEmpty {
            deletedWorkouts[index].ownerId = ownerId
            changed = true
        }
        if changed { save() }
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([Workout].self, from: data)
        else {
            workouts = []
            deletedWorkouts = loadDeleted()
            return
        }
        let active = decoded.filter { $0.deletedAt == nil }
        let softDeleted = decoded.filter { $0.deletedAt != nil }
        workouts = active.sorted { $0.updatedAt > $1.updatedAt }
        deletedWorkouts = softDeleted + loadDeleted().filter { pending in
            !softDeleted.contains(where: { $0.id == pending.id })
        }
    }

    private func loadDeleted() -> [Workout] {
        guard let data = UserDefaults.standard.data(forKey: deletedStorageKey),
              let decoded = try? JSONDecoder().decode([Workout].self, from: data) else {
            return []
        }
        return decoded
    }

    private func save() {
        do {
            try saveThrowing()
        } catch {
            #if DEBUG
            print("[WorkoutStore] ERROR saving: \(error)")
            #endif
        }
    }

    private func saveThrowing() throws {
        let combined = workouts + deletedWorkouts
        let data = try JSONEncoder().encode(combined)
        UserDefaults.standard.set(data, forKey: storageKey)
        let deletedData = try JSONEncoder().encode(deletedWorkouts)
        UserDefaults.standard.set(deletedData, forKey: deletedStorageKey)
        #if DEBUG
        print("[WorkoutStore] save ok active=\(workouts.count) deleted=\(deletedWorkouts.count) bytes=\(data.count)")
        #endif
    }
}

enum DuplicateWorkoutError: LocalizedError {
    case sourceNotFound
    case persistenceFailed(Error)

    var errorDescription: String? {
        switch self {
        case .sourceNotFound:
            return "The workout could not be duplicated. Please try again."
        case .persistenceFailed:
            return "The workout could not be duplicated. Please try again."
        }
    }
}
