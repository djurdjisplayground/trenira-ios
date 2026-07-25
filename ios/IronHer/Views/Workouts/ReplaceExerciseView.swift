import SwiftUI

struct ReplaceExerciseView: View {
    @Environment(WorkoutStore.self) private var workoutStore
    @Environment(\.dismiss) private var dismiss

    let workoutId: UUID
    let entryId: UUID

    @State private var proposal: WorkoutAdaptationProposal?
    @State private var originalName = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Swap one movement for an equivalent that keeps the same muscle focus and training prescription.")
                    .font(SheLiftsFont.body)
                    .foregroundStyle(IronHerTheme.secondaryText)

                if let proposal {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Suggested replacement")
                            .font(.headline)
                            .foregroundStyle(IronHerTheme.primaryText)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(proposal.originalName) → \(proposal.proposedName)")
                                .font(.body.weight(.medium))
                                .foregroundStyle(IronHerTheme.primaryText)
                            Text("\(proposal.proposedEquipment) · \(proposal.sets)×\(proposal.reps)")
                                .font(.caption)
                                .foregroundStyle(IronHerTheme.secondaryText)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(IronHerTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        Button {
                            regenerateProposal()
                        } label: {
                            Text("Try another option")
                        }
                        .buttonStyle(OutlineButtonStyle())

                        Button {
                            applyReplacement(proposal)
                        } label: {
                            Text("Replace exercise")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!proposal.isVarietySwap)
                    }
                } else if !originalName.isEmpty {
                    Text("No alternative found for \(originalName) with the same equipment.")
                        .font(.subheadline)
                        .foregroundStyle(IronHerTheme.secondaryText)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(IronHerScreenBackground())
        .navigationTitle("Replace Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadProposal)
    }

    private func loadProposal() {
        guard let workout = workoutStore.workout(id: workoutId),
              let entry = workout.exercises.first(where: { $0.id == entryId }) else {
            dismiss()
            return
        }

        originalName = ExerciseCatalog.exercise(id: entry.exerciseId)?.name ?? "Exercise"
        proposal = WorkoutAdaptationService.proposeSingleReplacement(for: entry, in: workout)
    }

    private func regenerateProposal() {
        loadProposal()
    }

    private func applyReplacement(_ proposal: WorkoutAdaptationProposal) {
        guard var workout = workoutStore.workout(id: workoutId) else { return }

        let updatedExercises = workout.exercises.map { entry -> WorkoutExerciseEntry in
            guard entry.id == entryId else { return entry }
            return WorkoutExerciseEntry(
                id: entry.id,
                exerciseId: proposal.proposedExerciseId,
                sets: proposal.sets,
                reps: proposal.reps,
                startingWeight: proposal.startingWeight,
                durationSeconds: entry.durationSeconds,
                distanceMeters: entry.distanceMeters,
                order: entry.order
            )
        }

        workoutStore.updateWorkout(id: workoutId, name: workout.name, exercises: updatedExercises)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        ReplaceExerciseView(workoutId: UUID(), entryId: UUID())
            .environment(WorkoutStore())
    }
}
