import SwiftUI

struct CreateCustomExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CustomExerciseStore.self) private var customExerciseStore

    let initialName: String
    let onCreated: (Exercise) -> Void

    @State private var name: String
    @State private var primaryMuscle: MuscleGroup = .chest
    @State private var equipment: EquipmentType = .dumbbell
    @State private var measurement: MeasurementUnit = .weight
    @State private var progression: ProgressionMethod = .addWeight

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

                Section("Tracking") {
                    Picker("Measurement", selection: $measurement) {
                        ForEach(MeasurementUnit.allCases, id: \.self) { unit in
                            Text(unit.label).tag(unit)
                        }
                    }
                    .onChange(of: measurement) { _, newValue in
                        progression = EquipmentDefaults.defaultProgressionMethod(for: newValue)
                    }

                    Picker("Default progression", selection: $progression) {
                        ForEach(progressionOptions, id: \.self) { method in
                            Text(method.label).tag(method)
                        }
                    }
                }

                Section {
                    Button("Save exercise") {
                        saveExercise()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundStyle(IronHerTheme.accent)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Custom Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var progressionOptions: [ProgressionMethod] {
        switch measurement {
        case .weight: return [.addWeight, .addReps, .addSets]
        case .bodyweight: return [.addReps, .addSets, .addExternalWeight]
        case .time: return [.addDuration, .addSets]
        case .distance: return [.addDistance, .addSets]
        case .reps, .repsWithOptionalWeight: return [.addReps, .addSets, .addExternalWeight]
        case .weightAndTime: return [.addDuration, .addSets, .addWeight]
        }
    }

    private func saveExercise() {
        let exercise = customExerciseStore.add(
            name: name,
            primaryMuscleGroup: primaryMuscle,
            equipment: equipment,
            measurementUnit: measurement,
            progressionMethod: progression
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
