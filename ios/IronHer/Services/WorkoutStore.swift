import Foundation

enum WorkoutProgression {
    static let weightIncrementKg = 2.5
    static let defaultIncrementKg = 2.5
}

@Observable
@MainActor
final class WorkoutStore {
    private(set) var workouts: [Workout] = []

    private let storageKey = "savedWorkouts"

    init() {
        load()
    }

    @discardableResult
    func createWorkout(named name: String, exercises: [WorkoutExerciseEntry] = []) -> Workout {
        let workout = Workout(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            exercises: exercises
        )
        workouts.insert(workout, at: 0)
        save()
        return workout
    }

    func updateWorkout(id: UUID, name: String) {
        updateWorkout(id: id, name: name, exercises: workouts.first { $0.id == id }?.exercises ?? [])
    }

    func updateWorkout(id: UUID, name: String, exercises: [WorkoutExerciseEntry]) {
        guard let index = workouts.firstIndex(where: { $0.id == id }) else { return }
        workouts[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        workouts[index].exercises = exercises
        workouts[index].updatedAt = .now
        save()
    }

    func deleteWorkout(id: UUID) {
        workouts.removeAll { $0.id == id }
        save()
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
        if didChange { save() }
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

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([Workout].self, from: data)
        else {
            workouts = []
            return
        }
        workouts = decoded.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(workouts) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
