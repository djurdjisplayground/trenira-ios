import SwiftUI

/// Lets the user set lighter session weights before training.
/// Updates the active session only — progression store is untouched until finish.
struct LighterStartSheet: View {
    @Environment(WorkoutSessionStore.self) private var sessionStore
    @Environment(GlobalExerciseProgressStore.self) private var globalProgressStore
    @Environment(UserSettingsStore.self) private var settingsStore
    @Environment(LocalizationStore.self) private var l10n
    @Environment(\.dismiss) private var dismiss

    let workout: Workout
    let onBegin: () -> Void

    @State private var draftWeightsKg: [UUID: Double] = [:]

    private var weightEntries: [WorkoutExerciseEntry] {
        workout.exercises.filter { entry in
            guard let exercise = ExerciseCatalog.exercise(id: entry.exerciseId) else { return false }
            return exercise.tracksWeight
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(l10n.t(.lighter_start_subtitle))
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)
                }

                Section {
                    ForEach(weightEntries) { entry in
                        if let exercise = ExerciseCatalog.exercise(id: entry.exerciseId) {
                            weightRow(entry: entry, exercise: exercise)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(l10n.t(.lighter_start_title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(l10n.t(.cancel)) { dismiss() }
                        .foregroundStyle(IronHerTheme.secondaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(l10n.t(.begin_workout)) {
                        applyAndBegin()
                    }
                    .font(SheLiftsFont.bodyMedium)
                }
            }
            .onAppear(perform: seedDrafts)
        }
    }

    private func weightRow(entry: WorkoutExerciseEntry, exercise: Exercise) -> some View {
        let unit = globalProgressStore.resolvedWeightUnit(
            for: exercise.id,
            defaultUnit: settingsStore.weightUnit
        )
        let binding = Binding<Double>(
            get: {
                draftWeightsKg[entry.id]
                    ?? globalProgressStore.resolvedWeight(for: entry.exerciseId, entryWeight: entry.startingWeight)
            },
            set: { draftWeightsKg[entry.id] = max(0, $0) }
        )
        let step = unit == .pounds ? 2.5 : 1.25

        return VStack(alignment: .leading, spacing: 10) {
            Text(exercise.localizedName(using: l10n))
                .font(SheLiftsFont.bodyMedium)
                .foregroundStyle(IronHerTheme.primaryText)

            HStack {
                Text(l10n.t(.weight))
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
                Spacer()
                Text(WeightFormatter.format(kg: binding.wrappedValue, unit: unit))
                    .font(SheLiftsFont.bodyMedium)
                    .foregroundStyle(IronHerTheme.primaryText)
            }

            Slider(
                value: Binding(
                    get: { WeightFormatter.displayValue(kg: binding.wrappedValue, unit: unit) },
                    set: { display in
                        binding.wrappedValue = WeightFormatter.kilograms(from: display, unit: unit)
                    }
                ),
                in: 0...WeightFormatter.displayValue(kg: max(binding.wrappedValue * 1.5, 60), unit: unit),
                step: step
            )
        }
        .padding(.vertical, 6)
    }

    private func seedDrafts() {
        guard draftWeightsKg.isEmpty else { return }
        for entry in weightEntries {
            let planned = globalProgressStore.resolvedWeight(for: entry.exerciseId, entryWeight: entry.startingWeight)
            // Soft suggestion: ~10% lighter, rounded to 0.5 kg / display step — user can change freely.
            let suggested = WeightFormatter.roundToTenth(max(0, (planned * 0.9 * 2).rounded(.down) / 2))
            draftWeightsKg[entry.id] = suggested > 0 ? suggested : planned
        }
    }

    private func applyAndBegin() {
        for (entryId, weightKg) in draftWeightsKg {
            sessionStore.applyWeightToAllSets(entryId: entryId, weightKg: weightKg)
        }
        onBegin()
        dismiss()
    }
}
