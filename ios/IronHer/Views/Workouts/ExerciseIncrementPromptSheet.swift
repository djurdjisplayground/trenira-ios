import SwiftUI

/// First-time machine/cable increment — asked only when relevant.
struct ExerciseIncrementPromptSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UserSettingsStore.self) private var settingsStore
    @Environment(GlobalExerciseProgressStore.self) private var globalProgressStore
    @Environment(LocalizationStore.self) private var l10n

    let exercise: Exercise
    let onComplete: () -> Void

    @State private var selectedDisplay: Double?
    @State private var customDisplay: Double = 0
    @State private var useCustom = false

    private var unit: WeightUnit {
        globalProgressStore.resolvedWeightUnit(
            for: exercise.id,
            defaultUnit: settingsStore.weightUnit
        )
    }

    private var presets: [Double] {
        WeightFormatter.contextualIncrements(for: exercise.equipment, unit: unit)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(l10n.t(.increment_prompt_intro))
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)
                }

                Section {
                    Text(exercise.localizedName(using: l10n))
                        .font(SheLiftsFont.bodyMedium)
                        .foregroundStyle(IronHerTheme.primaryText)
                    Text(exercise.listSubtitle)
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)
                }

                Section {
                    ForEach(presets, id: \.self) { value in
                        Button {
                            useCustom = false
                            selectedDisplay = value
                        } label: {
                            HStack {
                                Text(WeightFormatter.formatDisplay(value, unit: unit))
                                    .foregroundStyle(IronHerTheme.primaryText)
                                Spacer()
                                if !useCustom, selectedDisplay == value {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(IronHerTheme.primaryText)
                                }
                            }
                        }
                    }

                    Button {
                        useCustom = true
                        selectedDisplay = nil
                    } label: {
                        HStack {
                            Text(l10n.t(.custom))
                                .foregroundStyle(IronHerTheme.primaryText)
                            Spacer()
                            if useCustom {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(IronHerTheme.primaryText)
                            }
                        }
                    }

                    if useCustom {
                        HStack {
                            TextField(l10n.t(.increment), value: $customDisplay, format: .number)
                                .keyboardType(.decimalPad)
                            Text(unit.shortLabel)
                                .foregroundStyle(IronHerTheme.secondaryText)
                        }
                    }
                } header: {
                    Text(l10n.t(.increment))
                } footer: {
                    Text(l10n.t(.increment_prompt_footer))
                        .font(SheLiftsFont.caption)
                }
            }
            .navigationTitle(l10n.t(.set_increment))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(l10n.t(.skip)) {
                        finishWithoutSaving()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(l10n.t(.save)) {
                        saveAndFinish()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            .onAppear {
                if let first = presets.first {
                    selectedDisplay = first
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var canSave: Bool {
        if useCustom {
            return customDisplay > 0
        }
        return selectedDisplay != nil && (selectedDisplay ?? 0) > 0
    }

    private func saveAndFinish() {
        let display: Double
        if useCustom {
            display = customDisplay
        } else if let selectedDisplay {
            display = selectedDisplay
        } else {
            return
        }
        let kg = WeightFormatter.kilograms(from: display, unit: unit)
        guard kg > 0 else { return }
        settingsStore.exerciseIncrementOverridesKg[exercise.id] = kg
        onComplete()
        dismiss()
    }

    private func finishWithoutSaving() {
        onComplete()
        dismiss()
    }
}
