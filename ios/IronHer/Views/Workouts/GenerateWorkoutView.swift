import SwiftUI

struct GenerateWorkoutView: View {
    @Environment(WorkoutStore.self) private var workoutStore
    @Environment(WeightHistoryStore.self) private var historyStore
    @Environment(GlobalExerciseProgressStore.self) private var globalProgressStore
    @Environment(StrengthCalibrationStore.self) private var calibrationStore
    @Environment(SubscriptionStore.self) private var subscriptionStore
    @Environment(\.dismiss) private var dismiss

    @State private var request = WorkoutGenerationRequest()
    @State private var generatedWorkouts: [Workout] = []
    @State private var showPremiumUpgrade = false
    @State private var swapTarget: GeneratedExerciseSwapTarget?

    /// Used when embedding in first-launch onboarding.
    var onSaved: (() -> Void)? = nil
    var onSkip: (() -> Void)? = nil
    var onBack: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                introSection
                goalSection
                experienceSection
                durationSection
                trainingDaysSection
                equipmentSection
                muscleSection
                generateButton

                if !generatedWorkouts.isEmpty {
                    previewSection(generatedWorkouts)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(IronHerScreenBackground())
        .navigationTitle("Generate Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let onBack {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") { onBack() }
                        .foregroundStyle(IronHerTheme.secondaryText)
                }
            }
            if let onSkip {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip for now") { onSkip() }
                        .foregroundStyle(IronHerTheme.secondaryText)
                }
            }
        }
        .sheet(isPresented: $showPremiumUpgrade) {
            NavigationStack {
                PremiumUpgradeView(highlightFeature: .generateWorkout)
            }
        }
        .sheet(item: $swapTarget) { target in
            AdaptSwapExercisePicker(
                originalName: target.originalName,
                originalExerciseId: target.entry.exerciseId,
                excludedIds: excludedIds(in: target.workoutID, replacing: target.entry.exerciseId),
                compatibleEquipment: request.availableEquipment
            ) { exercise in
                applyGeneratedSwap(target: target, exercise: exercise)
            }
        }
    }

    private var introSection: some View {
        Text("Choose your goals, equipment, and how many days you train. trenira drafts one complementary workout for each training day — review and edit before you save.")
            .font(SheLiftsFont.body)
            .foregroundStyle(IronHerTheme.secondaryText)
    }

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Training goals")
                .font(.headline)
                .foregroundStyle(IronHerTheme.primaryText)

            Text("Select every goal this session should cover. You can tap a selected goal to deselect it.")
                .font(SheLiftsFont.caption)
                .foregroundStyle(IronHerTheme.secondaryText)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))], spacing: 10) {
                ForEach(WorkoutTrainingGoal.allCases) { goal in
                    selectionChip(
                        title: goal.label,
                        isSelected: request.goals.contains(goal)
                    ) {
                        toggleGoal(goal)
                    }
                }
            }
        }
    }

    private var experienceSection: some View {
        pickerSection(title: "Experience") {
            ForEach(TrainingExperience.allCases) { level in
                selectionChip(
                    title: level.label,
                    isSelected: request.experience == level
                ) {
                    request.experience = level
                    generatedWorkouts = []
                }
            }
        }
    }

    private var durationSection: some View {
        pickerSection(title: "Workout duration") {
            ForEach(WorkoutDuration.allCases) { duration in
                selectionChip(
                    title: duration.label,
                    isSelected: request.duration == duration
                ) {
                    request.duration = duration
                    generatedWorkouts = []
                }
            }
        }
    }

    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available equipment")
                .font(.headline)
                .foregroundStyle(IronHerTheme.primaryText)

            Text("Only exercises you can perform with this equipment will be suggested.")
                .font(SheLiftsFont.caption)
                .foregroundStyle(IronHerTheme.secondaryText)

            GymEquipmentPicker(selection: Binding(
                get: { request.availableEquipment },
                set: {
                    request.availableEquipment = $0
                    generatedWorkouts = []
                }
            ))
        }
    }

    private var trainingDaysSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Training days / week")
                .font(.headline)
                .foregroundStyle(IronHerTheme.primaryText)

            Text("trenira creates one workout for each day so the week is a complete plan, not a single session.")
                .font(SheLiftsFont.caption)
                .foregroundStyle(IronHerTheme.secondaryText)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))], spacing: 10) {
                ForEach([2, 3, 4, 5, 6], id: \.self) { days in
                    selectionChip(
                        title: "\(days) days",
                        isSelected: request.trainingDays == days
                    ) {
                        request.trainingDays = days
                        generatedWorkouts = []
                    }
                }
            }
        }
    }

    private var muscleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Muscle groups")
                .font(.headline)
                .foregroundStyle(IronHerTheme.primaryText)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 10) {
                ForEach(MuscleGroup.allCases, id: \.self) { group in
                    selectionChip(
                        title: group.label,
                        isSelected: request.muscleGroups.contains(group)
                    ) {
                        toggleMuscle(group)
                    }
                }
            }
        }
    }

    private var generateButton: some View {
        Button {
            generate()
        } label: {
            Text("Generate \(request.trainingDays)-day plan")
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(request.goals.isEmpty || request.availableEquipment.isEmpty || request.muscleGroups.isEmpty)
    }

    private func previewSection(_ workouts: [Workout]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Suggested \(workouts.count)-day plan")
                .font(.headline)
                .foregroundStyle(IronHerTheme.primaryText)

            Text("Each day is a separate workout you can start independently.")
                .font(SheLiftsFont.caption)
                .foregroundStyle(IronHerTheme.secondaryText)

            RecommendationDisclaimerBanner()

            ForEach(Array(workouts.enumerated()), id: \.element.id) { _, workout in
                VStack(alignment: .leading, spacing: 10) {
                    Text(workout.name)
                        .font(SheLiftsFont.bodyMedium)
                        .foregroundStyle(IronHerTheme.primaryText)

                    ForEach(workout.exercises.sorted { $0.order < $1.order }) { entry in
                        if let exercise = ExerciseCatalog.exercise(id: entry.exerciseId) {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(exercise.name)
                                        .font(.body)
                                        .foregroundStyle(IronHerTheme.primaryText)
                                    Spacer()
                                    Text("\(entry.sets)×\(entry.reps)")
                                        .font(.caption)
                                        .foregroundStyle(IronHerTheme.secondaryText)
                                }

                                Button {
                                    swapTarget = GeneratedExerciseSwapTarget(
                                        workoutID: workout.id,
                                        entry: entry,
                                        originalName: exercise.name
                                    )
                                } label: {
                                    Text("Swap")
                                        .font(SheLiftsFont.caption)
                                        .foregroundStyle(IronHerTheme.primaryText)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(IronHerTheme.groupedBackground)
                                        .clipShape(Capsule())
                                        .overlay {
                                            Capsule()
                                                .stroke(IronHerTheme.separator.opacity(0.85), lineWidth: 0.5)
                                        }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Swap \(exercise.name)")
                            }
                            .padding(14)
                            .background(IronHerTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }
            }

            Button {
                saveWorkouts(workouts)
            } label: {
                Text(workouts.count == 1 ? "Save workout" : "Save \(workouts.count) workouts")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(workouts.contains { $0.exercises.isEmpty })
        }
    }

    private func pickerSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(IronHerTheme.primaryText)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))], spacing: 10) {
                content()
            }
        }
    }

    private func selectionChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? IronHerTheme.accentForeground : IronHerTheme.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? IronHerTheme.accent : IronHerTheme.cardBackground)
                .clipShape(Capsule())
                .overlay {
                    if !isSelected {
                        Capsule()
                            .stroke(IronHerTheme.separator.opacity(0.6), lineWidth: 0.5)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func toggleGoal(_ goal: WorkoutTrainingGoal) {
        if request.goals.contains(goal) {
            request.goals.remove(goal)
        } else {
            request.goals.insert(goal)
        }
        generatedWorkouts = []
    }

    private func toggleMuscle(_ group: MuscleGroup) {
        if request.muscleGroups.contains(group) {
            request.muscleGroups.remove(group)
        } else {
            request.muscleGroups.insert(group)
        }
        generatedWorkouts = []
    }

    private func generate() {
        generatedWorkouts = StrengthCalibrationResolver.applyStartingWeights(
            to: WorkoutGenerationService.generateWorkouts(from: request),
            progressFor: { globalProgressStore.progress(for: $0) },
            historyFor: { historyStore.entries(for: $0) },
            calibrationFor: { calibrationStore.calibration(for: $0) }
        )
    }

    private func excludedIds(in workoutID: UUID, replacing exerciseId: String) -> Set<String> {
        var ids = Set(
            generatedWorkouts
                .first(where: { $0.id == workoutID })?
                .exercises.map(\.exerciseId) ?? []
        )
        ids.insert(exerciseId)
        return ids
    }

    private func applyGeneratedSwap(target: GeneratedExerciseSwapTarget, exercise: Exercise) {
        guard let workoutIndex = generatedWorkouts.firstIndex(where: { $0.id == target.workoutID }),
              let entryIndex = generatedWorkouts[workoutIndex].exercises.firstIndex(where: { $0.id == target.entry.id })
        else { return }

        generatedWorkouts[workoutIndex].exercises[entryIndex] = WorkoutGenerationService.replacingGeneratedEntry(
            generatedWorkouts[workoutIndex].exercises[entryIndex],
            with: exercise,
            request: request
        )
        let entry = generatedWorkouts[workoutIndex].exercises[entryIndex]
        generatedWorkouts[workoutIndex].exercises[entryIndex].startingWeight =
            StrengthCalibrationResolver.startingWeightKg(
                exerciseId: entry.exerciseId,
                progress: globalProgressStore.progress(for: entry.exerciseId),
                historyEntries: historyStore.entries(for: entry.exerciseId),
                calibration: calibrationStore.calibration(for: entry.exerciseId)
            )
    }

    private func saveWorkouts(_ workouts: [Workout]) {
        let needed = workouts.count
        let allowed = subscriptionStore.hasPremiumAccess
            || workoutStore.savedWorkoutCount + needed <= SubscriptionStore.freeWorkoutPlanLimit
        guard allowed else {
            showPremiumUpgrade = true
            return
        }

        for workout in workouts.reversed() {
            workoutStore.createWorkout(named: workout.name, exercises: workout.exercises)
            for entry in workout.exercises {
                let measurement = ExerciseCatalog.exercise(id: entry.exerciseId)?.measurementUnit ?? .weight
                let established = StrengthCalibrationResolver.hasEstablishedProgress(
                    progress: globalProgressStore.progress(for: entry.exerciseId),
                    historyEntries: historyStore.entries(for: entry.exerciseId)
                )
                globalProgressStore.applyExistingOrSeedInitial(
                    exerciseId: entry.exerciseId,
                    measurement: measurement,
                    weightKg: entry.startingWeight,
                    reps: entry.reps,
                    sets: entry.sets,
                    durationSeconds: entry.durationSeconds,
                    distanceMeters: entry.distanceMeters,
                    established: established,
                    into: workoutStore
                )
                if !established,
                   entry.startingWeight > 0,
                   measurement != .reps,
                   measurement != .bodyweight {
                    historyStore.recordInitial(exerciseId: entry.exerciseId, weightKg: entry.startingWeight)
                }
            }
        }
        if let onSaved {
            onSaved()
        } else {
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        GenerateWorkoutView()
            .environment(WorkoutStore())
            .environment(WeightHistoryStore())
            .environment(SubscriptionStore())
            .environment(LocalizationStore())
            .environment(CustomExerciseStore())
            .environment(GlobalExerciseProgressStore())
            .environment(StrengthCalibrationStore())
    }
}

private struct GeneratedExerciseSwapTarget: Identifiable {
    let workoutID: UUID
    let entry: WorkoutExerciseEntry
    let originalName: String

    var id: UUID { entry.id }
}
