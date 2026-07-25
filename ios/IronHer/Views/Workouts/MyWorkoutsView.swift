import SwiftUI

/// Workout library — manage plans. Not where you start today's session.
///
/// Saved workouts: plain Button rows + exactly one trailing `.swipeActions`
/// containing both Delete (red trash) and Duplicate (blue copy).
/// No NavigationLink on those rows — it hides swipe action icons.
/// Drafts keep native `.onDelete` for Delete only.
struct MyWorkoutsView: View {
    @Environment(WorkoutStore.self) private var workoutStore
    @Environment(GlobalExerciseProgressStore.self) private var globalProgressStore
    @Environment(LocalizationStore.self) private var l10n
    @Environment(SubscriptionStore.self) private var subscriptionStore

    @State private var showPremiumUpgrade = false
    @State private var editAfterDuplicate: WorkoutEditDestination?
    @State private var duplicateErrorMessage: String?

    private var savedWorkouts: [Workout] {
        workoutStore.workouts.filter { !$0.isDraft }
    }

    private var drafts: [Workout] {
        workoutStore.draftWorkouts
    }

    var body: some View {
        List {
            if savedWorkouts.isEmpty && drafts.isEmpty {
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
                if !drafts.isEmpty {
                    Section {
                        ForEach(drafts, id: \.id) { draft in
                            NavigationLink {
                                CreateWorkoutView(resumingDraftId: draft.id)
                            } label: {
                                draftRow(draft)
                            }
                        }
                        .onDelete(perform: deleteDrafts)
                    } header: {
                        Text("Drafts")
                    } footer: {
                        Text("Swipe left and tap Delete to permanently remove a draft.")
                            .font(SheLiftsFont.caption)
                    }
                }

                if !savedWorkouts.isEmpty {
                    Section {
                        ForEach(savedWorkouts, id: \.id) { workout in
                            Button {
                                openWorkoutEditor(id: workout.id)
                            } label: {
                                libraryRow(for: workout, canOpen: !workout.exercises.isEmpty)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            // Exactly one trailing swipeActions — both actions must live here.
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    #if DEBUG
                                    print("[WorkoutDelete] Swipe delete tapped for workout: \(workout.id)")
                                    #endif
                                    withAnimation {
                                        workoutStore.deleteWorkout(id: workout.id)
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .tint(Color.red.opacity(0.78))
                                .accessibilityLabel("Delete")

                                Button {
                                    #if DEBUG
                                    print("[WorkoutDuplicate] Swipe duplicate tapped for workout: \(workout.id)")
                                    #endif
                                    duplicateAndOpen(id: workout.id)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                }
                                .tint(Color(.systemGray3))
                                .accessibilityLabel("Duplicate")
                            }
                            .contextMenu {
                                if !workout.exercises.isEmpty {
                                    Button {
                                        openWorkoutEditor(id: workout.id)
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                }
                                Button {
                                    duplicateAndOpen(id: workout.id)
                                } label: {
                                    Label("Duplicate Workout", systemImage: "doc.on.doc")
                                }
                                Button(role: .destructive) {
                                    withAnimation {
                                        workoutStore.deleteWorkout(id: workout.id)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    } footer: {
                        Text("Swipe left for Duplicate and Delete. Delete moves a workout to Recently Deleted for 30 days.")
                            .font(SheLiftsFont.caption)
                    }
                }
            }

            Section {
                NavigationLink(value: WorkoutRoute.recentlyDeleted) {
                    Label("Recently Deleted", systemImage: "trash")
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(IronHerTheme.groupedBackground)
        // Keep system destructive red for swipe Delete; TabView tint must not wash it out.
        .tint(nil)
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
        .navigationDestination(item: $editAfterDuplicate) { target in
            EditWorkoutDetailView(workoutId: target.id)
        }
        .sheet(isPresented: $showPremiumUpgrade) {
            NavigationStack {
                PremiumUpgradeView(highlightFeature: .unlimitedWorkoutPlans)
                    .environment(subscriptionStore)
            }
        }
        .alert(
            "Couldn’t duplicate",
            isPresented: Binding(
                get: { duplicateErrorMessage != nil },
                set: { if !$0 { duplicateErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(duplicateErrorMessage ?? "The workout could not be duplicated. Please try again.")
        }
        .onAppear {
            _ = workoutStore.purgeExpiredDeletedIfNeeded()
            globalProgressStore.applyAll(to: workoutStore)
        }
    }

    private func openWorkoutEditor(id: UUID) {
        guard let workout = savedWorkouts.first(where: { $0.id == id }),
              !workout.exercises.isEmpty else { return }
        editAfterDuplicate = WorkoutEditDestination(id: id)
    }

    private func deleteDrafts(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                workoutStore.deleteDraft(id: drafts[index].id)
            }
        }
    }

    private func duplicateAndOpen(id: UUID) {
        guard subscriptionStore.canCreateWorkoutPlan(currentCount: workoutStore.savedWorkoutCount) else {
            showPremiumUpgrade = true
            return
        }

        do {
            let copy = try workoutStore.duplicateWorkout(id: id)
            #if DEBUG
            print("[WorkoutDuplicate] Duplicate created with ID: \(copy.id)")
            print("[WorkoutDuplicate] Save succeeded")
            #endif
            editAfterDuplicate = WorkoutEditDestination(id: copy.id)
        } catch {
            #if DEBUG
            print("[WorkoutDuplicate] persistence error: \(error)")
            #endif
            duplicateErrorMessage = (error as? LocalizedError)?.errorDescription
                ?? "The workout could not be duplicated. Please try again."
        }
    }

    private func draftRow(_ draft: Workout) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(draft.name)
                    .font(SheLiftsFont.bodyMedium)
                    .foregroundStyle(IronHerTheme.primaryText)
                Spacer()
                Text("Draft")
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
            }
            Text(librarySummary(for: draft))
                .font(SheLiftsFont.caption)
                .foregroundStyle(IronHerTheme.secondaryText)
        }
        .padding(.vertical, 4)
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
}

struct WorkoutEditDestination: Identifiable, Hashable {
    let id: UUID
}

struct RecentlyDeletedWorkoutsView: View {
    @Environment(WorkoutStore.self) private var workoutStore

    var body: some View {
        List {
            if workoutStore.recentlyDeleted.isEmpty {
                ContentUnavailableView(
                    "Nothing here",
                    systemImage: "trash",
                    description: Text("Deleted workouts stay here for 30 days, then are removed permanently.")
                )
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(workoutStore.recentlyDeleted, id: \.id) { workout in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(workout.name)
                                .font(SheLiftsFont.bodyMedium)
                            if let deletedAt = workout.deletedAt {
                                Text("Deleted \(deletedAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(SheLiftsFont.caption)
                                    .foregroundStyle(IronHerTheme.secondaryText)
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                withAnimation {
                                    workoutStore.restoreWorkout(id: workout.id)
                                }
                            } label: {
                                Label("Restore", systemImage: "arrow.uturn.backward")
                            }
                            .tint(.green)
                        }
                    }
                    .onDelete(perform: permanentlyDelete)
                } footer: {
                    Text("Swipe left to delete permanently. Swipe right to restore. Exercise history and progression stay intact.")
                        .font(SheLiftsFont.caption)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Recently Deleted")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            _ = workoutStore.purgeExpiredDeletedIfNeeded()
        }
    }

    private func permanentlyDelete(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                workoutStore.permanentlyDeleteWorkout(id: workoutStore.recentlyDeleted[index].id)
            }
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
            .environment(SubscriptionStore())
    }
}
