import Foundation

/// Device-local starting-weight samples. Independent of the progression engine.
@Observable
@MainActor
final class StrengthCalibrationStore {
    static let storageKey = "trenira.strengthCalibration"

    private(set) var state: StrengthCalibrationState = .empty

    var onMutation: (() -> Void)?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    var records: [String: ExerciseCalibration] { state.records }

    var skippedExerciseIds: Set<String> { Set(state.skippedExerciseIds) }

    var hasFinishedOrSkippedFlow: Bool { state.hasFinishedOrSkippedFlow }

    var hasDismissedSetupCard: Bool { state.hasDismissedHomePrompt }

    var hasAnyCalibration: Bool { !state.records.isEmpty }

    /// Incomplete setup that has not been dismissed from Home / Workouts.
    var showsWorkoutsSetupCard: Bool {
        !hasAnyCalibration && !hasDismissedSetupCard
    }

    /// Same visibility as Home — existing users land on Home, not My Workouts.
    var showsHomeSetupCard: Bool { showsWorkoutsSetupCard }

    /// Shown during workout creation until the user has at least one calibration sample.
    var showsCreateWorkoutSetupPrompt: Bool {
        !hasAnyCalibration
    }

    func calibration(for exerciseId: String) -> ExerciseCalibration? {
        state.records[exerciseId]
    }

    func saveCalibration(
        exerciseId: String,
        weightKg: Double,
        reps: Int,
        effort: CalibrationEffort? = nil
    ) {
        let exercise = ExerciseCatalog.exercise(id: exerciseId)
        var record = ExerciseCalibration(
            exerciseId: exerciseId,
            weightKg: weightKg,
            reps: reps,
            date: .now,
            movementPattern: exercise?.movementPattern,
            movementFamily: exercise?.movementFamily,
            effort: effort,
            matchingVersion: 1
        )
        if effort == nil, let existing = state.records[exerciseId]?.effort {
            record.effort = existing
        }
        state.records[exerciseId] = record
        state.skippedExerciseIds.removeAll { $0 == exerciseId }
        persist()
    }

    func skipExercise(id: String) {
        if !state.skippedExerciseIds.contains(id) {
            state.skippedExerciseIds.append(id)
        }
        persist()
    }

    func unskipExercise(id: String) {
        state.skippedExerciseIds.removeAll { $0 == id }
        persist()
    }

    func markFlowFinishedOrSkipped() {
        state.hasFinishedOrSkippedFlow = true
        persist()
    }

    func dismissSetupCard() {
        state.hasDismissedHomePrompt = true
        persist()
    }

    func clearAll() {
        state = .empty
        persist()
    }

    func exportSyncBlob() -> Data? {
        guard state != .empty else { return nil }
        return try? JSONEncoder().encode(state)
    }

    func importSyncBlob(_ data: Data) {
        guard let decoded = try? JSONDecoder().decode(StrengthCalibrationState.self, from: data) else {
            return
        }
        state = decoded
        persist()
    }

    private func persist() {
        save()
        onMutation?()
    }

    private func load() {
        guard
            let data = defaults.data(forKey: Self.storageKey),
            let decoded = try? JSONDecoder().decode(StrengthCalibrationState.self, from: data)
        else {
            state = .empty
            return
        }
        state = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
