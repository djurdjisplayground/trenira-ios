import SwiftUI

struct EquipmentIncrementsSettingsView: View {
    @Environment(UserSettingsStore.self) private var settingsStore
    @Environment(LocalizationStore.self) private var l10n

    private var standardEquipment: [EquipmentType] {
        [.barbell, .dumbbell, .kettlebell]
    }

    private var savedExerciseIncrements: [(exercise: Exercise, kg: Double)] {
        settingsStore.savedExerciseIncrements()
            .filter { ExerciseIncrementResolver.requiresContextualIncrement(for: $0.exercise.equipment) }
    }

    var body: some View {
        Form {
            Section {
                Text(l10n.t(.equipment_increments_intro))
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
            }

            Section {
                ForEach(standardEquipment) { equipment in
                    EquipmentIncrementRow(equipment: equipment)
                }
            } header: {
                Text(l10n.t(.standard_increments))
            } footer: {
                Text(l10n.t(.standard_increments_footer))
                    .font(SheLiftsFont.caption)
            }

            Section {
                if savedExerciseIncrements.isEmpty {
                    Text(l10n.t(.machine_cable_increments_empty))
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)
                } else {
                    ForEach(savedExerciseIncrements, id: \.exercise.id) { item in
                        NavigationLink {
                            ExerciseIncrementEditorView(exercise: item.exercise)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.exercise.localizedName(using: l10n))
                                        .font(SheLiftsFont.bodyMedium)
                                        .foregroundStyle(IronHerTheme.primaryText)
                                    Text(item.exercise.equipment.label)
                                        .font(SheLiftsFont.caption)
                                        .foregroundStyle(IronHerTheme.secondaryText)
                                }
                                Spacer()
                                Text(
                                    WeightFormatter.format(
                                        kg: item.kg,
                                        unit: settingsStore.weightUnit
                                    )
                                )
                                .font(SheLiftsFont.subheadline)
                                .foregroundStyle(IronHerTheme.secondaryText)
                            }
                        }
                    }
                }
            } header: {
                Text(l10n.t(.machine_cable_increments))
            } footer: {
                Text(l10n.t(.machine_cable_increments_footer))
                    .font(SheLiftsFont.caption)
            }
        }
        .navigationTitle(l10n.t(.equipment_increments))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ExerciseIncrementEditorView: View {
    @Environment(UserSettingsStore.self) private var settingsStore
    @Environment(LocalizationStore.self) private var l10n

    let exercise: Exercise

    @State private var displayValue: Double = 0
    @State private var suppressUpdates = false

    private var unit: WeightUnit { settingsStore.weightUnit }

    private var presets: [Double] {
        WeightFormatter.contextualIncrements(for: exercise.equipment, unit: unit)
    }

    var body: some View {
        Form {
            Section {
                Text(exercise.localizedName(using: l10n))
                    .font(SheLiftsFont.bodyMedium)
                Text(exercise.listSubtitle)
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
            }

            Section {
                ForEach(presets, id: \.self) { value in
                    Button {
                        displayValue = value
                        persist()
                    } label: {
                        HStack {
                            Text(WeightFormatter.formatDisplay(value, unit: unit))
                                .foregroundStyle(IronHerTheme.primaryText)
                            Spacer()
                            if abs(displayValue - value) < 0.001 {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(IronHerTheme.primaryText)
                            }
                        }
                    }
                }

                HStack {
                    TextField(l10n.t(.custom), value: $displayValue, format: .number)
                        .keyboardType(.decimalPad)
                        .onChange(of: displayValue) { _, _ in
                            guard !suppressUpdates else { return }
                            persist()
                        }
                    Text(unit.shortLabel)
                        .foregroundStyle(IronHerTheme.secondaryText)
                }
            } header: {
                Text(l10n.t(.increment))
            }

            Section {
                Button(l10n.t(.reset), role: .destructive) {
                    settingsStore.resetExerciseIncrement(for: exercise.id)
                    syncFromStore()
                }
            } footer: {
                Text(l10n.t(.exercise_increment_reset_footer))
                    .font(SheLiftsFont.caption)
            }
        }
        .navigationTitle(l10n.t(.set_increment))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { syncFromStore() }
        .onChange(of: settingsStore.weightUnit) { _, _ in syncFromStore() }
    }

    private func syncFromStore() {
        suppressUpdates = true
        let kg = settingsStore.incrementKg(for: exercise)
        displayValue = WeightFormatter.displayValue(kg: kg, unit: unit)
        suppressUpdates = false
    }

    private func persist() {
        let kg = WeightFormatter.kilograms(from: displayValue, unit: unit)
        guard kg > 0 else { return }
        settingsStore.exerciseIncrementOverridesKg[exercise.id] = kg
    }
}

private struct EquipmentIncrementRow: View {
    @Environment(UserSettingsStore.self) private var settingsStore
    @Environment(LocalizationStore.self) private var l10n
    let equipment: EquipmentType

    @State private var displayValue: Double = 0
    @State private var suppressUpdates = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(equipment.label)
                    .font(SheLiftsFont.bodyMedium)
                Spacer()
                if settingsStore.equipmentIncrementOverridesKg[equipment.rawValue] != nil {
                    Button(l10n.t(.reset)) {
                        settingsStore.resetEquipmentIncrement(for: equipment)
                        syncFromStore()
                    }
                    .font(SheLiftsFont.caption)
                }
            }

            HStack {
                TextField(l10n.t(.increment), value: $displayValue, format: .number)
                    .keyboardType(.decimalPad)
                    .onChange(of: displayValue) { _, _ in
                        guard !suppressUpdates else { return }
                        persistIncrement()
                    }
                Text(settingsStore.weightUnit.shortLabel)
                    .foregroundStyle(IronHerTheme.secondaryText)
            }

            Text(hintText)
                .font(SheLiftsFont.caption)
                .foregroundStyle(IronHerTheme.secondaryText)
        }
        .onAppear { syncFromStore() }
        .onChange(of: settingsStore.weightUnit) { _, _ in syncFromStore() }
    }

    private var hintText: String {
        let suggested = WeightFormatter.format(
            kg: EquipmentDefaults.defaultIncrementKg(for: equipment),
            unit: settingsStore.weightUnit
        )
        return l10n.t(.equipment_increment_suggested, suggested)
    }

    private func syncFromStore() {
        suppressUpdates = true
        let kg = settingsStore.effectiveIncrementKg(for: equipment)
        displayValue = WeightFormatter.displayValue(kg: kg, unit: settingsStore.weightUnit)
        suppressUpdates = false
    }

    private func persistIncrement() {
        let kg = WeightFormatter.kilograms(from: displayValue, unit: settingsStore.weightUnit)
        guard kg >= 0 else { return }
        settingsStore.equipmentIncrementOverridesKg[equipment.rawValue] = kg
    }
}
