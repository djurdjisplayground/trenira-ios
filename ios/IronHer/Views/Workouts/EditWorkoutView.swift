import SwiftUI

struct EditWorkoutView: View {
    @Environment(WorkoutStore.self) private var workoutStore

    var body: some View {
        Group {
            if workoutStore.workouts.isEmpty {
                ContentUnavailableView(
                    "No workouts yet",
                    systemImage: "dumbbell",
                    description: Text("Create a workout first, then come back to edit it.")
                )
            } else {
                List {
                    ForEach(workoutStore.workouts) { workout in
                        NavigationLink {
                            EditWorkoutDetailView(workoutId: workout.id)
                        } label: {
                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(workout.name)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(IronHerTheme.primaryText)

                                    Text(exerciseSummary(for: workout))
                                        .font(.caption)
                                        .foregroundStyle(IronHerTheme.secondaryText)
                                }

                                Spacer()

                                if let firstEntry = workout.exercises.sorted(by: { $0.order < $1.order }).first,
                                   let exercise = ExerciseCatalog.exercise(id: firstEntry.exerciseId),
                                   exercise.hasVisualAsset {
                                    ExerciseThumbnailView(exercise: exercise, size: 44)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .background(IronHerTheme.groupedBackground)
        .navigationTitle("Edit Workout")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func exerciseSummary(for workout: Workout) -> String {
        let count = workout.exercises.count
        let date = workout.updatedAt.formatted(date: .abbreviated, time: .omitted)
        if count == 0 {
            return "No exercises · \(date)"
        }
        let label = count == 1 ? "exercise" : "exercises"
        return "\(count) \(label) · \(date)"
    }
}

#Preview {
    NavigationStack {
        EditWorkoutView()
            .environment(WorkoutStore())
    }
}
