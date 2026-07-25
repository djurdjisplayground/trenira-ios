import SwiftUI

struct CreateCustomExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CustomExerciseStore.self) private var customExerciseStore

    let initialName: String
    let onCreated: (Exercise) -> Void

    @State private var name: String
    @State private var primaryMuscle: MuscleGroup = .chest
    @State private var equipment: EquipmentType = .dumbbell
    @State private var selectedMetrics: Set<MeasurementMetric> = [.weight, .reps, .sets]
    @State private var primaryMetric: MeasurementMetric = .weight
    @State private var secondaryMetric: MeasurementMetric? = nil
    @State private var progressionMode: MultiMetricProgressionMode = .primary
    @State private var showAdvancedProgression = false

    init(initialName: String = "", onCreated: @escaping (Exercise) -> Void) {
        self.initialName = initialName
        self.onCreated = onCreated
        _name = State(initialValue: initialName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section("Details") {
                    Picker("Primary muscle", selection: $primaryMuscle) {
                        ForEach(MuscleGroup.allCases, id: \.self) { group in
                            Text(group.label).tag(group)
                        }
                    }

                    Picker("Equipment", selection: $equipment) {
                        ForEach(EquipmentType.allCases) { type in
                            Text(type.label).tag(type)
                        }
                    }
                }

                Section {
                    ForEach(MeasurementMetric.allCases) { metric in
                        Toggle(metric.label, isOn: metricBinding(metric))
                    }
                } header: {
                    Text("Measurement Types")
                } footer: {
                    Text("Choose what you record each set. Sensible defaults are already selected for most lifts.")
                        .font(SheLiftsFont.caption)
                }

                if selectableProgressionMetrics.count > 1 {
                    Section("Primary Progression Metric") {
                        Picker("Progress by", selection: $primaryMetric) {
                            ForEach(selectableProgressionMetrics, id: \.self) { metric in
                                Text(metric.progressionChoiceLabel).tag(metric)
                            }
                        }
                        .pickerStyle(.inline)
                    }
                }

                if selectableProgressionMetrics.count > 1 {
                    Section {
                        Toggle("Advanced progression", isOn: $showAdvancedProgression)
                        if showAdvancedProgression {
                            Picker("Also progress", selection: secondaryBinding) {
                                Text("None").tag(Optional<MeasurementMetric>.none)
                                ForEach(secondaryOptions, id: \.self) { metric in
                                    Text(metric.label).tag(Optional(metric))
                                }
                            }

                            if secondaryMetric != nil {
                                Picker("Mode", selection: $progressionMode) {
                                    Text(MultiMetricProgressionMode.primary.label).tag(MultiMetricProgressionMode.primary)
                                    Text(MultiMetricProgressionMode.secondary.label).tag(MultiMetricProgressionMode.secondary)
                                    Text(MultiMetricProgressionMode.both.label).tag(MultiMetricProgressionMode.both)
                                }
                            }
                        }
                    } header: {
                        Text("Progression")
                    } footer: {
                        Text("Leave advanced off to progress only the primary metric.")
                            .font(SheLiftsFont.caption)
                    }
                }

                Section {
                    Button("Save exercise") {
                        saveExercise()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundStyle(IronHerTheme.accent)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedMetrics.isEmpty)
                }
            }
            .navigationTitle("Custom Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: selectedMetrics) { _, _ in
                reconcileProgressionSelection()
            }
        }
    }

    private var selectableProgressionMetrics: [MeasurementMetric] {
        MeasurementMetric.allCases.filter { selectedMetrics.contains($0) }
    }

    private var secondaryOptions: [MeasurementMetric] {
        selectableProgressionMetrics.filter { $0 != primaryMetric }
    }

    private var secondaryBinding: Binding<MeasurementMetric?> {
        Binding(
            get: { secondaryMetric },
            set: { newValue in
                secondaryMetric = newValue
                if newValue == nil {
                    progressionMode = .primary
                }
            }
        )
    }

    private func metricBinding(_ metric: MeasurementMetric) -> Binding<Bool> {
        Binding(
            get: { selectedMetrics.contains(metric) },
            set: { isOn in
                if isOn {
                    selectedMetrics.insert(metric)
                } else if selectedMetrics.count > 1 {
                    selectedMetrics.remove(metric)
                }
            }
        )
    }

    private func reconcileProgressionSelection() {
        if !selectedMetrics.contains(primaryMetric) {
            primaryMetric = selectableProgressionMetrics.first(where: { $0 != .sets })
                ?? selectableProgressionMetrics.first
                ?? .reps
        }
        if let secondary = secondaryMetric, !selectedMetrics.contains(secondary) || secondary == primaryMetric {
            secondaryMetric = nil
            progressionMode = .primary
        }
    }

    private func saveExercise() {
        var metrics = MeasurementMetric.allCases.filter { selectedMetrics.contains($0) }
        if !metrics.contains(.sets) {
            metrics.append(.sets)
        }
        let profile = ExerciseTrackingProfile(
            metrics: metrics,
            primaryProgressionMetric: primaryMetric,
            secondaryProgressionMetric: showAdvancedProgression ? secondaryMetric : nil,
            progressionMode: showAdvancedProgression ? progressionMode : .primary
        )
        let exercise = customExerciseStore.add(
            name: name,
            primaryMuscleGroup: primaryMuscle,
            equipment: equipment,
            trackingProfile: profile
        )
        ExerciseCatalog.syncCustomExercises(customExerciseStore.exercises)
        onCreated(exercise)
        dismiss()
    }
}

#Preview {
    CreateCustomExerciseSheet(initialName: "My Exercise") { _ in }
        .environment(CustomExerciseStore())
}
