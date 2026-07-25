import Foundation

@Observable
@MainActor
final class CustomExerciseStore {
    private(set) var exercises: [Exercise] = []

    var ownershipProvider: (() -> String)?
    var onMutation: (() -> Void)?

    private let storageKey = "customExercises"

    init() {
        load()
    }

    var count: Int { exercises.count }

    func exercise(id: String) -> Exercise? {
        exercises.first { $0.id == id }
    }

    @discardableResult
    func add(
        name: String,
        primaryMuscleGroup: MuscleGroup,
        equipment: EquipmentType,
        measurementUnit: MeasurementUnit? = nil,
        trackingProfile: ExerciseTrackingProfile? = nil,
        progressionMethod: ProgressionMethod? = nil,
        category: ExerciseCategory = .isolation,
        movementPattern: MovementPattern = .isolation
    ) -> Exercise {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = uniqueId(for: trimmed)
        let profile = trackingProfile
            ?? ExerciseTrackingProfile.migrated(
                from: measurementUnit ?? EquipmentDefaults.defaultMeasurementUnit(for: equipment)
            )
        let exercise = Exercise(
            id: id,
            name: trimmed,
            primaryMuscleGroup: primaryMuscleGroup,
            equipment: equipment,
            category: category,
            movementPattern: movementPattern,
            measurementUnit: measurementUnit ?? profile.legacyMeasurementUnit,
            trackingProfile: profile,
            progressionMethod: progressionMethod,
            isCustom: true,
            ownerId: ownershipProvider?() ?? ""
        )
        exercises.insert(exercise, at: 0)
        save()
        onMutation?()
        return exercise
    }

    func delete(id: String) {
        exercises.removeAll { $0.id == id }
        save()
        onMutation?()
    }

    func replaceAllForSync(_ records: [Exercise]) {
        exercises = records
        save()
    }

    func stampMissingOwnership(_ ownerId: String) {
        var changed = false
        for index in exercises.indices where exercises[index].ownerId.isEmpty {
            exercises[index].ownerId = ownerId
            changed = true
        }
        if changed { save() }
    }

    private func uniqueId(for name: String) -> String {
        let base = "custom-" + name
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        var candidate = base.isEmpty ? "custom-exercise" : base
        var suffix = 1
        let existing = Set(exercises.map(\.id))
        while existing.contains(candidate) || ExerciseCatalog.builtInExercise(id: candidate) != nil {
            suffix += 1
            candidate = "\(base)-\(suffix)"
        }
        return candidate
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Exercise].self, from: data) else {
            exercises = []
            return
        }
        exercises = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(exercises) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
