import SwiftUI

struct ExerciseTrackingFields: View {
    @Environment(UserSettingsStore.self) private var settingsStore
    @Environment(GlobalExerciseProgressStore.self) private var globalProgressStore

    let exercise: Exercise
    @Binding var sets: Int
    @Binding var reps: Int
    @Binding var weightInput: Double
    @Binding var durationSeconds: Int
    @Binding var distanceMeters: Double

    /// When true, weightInput is already in the exercise's resolved display unit.
    var usesDisplayUnits: Bool = true

    private var profile: ExerciseTrackingProfile { exercise.trackingProfile }

    private var resolvedUnit: WeightUnit {
        globalProgressStore.resolvedWeightUnit(
            for: exercise.id,
            defaultUnit: settingsStore.weightUnit
        )
    }

    private var showsUnitPicker: Bool {
        profile.supports(.weight)
    }

    var body: some View {
        Group {
            if profile.supports(.sets) {
                setsStepper
            }
            if profile.supports(.reps) {
                repsStepper
            }
            if profile.supports(.weight) {
                if exercise.tracksOptionalWeight {
                    optionalWeightField
                    if weightInput > 0 {
                        unitPicker
                    }
                } else {
                    weightField(label: exercise.weightFieldLabel)
                    unitPicker
                    weightCaption
                }
            }
            if profile.supports(.time) {
                durationStepper
            }
            if profile.supports(.distance) {
                distanceField
            }

            if !profile.supports(.weight), profile.supports(.reps) {
                progressionNote("Progress through reps, sets, tempo, or added external weight when applicable.")
            }
        }
    }

    private var setsStepper: some View {
        Stepper("Sets: \(sets)", value: $sets, in: 1...10)
    }

    private var repsStepper: some View {
        Stepper("\(exercise.repsFieldLabel): \(reps)", value: $reps, in: 1...100)
    }

    private var durationStepper: some View {
        Stepper(
            "Duration: \(ExerciseTrackingFormatter.formatDuration(seconds: durationSeconds))",
            value: $durationSeconds,
            in: 5...600,
            step: 5
        )
    }

    private func weightField(label: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField(
                "0",
                value: $weightInput,
                format: .number.precision(.fractionLength(0...1))
            )
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 100)
            Text(resolvedUnit.shortLabel)
                .foregroundStyle(IronHerTheme.secondaryText)
        }
    }

    @ViewBuilder
    private var unitPicker: some View {
        if showsUnitPicker {
            Picker("Weight Unit", selection: unitPreferenceBinding) {
                ForEach(ExerciseWeightUnitPreference.allCases) { preference in
                    Text(preference.label).tag(preference)
                }
            }
        }
    }

    private var unitPreferenceBinding: Binding<ExerciseWeightUnitPreference> {
        Binding(
            get: { globalProgressStore.weightUnitPreference(for: exercise.id) },
            set: { newPreference in
                let oldUnit = resolvedUnit
                let oldDisplay = weightInput
                globalProgressStore.setWeightUnitPreference(newPreference, for: exercise.id)
                let newUnit = newPreference.resolved(defaultUnit: settingsStore.weightUnit)
                // Preserve physical load: convert display value when the user changes units.
                if usesDisplayUnits, oldUnit != newUnit {
                    let kg = WeightFormatter.kilograms(from: oldDisplay, unit: oldUnit)
                    weightInput = WeightFormatter.displayValue(kg: kg, unit: newUnit)
                }
            }
        )
    }

    @ViewBuilder
    private var weightCaption: some View {
        if let caption = exercise.weightFieldCaption {
            Text(caption)
                .font(SheLiftsFont.caption)
                .foregroundStyle(IronHerTheme.secondaryText)
        }
    }

    private var optionalWeightField: some View {
        VStack(alignment: .leading, spacing: 6) {
            weightField(label: exercise.displaysWeightPerHand ? "Weight per dumbbell (optional)" : "Weight (optional)")
            if let caption = exercise.weightFieldCaption {
                Text(caption)
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
            } else {
                Text("Leave at 0 for bodyweight.")
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
            }
        }
    }

    private var distanceField: some View {
        HStack {
            Text("Distance (m)")
            Spacer()
            TextField("0", value: $distanceMeters, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 100)
        }
    }

    private func progressionNote(_ text: String) -> some View {
        Text(text)
            .font(SheLiftsFont.caption)
            .foregroundStyle(IronHerTheme.secondaryText)
    }
}
