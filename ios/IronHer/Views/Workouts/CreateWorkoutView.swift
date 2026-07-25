import SwiftUI

struct CreateWorkoutView: View {
    @Environment(WorkoutStore.self) private var workoutStore
    @Environment(WeightHistoryStore.self) private var historyStore
    @Environment(SubscriptionStore.self) private var subscriptionStore
    @Environment(GlobalExerciseProgressStore.self) private var globalProgressStore
    @Environment(LocalizationStore.self) private var l10n
    @Environment(\.dismiss) private var dismiss

    @State private var workoutName = ""
    @State private var draftExercises: [DraftWorkoutExercise] = []
    @State private var showAddExercise = false
    @State private var editingExercise: DraftWorkoutExercise?
    @State private var showPremiumUpgrade = false
    @FocusState private var isNameFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if !subscriptionStore.isPremium {
                    planLimitBanner
                }
                nameSection
                exercisesSection
                addExerciseButton
                saveButton
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(IronHerTheme.background)
        .navigationTitle(l10n.t(.create_workout))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddExercise) {
            AddExerciseSheet { draft in
                draftExercises.append(draft)
                _ = globalProgressStore.syncFromTemplateEdit(
                    exerciseId: draft.exercise.id,
                    measurement: draft.exercise.measurementUnit,
                    weightKg: draft.startingWeight,
                    reps: draft.reps,
                    sets: draft.sets,
                    durationSeconds: draft.durationSeconds,
                    distanceMeters: draft.distanceMeters,
                    into: workoutStore
                )
            }
        }
        .sheet(item: $editingExercise) { draft in
            EditExerciseSheet(
                exercise: draft.exercise,
                sets: draft.sets,
                reps: draft.reps,
                startingWeight: draft.startingWeight,
                durationSeconds: draft.durationSeconds,
                distanceMeters: draft.distanceMeters
            ) { sets, reps, weight, duration, distance in
                if let index = draftExercises.firstIndex(where: { $0.id == draft.id }) {
                    draftExercises[index].sets = sets
                    draftExercises[index].reps = reps
                    draftExercises[index].startingWeight = weight
                    draftExercises[index].durationSeconds = duration
                    draftExercises[index].distanceMeters = distance

                    let record = globalProgressStore.syncFromTemplateEdit(
                        exerciseId: draft.exercise.id,
                        measurement: draft.exercise.measurementUnit,
                        weightKg: weight,
                        reps: reps,
                        sets: sets,
                        durationSeconds: duration,
                        distanceMeters: distance,
                        into: workoutStore
                    )

                    for draftIndex in draftExercises.indices
                    where draftExercises[draftIndex].exercise.id == draft.exercise.id {
                        draftExercises[draftIndex].sets = record.targetSets
                        draftExercises[draftIndex].reps = record.targetReps
                        draftExercises[draftIndex].startingWeight = record.workingWeightKg
                        draftExercises[draftIndex].durationSeconds = record.targetDurationSeconds
                        draftExercises[draftIndex].distanceMeters = record.targetDistanceMeters
                    }
                }
            }
        }
        .onAppear {
            isNameFocused = true
        }
        .sheet(isPresented: $showPremiumUpgrade) {
            NavigationStack {
                PremiumUpgradeView(highlightFeature: .unlimitedWorkoutPlans)
                    .environment(subscriptionStore)
            }
        }
        .id(subscriptionStore.revision)
    }

    private var planLimitBanner: some View {
        let remaining = subscriptionStore.remainingFreeWorkoutPlans(currentCount: workoutStore.workouts.count)
        return VStack(alignment: .leading, spacing: 6) {
            Text("\(remaining) of \(SubscriptionStore.freeWorkoutPlanLimit) workouts remaining")
                .font(SheLiftsFont.bodyMedium)
                .foregroundStyle(IronHerTheme.primaryText)

            Text("Free includes everything you need to track up to 3 workouts. Premium goes beyond tracking with unlimited workouts.")
                .font(SheLiftsFont.caption)
                .foregroundStyle(IronHerTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .notesCard(padding: 16)
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Name")
                .font(.headline)
                .foregroundStyle(IronHerTheme.primaryText)

            TextField("e.g. Glute Day, Push Power", text: $workoutName)
                .focused($isNameFocused)
                .padding(14)
                .background(IronHerTheme.groupedBackground)
                .clipShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadiusSmall, style: .continuous))
        }
    }

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l10n.t(.exercises))
                .font(.headline)
                .foregroundStyle(IronHerTheme.primaryText)

            if draftExercises.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "dumbbell")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(IronHerTheme.secondaryText)

                    Text("No exercises yet")
                        .font(.subheadline)
                        .foregroundStyle(IronHerTheme.primaryText)

                    Text("Add movements from the exercise library.")
                        .font(.footnote)
                        .foregroundStyle(IronHerTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .notesCard(padding: 24)
            } else {
                VStack(spacing: 10) {
                    ForEach(draftExercises) { draft in
                        DraftExerciseRow(
                            draft: draft,
                            onTap: { editingExercise = draft },
                            onDelete: {
                                draftExercises.removeAll { $0.id == draft.id }
                            }
                        )
                    }
                }
            }
        }
    }

    private var addExerciseButton: some View {
        Button {
            showAddExercise = true
        } label: {
            HStack {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .light))
                Text(l10n.t(.add_exercise))
                    .font(.headline)
            }
        }
        .buttonStyle(OutlineButtonStyle())
    }

    private var saveButton: some View {
        Button {
            saveWorkoutPlan()
        } label: {
            Text(l10n.t(.save))
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!canSave)
        .padding(.bottom, 8)
    }

    private var canSave: Bool {
        !workoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draftExercises.isEmpty
    }

    private func saveWorkoutPlan() {
        guard subscriptionStore.canCreateWorkoutPlan(currentCount: workoutStore.workouts.count) else {
            showPremiumUpgrade = true
            return
        }

        let entries = draftExercises.enumerated().map { index, draft in
            WorkoutExerciseEntry(
                exerciseId: draft.exercise.id,
                sets: draft.sets,
                reps: draft.reps,
                startingWeight: draft.startingWeight,
                durationSeconds: draft.durationSeconds,
                distanceMeters: draft.distanceMeters,
                order: index
            )
        }

        workoutStore.createWorkout(named: workoutName, exercises: entries)
        for entry in entries {
            let measurement = ExerciseCatalog.exercise(id: entry.exerciseId)?.measurementUnit ?? .weight
            globalProgressStore.syncFromTemplateEdit(
                exerciseId: entry.exerciseId,
                measurement: measurement,
                weightKg: entry.startingWeight,
                reps: entry.reps,
                sets: entry.sets,
                durationSeconds: entry.durationSeconds,
                distanceMeters: entry.distanceMeters,
                into: workoutStore
            )
            if entry.startingWeight > 0,
               measurement != .reps,
               measurement != .bodyweight {
                historyStore.recordInitial(exerciseId: entry.exerciseId, weightKg: entry.startingWeight)
            }
        }
        dismiss()
    }
}

#Preview {
    NavigationStack {
        CreateWorkoutView()
            .environment(WorkoutStore())
            .environment(WeightHistoryStore())
            .environment(SubscriptionStore())
            .environment(CustomExerciseStore())
            .environment(LocalizationStore())
    }
}
