import Foundation

@Observable
@MainActor
final class ExerciseProgressionStore {
    /// Named reusable progression configurations (legacy presets — still used as ladder source).
    private(set) var configurations: [ProgressionConfiguration] = []
    /// Configuration applied when an exercise has no override.
    private(set) var defaultConfigurationId: UUID = ProgressionConfiguration.makeDefault().id
    /// Optional per-exercise configuration overrides.
    private(set) var exerciseAssignments: [String: UUID] = [:]

    private(set) var states: [String: ExerciseProgressionState] = [:]
    /// Legacy per-exercise engine rules — kept for older data only.
    private(set) var rules: [String: ExerciseProgressionRule] = [:]

    /// Category-level HOW + default increment sizes.
    private(set) var categoryDefaults: ProgressionCategoryDefaults = .default
    /// Per-exercise HOW overrides (Weight / Reps / Sets / Time).
    private(set) var exerciseDimensionOverrides: [String: ProgressionDimension] = [:]

    private let storageKey = "exerciseProgressionStates"
    private let rulesKey = "exerciseProgressionRules"
    private let globalRuleKey = "globalProgressionRule"
    private let configurationsKey = "progressionConfigurations"
    private let defaultConfigurationKey = "defaultProgressionConfigurationId"
    private let assignmentsKey = "progressionExerciseAssignments"
    private let categoryDefaultsKey = "progressionCategoryDefaults"
    private let dimensionOverridesKey = "progressionDimensionOverrides"

    init() {
        load()
    }

    /// Convenience: the current default configuration.
    var defaultConfiguration: ProgressionConfiguration {
        configuration(id: defaultConfigurationId) ?? configurations.first ?? .makeDefault()
    }

    /// Backward-compatible alias used by older call sites.
    var globalRule: ProgressionConfiguration {
        defaultConfiguration
    }

    func configuration(id: UUID?) -> ProgressionConfiguration? {
        guard let id else { return nil }
        return configurations.first { $0.id == id }
    }

    /// Effective configuration for an exercise (override → default).
    func configuration(for exerciseId: String) -> ProgressionConfiguration {
        if let assignedId = exerciseAssignments[exerciseId],
           let assigned = configuration(id: assignedId) {
            return assigned
        }
        return defaultConfiguration
    }

    func state(for exerciseId: String) -> ExerciseProgressionState {
        states[exerciseId] ?? ExerciseProgressionState()
    }

    func updateCategoryDefaults(_ defaults: ProgressionCategoryDefaults) {
        categoryDefaults = defaults.normalized
        saveCategoryDefaults()
    }

    func dimension(for exercise: Exercise) -> ProgressionDimension {
        if let override = exerciseDimensionOverrides[exercise.id],
           ProgressionTrainingCategory.category(for: exercise).allowedDimensions.contains(override) {
            return override
        }
        return categoryDefaults.rule(for: ProgressionTrainingCategory.category(for: exercise))
    }

    func setDimension(_ dimension: ProgressionDimension?, for exercise: Exercise, forceOverride: Bool = false) {
        let category = ProgressionTrainingCategory.category(for: exercise)
        if let dimension, category.allowedDimensions.contains(dimension) {
            let defaultRule = categoryDefaults.rule(for: category)
            if !forceOverride && dimension == defaultRule {
                exerciseDimensionOverrides.removeValue(forKey: exercise.id)
            } else {
                exerciseDimensionOverrides[exercise.id] = dimension
            }
        } else {
            exerciseDimensionOverrides.removeValue(forKey: exercise.id)
        }
        // Dimension override supersedes legacy custom engine rules / preset assignments.
        rules.removeValue(forKey: exercise.id)
        exerciseAssignments.removeValue(forKey: exercise.id)
        saveDimensionOverrides()
        saveRules()
        saveAssignments()
    }

    func hasDimensionOverride(for exerciseId: String) -> Bool {
        exerciseDimensionOverrides[exerciseId] != nil
    }

    /// Keeps the legacy default configuration ladder aligned with category defaults.
    func syncDefaultConfigurationFromCategoryDefaults() {
        let d = categoryDefaults.normalized
        let updated = ProgressionConfiguration(
            id: defaultConfigurationId,
            name: defaultConfiguration.name,
            targetSets: d.strengthTargetSets,
            startingReps: d.strengthStartingReps,
            thresholdReps: d.strengthThresholdReps,
            weightIncrementKg: d.defaultWeightIncrementKg
        )
        if let index = configurations.firstIndex(where: { $0.id == defaultConfigurationId }) {
            configurations[index] = updated.normalized
        } else {
            configurations.insert(updated.normalized, at: 0)
        }
        saveConfigurations()
    }

    // MARK: - Configurations CRUD

    @discardableResult
    func addConfiguration(_ configuration: ProgressionConfiguration) -> ProgressionConfiguration {
        let normalized = configuration.normalized
        configurations.append(normalized)
        saveConfigurations()
        return normalized
    }

    func updateConfiguration(_ configuration: ProgressionConfiguration) {
        let normalized = configuration.normalized
        guard let index = configurations.firstIndex(where: { $0.id == normalized.id }) else { return }
        configurations[index] = normalized
        saveConfigurations()
    }

    func deleteConfiguration(id: UUID) {
        guard configurations.count > 1 else { return }
        configurations.removeAll { $0.id == id }
        if defaultConfigurationId == id {
            defaultConfigurationId = configurations[0].id
            saveDefaultConfigurationId()
        }
        exerciseAssignments = exerciseAssignments.filter { $0.value != id }
        saveAssignments()
        saveConfigurations()
    }

    func setDefaultConfiguration(id: UUID) {
        guard configurations.contains(where: { $0.id == id }) else { return }
        defaultConfigurationId = id
        saveDefaultConfigurationId()
    }

    /// Effective engine rule for an exercise — legacy custom → dimension + category defaults.
    func rule(
        for exercise: Exercise,
        weightIncrementKg: Double
    ) -> ExerciseProgressionRule {
        if let custom = rules[exercise.id] {
            return custom
        }

        let profile = exercise.trackingProfile
        let effectiveWeight = weightIncrementKg > 0
            ? WeightProgressionCalculator.normalize(weightIncrementKg)
            : WeightProgressionCalculator.normalize(categoryDefaults.normalized.defaultWeightIncrementKg)

        // Timed / carry exercises must never inherit strength rep progression.
        // Farmer's Carry and similar weight+time work use durationCycle (+ weight after ladder).
        if profile.supports(.time),
           !profile.supports(.reps),
           profile.primaryProgressionMetric == .time {
            var recommended = ExerciseProgressionRule.recommended(
                for: exercise,
                weightIncrementKg: effectiveWeight
            )
            let config = configuration(for: exercise.id)
            if config.targetSets > 0 {
                recommended.targetSets = config.targetSets
            }
            return recommended
        }

        var defaults = categoryDefaults.normalized
        // Prefer ladder endpoints from the legacy default configuration when present.
        let config = configuration(for: exercise.id)
        defaults.strengthTargetSets = config.targetSets
        defaults.strengthStartingReps = config.startingReps
        defaults.strengthThresholdReps = config.thresholdReps

        let dimension = dimension(for: exercise)

        return ExerciseProgressionRule.from(
            dimension: dimension,
            defaults: defaults,
            weightIncrementKg: effectiveWeight
        )
    }

    func hasCustomRule(for exerciseId: String) -> Bool {
        rules[exerciseId] != nil
    }

    func ruleIfCustom(for exerciseId: String) -> ExerciseProgressionRule? {
        rules[exerciseId]
    }

    var customRuleExerciseIds: [String] {
        Array(rules.keys).sorted()
    }

    func updateRule(_ rule: ExerciseProgressionRule, for exerciseId: String) {
        var normalized = rule
        normalized.repSteps = rule.normalizedRepSteps
        normalized.durationSteps = rule.normalizedDurationSteps
        rules[exerciseId] = normalized
        // Custom rules supersede preset assignments.
        exerciseAssignments.removeValue(forKey: exerciseId)
        saveRules()
        saveAssignments()
    }

    func removeCustomRule(for exerciseId: String) {
        rules.removeValue(forKey: exerciseId)
        saveRules()
    }

    func resetRule(for exercise: Exercise, weightIncrementKg: Double) {
        rules[exercise.id] = ExerciseProgressionRule.recommended(
            for: exercise,
            weightIncrementKg: weightIncrementKg
        )
        exerciseAssignments.removeValue(forKey: exercise.id)
        saveRules()
        saveAssignments()
    }

    func assignConfiguration(_ configurationId: UUID?, to exerciseId: String) {
        // Choosing a preset clears any custom exercise rule.
        rules.removeValue(forKey: exerciseId)
        saveRules()
        if let configurationId, configurations.contains(where: { $0.id == configurationId }) {
            exerciseAssignments[exerciseId] = configurationId
        } else {
            exerciseAssignments.removeValue(forKey: exerciseId)
        }
        saveAssignments()
    }

    @discardableResult
    func evaluateAfterExercise(
        session: ProgressionSessionResult,
        exercise: Exercise,
        weightIncrementKg: Double
    ) -> ProgressionOutcome {
        let rule = rule(for: exercise, weightIncrementKg: weightIncrementKg)
        let current = state(for: session.exerciseId)
        let result = ProgressionEngine.evaluate(
            session: session,
            exercise: exercise,
            rule: rule,
            state: current
        )
        states[session.exerciseId] = result.updatedState
        saveStates()

        // Keep custom set-progression rules in sync with the new set target.
        if case .applied(let update) = result.outcome, update.kind == .nextSetTarget,
           var custom = rules[exercise.id] {
            custom.targetSets = update.targetSets
            rules[exercise.id] = custom
            saveRules()
        }

        return result.outcome
    }

    /// Exercise IDs currently resolved to a given configuration (excludes custom-rule exercises).
    func exerciseIds(using configurationId: UUID, knownExerciseIds: Set<String>) -> [String] {
        knownExerciseIds.filter { exerciseId in
            if rules[exerciseId] != nil { return false }
            if let assigned = exerciseAssignments[exerciseId] {
                return assigned == configurationId
            }
            return configurationId == defaultConfigurationId
        }
    }

    func clearAll() {
        let fresh = ProgressionConfiguration.makeDefault()
        configurations = [fresh]
        defaultConfigurationId = fresh.id
        exerciseAssignments = [:]
        states = [:]
        rules = [:]
        categoryDefaults = .default
        exerciseDimensionOverrides = [:]
        saveConfigurations()
        saveDefaultConfigurationId()
        saveAssignments()
        saveStates()
        saveRules()
        saveCategoryDefaults()
        saveDimensionOverrides()
    }

    // MARK: - Persistence

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: ExerciseProgressionState].self, from: data) {
            states = decoded
        } else {
            states = [:]
        }

        if let data = UserDefaults.standard.data(forKey: rulesKey),
           let decoded = try? JSONDecoder().decode([String: ExerciseProgressionRule].self, from: data) {
            rules = decoded
        } else {
            rules = [:]
        }

        if let data = UserDefaults.standard.data(forKey: configurationsKey),
           let decoded = try? JSONDecoder().decode([ProgressionConfiguration].self, from: data),
           !decoded.isEmpty {
            configurations = decoded.map(\.normalized)
        } else if let data = UserDefaults.standard.data(forKey: globalRuleKey),
                  let legacy = try? JSONDecoder().decode(GlobalProgressionRule.self, from: data) {
            let migrated = legacy.asConfiguration
            configurations = [migrated]
            defaultConfigurationId = migrated.id
        } else {
            let fresh = ProgressionConfiguration.makeDefault()
            configurations = [fresh]
            defaultConfigurationId = fresh.id
        }

        if let raw = UserDefaults.standard.string(forKey: defaultConfigurationKey),
           let id = UUID(uuidString: raw),
           configurations.contains(where: { $0.id == id }) {
            defaultConfigurationId = id
        } else {
            defaultConfigurationId = configurations[0].id
        }

        if let data = UserDefaults.standard.data(forKey: assignmentsKey),
           let decoded = try? JSONDecoder().decode([String: UUID].self, from: data) {
            exerciseAssignments = decoded.filter { assignment in
                configurations.contains { $0.id == assignment.value }
            }
        } else {
            exerciseAssignments = [:]
        }

        if let data = UserDefaults.standard.data(forKey: categoryDefaultsKey),
           let decoded = try? JSONDecoder().decode(ProgressionCategoryDefaults.self, from: data) {
            categoryDefaults = decoded.normalized
        } else {
            // Seed from legacy default configuration.
            let config = defaultConfiguration
            var seeded = ProgressionCategoryDefaults.default
            seeded.defaultWeightIncrementKg = config.weightIncrementKg
            seeded.strengthTargetSets = config.targetSets
            seeded.strengthStartingReps = config.startingReps
            seeded.strengthThresholdReps = config.thresholdReps
            categoryDefaults = seeded.normalized
        }

        if let data = UserDefaults.standard.data(forKey: dimensionOverridesKey),
           let decoded = try? JSONDecoder().decode([String: ProgressionDimension].self, from: data) {
            exerciseDimensionOverrides = decoded
        } else {
            exerciseDimensionOverrides = [:]
        }

        saveConfigurations()
        saveDefaultConfigurationId()
        saveAssignments()
        saveCategoryDefaults()
        saveDimensionOverrides()
    }

    private func saveStates() {
        guard let data = try? JSONEncoder().encode(states) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func saveRules() {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        UserDefaults.standard.set(data, forKey: rulesKey)
    }

    private func saveConfigurations() {
        guard let data = try? JSONEncoder().encode(configurations) else { return }
        UserDefaults.standard.set(data, forKey: configurationsKey)
    }

    private func saveDefaultConfigurationId() {
        UserDefaults.standard.set(defaultConfigurationId.uuidString, forKey: defaultConfigurationKey)
    }

    private func saveAssignments() {
        guard let data = try? JSONEncoder().encode(exerciseAssignments) else { return }
        UserDefaults.standard.set(data, forKey: assignmentsKey)
    }

    private func saveCategoryDefaults() {
        guard let data = try? JSONEncoder().encode(categoryDefaults) else { return }
        UserDefaults.standard.set(data, forKey: categoryDefaultsKey)
    }

    private func saveDimensionOverrides() {
        guard let data = try? JSONEncoder().encode(exerciseDimensionOverrides) else { return }
        UserDefaults.standard.set(data, forKey: dimensionOverridesKey)
    }

    // MARK: - Sync blobs

    struct SyncBlob: Codable {
        var states: [String: ExerciseProgressionState]
        var rules: [String: ExerciseProgressionRule]
        var configurations: [ProgressionConfiguration]
        var defaultConfigurationId: UUID
        var exerciseAssignments: [String: UUID]
        var categoryDefaults: ProgressionCategoryDefaults
        var exerciseDimensionOverrides: [String: ProgressionDimension]
    }

    func exportSyncBlob() -> Data? {
        let blob = SyncBlob(
            states: states,
            rules: rules,
            configurations: configurations,
            defaultConfigurationId: defaultConfigurationId,
            exerciseAssignments: exerciseAssignments,
            categoryDefaults: categoryDefaults,
            exerciseDimensionOverrides: exerciseDimensionOverrides
        )
        return try? JSONEncoder().encode(blob)
    }

    func importSyncBlob(_ data: Data) {
        guard let blob = try? JSONDecoder().decode(SyncBlob.self, from: data) else { return }
        states = blob.states
        rules = blob.rules
        configurations = blob.configurations
        defaultConfigurationId = blob.defaultConfigurationId
        exerciseAssignments = blob.exerciseAssignments
        categoryDefaults = blob.categoryDefaults
        exerciseDimensionOverrides = blob.exerciseDimensionOverrides
        saveStates()
        saveRules()
        saveConfigurations()
        saveDefaultConfigurationId()
        saveAssignments()
        saveCategoryDefaults()
        saveDimensionOverrides()
    }
}
