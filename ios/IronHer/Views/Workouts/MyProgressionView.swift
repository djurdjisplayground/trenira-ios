import SwiftUI

/// Defines HOW exercises progress by category, plus default increment sizes.
struct MyProgressionView: View {
    @Environment(ExerciseProgressionStore.self) private var progressionStore
    @Environment(UserSettingsStore.self) private var settingsStore
    @Environment(LocalizationStore.self) private var l10n

    @State private var draft: ProgressionCategoryDefaults = .default

    var body: some View {
        Form {
            Section {
                Text(l10n.t(.progression_rules_intro))
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
            }

            ForEach(ProgressionTrainingCategory.allCases) { category in
                Section {
                    ForEach(category.allowedDimensions) { dimension in
                        Button {
                            draft.setRule(dimension, for: category)
                            persist()
                        } label: {
                            HStack {
                                Text(dimension.label)
                                    .foregroundStyle(IronHerTheme.primaryText)
                                Spacer()
                                if draft.rule(for: category) == dimension {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(IronHerTheme.primaryText)
                                }
                            }
                        }
                    }
                } header: {
                    Text(category.label)
                } footer: {
                    Text(footer(for: category))
                        .font(SheLiftsFont.caption)
                }
            }

            Section {
                weightIncrementRow
                repIncrementRow
                timeIncrementRow
            } header: {
                Text(l10n.t(.default_increments))
            } footer: {
                Text(l10n.t(.default_increments_footer))
                    .font(SheLiftsFont.caption)
            }
        }
        .navigationTitle(l10n.t(.progression_rules))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            draft = progressionStore.categoryDefaults
        }
    }

    private var weightIncrementRow: some View {
        HStack {
            Text(l10n.t(.weight_increment))
            Spacer()
            TextField(
                "",
                value: Binding(
                    get: {
                        WeightFormatter.displayValue(
                            kg: draft.defaultWeightIncrementKg,
                            unit: settingsStore.weightUnit
                        )
                    },
                    set: { display in
                        draft.defaultWeightIncrementKg = WeightFormatter.kilograms(
                            from: display,
                            unit: settingsStore.weightUnit
                        )
                        persist()
                    }
                ),
                format: .number
            )
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 72)
            Text(settingsStore.weightUnit.shortLabel)
                .foregroundStyle(IronHerTheme.secondaryText)
        }
    }

    private var repIncrementRow: some View {
        Stepper(
            value: Binding(
                get: { draft.defaultRepIncrement },
                set: {
                    draft.defaultRepIncrement = $0
                    persist()
                }
            ),
            in: 1...10
        ) {
            Text(l10n.t(.rep_increment_value, draft.defaultRepIncrement))
        }
    }

    private var timeIncrementRow: some View {
        Stepper(
            value: Binding(
                get: { draft.defaultDurationIncrementSeconds },
                set: {
                    draft.defaultDurationIncrementSeconds = $0
                    persist()
                }
            ),
            in: 1...60,
            step: 5
        ) {
            Text(l10n.t(.time_increment_value, draft.defaultDurationIncrementSeconds))
        }
    }

    private func footer(for category: ProgressionTrainingCategory) -> String {
        switch category {
        case .strength: return l10n.t(.progression_strength_footer)
        case .bodyweight: return l10n.t(.progression_bodyweight_footer)
        case .timed: return l10n.t(.progression_timed_footer)
        }
    }

    private func persist() {
        progressionStore.updateCategoryDefaults(draft)
    }
}

/// Per-exercise progression rule + optional weight increment override.
struct ExerciseProgressionFields: View {
    @Environment(ExerciseProgressionStore.self) private var progressionStore
    @Environment(UserSettingsStore.self) private var settingsStore
    @Environment(LocalizationStore.self) private var l10n

    let exercise: Exercise
    var onSetsChanged: ((Int) -> Void)? = nil

    @State private var incrementDisplay: Double = 0
    @State private var suppressUpdates = false

    private var category: ProgressionTrainingCategory {
        ProgressionTrainingCategory.category(for: exercise)
    }

    private var selectedDimension: ProgressionDimension {
        progressionStore.dimension(for: exercise)
    }

    private var unit: WeightUnit {
        settingsStore.weightUnit
    }

    var body: some View {
        Section {
            ForEach(category.allowedDimensions) { dimension in
                Button {
                    progressionStore.setDimension(dimension, for: exercise)
                    if dimension == .weight || dimension == .reps || dimension == .sets {
                        onSetsChanged?(progressionStore.categoryDefaults.strengthTargetSets)
                    }
                } label: {
                    HStack {
                        Text(dimension.label)
                            .foregroundStyle(IronHerTheme.primaryText)
                        Spacer()
                        if selectedDimension == dimension {
                            Image(systemName: "checkmark")
                                .foregroundStyle(IronHerTheme.primaryText)
                        }
                    }
                }
            }
        } header: {
            Text(l10n.t(.progression_rule))
        } footer: {
            Text(l10n.t(.progression_rule_footer))
                .font(SheLiftsFont.caption)
        }

        if selectedDimension == .weight {
            Section {
                ForEach(
                    WeightFormatter.contextualIncrements(for: exercise.equipment, unit: unit),
                    id: \.self
                ) { value in
                    Button {
                        suppressUpdates = true
                        incrementDisplay = value
                        suppressUpdates = false
                        persistIncrement()
                    } label: {
                        HStack {
                            Text(WeightFormatter.formatDisplay(value, unit: unit))
                                .foregroundStyle(IronHerTheme.primaryText)
                            Spacer()
                            if abs(incrementDisplay - value) < 0.001 {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(IronHerTheme.primaryText)
                            }
                        }
                    }
                }

                HStack {
                    Text(l10n.t(.custom))
                    Spacer()
                    TextField(l10n.t(.increment), value: $incrementDisplay, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 72)
                        .onChange(of: incrementDisplay) { _, _ in
                            guard !suppressUpdates else { return }
                            persistIncrement()
                        }
                    Text(unit.shortLabel)
                        .foregroundStyle(IronHerTheme.secondaryText)
                }
            } header: {
                Text(l10n.t(.weight_increment))
            } footer: {
                Text(l10n.t(.exercise_weight_increment_footer))
                    .font(SheLiftsFont.caption)
            }
            .onAppear { syncIncrement() }
            .onChange(of: settingsStore.weightUnit) { _, _ in syncIncrement() }
        }
    }

    private func syncIncrement() {
        suppressUpdates = true
        let kg = settingsStore.incrementKg(for: exercise)
        incrementDisplay = WeightFormatter.displayValue(kg: kg, unit: unit)
        suppressUpdates = false
    }

    private func persistIncrement() {
        let kg = WeightFormatter.kilograms(from: incrementDisplay, unit: unit)
        guard kg > 0 else { return }
        settingsStore.exerciseIncrementOverridesKg[exercise.id] = kg
    }
}

/// Backward-compatible alias used by older call sites.
typealias ProgressionConfigurationPicker = ExerciseProgressionFieldsCompat

struct ExerciseProgressionFieldsCompat: View {
    let exerciseId: String
    var onConfigurationChanged: ((ProgressionConfiguration) -> Void)? = nil

    @Environment(ExerciseProgressionStore.self) private var progressionStore

    var body: some View {
        if let exercise = ExerciseCatalog.exercise(id: exerciseId) {
            ExerciseProgressionFields(exercise: exercise) { sets in
                onConfigurationChanged?(
                    ProgressionConfiguration(
                        id: progressionStore.defaultConfigurationId,
                        name: progressionStore.defaultConfiguration.name,
                        targetSets: sets,
                        startingReps: progressionStore.defaultConfiguration.startingReps,
                        thresholdReps: progressionStore.defaultConfiguration.thresholdReps,
                        weightIncrementKg: progressionStore.categoryDefaults.defaultWeightIncrementKg
                    )
                )
            }
        }
    }
}
