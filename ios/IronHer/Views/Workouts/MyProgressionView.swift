import SwiftUI

/// Progression Rules — simple per-category defaults used when tracking workouts.
struct MyProgressionView: View {
    @Environment(ExerciseProgressionStore.self) private var progressionStore
    @Environment(UserSettingsStore.self) private var settingsStore

    @State private var draft: ProgressionCategoryDefaults = .default

    private var unit: WeightUnit { settingsStore.weightUnit }

    var body: some View {
        Form {
            Section {
                Text("Define how you normally progress. trenira will automatically apply these rules when tracking your workouts.")
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
            }

            weightedSection
            bodyweightSection
            timedSection
        }
        .navigationTitle("Progression Rules")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            draft = progressionStore.categoryDefaults
        }
        .onChange(of: settingsStore.weightUnit) { oldUnit, newUnit in
            // Display binding already converts; keep stored kg values, refresh UI.
            _ = (oldUnit, newUnit)
            draft = progressionStore.categoryDefaults
        }
    }

    // MARK: - Weighted

    private var weightedSection: some View {
        Section {
            Text("Increase weight when you complete:")
                .font(SheLiftsFont.caption)
                .foregroundStyle(IronHerTheme.secondaryText)

            Stepper(value: strengthSetsBinding, in: 1...10) {
                Text("\(draft.strengthTargetSets) sets")
            }

            Stepper(value: strengthThresholdBinding, in: draft.strengthStartingReps...50) {
                Text("\(draft.strengthThresholdReps) reps")
            }

            Text("Next workout starts with:")
                .font(SheLiftsFont.caption)
                .foregroundStyle(IronHerTheme.secondaryText)
                .padding(.top, 4)

            Stepper(value: strengthStartingBinding, in: 1...draft.strengthThresholdReps) {
                Text("\(draft.strengthTargetSets) sets · \(draft.strengthStartingReps) reps")
            }

            weightIncrementPicker
        } header: {
            Text("Weighted exercises")
        } footer: {
            Text("Used for every weighted exercise unless you override it on that exercise.")
                .font(SheLiftsFont.caption)
        }
    }

    private var weightIncrementPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Weight increment")
                .font(SheLiftsFont.caption)
                .foregroundStyle(IronHerTheme.secondaryText)

            let presets = WeightFormatter.commonIncrements(for: unit)
            ForEach(presets, id: \.self) { display in
                Button {
                    draft.defaultWeightIncrementKg = WeightFormatter.kilograms(from: display, unit: unit)
                    persist()
                } label: {
                    HStack {
                        Text("+\(WeightFormatter.formatDisplay(display, unit: unit))")
                            .foregroundStyle(IronHerTheme.primaryText)
                        Spacer()
                        if abs(
                            WeightFormatter.displayValue(kg: draft.defaultWeightIncrementKg, unit: unit) - display
                        ) < 0.001 {
                            Image(systemName: "checkmark")
                                .foregroundStyle(IronHerTheme.primaryText)
                        }
                    }
                }
            }

            HStack {
                Text("Custom")
                Spacer()
                TextField(
                    "",
                    value: Binding(
                        get: {
                            WeightFormatter.displayValue(kg: draft.defaultWeightIncrementKg, unit: unit)
                        },
                        set: { display in
                            draft.defaultWeightIncrementKg = WeightFormatter.kilograms(from: display, unit: unit)
                            persist()
                        }
                    ),
                    format: .number
                )
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 72)
                Text(unit.shortLabel)
                    .foregroundStyle(IronHerTheme.secondaryText)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Bodyweight

    private var bodyweightSection: some View {
        Section {
            ForEach(ProgressionTrainingCategory.bodyweight.allowedDimensions) { dimension in
                Button {
                    draft.setRule(dimension, for: .bodyweight)
                    persist()
                } label: {
                    HStack {
                        Text(dimension.label)
                            .foregroundStyle(IronHerTheme.primaryText)
                        Spacer()
                        if draft.bodyweightRule == dimension {
                            Image(systemName: "checkmark")
                                .foregroundStyle(IronHerTheme.primaryText)
                        }
                    }
                }
            }

            if draft.bodyweightRule == .reps {
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
                    Text("Increase by +\(draft.defaultRepIncrement) rep\(draft.defaultRepIncrement == 1 ? "" : "s")")
                }
            } else if draft.bodyweightRule == .sets {
                Text("Increase by +1 set when all sets hit the target reps.")
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
            } else if draft.bodyweightRule == .time {
                durationIncrementControls
            }
        } header: {
            Text("Bodyweight exercises")
        } footer: {
            Text("Choose how bodyweight work progresses. Hold time applies to static moves.")
                .font(SheLiftsFont.caption)
        }
    }

    // MARK: - Timed

    private var timedSection: some View {
        Section {
            durationIncrementControls
        } header: {
            Text("Timed exercises")
        } footer: {
            Text("For planks, wall sits, dead hangs, and other timed holds.")
                .font(SheLiftsFont.caption)
        }
    }

    private var durationIncrementControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Increase timer by")
                .font(SheLiftsFont.caption)
                .foregroundStyle(IronHerTheme.secondaryText)

            ForEach([5, 10, 15], id: \.self) { seconds in
                Button {
                    draft.defaultDurationIncrementSeconds = seconds
                    persist()
                } label: {
                    HStack {
                        Text("+\(seconds) sec")
                            .foregroundStyle(IronHerTheme.primaryText)
                        Spacer()
                        if draft.defaultDurationIncrementSeconds == seconds {
                            Image(systemName: "checkmark")
                                .foregroundStyle(IronHerTheme.primaryText)
                        }
                    }
                }
            }

            Stepper(
                value: Binding(
                    get: { draft.defaultDurationIncrementSeconds },
                    set: {
                        draft.defaultDurationIncrementSeconds = $0
                        persist()
                    }
                ),
                in: 1...60,
                step: 1
            ) {
                Text("Custom: +\(draft.defaultDurationIncrementSeconds) sec")
            }
        }
    }

    // MARK: - Bindings

    private var strengthSetsBinding: Binding<Int> {
        Binding(
            get: { draft.strengthTargetSets },
            set: {
                draft.strengthTargetSets = $0
                persist()
            }
        )
    }

    private var strengthThresholdBinding: Binding<Int> {
        Binding(
            get: { draft.strengthThresholdReps },
            set: {
                draft.strengthThresholdReps = max(draft.strengthStartingReps, $0)
                persist()
            }
        )
    }

    private var strengthStartingBinding: Binding<Int> {
        Binding(
            get: { draft.strengthStartingReps },
            set: {
                draft.strengthStartingReps = min(draft.strengthThresholdReps, max(1, $0))
                persist()
            }
        )
    }

    private func persist() {
        // Force weight progression for the weighted category (product model).
        draft.strengthRule = .weight
        draft.timedRule = .time
        progressionStore.updateCategoryDefaults(draft)
        // Keep legacy default configuration ladder in sync.
        progressionStore.syncDefaultConfigurationFromCategoryDefaults()
    }
}

/// Per-exercise progression: use global rule, or override.
struct ExerciseProgressionFields: View {
    @Environment(ExerciseProgressionStore.self) private var progressionStore
    @Environment(UserSettingsStore.self) private var settingsStore
    @Environment(GlobalExerciseProgressStore.self) private var globalProgressStore

    let exercise: Exercise
    var onSetsChanged: ((Int) -> Void)? = nil

    @State private var useCustom = false
    @State private var incrementDisplay: Double = 0
    @State private var timeIncrementSeconds: Int = 5
    @State private var suppressUpdates = false

    private var category: ProgressionTrainingCategory {
        ProgressionTrainingCategory.category(for: exercise)
    }

    private var selectedDimension: ProgressionDimension {
        progressionStore.dimension(for: exercise)
    }

    /// Weight + time (e.g. Farmer's Carry) — show Progress: Weight / Time / Both.
    private var supportsWeightAndTimeProgress: Bool {
        exercise.trackingProfile.supports(.weight) && exercise.trackingProfile.supports(.time)
    }

    /// Always matches this exercise's weight unit (not the global Settings unit alone).
    private var unit: WeightUnit {
        globalProgressStore.resolvedWeightUnit(
            for: exercise.id,
            defaultUnit: settingsStore.weightUnit
        )
    }

    private var effectiveRule: ExerciseProgressionRule {
        progressionStore.rule(
            for: exercise,
            weightIncrementKg: settingsStore.incrementKg(for: exercise)
        )
    }

    private var weightTimeChoice: WeightTimeProgressChoice {
        WeightTimeProgressChoice(from: effectiveRule)
    }

    var body: some View {
        Section {
            Button {
                useCustom = false
                progressionStore.setDimension(nil, for: exercise)
                progressionStore.removeCustomRule(for: exercise.id)
            } label: {
                HStack {
                    Text("Use global progression rule")
                        .foregroundStyle(IronHerTheme.primaryText)
                    Spacer()
                    if !progressionStore.hasDimensionOverride(for: exercise.id)
                        && !progressionStore.hasCustomRule(for: exercise.id) {
                        Image(systemName: "checkmark")
                            .foregroundStyle(IronHerTheme.primaryText)
                    }
                }
            }

            Button {
                useCustom = true
                if supportsWeightAndTimeProgress {
                    applyWeightTimeChoice(weightTimeChoice)
                } else if !progressionStore.hasDimensionOverride(for: exercise.id) {
                    progressionStore.setDimension(selectedDimension, for: exercise, forceOverride: true)
                }
            } label: {
                HStack {
                    Text("Custom progression for this exercise")
                        .foregroundStyle(IronHerTheme.primaryText)
                    Spacer()
                    if progressionStore.hasDimensionOverride(for: exercise.id)
                        || progressionStore.hasCustomRule(for: exercise.id) {
                        Image(systemName: "checkmark")
                            .foregroundStyle(IronHerTheme.primaryText)
                    }
                }
            }
        } header: {
            Text("Progression")
        } footer: {
            Text("Defaults come from Progression Rules. Override only when this exercise needs different behaviour.")
                .font(SheLiftsFont.caption)
        }

        // Multi-metric (weight + time) — always visible, not behind Custom.
        if supportsWeightAndTimeProgress {
            weightTimeProgressSection
            if showsWeightIncrementFields {
                weightIncrementSection
            }
            if showsTimeIncrementFields {
                timeIncrementSection
            }
        } else if progressionStore.hasDimensionOverride(for: exercise.id)
            || progressionStore.hasCustomRule(for: exercise.id)
            || useCustom {
            standardDimensionSection
            if showsWeightIncrementFields {
                weightIncrementSection
            }
        } else {
            Color.clear.frame(height: 0).onAppear {
                useCustom = progressionStore.hasDimensionOverride(for: exercise.id)
                    || progressionStore.hasCustomRule(for: exercise.id)
            }
        }
    }

    private var showsWeightIncrementFields: Bool {
        if supportsWeightAndTimeProgress {
            return weightTimeChoice == .weight || weightTimeChoice == .both
        }
        guard progressionStore.hasDimensionOverride(for: exercise.id)
            || progressionStore.hasCustomRule(for: exercise.id)
            || useCustom else { return false }
        return selectedDimension == .weight
    }

    private var showsTimeIncrementFields: Bool {
        guard supportsWeightAndTimeProgress else { return false }
        return weightTimeChoice == .time || weightTimeChoice == .both
    }

    private var weightTimeProgressSection: some View {
        Section {
            ForEach(WeightTimeProgressChoice.allCases) { choice in
                Button {
                    applyWeightTimeChoice(choice)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: weightTimeChoice == choice ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(IronHerTheme.primaryText)
                        Text(choice.label)
                            .foregroundStyle(IronHerTheme.primaryText)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Progress")
        } footer: {
            Text("Choose whether weight, time, or both increase after a successful session.")
                .font(SheLiftsFont.caption)
        }
    }

    private var standardDimensionSection: some View {
        Section {
            ForEach(category.allowedDimensions) { dimension in
                Button {
                    progressionStore.setDimension(dimension, for: exercise, forceOverride: true)
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
            Text("How this exercise progresses")
        }
    }

    private var weightIncrementSection: some View {
        Section {
            ForEach(
                WeightFormatter.contextualIncrements(for: exercise.equipment, unit: unit),
                id: \.self
            ) { value in
                Button {
                    suppressUpdates = true
                    incrementDisplay = value
                    suppressUpdates = false
                    persistWeightIncrement()
                } label: {
                    HStack {
                        Text("+\(WeightFormatter.formatDisplay(value, unit: unit))")
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
                Text("Custom")
                Spacer()
                TextField("Increment", value: $incrementDisplay, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 72)
                    .onChange(of: incrementDisplay) { _, _ in
                        guard !suppressUpdates else { return }
                        persistWeightIncrement()
                    }
                Text(unit.shortLabel)
                    .foregroundStyle(IronHerTheme.secondaryText)
            }
        } header: {
            Text("Weight Increment (\(unit.shortLabel))")
        } footer: {
            Text("Stored in kilograms internally. Display matches this exercise's unit.")
                .font(SheLiftsFont.caption)
        }
        .id("increment-\(exercise.id)-\(unit.rawValue)")
        .onAppear {
            useCustom = progressionStore.hasDimensionOverride(for: exercise.id)
                || progressionStore.hasCustomRule(for: exercise.id)
            syncIncrementsFromRule()
        }
        .onChange(of: settingsStore.weightUnit) { _, _ in syncIncrementsFromRule() }
        .onChange(of: globalProgressStore.weightUnitPreference(for: exercise.id)) { _, _ in
            syncIncrementsFromRule()
        }
    }

    private var timeIncrementSection: some View {
        Section {
            Stepper(
                "+\(timeIncrementSeconds) sec",
                value: $timeIncrementSeconds,
                in: 1...60,
                step: 1
            )
            .onChange(of: timeIncrementSeconds) { _, _ in
                persistTimeIncrement()
            }
        } header: {
            Text("Time Increment")
        } footer: {
            Text("Added to hold/carry duration after a successful session.")
                .font(SheLiftsFont.caption)
        }
        .onAppear {
            syncIncrementsFromRule()
        }
    }

    private func applyWeightTimeChoice(_ choice: WeightTimeProgressChoice) {
        useCustom = true
        // Selecting a progress mode always writes a custom rule so Both/Weight/Time persist.
        var rule = effectiveRule
        let weightKg = max(
            0.25,
            settingsStore.incrementKg(for: exercise) > 0
                ? settingsStore.incrementKg(for: exercise)
                : (exercise.trackingProfile.defaultWeightIncrementKg ?? 2.5)
        )
        let seconds = max(
            1,
            rule.durationIncrementSeconds > 0
                ? rule.durationIncrementSeconds
                : (exercise.trackingProfile.defaultDurationIncrementSeconds ?? 5)
        )

        rule.method = .durationCycle
        rule.weightIncrementKg = weightKg
        switch choice {
        case .time:
            rule.multiMetricMode = .primary
            rule.increaseWeightAfterDurationCycle = false
            rule.durationIncrementSeconds = seconds
        case .weight:
            rule.multiMetricMode = .secondary
            rule.increaseWeightAfterDurationCycle = true
            rule.durationIncrementSeconds = 0
        case .both:
            rule.multiMetricMode = .both
            rule.increaseWeightAfterDurationCycle = false
            rule.durationIncrementSeconds = seconds
        }
        progressionStore.updateRule(rule, for: exercise.id)
        syncIncrementsFromRule()
    }

    private func syncIncrementsFromRule() {
        suppressUpdates = true
        let rule = effectiveRule
        incrementDisplay = WeightFormatter.displayValue(kg: rule.weightIncrementKg, unit: unit)
        timeIncrementSeconds = max(1, rule.durationIncrementSeconds > 0 ? rule.durationIncrementSeconds : 5)
        suppressUpdates = false
    }

    private func persistWeightIncrement() {
        let kg = WeightFormatter.kilograms(from: incrementDisplay, unit: unit)
        guard kg > 0 else { return }
        settingsStore.exerciseIncrementOverridesKg[exercise.id] = kg
        var rule = effectiveRule
        rule.weightIncrementKg = kg
        progressionStore.updateRule(rule, for: exercise.id)
    }

    private func persistTimeIncrement() {
        var rule = effectiveRule
        rule.durationIncrementSeconds = max(1, timeIncrementSeconds)
        if rule.multiMetricMode == .both || WeightTimeProgressChoice(from: rule) == .time {
            rule.multiMetricMode = rule.multiMetricMode == .secondary ? .both : rule.multiMetricMode
            if rule.multiMetricMode == .primary || rule.multiMetricMode == .both {
                rule.increaseWeightAfterDurationCycle = false
            }
        }
        progressionStore.updateRule(rule, for: exercise.id)
    }
}

/// Visible Progress options for weight + time exercises (Farmer's Carry, Weighted Plank, …).
enum WeightTimeProgressChoice: String, CaseIterable, Identifiable {
    case weight
    case time
    case both

    var id: String { rawValue }

    var label: String {
        switch self {
        case .weight: return "Weight"
        case .time: return "Time"
        case .both: return "Both"
        }
    }

    init(from rule: ExerciseProgressionRule) {
        switch rule.multiMetricMode {
        case .both:
            self = .both
        case .secondary:
            self = .weight
        case .primary:
            if rule.increaseWeightAfterDurationCycle {
                self = .weight
            } else {
                self = .time
            }
        }
    }
}

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
