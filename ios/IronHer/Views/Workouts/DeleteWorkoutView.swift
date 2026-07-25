import SwiftUI

struct DeleteWorkoutView: View {
    @Environment(WorkoutStore.self) private var workoutStore

    @State private var workoutToDelete: Workout?

    var body: some View {
        Group {
            if workoutStore.workouts.isEmpty {
                ContentUnavailableView(
                    "No workouts yet",
                    systemImage: "trash",
                    description: Text("Nothing to delete. Create a workout first.")
                )
            } else {
                List {
                    ForEach(workoutStore.workouts) { workout in
                        Button(role: .destructive) {
                            workoutToDelete = workout
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(workout.name)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(IronHerTheme.primaryText)

                                    Text(workout.updatedAt.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption)
                                        .foregroundStyle(IronHerTheme.secondaryText)
                                }

                                Spacer()

                                Image(systemName: "trash")
                                    .foregroundStyle(Color.red.opacity(0.8))
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .background(IronHerTheme.groupedBackground)
        .navigationTitle("Delete Workout")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete workout?", isPresented: isConfirmingDelete) {
            Button("Delete", role: .destructive) {
                confirmDelete()
            }
            Button("Cancel", role: .cancel) {
                workoutToDelete = nil
            }
        } message: {
            if let workout = workoutToDelete {
                Text("“\(workout.name)” will be permanently removed.")
            }
        }
    }

    private var isConfirmingDelete: Binding<Bool> {
        Binding(
            get: { workoutToDelete != nil },
            set: { if !$0 { workoutToDelete = nil } }
        )
    }

    private func confirmDelete() {
        guard let workout = workoutToDelete else { return }
        workoutStore.deleteWorkout(id: workout.id)
        workoutToDelete = nil
    }
}

#Preview {
    NavigationStack {
        DeleteWorkoutView()
            .environment(WorkoutStore())
    }
}
