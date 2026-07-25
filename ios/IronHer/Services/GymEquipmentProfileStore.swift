import Foundation

/// Saved gym equipment profile (e.g. Bangkok Gym, Hotel, Home).
/// Structured so future versions can attach per-machine weight units and increments.
struct GymEquipmentProfile: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var availableEquipment: Set<GymEquipmentKind>
    /// Default display unit for this gym when not overridden per exercise.
    var defaultWeightUnit: WeightUnit
    /// Optional per-exercise unit overrides keyed by exercise id (future gym-specific units).
    var exerciseWeightUnitOverrides: [String: WeightUnit]
    /// Optional per-exercise increment overrides in kg, keyed by exercise id.
    var exerciseIncrementOverridesKg: [String: Double]
    var notes: String
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        availableEquipment: Set<GymEquipmentKind> = GymEquipmentPreset.fullGym.equipment,
        defaultWeightUnit: WeightUnit = .kilograms,
        exerciseWeightUnitOverrides: [String: WeightUnit] = [:],
        exerciseIncrementOverridesKg: [String: Double] = [:],
        notes: String = "",
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.availableEquipment = availableEquipment
        self.defaultWeightUnit = defaultWeightUnit
        self.exerciseWeightUnitOverrides = exerciseWeightUnitOverrides
        self.exerciseIncrementOverridesKg = exerciseIncrementOverridesKg
        self.notes = notes
        self.updatedAt = updatedAt
    }

    func resolvedWeightUnit(
        for exerciseId: String,
        appDefault: WeightUnit
    ) -> WeightUnit {
        exerciseWeightUnitOverrides[exerciseId] ?? defaultWeightUnit
    }
}

@Observable
final class GymEquipmentProfileStore {
    private let profilesKey = "gymEquipmentProfiles.v1"
    private let activeProfileKey = "gymEquipmentProfiles.activeId.v1"

    var profiles: [GymEquipmentProfile] = []
    var activeProfileId: UUID?

    var activeProfile: GymEquipmentProfile? {
        guard let activeProfileId else { return nil }
        return profiles.first { $0.id == activeProfileId }
    }

    init() {
        load()
        if profiles.isEmpty {
            seedDefaults()
        }
    }

    func selectProfile(_ id: UUID?) {
        activeProfileId = id
        save()
    }

    /// Applies this profile's per-exercise unit overrides into the progression store.
    /// Does not rewrite workout history — only future display/prescription context.
    @MainActor
    func applyUnitOverrides(to globalProgress: GlobalExerciseProgressStore) {
        guard let profile = activeProfile else { return }
        for (exerciseId, unit) in profile.exerciseWeightUnitOverrides {
            globalProgress.setWeightUnitPreference(.from(unit), for: exerciseId)
        }
    }

    func upsert(_ profile: GymEquipmentProfile) {
        var copy = profile
        copy.updatedAt = .now
        if let index = profiles.firstIndex(where: { $0.id == copy.id }) {
            profiles[index] = copy
        } else {
            profiles.append(copy)
        }
        profiles.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        if activeProfileId == nil {
            activeProfileId = copy.id
        }
        save()
    }

    func delete(id: UUID) {
        profiles.removeAll { $0.id == id }
        if activeProfileId == id {
            activeProfileId = profiles.first?.id
        }
        save()
    }

    /// Equipment available for generation/adaptation right now.
    func currentEquipment(
        fallback: Set<GymEquipmentKind> = GymEquipmentPreset.fullGym.equipment
    ) -> Set<GymEquipmentKind> {
        activeProfile?.availableEquipment ?? fallback
    }

    private func seedDefaults() {
        let home = GymEquipmentProfile(
            name: "Home",
            availableEquipment: GymEquipmentPreset.homeGym.equipment,
            defaultWeightUnit: .kilograms,
            notes: "Default home setup"
        )
        let hotel = GymEquipmentProfile(
            name: "Hotel Gym",
            availableEquipment: GymEquipmentPreset.hotelGym.equipment,
            defaultWeightUnit: .kilograms,
            notes: "Typical hotel / travel gym"
        )
        profiles = [home, hotel]
        activeProfileId = home.id
        save()
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: profilesKey),
           let decoded = try? JSONDecoder().decode([GymEquipmentProfile].self, from: data) {
            profiles = decoded
        }
        if let idString = UserDefaults.standard.string(forKey: activeProfileKey),
           let id = UUID(uuidString: idString) {
            activeProfileId = id
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: profilesKey)
        }
        if let activeProfileId {
            UserDefaults.standard.set(activeProfileId.uuidString, forKey: activeProfileKey)
        } else {
            UserDefaults.standard.removeObject(forKey: activeProfileKey)
        }
    }
}
