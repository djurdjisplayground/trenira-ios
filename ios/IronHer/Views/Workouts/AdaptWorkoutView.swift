import SwiftUI

struct AdaptWorkoutView: View {
    @Environment(WorkoutStore.self) private var workoutStore
    @Environment(SubscriptionStore.self) private var subscriptionStore
    @Environment(GymEquipmentProfileStore.self) private var gymProfiles
    @Environment(\.dismiss) private var dismiss

    @State private var selectedWorkoutId: UUID?
    @State private var selectedKinds: Set<GymEquipmentKind> = []
    @State private var proposals: [WorkoutAdaptationProposal] = []
    @State private var showProposals = false
    @State private var showPremiumUpgrade = false

    private var eligibleWorkouts: [Workout] {
        workoutStore.workouts.filter { !$0.exercises.isEmpty }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                introSection
                workoutPicker
                equipmentSection
                generateButton

                if showProposals, !proposals.isEmpty {
                    proposalsSection
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(IronHerScreenBackground())
        .navigationTitle("Adapt Workout")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPremiumUpgrade) {
            NavigationStack {
                PremiumUpgradeView(highlightFeature: .unlimitedWorkoutPlans)
            }
        }
        .onAppear {
            if selectedKinds.isEmpty {
                selectedKinds = gymProfiles.currentEquipment(fallback: GymEquipmentPreset.hotelGym.equipment)
            }
        }
    }

    private var introSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What equipment is available today?")
                .font(SheLiftsFont.bodyMedium)
                .foregroundStyle(IronHerTheme.primaryText)
            Text("Adjust for a different gym, limited equipment, or training at home. Your progression stays with each exercise.")
                .font(SheLiftsFont.body)
                .foregroundStyle(IronHerTheme.secondaryText)
        }
    }

    private var workoutPicker: some View {
        WorkoutPickerSection(
            title: "Workout to adapt",
            workouts: eligibleWorkouts,
            selectedWorkoutId: selectedWorkoutId,
            emptyMessage: "Create a workout with exercises first."
        ) { workout in
            selectWorkout(workout)
        }
    }

    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            GymProfilePickerRow(selection: $selectedKinds)
            GymEquipmentPicker(selection: $selectedKinds)
        }
    }

    private var generateButton: some View {
        Button {
            generateProposals()
        } label: {
            Text("Adapt Workout")
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(selectedWorkoutId == nil || selectedKinds.isEmpty)
    }

    private var proposalsSection: some View {
        WorkoutAdaptationProposalsSection(
            proposals: proposals,
            actionTitle: "Save adapted workout"
        ) {
            applyAdaptation()
        }
    }

    private func selectWorkout(_ workout: Workout) {
        selectedWorkoutId = workout.id
        showProposals = false
    }

    private func generateProposals() {
        guard let workoutId = selectedWorkoutId,
              let workout = workoutStore.workout(id: workoutId) else { return }

        proposals = WorkoutAdaptationService.proposeRefresh(
            for: workout,
            mode: .detailedEquipment(selectedKinds)
        )
        showProposals = true
    }

    private func applyAdaptation() {
        guard let workoutId = selectedWorkoutId,
              let workout = workoutStore.workout(id: workoutId) else { return }

        guard subscriptionStore.canCreateWorkoutPlan(currentCount: workoutStore.workouts.count) else {
            showPremiumUpgrade = true
            return
        }

        let adapted = WorkoutAdaptationService.buildRefreshedWorkout(
            from: workout,
            proposals: proposals,
            mode: .detailedEquipment(selectedKinds)
        )
        workoutStore.createWorkout(named: adapted.name, exercises: adapted.exercises)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        AdaptWorkoutView()
            .environment(WorkoutStore())
            .environment(SubscriptionStore())
            .environment(GymEquipmentProfileStore())
    }
}
