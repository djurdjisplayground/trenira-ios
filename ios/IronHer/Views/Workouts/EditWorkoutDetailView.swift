import SwiftUI

struct EditWorkoutDetailView: View {
    @Environment(WorkoutStore.self) private var workoutStore
    @Environment(WeightHistoryStore.self) private var historyStore
    @Environment(GlobalExerciseProgressStore.self) private var globalProgressStore
    @Environment(WorkoutSessionStore.self) private var sessionStore
    @Environment(SubscriptionStore.self) private var subscriptionStore
    @Environment(TestingTimeStore.self) private var testingTimeStore
    @Environment(\.dismiss) private var dismiss

    let workoutId: UUID

    @State private var workoutName = ""
    @State private var draftExercises: [DraftWorkoutExercise] = []
    @State private var showAddExercise = false
    @State private var editingExercise: DraftWorkoutExercise?
    @State private var replaceDraft: DraftWorkoutExercise?
    @State private var showReplacePremium = false
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if DevelopmentConfig.isDevelopmentMode, testingTimeStore.isSimulating {
                    TestModeBanner()
                }

                nameSection
                exercisesSection
                addExerciseButton
                saveButton
                deleteWorkoutButton
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(IronHerTheme.background)
        .navigationTitle("Edit Workout")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Workout?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Workout", role: .destructive) {
                #if DEBUG
                print("[WorkoutDelete] editor confirm delete id=\(workoutId)")
                #endif
                sessionStore.clearCompletedThisWeek(workoutId: workoutId)
                if sessionStore.activeSession?.workoutId == workoutId {
                    sessionStore.endSession(markWeeklyCompletion: false)
                }
                workoutStore.deleteWorkout(id: workoutId)
                dismiss()
            }
        } message: {
            Text("This moves the workout to Recently Deleted for 30 days. Your exercise progression and history stay intact.")
        }
        .onAppear(perform: loadWorkout)
        .sheet(isPresented: $showAddExercise) {
            AddExerciseSheet { draft in
                draftExercises.append(draft)
                syncGlobalProgress(from: draft)
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
                updateExercise(
                    draft.id,
                    sets: sets,
                    reps: reps,
                    weight: weight,
                    duration: duration,
                    distance: distance,
                    restDurationOverride: restOverride
                )
            }
        }
        .sheet(item: $replaceDraft) { draft in
            NavigationStack {
                ReplaceExerciseView(
                    workoutId: workoutId,
                    entryId: draft.id,
                    isActiveSession: false
                )
            }
        }
        .sheet(isPresented: $showReplacePremium) {
            NavigationStack {
                PremiumUpgradeView(highlightFeature: .replaceExercise)
            }
        }
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Name")
                .font(.headline)
                .foregroundStyle(IronHerTheme.primaryText)

            TextField("Workout name", text: $workoutName)
                .padding(14)
                .background(IronHerTheme.groupedBackground)
                .clipShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadiusSmall, style: .continuous))
        }
    }

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercises")
                .font(.headline)
                .foregroundStyle(IronHerTheme.primaryText)

            if draftExercises.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "dumbbell")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(IronHerTheme.secondaryText)

                    Text("No exercises in this plan")
                        .font(.subheadline)
                        .foregroundStyle(IronHerTheme.primaryText)

                    Text("Add exercises below.")
                        .font(.footnote)
                        .foregroundStyle(IronHerTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .notesCard(padding: 24)
            } else {
                VStack(spacing: 10) {
                    ForEach(draftExercises) { draft in
                        VStack(alignment: .leading, spacing: 8) {
                            DraftExerciseRow(
                                draft: draft,
                                onTap: { editingExercise = draft },
                                onDelete: {
                                    draftExercises.removeAll { $0.id == draft.id }
                                }
                            )

                            Button {
                                if subscriptionStore.hasAccess(to: .replaceExercise) {
                                    replaceDraft = draft
                                } else {
                                    showReplacePremium = true
                                }
                            } label: {
                                PremiumFeatureRow(
                                    feature: .replaceExercise,
                                    title: "Replace Exercise",
                                    subtitle: "Same focus, different movement",
                                    systemImage: "arrow.left.arrow.right"
                                )
                            }
                            .buttonStyle(.plain)
                            .font(SheLiftsFont.caption)
                            .padding(.leading, 4)
                        }
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
                Text("Add exercise")
                    .font(.headline)
            }
        }
        .buttonStyle(OutlineButtonStyle())
    }

    private var saveButton: some View {
        Button {
            saveChanges()
        } label: {
            Text("Save changes")
        }
        .buttonStyle(OutlineButtonStyle())
        .disabled(!canSave)
    }

    private var deleteWorkoutButton: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            Text("Delete Workout")
                .font(SheLiftsFont.bodyMedium)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .accessibilityIdentifier("delete-workout-button")
    }

    private var canSave: Bool {
        !workoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draftExercises.isEmpty
    }

    private func loadWorkout() {
        guard let workout = workoutStore.workouts.first(where: { $0.id == workoutId }) else {
            dismiss()
            return
        }

        // Always materialize the latest global prescription into plan copies first.
        globalProgressStore.applyAll(to: workoutStore)

        guard let refreshed = workoutStore.workouts.first(where: { $0.id == workoutId }) else {
            dismiss()
            return
        }

        workoutName = refreshed.name
        draftExercises = refreshed.exercises
            .sorted { $0.order < $1.order }
            .compactMap { entry in
                guard let exercise = ExerciseCatalog.exercise(id: entry.exerciseId) else { return nil }
                return DraftWorkoutExercise(
                    entryId: entry.id,
                    exercise: exercise,
                    sets: globalProgressStore.resolvedSets(for: entry.exerciseId, entrySets: entry.sets),
                    reps: globalProgressStore.resolvedReps(for: entry.exerciseId, entryReps: entry.reps),
                    startingWeight: globalProgressStore.resolvedWeight(
                        for: entry.exerciseId,
                        entryWeight: entry.startingWeight
                    ),
                    durationSeconds: globalProgressStore.resolvedDurationSeconds(
                        for: entry.exerciseId,
                        entryDurationSeconds: entry.durationSeconds
                    ),
                    distanceMeters: globalProgressStore.resolvedDistanceMeters(
                        for: entry.exerciseId,
                        entryDistanceMeters: entry.distanceMeters
                    ),
                    restDurationOverride: entry.restDurationOverride
                )
            }
    }

    private func updateExercise(
        _ id: UUID,
        sets: Int,
        reps: Int,
        weight: Double,
        duration: Int,
        distance: Double,
        restDurationOverride: TimeInterval?
    ) {
        guard let index = draftExercises.firstIndex(where: { $0.id == id }) else { return }
        draftExercises[index].sets = sets
        draftExercises[index].reps = reps
        draftExercises[index].startingWeight = weight
        draftExercises[index].durationSeconds = duration
        draftExercises[index].distanceMeters = distance
        draftExercises[index].restDurationOverride = restDurationOverride

        // Edit Exercise save → update the single global progression record immediately.
        syncGlobalProgress(from: draftExercises[index])
    }

    private func syncGlobalProgress(from draft: DraftWorkoutExercise) {
        let record = globalProgressStore.syncFromTemplateEdit(
            exerciseId: draft.exercise.id,
            measurement: draft.exercise.measurementUnit,
            weightKg: draft.startingWeight,
            reps: draft.reps,
            sets: draft.sets,
            durationSeconds: draft.durationSeconds,
            distanceMeters: draft.distanceMeters,
            into: workoutStore
        )

        if record.workingWeightKg > 0,
           draft.exercise.measurementUnit != .reps,
           draft.exercise.measurementUnit != .bodyweight {
            historyStore.recordInitial(exerciseId: draft.exercise.id, weightKg: record.workingWeightKg)
        }

        // Weight/reps/duration stay aligned globally. Planned set counts stay per entry.
        for index in draftExercises.indices where draftExercises[index].exercise.id == draft.exercise.id {
            draftExercises[index].reps = record.targetReps
            draftExercises[index].startingWeight = record.workingWeightKg
            draftExercises[index].durationSeconds = record.targetDurationSeconds
            draftExercises[index].distanceMeters = record.targetDistanceMeters
        }
    }

    private func saveChanges() {
        for draft in draftExercises {
            syncGlobalProgress(from: draft)
        }

        let entries = draftExercises.enumerated().map { index, draft in
            let progress = globalProgressStore.progress(for: draft.exercise.id)
            return WorkoutExerciseEntry(
                id: draft.id,
                exerciseId: draft.exercise.id,
                sets: draft.sets,
                reps: progress?.targetReps ?? draft.reps,
                startingWeight: progress?.workingWeightKg ?? draft.startingWeight,
                durationSeconds: progress?.targetDurationSeconds ?? draft.durationSeconds,
                distanceMeters: progress?.targetDistanceMeters ?? draft.distanceMeters,
                order: index,
                restDurationOverride: draft.restDurationOverride
            )
        }

        workoutStore.updateWorkout(
            id: workoutId,
            name: workoutName,
            exercises: entries
        )

        // Fan-out again so every other plan stays aligned after this template save.
        globalProgressStore.applyAll(to: workoutStore)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        EditWorkoutDetailView(workoutId: UUID())
            .environment(WorkoutStore())
            .environment(WeightHistoryStore())
            .environment(GlobalExerciseProgressStore())
            .environment(WorkoutSessionStore())
            .environment(SubscriptionStore())
            .environment(TestingTimeStore())
            .environment(LocalizationStore())
    }
}
