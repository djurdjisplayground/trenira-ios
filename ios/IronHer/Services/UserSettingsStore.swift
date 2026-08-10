import Foundation

@Observable
@MainActor
final class UserSettingsStore {
    var weightUnit: WeightUnit {
        didSet { save() }
    }

    var appTheme: AppTheme {
        didSet { save() }
    }

    var coachingMode: CoachingMode {
        didSet { save() }
    }

    var progressNotificationsEnabled: Bool {
        didSet { save() }
    }

    /// Reserved for future personalized recommendations (cycle-aware training, etc.).
    var personalization: PersonalizationContext {
        didSet { save() }
    }

    /// Custom default increments by equipment type (kg), keyed by `EquipmentType.rawValue`.
    var equipmentIncrementOverridesKg: [String: Double] {
        didSet { save() }
    }

    /// Per-exercise increment overrides (kg), keyed by exercise id.
    var exerciseIncrementOverridesKg: [String: Double] {
        didSet { save() }
    }

    // MARK: - Developer toggles (DEBUG UI only)

    var allowReopenCompletedWorkouts: Bool {
        didSet { save() }
    }

    /// When true (DEBUG), Track This Week checkboxes can mark workouts complete/incomplete.
    var allowManualWorkoutCompletionTesting: Bool {
        didSet { save() }
    }

    var enableTestNotifications: Bool {
        didSet { save() }
    }

    var restTimer: RestTimerSettings {
        didSet { save() }
    }

    /// Countdown completion sound for duration-based sets (Farmer's Carry, plank, etc.).
    var timerSoundsEnabled: Bool {
        didSet { save() }
    }

    private(set) var lastDeveloperActionMessage: String?

    private let storageKey = "userSettings"

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(PersistedSettings.self, from: data) {
            weightUnit = decoded.weightUnit
            appTheme = decoded.appTheme
            coachingMode = decoded.coachingMode ?? .minimal
            progressNotificationsEnabled = decoded.progressNotificationsEnabled
            personalization = decoded.personalization ?? PersonalizationContext()
            equipmentIncrementOverridesKg = decoded.equipmentIncrementOverridesKg ?? [:]
            exerciseIncrementOverridesKg = decoded.exerciseIncrementOverridesKg ?? [:]
            allowReopenCompletedWorkouts = decoded.allowReopenCompletedWorkouts ?? true
            allowManualWorkoutCompletionTesting = decoded.allowManualWorkoutCompletionTesting ?? true
            enableTestNotifications = decoded.enableTestNotifications ?? false
            restTimer = decoded.restTimer ?? .default
            timerSoundsEnabled = decoded.timerSoundsEnabled ?? true
        } else {
            weightUnit = .kilograms
            appTheme = .system
            coachingMode = .minimal
            progressNotificationsEnabled = false
            personalization = PersonalizationContext()
            equipmentIncrementOverridesKg = [:]
            exerciseIncrementOverridesKg = [:]
            allowReopenCompletedWorkouts = true
            allowManualWorkoutCompletionTesting = true
            enableTestNotifications = false
            restTimer = .default
            timerSoundsEnabled = true
        }

        // Migrate legacy developer settings key if present.
        migrateLegacyDeveloperSettingsIfNeeded()
    }

    var showsEncouragement: Bool {
        coachingMode == .encouragement
    }

    var showsReopenWorkoutButton: Bool {
        DevelopmentConfig.isDevelopmentMode && allowReopenCompletedWorkouts
    }

    var allowsManualWorkoutCompletionToggle: Bool {
        DevelopmentConfig.isDevelopmentMode && allowManualWorkoutCompletionTesting
    }

    func noteDeveloperAction(_ message: String) {
        lastDeveloperActionMessage = message
    }

    func clearDeveloperActionStatus() {
        lastDeveloperActionMessage = nil
    }

    func resetEquipmentIncrement(for equipment: EquipmentType) {
        equipmentIncrementOverridesKg.removeValue(forKey: equipment.rawValue)
    }

    func resetExerciseIncrement(for exerciseId: String) {
        exerciseIncrementOverridesKg.removeValue(forKey: exerciseId)
    }

    func needsContextualIncrementPrompt(for exercise: Exercise) -> Bool {
        ExerciseIncrementResolver.needsContextualPrompt(
            for: exercise,
            exerciseOverridesKg: exerciseIncrementOverridesKg
        )
    }

    func savedExerciseIncrements() -> [(exercise: Exercise, kg: Double)] {
        exerciseIncrementOverridesKg.compactMap { id, kg in
            guard let exercise = ExerciseCatalog.exercise(id: id) else { return nil }
            return (exercise, kg)
        }
        .sorted { $0.exercise.name.localizedCaseInsensitiveCompare($1.exercise.name) == .orderedAscending }
    }

    func effectiveIncrementKg(for equipment: EquipmentType) -> Double {
        if let override = equipmentIncrementOverridesKg[equipment.rawValue] {
            return override
        }
        return EquipmentDefaults.defaultIncrementKg(for: equipment)
    }

    func incrementKg(
        for exercise: Exercise,
        categoryDefaultKg: Double = WeightProgressionCalculator.defaultIncrementKg
    ) -> Double {
        ExerciseIncrementResolver.incrementKg(
            for: exercise,
            equipmentOverridesKg: equipmentIncrementOverridesKg,
            exerciseOverridesKg: exerciseIncrementOverridesKg,
            categoryDefaultKg: categoryDefaultKg
        )
    }

    func incrementKg(
        for exerciseId: String,
        categoryDefaultKg: Double = WeightProgressionCalculator.defaultIncrementKg
    ) -> Double {
        ExerciseIncrementResolver.incrementKg(
            for: exerciseId,
            equipmentOverridesKg: equipmentIncrementOverridesKg,
            exerciseOverridesKg: exerciseIncrementOverridesKg,
            categoryDefaultKg: categoryDefaultKg
        )
    }

    private func migrateLegacyDeveloperSettingsIfNeeded() {
        let legacyKey = "developerSettings"
        guard let data = UserDefaults.standard.data(forKey: legacyKey),
              let legacy = try? JSONDecoder().decode(LegacyDeveloperSettings.self, from: data) else {
            return
        }
        allowReopenCompletedWorkouts = legacy.allowReopenCompletedWorkouts
        enableTestNotifications = legacy.enableTestNotifications
        UserDefaults.standard.removeObject(forKey: legacyKey)
        save()
    }

    private func save() {
        let payload = PersistedSettings(
            weightUnit: weightUnit,
            appTheme: appTheme,
            coachingMode: coachingMode,
            progressNotificationsEnabled: progressNotificationsEnabled,
            personalization: personalization,
            equipmentIncrementOverridesKg: equipmentIncrementOverridesKg,
            exerciseIncrementOverridesKg: exerciseIncrementOverridesKg,
            allowReopenCompletedWorkouts: allowReopenCompletedWorkouts,
            allowManualWorkoutCompletionTesting: allowManualWorkoutCompletionTesting,
            enableTestNotifications: enableTestNotifications,
            restTimer: restTimer,
            timerSoundsEnabled: timerSoundsEnabled
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    func exportSyncBlob() -> Data? {
        UserDefaults.standard.data(forKey: storageKey)
    }

    func importSyncBlob(_ data: Data) {
        guard let payload = try? JSONDecoder().decode(PersistedSettings.self, from: data) else { return }
        weightUnit = payload.weightUnit
        appTheme = payload.appTheme
        coachingMode = payload.coachingMode ?? .minimal
        progressNotificationsEnabled = payload.progressNotificationsEnabled
        personalization = payload.personalization ?? PersonalizationContext()
        equipmentIncrementOverridesKg = payload.equipmentIncrementOverridesKg ?? [:]
        exerciseIncrementOverridesKg = payload.exerciseIncrementOverridesKg ?? [:]
        allowReopenCompletedWorkouts = payload.allowReopenCompletedWorkouts ?? true
        allowManualWorkoutCompletionTesting = payload.allowManualWorkoutCompletionTesting ?? true
        enableTestNotifications = payload.enableTestNotifications ?? false
        restTimer = payload.restTimer ?? .default
        timerSoundsEnabled = payload.timerSoundsEnabled ?? true
        save()
    }

    /// Resets preferences to factory defaults (account deletion).
    func resetToDefaults() {
        weightUnit = .kilograms
        appTheme = .system
        coachingMode = .minimal
        progressNotificationsEnabled = false
        personalization = PersonalizationContext()
        equipmentIncrementOverridesKg = [:]
        exerciseIncrementOverridesKg = [:]
        allowReopenCompletedWorkouts = true
        allowManualWorkoutCompletionTesting = true
        enableTestNotifications = false
        restTimer = .default
        timerSoundsEnabled = true
        save()
    }

    private struct PersistedSettings: Codable {
        let weightUnit: WeightUnit
        let appTheme: AppTheme
        let coachingMode: CoachingMode?
        let progressNotificationsEnabled: Bool
        let personalization: PersonalizationContext?
        let equipmentIncrementOverridesKg: [String: Double]?
        let exerciseIncrementOverridesKg: [String: Double]?
        let allowReopenCompletedWorkouts: Bool?
        let allowManualWorkoutCompletionTesting: Bool?
        let enableTestNotifications: Bool?
        let restTimer: RestTimerSettings?
        let timerSoundsEnabled: Bool?
    }

    private struct LegacyDeveloperSettings: Codable {
        let allowReopenCompletedWorkouts: Bool
        let enableTestNotifications: Bool
    }
}
