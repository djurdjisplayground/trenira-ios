import Foundation

struct Exercise: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let aliases: [String]
    let primaryMuscleGroup: MuscleGroup
    let secondaryMuscleGroups: [MuscleGroup]
    let equipment: EquipmentType
    let category: ExerciseCategory
    let movementPattern: MovementPattern
    let laterality: Laterality
    /// Legacy single-unit field. Prefer `trackingProfile` for new logic.
    let measurementUnit: MeasurementUnit
    /// What is recorded, what progresses, and default increments.
    let trackingProfile: ExerciseTrackingProfile
    let progressionMethod: ProgressionMethod
    let supportsProgressiveOverload: Bool
    let isCustom: Bool
    let imageAssetName: String?
    let animationAssetName: String?
    /// Links equipment variations for search/substitution (not progression).
    let movementFamily: MovementFamily
    /// Fine-grained equipment required to perform this variation.
    let requiredEquipment: [GymEquipmentKind]
    /// Related exercise IDs preferred as substitutions.
    let suggestedAlternatives: [String]
    let weightInterpretation: WeightInterpretation
    /// `guest:…` / `account:…` for custom exercises. Built-ins leave this empty.
    var ownerId: String

    init(
        id: String,
        name: String,
        aliases: [String] = [],
        primaryMuscleGroup: MuscleGroup,
        secondaryMuscleGroups: [MuscleGroup] = [],
        equipment: EquipmentType,
        category: ExerciseCategory,
        movementPattern: MovementPattern,
        laterality: Laterality = .bilateral,
        measurementUnit: MeasurementUnit? = nil,
        trackingProfile: ExerciseTrackingProfile? = nil,
        progressionMethod: ProgressionMethod? = nil,
        supportsProgressiveOverload: Bool? = nil,
        isCustom: Bool = false,
        imageAssetName: String? = nil,
        animationAssetName: String? = nil,
        movementFamily: MovementFamily = .other,
        requiredEquipment: [GymEquipmentKind] = [],
        suggestedAlternatives: [String] = [],
        weightInterpretation: WeightInterpretation? = nil,
        ownerId: String = ""
    ) {
        let resolvedMeasurement = measurementUnit
            ?? trackingProfile?.legacyMeasurementUnit
            ?? EquipmentDefaults.defaultMeasurementUnit(for: equipment)
        let resolvedProfile = trackingProfile ?? ExerciseTrackingProfile.migrated(from: resolvedMeasurement)
        self.id = id
        self.name = name
        self.aliases = aliases
        self.primaryMuscleGroup = primaryMuscleGroup
        self.secondaryMuscleGroups = secondaryMuscleGroups
        self.equipment = equipment
        self.category = category
        self.movementPattern = movementPattern
        self.laterality = laterality
        self.measurementUnit = resolvedMeasurement
        self.trackingProfile = resolvedProfile
        self.progressionMethod = progressionMethod
            ?? EquipmentDefaults.defaultProgressionMethod(for: resolvedMeasurement)
        self.supportsProgressiveOverload = supportsProgressiveOverload
            ?? EquipmentDefaults.defaultSupportsProgressiveOverload(
                equipment: equipment,
                measurement: resolvedMeasurement
            )
        self.isCustom = isCustom
        self.imageAssetName = imageAssetName
        self.animationAssetName = animationAssetName
        self.movementFamily = movementFamily
        self.requiredEquipment = requiredEquipment.isEmpty
            ? equipment.defaultRequiredEquipment
            : requiredEquipment
        self.suggestedAlternatives = suggestedAlternatives
        self.weightInterpretation = weightInterpretation
            ?? Self.defaultWeightInterpretation(
                equipment: equipment,
                laterality: laterality,
                measurement: resolvedMeasurement,
                id: id
            )
        self.ownerId = ownerId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        aliases = try container.decodeIfPresent([String].self, forKey: .aliases) ?? []
        primaryMuscleGroup = try container.decode(MuscleGroup.self, forKey: .primaryMuscleGroup)
        secondaryMuscleGroups = try container.decodeIfPresent([MuscleGroup].self, forKey: .secondaryMuscleGroups) ?? []
        equipment = try container.decode(EquipmentType.self, forKey: .equipment)
        category = try container.decode(ExerciseCategory.self, forKey: .category)
        movementPattern = try container.decode(MovementPattern.self, forKey: .movementPattern)
        laterality = try container.decodeIfPresent(Laterality.self, forKey: .laterality) ?? .bilateral
        measurementUnit = try container.decode(MeasurementUnit.self, forKey: .measurementUnit)
        // Prefer stored multi-metric profile; otherwise migrate from legacy unit without wiping user data.
        trackingProfile = try container.decodeIfPresent(ExerciseTrackingProfile.self, forKey: .trackingProfile)
            ?? ExerciseTrackingProfile.migrated(from: measurementUnit)
        progressionMethod = try container.decodeIfPresent(ProgressionMethod.self, forKey: .progressionMethod)
            ?? EquipmentDefaults.defaultProgressionMethod(for: measurementUnit)
        supportsProgressiveOverload = try container.decode(Bool.self, forKey: .supportsProgressiveOverload)
        isCustom = try container.decodeIfPresent(Bool.self, forKey: .isCustom) ?? false
        imageAssetName = try container.decodeIfPresent(String.self, forKey: .imageAssetName)
        animationAssetName = try container.decodeIfPresent(String.self, forKey: .animationAssetName)
        movementFamily = try container.decodeIfPresent(MovementFamily.self, forKey: .movementFamily) ?? .other
        let decodedRequired = try container.decodeIfPresent([GymEquipmentKind].self, forKey: .requiredEquipment) ?? []
        requiredEquipment = decodedRequired.isEmpty ? equipment.defaultRequiredEquipment : decodedRequired
        suggestedAlternatives = try container.decodeIfPresent([String].self, forKey: .suggestedAlternatives) ?? []
        weightInterpretation = try container.decodeIfPresent(WeightInterpretation.self, forKey: .weightInterpretation)
            ?? Self.defaultWeightInterpretation(
                equipment: equipment,
                laterality: laterality,
                measurement: measurementUnit,
                id: id
            )
        ownerId = try container.decodeIfPresent(String.self, forKey: .ownerId) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, aliases, primaryMuscleGroup, secondaryMuscleGroups, equipment
        case category, movementPattern, laterality, measurementUnit, trackingProfile, progressionMethod
        case supportsProgressiveOverload, isCustom, imageAssetName, animationAssetName
        case movementFamily, requiredEquipment, suggestedAlternatives, weightInterpretation, ownerId
    }

    static func defaultWeightInterpretation(
        equipment: EquipmentType,
        laterality: Laterality,
        measurement: MeasurementUnit,
        id: String
    ) -> WeightInterpretation {
        switch measurement {
        case .bodyweight, .reps, .time, .distance:
            return measurement == .reps || measurement == .bodyweight ? .bodyweight : .none
        case .weight, .weightAndTime, .repsWithOptionalWeight:
            break
        }
        if equipment == .machine { return .machineSetting }
        if id == "farmer-carry" || id == "suitcase-carry" { return .perHand }
        if laterality == .unilateral, equipment == .dumbbell { return .perArm }
        if equipment == .dumbbell {
            let totalWeightExceptions: Set<String> = [
                "goblet-squat", "svend-press", "concentration-curl", "weighted-sit-up",
            ]
            return totalWeightExceptions.contains(id) ? .totalLoad : .perHand
        }
        return .totalLoad
    }

    /// True when every required equipment kind is present in `available`.
    func isCompatible(with available: Set<GymEquipmentKind>) -> Bool {
        // Cable station covers high/low pulley needs when those aren't listed separately.
        var effective = available
        if available.contains(.cableStation) {
            effective.formUnion([.highPulley, .lowPulley, .dualAdjustablePulley, .cableAttachments])
        }
        if available.contains(.dualAdjustablePulley) {
            effective.formUnion([.cableStation, .highPulley, .lowPulley, .cableAttachments])
        }
        if available.contains(.adjustableBench) {
            effective.insert(.flatBench)
        }

        let required = Set(requiredEquipment)
        if required.isEmpty {
            switch equipment {
            case .bodyweight:
                return effective.contains(.bodyweight) || !effective.isEmpty
            case .dumbbell:
                return effective.contains(.dumbbells)
            case .barbell:
                return effective.contains(.barbell)
                    || effective.contains(.smithMachine)
                    || effective.contains(.ezCurlBar)
            case .cable:
                return effective.contains(.cableStation)
                    || effective.contains(.dualAdjustablePulley)
                    || effective.contains(.highPulley)
                    || effective.contains(.lowPulley)
            case .kettlebell:
                return effective.contains(.kettlebells)
            case .machine:
                return effective.contains(where: { $0.category == .machines })
            }
        }
        if required == [.bodyweight] {
            return effective.contains(.bodyweight) || !effective.isEmpty
        }
        return required.isSubset(of: effective)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(aliases, forKey: .aliases)
        try container.encode(primaryMuscleGroup, forKey: .primaryMuscleGroup)
        try container.encode(secondaryMuscleGroups, forKey: .secondaryMuscleGroups)
        try container.encode(equipment, forKey: .equipment)
        try container.encode(category, forKey: .category)
        try container.encode(movementPattern, forKey: .movementPattern)
        try container.encode(laterality, forKey: .laterality)
        try container.encode(measurementUnit, forKey: .measurementUnit)
        try container.encode(trackingProfile, forKey: .trackingProfile)
        try container.encode(progressionMethod, forKey: .progressionMethod)
        try container.encode(supportsProgressiveOverload, forKey: .supportsProgressiveOverload)
        try container.encode(isCustom, forKey: .isCustom)
        try container.encodeIfPresent(imageAssetName, forKey: .imageAssetName)
        try container.encodeIfPresent(animationAssetName, forKey: .animationAssetName)
        try container.encode(movementFamily, forKey: .movementFamily)
        try container.encode(requiredEquipment, forKey: .requiredEquipment)
        try container.encode(suggestedAlternatives, forKey: .suggestedAlternatives)
        try container.encode(weightInterpretation, forKey: .weightInterpretation)
        try container.encode(ownerId, forKey: .ownerId)
    }

    var listSubtitle: String {
        [primaryMuscleGroup.label, equipment.label, trackingProfile.compactSummary]
            .joined(separator: " · ")
    }

    var metadataSummary: String {
        var parts = [movementPattern.label, laterality.label, trackingProfile.compactSummary]
        if !secondaryMuscleGroups.isEmpty {
            parts.insert(secondaryMuscleGroups.map(\.label).joined(separator: ", "), at: 1)
        }
        return parts.joined(separator: " · ")
    }

    var hasVisualAsset: Bool {
        ExerciseVisuals.resolvedImageAsset(for: self) != nil
            || ExerciseVisuals.resolvedAnimationAsset(for: self) != nil
    }

    var muscleGroup: String { primaryMuscleGroup.label }
    var secondaryMuscleGroup: MuscleGroup? { secondaryMuscleGroups.first }

    var searchableTerms: [String] {
        var terms = [name, id.replacingOccurrences(of: "-", with: " ")]
        terms.append(contentsOf: aliases)
        if let localized = ExerciseLocalizations.englishNames[id] {
            terms.append(localized)
        }
        terms.append(primaryMuscleGroup.label)
        terms.append(contentsOf: primaryMuscleGroup.searchSynonyms)
        terms.append(contentsOf: secondaryMuscleGroups.map(\.label))
        terms.append(contentsOf: secondaryMuscleGroups.flatMap(\.searchSynonyms))
        terms.append(equipment.label)
        terms.append(movementFamily.label)
        terms.append(contentsOf: requiredEquipment.map(\.label))
        return terms
    }

    /// Display name for the current UI language. Custom exercises keep the user-entered name.
    @MainActor
    func localizedName(using l10n: LocalizationStore) -> String {
        if isCustom { return name }
        return ExerciseLocalizations.name(for: id, language: l10n.language, englishFallback: name)
    }

    var tracksOptionalWeight: Bool {
        trackingProfile.supports(.weight)
            && trackingProfile.supports(.reps)
            && trackingProfile.primaryProgressionMetric == .reps
    }

    var tracksWeightAndDuration: Bool {
        trackingProfile.supports(.weight) && trackingProfile.supports(.time)
    }

    /// Weight is logged per dumbbell / per hand (not combined total).
    var displaysWeightPerHand: Bool {
        weightInterpretation == .perHand || weightInterpretation == .perArm
    }

    var weightFieldLabel: String {
        switch weightInterpretation {
        case .perHand:
            return id == "farmer-carry" || id == "suitcase-carry" ? "Weight per hand" : "Weight (per dumbbell)"
        case .perArm:
            return "Weight (per arm)"
        case .machineSetting:
            return "Machine weight"
        case .totalLoad:
            return "Weight"
        case .bodyweight, .none:
            return "Weight"
        }
    }

    var weightFieldCaption: String? {
        weightInterpretation.shortCaption
    }

    /// Session / plan label for repetition targets.
    var repsFieldLabel: String {
        switch laterality {
        case .unilateral:
            return "Reps per side"
        case .alternating:
            return "Reps per side"
        case .bilateral:
            return "Reps"
        }
    }

    /// Short label for compact set steppers.
    var repsStepperLabel: String {
        switch laterality {
        case .unilateral, .alternating:
            return "reps/side"
        case .bilateral:
            return "reps"
        }
    }

    var showsDurationDuringSession: Bool {
        trackingProfile.supports(.time)
    }

    var showsDistanceDuringSession: Bool {
        trackingProfile.supports(.distance)
    }

    var showsSetsDuringSession: Bool {
        trackingProfile.supports(.sets)
    }

    /// Bodyweight-style +2 rep progression when no external load is used.
    func usesRepProgression(currentWeightKg: Double) -> Bool {
        guard supportsProgressiveOverload else { return false }
        if tracksOptionalWeight {
            return currentWeightKg <= 0
        }
        return trackingProfile.supports(.reps)
            && !trackingProfile.supports(.weight)
            && trackingProfile.primaryProgressionMetric == .reps
    }

    /// Whether the active workout UI should show a weight field for this exercise.
    var showsWeightDuringSession: Bool {
        trackingProfile.supports(.weight)
    }

    /// Whether the active workout UI should show a reps field for this exercise.
    var showsRepsDuringSession: Bool {
        trackingProfile.supports(.reps)
    }

    /// Weight ladder progression for loaded lifts (including optional-weight with a load entered).
    func usesWeightProgression(currentWeightKg: Double) -> Bool {
        guard supportsProgressiveOverload else { return false }
        if tracksOptionalWeight {
            return currentWeightKg > 0
        }
        return trackingProfile.activeProgressionMetrics.contains(.weight)
    }
}

struct WorkoutExerciseEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let exerciseId: String
    var sets: Int
    var reps: Int
    var startingWeight: Double
    var durationSeconds: Int
    var distanceMeters: Double
    var order: Int
    /// Optional rest between sets for this exercise. `nil` → Settings default.
    var restDurationOverride: TimeInterval?

    init(
        id: UUID = UUID(),
        exerciseId: String,
        sets: Int,
        reps: Int,
        startingWeight: Double = 0,
        durationSeconds: Int = 0,
        distanceMeters: Double = 0,
        order: Int,
        restDurationOverride: TimeInterval? = nil
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.sets = sets
        self.reps = reps
        self.startingWeight = startingWeight
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.order = order
        self.restDurationOverride = restDurationOverride
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        exerciseId = try container.decode(String.self, forKey: .exerciseId)
        sets = try container.decode(Int.self, forKey: .sets)
        reps = try container.decode(Int.self, forKey: .reps)
        startingWeight = try container.decodeIfPresent(Double.self, forKey: .startingWeight) ?? 0
        durationSeconds = try container.decodeIfPresent(Int.self, forKey: .durationSeconds) ?? 0
        distanceMeters = try container.decodeIfPresent(Double.self, forKey: .distanceMeters) ?? 0
        order = try container.decode(Int.self, forKey: .order)
        restDurationOverride = try container.decodeIfPresent(TimeInterval.self, forKey: .restDurationOverride)
    }

    private enum CodingKeys: String, CodingKey {
        case id, exerciseId, sets, reps, startingWeight, durationSeconds, distanceMeters, order
        case restDurationOverride
    }

    /// Effective rest for this entry given global settings.
    func effectiveRestDuration(defaultDuration: TimeInterval) -> TimeInterval {
        restDurationOverride ?? defaultDuration
    }
}

struct DraftWorkoutExercise: Identifiable {
    let id: UUID
    let exercise: Exercise
    var sets: Int
    var reps: Int
    var startingWeight: Double
    var durationSeconds: Int
    var distanceMeters: Double
    var restDurationOverride: TimeInterval?

    init(
        entryId: UUID = UUID(),
        exercise: Exercise,
        sets: Int,
        reps: Int,
        startingWeight: Double = 0,
        durationSeconds: Int = 0,
        distanceMeters: Double = 0,
        restDurationOverride: TimeInterval? = nil
    ) {
        self.id = entryId
        self.exercise = exercise
        self.sets = sets
        self.reps = reps
        self.startingWeight = startingWeight
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.restDurationOverride = restDurationOverride
    }
}
