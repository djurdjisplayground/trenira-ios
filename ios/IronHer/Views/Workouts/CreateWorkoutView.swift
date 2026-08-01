import SwiftUI

struct CreateWorkoutView: View {
    @Environment(WorkoutStore.self) private var workoutStore
    @Environment(WeightHistoryStore.self) private var historyStore
    @Environment(SubscriptionStore.self) private var subscriptionStore
    @Environment(GlobalExerciseProgressStore.self) private var globalProgressStore
    @Environment(LocalizationStore.self) private var l10n
    @Environment(\.dismiss) private var dismiss

    /// When resuming, load this draft id. Autosave writes into the same id.
    var resumingDraftId: UUID? = nil

    @State private var draftId: UUID?
    @State private var workoutName = ""
    @State private var draftExercises: [DraftWorkoutExercise] = []
    @State private var showAddExercise = false
    @State private var editingExercise: DraftWorkoutExercise?
    @State private var showPremiumUpgrade = false
    @State private var didExplicitlySave = false
    @FocusState private var isNameFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if !subscriptionStore.hasPremiumAccess {
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
        .navigationTitle(resumingDraftId == nil ? l10n.t(.create_workout) : "Resume Draft")
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
                autosaveDraft()
            }
        }
        .sheet(item: $editingExercise) { draft in
            EditExerciseSheet(
                exercise: draft.exercise,
                sets: draft.sets,
                reps: draft.reps,
                startingWeight: draft.startingWeight,
                durationSeconds: draft.durationSeconds,
                distanceMeters: draft.distanceMeters,
                restDurationOverride: draft.restDurationOverride
            ) { sets, reps, weight, duration, distance, restOverride in
                if let index = draftExercises.firstIndex(where: { $0.id == draft.id }) {
                    draftExercises[index].sets = sets
                    draftExercises[index].reps = reps
                    draftExercises[index].startingWeight = weight
                    draftExercises[index].durationSeconds = duration
                    draftExercises[index].distanceMeters = distance
                    draftExercises[index].restDurationOverride = restOverride

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
                        draftExercises[draftIndex].reps = record.targetReps
                        draftExercises[draftIndex].startingWeight = record.workingWeightKg
                        draftExercises[draftIndex].durationSeconds = record.targetDurationSeconds
                        draftExercises[draftIndex].distanceMeters = record.targetDistanceMeters
                    }
                    // Keep the edited entry's set count as configured for this workout.
                    if let index = draftExercises.firstIndex(where: { $0.id == draft.id }) {
                        draftExercises[index].sets = sets
                    }
                    autosaveDraft()
                }
            }
        }
        .onAppear {
            loadResumeDraftIfNeeded()
            isNameFocused = true
        }
        .onChange(of: workoutName) { _, _ in
            autosaveDraft()
        }
        .onDisappear {
            if !didExplicitlySave {
                autosaveDraft()
            }
        }
        .sheet(isPresented: $showPremiumUpgrade) {
            NavigationStack {
                PremiumUpgradeView(highlightFeature: .unlimitedWorkoutPlans)
                    .environment(subscriptionStore)
            }
        }
    }

    private var planLimitBanner: some View {
        let remaining = subscriptionStore.remainingFreeWorkoutPlans(
            currentCount: workoutStore.savedWorkoutCount
        )
        return VStack(alignment: .leading, spacing: 6) {
            Text("\(remaining) of \(SubscriptionStore.freeWorkoutPlanLimit) workouts remaining")
                .font(SheLiftsFont.bodyMedium)
                .foregroundStyle(IronHerTheme.primaryText)

            Text("Free includes up to 3 saved workouts. Drafts don't count. Premium unlocks unlimited plans.")
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
                                autosaveDraft()
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

    private var hasDraftContent: Bool {
        !workoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !draftExercises.isEmpty
    }

    private func loadResumeDraftIfNeeded() {
        guard let resumingDraftId,
              let draft = workoutStore.workout(id: resumingDraftId),
              draft.isDraft else { return }
        draftId = draft.id
        workoutName = draft.name == "Untitled draft" ? "" : draft.name
        draftExercises = draft.exercises.compactMap { entry in
            guard let exercise = ExerciseCatalog.exercise(id: entry.exerciseId) else { return nil }
            return DraftWorkoutExercise(
                entryId: entry.id,
                exercise: exercise,
                sets: entry.sets,
                reps: entry.reps,
                startingWeight: entry.startingWeight,
                durationSeconds: entry.durationSeconds,
                distanceMeters: entry.distanceMeters,
                restDurationOverride: entry.restDurationOverride
            )
        }
    }

    private func autosaveDraft() {
        guard hasDraftContent, !didExplicitlySave else { return }
        let entries = makeEntries()
        let saved = workoutStore.upsertDraft(id: draftId, name: workoutName, exercises: entries)
        draftId = saved.id
    }

    private func makeEntries() -> [WorkoutExerciseEntry] {
        draftExercises.enumerated().map { index, draft in
            WorkoutExerciseEntry(
                id: draft.id,
                exerciseId: draft.exercise.id,
                sets: draft.sets,
                reps: draft.reps,
                startingWeight: draft.startingWeight,
                durationSeconds: draft.durationSeconds,
                distanceMeters: draft.distanceMeters,
                order: index,
                restDurationOverride: draft.restDurationOverride
            )
        }
    }

    private func saveWorkoutPlan() {
        guard subscriptionStore.canCreateWorkoutPlan(currentCount: workoutStore.savedWorkoutCount) else {
            showPremiumUpgrade = true
            return
        }

        let entries = makeEntries()
        let published: Workout?
        if let draftId {
            published = workoutStore.publishDraft(id: draftId, name: workoutName, exercises: entries)
        } else {
            published = workoutStore.createWorkout(named: workoutName, exercises: entries)
        }
        guard published != nil else { return }

        didExplicitlySave = true
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
