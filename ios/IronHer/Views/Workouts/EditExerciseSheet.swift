import SwiftUI

struct EditExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UserSettingsStore.self) private var settingsStore
    @Environment(ExerciseProgressionStore.self) private var progressionStore
    @Environment(GlobalExerciseProgressStore.self) private var globalProgressStore
    @Environment(WorkoutStore.self) private var workoutStore
    @Environment(LocalizationStore.self) private var l10n

    let exercise: Exercise
    @State var sets: Int
    @State var reps: Int
    @State var startingWeight: Double
    @State var durationSeconds: Int
    @State var distanceMeters: Double
    let onSave: (Int, Int, Double, Int, Double) -> Void

    @State private var weightInput = 0.0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ExerciseThumbnailSlot(exercise: exercise, size: 72) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.localizedName(using: l10n))
                                .font(SheLiftsFont.section)
                                .foregroundStyle(IronHerTheme.primaryText)

                            Text(exercise.listSubtitle)
                                .font(SheLiftsFont.subheadline)
                                .foregroundStyle(IronHerTheme.secondaryText)

                            Text(ExerciseTrackingFormatter.trackingLabel(for: exercise))
                                .font(SheLiftsFont.caption)
                                .foregroundStyle(IronHerTheme.secondaryText)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Tracking") {
                    ExerciseTrackingFields(
                        exercise: exercise,
                        sets: $sets,
                        reps: $reps,
                        weightInput: $weightInput,
                        durationSeconds: $durationSeconds,
                        distanceMeters: $distanceMeters
                    )
                }

                ProgressionConfigurationPicker(exerciseId: exercise.id) { configuration in
                    sets = configuration.targetSets
                    globalProgressStore.applyTargetSets(
                        configuration.targetSets,
                        for: [exercise.id],
                        into: workoutStore
                    )
                }

                Section {
                    Button("Save changes") {
                        let unit = globalProgressStore.resolvedWeightUnit(
                            for: exercise.id,
                            defaultUnit: settingsStore.weightUnit
                        )
                        let weightKg = WeightFormatter.kilograms(from: weightInput, unit: unit)
                        onSave(sets, reps, weightKg, durationSeconds, distanceMeters)
                        dismiss()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundStyle(IronHerTheme.accent)
                }
            }
            .navigationTitle("Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                let unit = globalProgressStore.resolvedWeightUnit(
                    for: exercise.id,
                    defaultUnit: settingsStore.weightUnit
                )
                weightInput = WeightFormatter.displayValue(kg: startingWeight, unit: unit)
            }
        }
    }
}

// MARK: - Define Your Progression

struct ExerciseProgressionSettingsView: View {
    @Environment(UserSettingsStore.self) private var settingsStore
    @Environment(ExerciseProgressionStore.self) private var progressionStore
    @Environment(GlobalExerciseProgressStore.self) private var globalProgressStore
    @Environment(WorkoutStore.self) private var workoutStore
    @Environment(LocalizationStore.self) private var l10n

    let exercise: Exercise

    @State private var rule: ExerciseProgressionRule
    @State private var weightIncrementDisplay = 0.0
    @State private var stepInputs: [String] = ["8", "12", "15"]
    @State private var durationInputs: [String] = ["30", "45", "60"]

    init(exercise: Exercise) {
        self.exercise = exercise
        let defaultIncrement = EquipmentDefaults.defaultIncrementKg(for: exercise.equipment)
        _rule = State(
            initialValue: ExerciseProgressionRule.recommended(
                for: exercise,
                weightIncrementKg: defaultIncrement
            )
        )
    }

    private var resolvedUnit: WeightUnit {
        globalProgressStore.resolvedWeightUnit(
            for: exercise.id,
            defaultUnit: settingsStore.weightUnit
        )
    }

    private var previewWeightKg: Double {
        globalProgressStore.workingWeightKg(for: exercise.id)
            ?? workoutStore.knownStartingWeight(for: exercise.id)
            ?? 0
    }

    private var previewLines: [String] {
        rule.cyclePreviewLines(
            startingWeightKg: previewWeightKg > 0 ? previewWeightKg : 10,
            weightUnit: resolvedUnit,
            measurement: exercise.measurementUnit
        )
    }

    var body: some View {
        Form {
            Section {
                Text(exercise.localizedName(using: l10n))
                    .font(SheLiftsFont.bodyMedium)
                Text(BrandIdentity.progressionRemembers)
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
            }

            Section("Recommended presets") {
                ForEach(availablePresets) { preset in
                    Button {
                        applyPreset(preset)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preset.title)
                                .font(SheLiftsFont.bodyMedium)
                                .foregroundStyle(IronHerTheme.primaryText)
                            Text(preset.subtitle)
                                .font(SheLiftsFont.caption)
                                .foregroundStyle(IronHerTheme.secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("How do you want to progress?") {
                if supportsWeightAndTimeProgress {
                    ForEach(WeightTimeProgressChoice.allCases) { choice in
                        Button {
                            applyWeightTimeChoice(choice)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: weightTimeChoice == choice ? "largecircle.fill.circle" : "circle")
                                    .foregroundStyle(IronHerTheme.primaryText)
                                Text(choice.label)
                                    .font(SheLiftsFont.body)
                                    .foregroundStyle(IronHerTheme.primaryText)
                                Spacer(minLength: 0)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    ForEach(availableMethods) { method in
                        Button {
                            rule.method = method
                            save()
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: rule.method == method ? "largecircle.fill.circle" : "circle")
                                    .foregroundStyle(IronHerTheme.primaryText)
                                Text(method.label)
                                    .font(SheLiftsFont.body)
                                    .foregroundStyle(IronHerTheme.primaryText)
                                Spacer(minLength: 0)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if rule.method != .manual {
                Section("How many sets?") {
                    Stepper("\(rule.targetSets) sets", value: $rule.targetSets, in: 1...10)
                }

                if showsRepLadder {
                    Section("Your repetition progression") {
                        ForEach(stepInputs.indices, id: \.self) { index in
                            HStack {
                                Text(index == 0 ? "Start" : index == stepInputs.count - 1 ? "Maximum" : "Step \(index + 1)")
                                Spacer()
                                TextField("0", text: $stepInputs[index])
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 64)
                                Text("reps")
                                    .foregroundStyle(IronHerTheme.secondaryText)
                            }
                        }

                        Button("Add rep step") {
                            stepInputs.append("\( (Int(stepInputs.last ?? "12") ?? 12) + 2 )")
                            syncStepsFromInputs()
                        }

                        if stepInputs.count > 2 {
                            Button("Remove last step", role: .destructive) {
                                stepInputs.removeLast()
                                syncStepsFromInputs()
                            }
                        }
                    }
                }

                if showsDurationLadder {
                    Section("Duration progression") {
                        ForEach(durationInputs.indices, id: \.self) { index in
                            HStack {
                                Text(index == 0 ? "Start" : index == durationInputs.count - 1 ? "Maximum" : "Step \(index + 1)")
                                Spacer()
                                TextField("0", text: $durationInputs[index])
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 64)
                                Text("sec")
                                    .foregroundStyle(IronHerTheme.secondaryText)
                            }
                        }
                    }
                }

                if showsWeightIncrement {
                    Section("Weight Increment") {
                        ForEach(WeightFormatter.commonIncrements(for: resolvedUnit), id: \.self) { increment in
                            Button {
                                weightIncrementDisplay = increment
                            } label: {
                                HStack {
                                    Text("+\(WeightFormatter.formatDisplay(increment, unit: resolvedUnit))")
                                        .foregroundStyle(IronHerTheme.primaryText)
                                    Spacer()
                                    if abs(weightIncrementDisplay - increment) < 0.001 {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(IronHerTheme.primaryText)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        HStack {
                            Text("Custom")
                            Spacer()
                            TextField("0", value: $weightIncrementDisplay, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 72)
                            Text(resolvedUnit.shortLabel)
                                .foregroundStyle(IronHerTheme.secondaryText)
                        }

                        if showsRepLadder {
                            Text("After increasing weight, restart at \(rule.startingReps) reps.")
                                .font(SheLiftsFont.caption)
                                .foregroundStyle(IronHerTheme.secondaryText)
                        }
                    }
                    .id("weight-increment-\(exercise.id)-\(resolvedUnit.rawValue)")
                }

                if showsTimeIncrement {
                    Section("Time Increment") {
                        Stepper(
                            "+\(rule.durationIncrementSeconds) sec",
                            value: $rule.durationIncrementSeconds,
                            in: 1...60,
                            step: 1
                        )
                    }
                }

                if showsDistanceIncrement {
                    Section("Distance Increment") {
                        HStack {
                            Text("+\(String(format: "%g", rule.distanceIncrementMeters)) m")
                            Spacer()
                            Stepper(
                                "",
                                value: $rule.distanceIncrementMeters,
                                in: 1...500,
                                step: 5
                            )
                            .labelsHidden()
                        }
                    }
                }

                if !previewLines.isEmpty {
                    Section("Your progression") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(previewLines.enumerated()), id: \.offset) { index, line in
                                Text(line)
                                    .font(SheLiftsFont.bodyMedium)
                                    .foregroundStyle(IronHerTheme.primaryText)
                                if index < previewLines.count - 1 {
                                    Text("↓")
                                        .font(SheLiftsFont.caption)
                                        .foregroundStyle(IronHerTheme.secondaryText)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Summary") {
                    Text(rule.recommendedSummary)
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)
                }
            }
        }
        .navigationTitle("Progression")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
        .onChange(of: rule.targetSets) { _, _ in save() }
        .onChange(of: rule.increaseWeightAfterDurationCycle) { _, _ in save() }
        .onChange(of: rule.multiMetricMode) { _, _ in save() }
        .onChange(of: rule.durationIncrementSeconds) { _, _ in save() }
        .onChange(of: rule.distanceIncrementMeters) { _, _ in save() }
        .onChange(of: settingsStore.weightUnit) { _, _ in refreshIncrementDisplay() }
        .onChange(of: globalProgressStore.weightUnitPreference(for: exercise.id)) { _, _ in
            refreshIncrementDisplay()
        }
        .onChange(of: weightIncrementDisplay) { _, newValue in
            rule.weightIncrementKg = WeightFormatter.kilograms(from: newValue, unit: resolvedUnit)
            save()
        }
        .onChange(of: stepInputs) { _, _ in
            syncStepsFromInputs()
        }
        .onChange(of: durationInputs) { _, _ in
            syncDurationsFromInputs()
        }
    }

    private var availablePresets: [ProgressionPreset] {
        if exercise.measurementUnit == .reps || exercise.measurementUnit == .bodyweight {
            return [.double815, .simple812, .highRep1015, .manual]
        }
        return ProgressionPreset.allCases
    }

    private var availableMethods: [ProgressionMethodChoice] {
        var methods: [ProgressionMethodChoice] = [.manual]
        let profile = exercise.trackingProfile
        if profile.supports(.weight), profile.supports(.reps) {
            methods.insert(.doubleProgression, at: 0)
        }
        if profile.supports(.reps) {
            methods.insert(.repsOnly, at: methods.count - 1)
        }
        if profile.supports(.time) {
            methods.insert(.durationCycle, at: methods.count - 1)
        }
        if profile.supports(.sets) {
            methods.insert(.setsProgression, at: methods.count - 1)
        }
        if profile.supports(.distance) {
            methods.insert(.distanceProgression, at: methods.count - 1)
        }
        // Preserve order uniqueness
        var seen = Set<ProgressionMethodChoice>()
        return methods.filter { seen.insert($0).inserted }
    }

    private var showsRepLadder: Bool {
        !supportsWeightAndTimeProgress
            && (rule.method == .doubleProgression || rule.method == .repsOnly)
    }

    private var showsDurationLadder: Bool {
        // Weight/time carries use simple time increments, not duration ladders.
        !supportsWeightAndTimeProgress && rule.method == .durationCycle
    }

    private var supportsWeightAndTimeProgress: Bool {
        exercise.trackingProfile.supports(.weight) && exercise.trackingProfile.supports(.time)
    }

    private var weightTimeChoice: WeightTimeProgressChoice {
        WeightTimeProgressChoice(from: rule)
    }

    private var showsWeightIncrement: Bool {
        if supportsWeightAndTimeProgress {
            return weightTimeChoice == .weight || weightTimeChoice == .both
        }
        return rule.activeProgressionIncludesWeight(for: exercise)
    }

    private var showsDistanceIncrement: Bool {
        rule.method == .distanceProgression
            || (rule.multiMetricMode == .both && exercise.trackingProfile.supports(.distance))
    }

    private var showsTimeIncrement: Bool {
        if supportsWeightAndTimeProgress {
            return weightTimeChoice == .time || weightTimeChoice == .both
        }
        return rule.method == .durationCycle
    }

    private func applyWeightTimeChoice(_ choice: WeightTimeProgressChoice) {
        let weightKg = max(
            0.25,
            rule.weightIncrementKg > 0
                ? rule.weightIncrementKg
                : settingsStore.incrementKg(for: exercise)
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
        weightIncrementDisplay = WeightFormatter.displayValue(kg: weightKg, unit: resolvedUnit)
        save()
    }

    private func load() {
        rule = progressionStore.rule(
            for: exercise,
            weightIncrementKg: settingsStore.incrementKg(for: exercise)
        )
        stepInputs = rule.normalizedRepSteps.map(String.init)
        durationInputs = rule.normalizedDurationSteps.map(String.init)
        weightIncrementDisplay = WeightFormatter.displayValue(
            kg: rule.weightIncrementKg,
            unit: resolvedUnit
        )
    }

    private func applyPreset(_ preset: ProgressionPreset) {
        let method: ProgressionMethodChoice? = {
            switch exercise.measurementUnit {
            case .reps, .bodyweight: return preset == .manual ? .manual : .repsOnly
            case .time, .weightAndTime: return preset == .manual ? .manual : .durationCycle
            default: return preset == .manual ? .manual : .doubleProgression
            }
        }()

        rule = .preset(
            preset,
            sets: rule.targetSets,
            weightIncrementKg: settingsStore.incrementKg(for: exercise),
            method: method
        )
        stepInputs = rule.normalizedRepSteps.map(String.init)
        durationInputs = rule.normalizedDurationSteps.map(String.init)
        weightIncrementDisplay = WeightFormatter.displayValue(
            kg: rule.weightIncrementKg,
            unit: resolvedUnit
        )
        save()
    }

    private func syncStepsFromInputs() {
        let values = stepInputs.compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }.filter { $0 > 0 }
        if !values.isEmpty {
            rule.repSteps = values
            save()
        }
    }

    private func syncDurationsFromInputs() {
        let values = durationInputs.compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }.filter { $0 > 0 }
        if !values.isEmpty {
            rule.durationSteps = values
            save()
        }
    }

    private func refreshIncrementDisplay() {
        weightIncrementDisplay = WeightFormatter.displayValue(
            kg: rule.weightIncrementKg,
            unit: resolvedUnit
        )
    }

    private func save() {
        progressionStore.updateRule(rule, for: exercise.id)
    }
}

#Preview {
    EditExerciseSheet(
        exercise: ExerciseCatalog.all[0],
        sets: 3,
        reps: 10,
        startingWeight: 40,
        durationSeconds: 0,
        distanceMeters: 0
    ) { _, _, _, _, _ in }
    .environment(UserSettingsStore())
    .environment(ExerciseProgressionStore())
    .environment(GlobalExerciseProgressStore())
    .environment(WorkoutStore())
    .environment(LocalizationStore())
}
