import SwiftUI

struct StrengthCalibrationSettingsView: View {
    @Environment(StrengthCalibrationStore.self) private var calibrationStore
    @Environment(UserSettingsStore.self) private var settingsStore
    @Environment(GlobalExerciseProgressStore.self) private var globalProgressStore
    @Environment(WeightHistoryStore.self) private var historyStore

    @State private var showFlow = false
    @State private var editing: Exercise?

    private var unit: WeightUnit { settingsStore.weightUnit }

    var body: some View {
        List {
            Section {
                Text("These starting weights are used only when an exercise has no workout history yet. Progression after that stays automatic.")
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)

                Button("Start strength setup") {
                    showFlow = true
                }
            }

            Section("Exercises") {
                ForEach(StrengthCalibrationCatalog.exercises) { exercise in
                    Button {
                        editing = exercise
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(exercise.name)
                                    .font(SheLiftsFont.bodyMedium)
                                    .foregroundStyle(IronHerTheme.primaryText)
                                Text(statusText(for: exercise))
                                    .font(SheLiftsFont.caption)
                                    .foregroundStyle(IronHerTheme.secondaryText)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(IronHerTheme.secondaryText)
                        }
                    }
                }
            }

            Section {
                Button("Redo calibration") {
                    showFlow = true
                }
            } footer: {
                Text("Redoing calibration updates starting weights for exercises you have not trained yet. Existing workout history is kept.")
                    .font(SheLiftsFont.caption)
            }
        }
        .listStyle(.insetGrouped)
        .background(IronHerTheme.groupedBackground)
        .navigationTitle("Strength setup")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showFlow) {
            WeightCalibrationFlowView(onExit: { _ in showFlow = false })
        }
        .sheet(item: $editing) { exercise in
            NavigationStack {
                StrengthCalibrationEditView(exercise: exercise)
            }
        }
    }

    private func statusText(for exercise: Exercise) -> String {
        let established = StrengthCalibrationResolver.hasEstablishedProgress(
            progress: globalProgressStore.progress(for: exercise.id),
            historyEntries: historyStore.entries(for: exercise.id)
        )
        if let record = calibrationStore.calibration(for: exercise.id) {
            let weight = WeightFormatter.format(kg: record.weightKg, unit: unit)
            if established {
                return "\(weight) × \(record.reps) saved — workout history is used instead"
            }
            return "\(weight) × \(record.reps)"
        }
        if calibrationStore.skippedExerciseIds.contains(exercise.id) {
            return "Skipped"
        }
        return "Not calibrated"
    }
}

private struct StrengthCalibrationEditView: View {
    @Environment(StrengthCalibrationStore.self) private var calibrationStore
    @Environment(UserSettingsStore.self) private var settingsStore
    @Environment(\.dismiss) private var dismiss

    let exercise: Exercise

    @State private var weightText = ""
    @State private var repsText = "10"

    private var unit: WeightUnit { settingsStore.weightUnit }

    var body: some View {
        Form {
            Section {
                TextField("Weight (\(unit.shortLabel))", text: $weightText)
                    .keyboardType(.decimalPad)
                TextField("Reps", text: $repsText)
                    .keyboardType(.numberPad)
            } footer: {
                Text("Use a weight you can lift for about 8–12 controlled reps, stopping with 1–2 reps in reserve.")
                    .font(SheLiftsFont.caption)
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(!canSave)
            }
        }
        .onAppear {
            if let existing = calibrationStore.calibration(for: exercise.id) {
                weightText = WeightFormatter.formatNumber(kg: existing.weightKg, unit: unit)
                repsText = "\(existing.reps)"
            }
        }
    }

    private var canSave: Bool {
        parsedWeightKg != nil && parsedReps != nil
    }

    private var parsedWeightKg: Double? {
        let normalized = weightText.replacingOccurrences(of: ",", with: ".")
        guard let display = Double(normalized), display > 0 else { return nil }
        return WeightFormatter.kilograms(from: display, unit: unit)
    }

    private var parsedReps: Int? {
        guard let reps = Int(repsText.trimmingCharacters(in: .whitespaces)), (1...50).contains(reps) else {
            return nil
        }
        return reps
    }

    private func save() {
        guard let weightKg = parsedWeightKg, let reps = parsedReps else { return }
        calibrationStore.saveCalibration(exerciseId: exercise.id, weightKg: weightKg, reps: reps)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        StrengthCalibrationSettingsView()
            .environment(StrengthCalibrationStore())
            .environment(UserSettingsStore())
            .environment(GlobalExerciseProgressStore())
            .environment(WeightHistoryStore())
    }
}
