import SwiftUI

struct GenerateWorkoutView: View {
    @Environment(WorkoutStore.self) private var workoutStore
    @Environment(WeightHistoryStore.self) private var historyStore
    @Environment(GlobalExerciseProgressStore.self) private var globalProgressStore
    @Environment(SubscriptionStore.self) private var subscriptionStore
    @Environment(\.dismiss) private var dismiss

    @State private var request = WorkoutGenerationRequest()
    @State private var generatedWorkout: Workout?
    @State private var showPremiumUpgrade = false

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

                if let generatedWorkout {
                    previewSection(generatedWorkout)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(IronHerScreenBackground())
        .navigationTitle("Generate Workout")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPremiumUpgrade) {
            NavigationStack {
                PremiumUpgradeView(highlightFeature: .generateWorkout)
            }
        }
    }

    private var introSection: some View {
        Text("Describe your goal and available equipment. trenira drafts a plan you can still edit.")
            .font(SheLiftsFont.body)
            .foregroundStyle(IronHerTheme.secondaryText)
    }

    private var goalSection: some View {
        pickerSection(title: "Training goal") {
            ForEach(WorkoutTrainingGoal.allCases) { goal in
                selectionChip(
                    title: goal.label,
                    isSelected: request.goal == goal
                ) {
                    request.goal = goal
                    generatedWorkout = nil
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
                    generatedWorkout = nil
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
                    generatedWorkout = nil
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

            GymProfilePickerRow(selection: $request.availableEquipment)

            GymEquipmentPicker(selection: Binding(
                get: { request.availableEquipment },
                set: {
                    request.availableEquipment = $0
                    generatedWorkout = nil
                }
            ))
        }
    }

    private var trainingDaysSection: some View {
        pickerSection(title: "Training days / week") {
            ForEach([2, 3, 4, 5, 6], id: \.self) { days in
                selectionChip(
                    title: "\(days) days",
                    isSelected: request.trainingDays == days
                ) {
                    request.trainingDays = days
                    generatedWorkout = nil
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
            Text("Generate Workout")
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(request.availableEquipment.isEmpty || request.muscleGroups.isEmpty)
    }

    private func previewSection(_ workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggested plan")
                .font(.headline)
                .foregroundStyle(IronHerTheme.primaryText)

            Text(workout.name)
                .font(SheLiftsFont.bodyMedium)
                .foregroundStyle(IronHerTheme.primaryText)

            ForEach(workout.exercises.sorted { $0.order < $1.order }) { entry in
                if let exercise = ExerciseCatalog.exercise(id: entry.exerciseId) {
                    HStack {
                        Text(exercise.name)
                            .font(.body)
                            .foregroundStyle(IronHerTheme.primaryText)
                        Spacer()
                        Text("\(entry.sets)×\(entry.reps)")
                            .font(.caption)
                            .foregroundStyle(IronHerTheme.secondaryText)
                    }
                    .padding(14)
                    .background(IronHerTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }

            Button {
                saveWorkout(workout)
            } label: {
                Text("Save workout")
            }
            .buttonStyle(PrimaryButtonStyle())
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

    private func toggleMuscle(_ group: MuscleGroup) {
        if request.muscleGroups.contains(group) {
            request.muscleGroups.remove(group)
        } else {
            request.muscleGroups.insert(group)
        }
        generatedWorkout = nil
    }

    private func generate() {
        generatedWorkout = WorkoutGenerationService.generateWorkout(from: request)
    }

    private func saveWorkout(_ workout: Workout) {
        guard subscriptionStore.canCreateWorkoutPlan(currentCount: workoutStore.workouts.count) else {
            showPremiumUpgrade = true
            return
        }

        workoutStore.createWorkout(named: workout.name, exercises: workout.exercises)
        for entry in workout.exercises {
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
        GenerateWorkoutView()
            .environment(WorkoutStore())
            .environment(WeightHistoryStore())
            .environment(SubscriptionStore())
    }
}
