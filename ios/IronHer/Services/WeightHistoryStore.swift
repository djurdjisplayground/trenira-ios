import Foundation

@Observable
@MainActor
final class WeightHistoryStore {
    private(set) var entries: [WeightHistoryEntry] = []

    var ownershipProvider: (() -> String)?
    var onMutation: (() -> Void)?

    private let storageKey = "weightHistory"

    init() {
        load()
    }

    func recordInitial(exerciseId: String, weightKg: Double) {
        guard weightKg >= 0 else { return }
        guard !entries.contains(where: { $0.exerciseId == exerciseId }) else { return }

        entries.append(
            WeightHistoryEntry(
                exerciseId: exerciseId,
                weightKg: weightKg,
                event: .initial,
                ownerId: ownershipProvider?() ?? ""
            )
        )
        save()
        onMutation?()
    }

    func recordProgression(exerciseId: String, from previousKg: Double, to newKg: Double) {
        guard newKg > previousKg else { return }

        entries.append(
            WeightHistoryEntry(
                exerciseId: exerciseId,
                weightKg: newKg,
                previousWeightKg: previousKg,
                event: .progression,
                ownerId: ownershipProvider?() ?? ""
            )
        )
        save()
        onMutation?()
    }

    func recordRepProgression(exerciseId: String, from previousReps: Int, to newReps: Int) {
        guard newReps > previousReps else { return }

        entries.append(
            WeightHistoryEntry(
                exerciseId: exerciseId,
                reps: newReps,
                previousReps: previousReps,
                event: .repProgression,
                ownerId: ownershipProvider?() ?? ""
            )
        )
        save()
        onMutation?()
    }

    func recordSetProgression(exerciseId: String, from previousSets: Int, to newSets: Int) {
        guard newSets > previousSets else { return }

        entries.append(
            WeightHistoryEntry(
                exerciseId: exerciseId,
                sets: newSets,
                previousSets: previousSets,
                event: .setProgression,
                ownerId: ownershipProvider?() ?? ""
            )
        )
        save()
        onMutation?()
    }

    func entries(for exerciseId: String) -> [WeightHistoryEntry] {
        entries
            .filter { $0.exerciseId == exerciseId }
            .sorted { $0.date < $1.date }
    }

    var progressSummaries: [ExerciseProgressSummary] {
        let grouped = Dictionary(
            grouping: entries.filter { $0.event == .initial || $0.event == .progression },
            by: \.exerciseId
        )

        return grouped.compactMap { exerciseId, items in
            guard let exercise = ExerciseCatalog.exercise(id: exerciseId),
                  let first = items.min(by: { $0.date < $1.date }),
                  let last = items.max(by: { $0.date < $1.date })
            else { return nil }

            return ExerciseProgressSummary(
                exerciseId: exerciseId,
                exerciseName: exercise.name,
                initialWeightKg: first.weightKg,
                currentWeightKg: last.weightKg,
                firstDate: first.date,
                lastDate: last.date,
                entryCount: items.count
            )
        }
        .sorted { $0.lastDate > $1.lastDate }
    }

    func notificationPreviewMessage(for summary: ExerciseProgressSummary, unit: WeightUnit) -> String {
        let gain = WeightFormatter.format(kg: summary.gainKg, unit: unit, includeUnit: true)
        let months = max(1, summary.daySpan / 30)
        let monthLabel = months == 1 ? "month" : "months"
        return "You increased \(summary.exerciseName) by \(gain) over \(months) \(monthLabel)."
    }

    func clearAll() {
        entries = []
        save()
        onMutation?()
    }

    func replaceAllForSync(_ records: [WeightHistoryEntry]) {
        entries = records
        save()
    }

    func stampMissingOwnership(_ ownerId: String) {
        var changed = false
        for index in entries.indices where entries[index].ownerId.isEmpty {
            entries[index].ownerId = ownerId
            changed = true
        }
        if changed { save() }
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([WeightHistoryEntry].self, from: data)
        else {
            entries = []
            return
        }
        entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
