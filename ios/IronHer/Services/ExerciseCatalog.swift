import Foundation

enum ExerciseCatalog {
    static var customExercises: [Exercise] = []

    static var all: [Exercise] {
        ExerciseDatabase.all + customExercises
    }

    private static let idAliases: [String: String] = [
        "walking-lunges": "walking-lunge",
        "forward-lunge": "forward-lunge",
        "dips": "tricep-dip",
        "bench-press": "barbell-bench-press",
        "squat": "barbell-back-squat",
        "deadlift": "conventional-deadlift",
        "rdl": "romanian-deadlift",
        "one-arm-row": "one-arm-dumbbell-row",
        "dumbbell-row": "one-arm-dumbbell-row",
        "barbell-overhead-press": "overhead-press",
        "military-press": "overhead-press",
        "ohp": "overhead-press",
    ]

    static func exercises(in family: MovementFamily) -> [Exercise] {
        all.filter { $0.movementFamily == family }
    }

    static func compatibleAlternatives(
        for exercise: Exercise,
        availableEquipment: Set<GymEquipmentKind>,
        excluding: Set<String> = []
    ) -> [Exercise] {
        var results: [Exercise] = []
        var seen = excluding.union([exercise.id])

        for altId in exercise.suggestedAlternatives {
            guard let alt = self.exercise(id: altId),
                  !seen.contains(alt.id),
                  alt.isCompatible(with: availableEquipment) else { continue }
            results.append(alt)
            seen.insert(alt.id)
        }

        if exercise.movementFamily != .other {
            for alt in exercises(in: exercise.movementFamily) {
                guard !seen.contains(alt.id), alt.isCompatible(with: availableEquipment) else { continue }
                results.append(alt)
                seen.insert(alt.id)
            }
        }

        for alt in all where alt.primaryMuscleGroup == exercise.primaryMuscleGroup
            && alt.movementPattern == exercise.movementPattern
            && !seen.contains(alt.id)
            && alt.isCompatible(with: availableEquipment)
        {
            results.append(alt)
            seen.insert(alt.id)
        }

        return results
    }

    static func syncCustomExercises(_ exercises: [Exercise]) {
        customExercises = exercises
    }

    @MainActor
    static func defaultIncrement(for exerciseId: String, settings: UserSettingsStore) -> Double {
        settings.incrementKg(for: exerciseId)
    }

    static func builtInExercise(id: String) -> Exercise? {
        let resolvedId = idAliases[id.lowercased()] ?? idAliases[id] ?? id
        return ExerciseDatabase.all.first { $0.id == resolvedId }
    }

    static func exercise(id: String) -> Exercise? {
        let resolvedId = idAliases[id.lowercased()] ?? idAliases[id] ?? id
        if let custom = customExercises.first(where: { $0.id == resolvedId }) {
            return custom
        }
        return ExerciseDatabase.all.first { $0.id == resolvedId }
    }

    static func search(_ query: String, filters: ExerciseSearchFilters = ExerciseSearchFilters()) -> [Exercise] {
        ExerciseSearchService.search(query, in: all, filters: filters)
    }
}
