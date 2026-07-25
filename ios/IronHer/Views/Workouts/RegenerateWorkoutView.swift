import SwiftUI

struct RegenerateWorkoutView: View {
    @Environment(WorkoutStore.self) private var workoutStore
    @Environment(SubscriptionStore.self) private var subscriptionStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedWorkoutId: UUID?
    @State private var selectedKinds: Set<GymEquipmentKind> = []
    @State private var useSameEquipment = true
    @State private var proposals: [WorkoutAdaptationProposal] = []
    @State private var showProposals = false
    @State private var showPremiumUpgrade = false

    private var eligibleWorkouts: [Workout] {
        workoutStore.workouts.filter { !$0.isDraft && !$0.exercises.isEmpty }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                introSection
                workoutPicker
                equipmentChoiceSection
                generateButton

                if showProposals, !proposals.isEmpty {
                    proposalsSection
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(IronHerScreenBackground())
        .navigationTitle("Regenerate Workout")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPremiumUpgrade) {
            NavigationStack {
                PremiumUpgradeView(highlightFeature: .regenerateWorkout)
            }
        }
        .onAppear {
            if selectedKinds.isEmpty {
                selectedKinds = GymEquipmentPreset.fullGym.equipment
            }
        }
    }

    private var introSection: some View {
        Text("Refresh exercises while keeping your focus and progression where it still fits.")
            .font(SheLiftsFont.body)
            .foregroundStyle(IronHerTheme.secondaryText)
    }

    private var workoutPicker: some View {
        WorkoutPickerSection(
            title: "Workout to regenerate",
            workouts: eligibleWorkouts,
            selectedWorkoutId: selectedWorkoutId,
            emptyMessage: "Create a workout with exercises first."
        ) { workout in
            selectedWorkoutId = workout.id
            showProposals = false
            proposals = []
        }
    }

    private var equipmentChoiceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What equipment is available today?")
                .font(.headline)
                .foregroundStyle(IronHerTheme.primaryText)

            Toggle("Keep similar equipment variety", isOn: $useSameEquipment)
                .font(SheLiftsFont.body)

            if !useSameEquipment {
                GymEquipmentPicker(selection: $selectedKinds)
            }
        }
    }

    private var generateButton: some View {
        Button {
            generateProposals()
        } label: {
            Text("Regenerate Workout")
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(selectedWorkoutId == nil || (!useSameEquipment && selectedKinds.isEmpty))
    }

    private var proposalsSection: some View {
        Group {
            if proposals.isEmpty {
                Text("No alternative exercises found for this workout with the current equipment.")
                    .font(SheLiftsFont.body)
                    .foregroundStyle(IronHerTheme.secondaryText)
            } else {
                WorkoutAdaptationProposalsSection(
                    proposals: proposals,
                    actionTitle: "Save regenerated workout"
                ) {
                    applyRefresh()
                }
            }
        }
    }

    private func generateProposals() {
        guard let workoutId = selectedWorkoutId,
              let workout = workoutStore.workout(id: workoutId) else { return }

        let mode: WorkoutRefreshMode = useSameEquipment
            ? .sameEquipment
            : .detailedEquipment(selectedKinds)
        proposals = WorkoutAdaptationService.proposeRefresh(for: workout, mode: mode)
        showProposals = true
    }

    private func applyRefresh() {
        guard let workoutId = selectedWorkoutId,
              let workout = workoutStore.workout(id: workoutId) else { return }

        guard subscriptionStore.canCreateWorkoutPlan(currentCount: workoutStore.savedWorkoutCount) else {
            showPremiumUpgrade = true
            return
        }

        let mode: WorkoutRefreshMode = useSameEquipment
            ? .sameEquipment
            : .detailedEquipment(selectedKinds)
        let refreshed = WorkoutAdaptationService.buildRefreshedWorkout(
            from: workout,
            proposals: proposals,
            mode: mode
        )
        workoutStore.createWorkout(named: refreshed.name, exercises: refreshed.exercises)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        RegenerateWorkoutView()
            .environment(WorkoutStore())
            .environment(SubscriptionStore())
    }
}
