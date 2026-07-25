import SwiftUI

/// Workout library — manage plans. Not where you start today's session.
struct MyWorkoutsView: View {
    @Environment(WorkoutStore.self) private var workoutStore
    @Environment(GlobalExerciseProgressStore.self) private var globalProgressStore
    @Environment(LocalizationStore.self) private var l10n

    var body: some View {
        List {
            if workoutStore.workouts.isEmpty {
                Section {
                    ContentUnavailableView(
                        l10n.t(.empty_workouts_title),
                        systemImage: "list.bullet",
                        description: Text(l10n.t(.my_workouts_empty_body))
                    )
                    .listRowBackground(Color.clear)

                    NavigationLink(value: WorkoutRoute.createOptions) {
                        Text(l10n.t(.create_workout))
                            .font(SheLiftsFont.bodyMedium)
                    }
                }
            } else {
                Section {
                    ForEach(workoutStore.workouts) { workout in
                        if workout.exercises.isEmpty {
                            libraryRow(for: workout, canOpen: false)
                        } else {
                            NavigationLink {
                                EditWorkoutDetailView(workoutId: workout.id)
                            } label: {
                                libraryRow(for: workout, canOpen: true)
                            }
                        }
                    }
                    .onDelete(perform: deleteWorkouts)
                } footer: {
                    Text(l10n.t(.my_workouts_library_footer))
                        .font(SheLiftsFont.caption)
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(IronHerTheme.groupedBackground)
        .navigationTitle(l10n.t(.my_workouts))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: WorkoutRoute.createOptions) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .accessibilityLabel(l10n.t(.create_workout))
                }
            }
        }
        .onAppear {
            globalProgressStore.applyAll(to: workoutStore)
        }
    }

    private func libraryRow(for workout: Workout, canOpen: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(workout.name)
                .font(SheLiftsFont.bodyMedium)
                .foregroundStyle(canOpen ? IronHerTheme.primaryText : IronHerTheme.secondaryText)

            Text(librarySummary(for: workout))
                .font(SheLiftsFont.caption)
                .foregroundStyle(IronHerTheme.secondaryText)
        }
        .padding(.vertical, 4)
    }

    private func librarySummary(for workout: Workout) -> String {
        let count = workout.exercises.count
        guard count > 0 else { return "No exercises yet" }
        let label = count == 1 ? "exercise" : "exercises"
        return "\(count) \(label)"
    }

    private func deleteWorkouts(at offsets: IndexSet) {
        for index in offsets {
            let id = workoutStore.workouts[index].id
            workoutStore.deleteWorkout(id: id)
        }
    }
}

#Preview {
    NavigationStack {
        MyWorkoutsView()
            .treniraNavigationDestinations()
            .environment(WorkoutStore())
            .environment(GlobalExerciseProgressStore())
            .environment(LocalizationStore())
    }
}
