import SwiftUI

/// What the user wants to change about an existing workout.
private enum AdaptationIntent: String, CaseIterable, Identifiable, Hashable {
    case availableEquipment
    case homeWorkout
    case hotelGym
    case differentGym
    case refreshVariety
    case replaceSeveral

    var id: String { rawValue }

    var title: String {
        switch self {
        case .availableEquipment: return "Available equipment"
        case .homeWorkout: return "Home workout"
        case .hotelGym: return "Hotel gym"
        case .differentGym: return "Different gym"
        case .refreshVariety: return "Fresh exercise variety"
        case .replaceSeveral: return "Replace several exercises"
        }
    }

    var subtitle: String {
        switch self {
        case .availableEquipment: return "Adapt to the equipment you have today"
        case .homeWorkout: return "Dumbbells, bench, and bodyweight"
        case .hotelGym: return "Limited free weights and machines"
        case .differentGym: return "Choose a full custom equipment list"
        case .refreshVariety: return "Keep similar equipment, change movements"
        case .replaceSeveral: return "Swap multiple exercises while keeping progression"
        }
    }
}

struct AdaptWorkoutView: View {
    @Environment(WorkoutStore.self) private var workoutStore
    @Environment(SubscriptionStore.self) private var subscriptionStore
    @Environment(LocalizationStore.self) private var l10n
    @Environment(\.dismiss) private var dismiss

    @State private var selectedWorkoutId: UUID?
    @State private var selectedIntent: AdaptationIntent?
    @State private var selectedKinds: Set<GymEquipmentKind> = []
    @State private var proposals: [WorkoutAdaptationProposal] = []
    @State private var showProposals = false
    @State private var showPremiumUpgrade = false

    private var eligibleWorkouts: [Workout] {
        workoutStore.workouts.filter { !$0.isDraft && !$0.exercises.isEmpty }
    }

    private var showsEquipmentPicker: Bool {
        guard let selectedIntent else { return false }
        switch selectedIntent {
        case .availableEquipment, .differentGym:
            return true
        case .homeWorkout, .hotelGym, .refreshVariety, .replaceSeveral:
            return false
        }
    }

    private var canGenerate: Bool {
        guard selectedWorkoutId != nil, let intent = selectedIntent else { return false }
        switch intent {
        case .availableEquipment, .differentGym:
            return !selectedKinds.isEmpty
        case .homeWorkout, .hotelGym, .refreshVariety, .replaceSeveral:
            return true
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                introSection
                workoutPicker
                intentSection

                if showsEquipmentPicker {
                    equipmentSection
                }

                adaptButton

                if showProposals {
                    proposalsSection
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(IronHerScreenBackground())
        .navigationTitle(l10n.t(.adapt_workout))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPremiumUpgrade) {
            NavigationStack {
                PremiumUpgradeView(highlightFeature: .adaptWorkout)
            }
        }
        .onAppear {
            if selectedKinds.isEmpty {
                selectedKinds = GymEquipmentPreset.fullGym.equipment
            }
        }
    }

    private var introSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l10n.t(.adapt_intro_title))
                .font(SheLiftsFont.bodyMedium)
                .foregroundStyle(IronHerTheme.primaryText)
            Text(l10n.t(.adapt_intro_body))
                .font(SheLiftsFont.body)
                .foregroundStyle(IronHerTheme.secondaryText)
        }
    }

    private var workoutPicker: some View {
        WorkoutPickerSection(
            title: l10n.t(.adapt_workout_picker_title),
            workouts: eligibleWorkouts,
            selectedWorkoutId: selectedWorkoutId,
            emptyMessage: "Create a workout with exercises first."
        ) { workout in
            selectedWorkoutId = workout.id
            showProposals = false
            proposals = []
        }
    }

    private var intentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l10n.t(.adapt_what_title))
                .font(SheLiftsFont.section)
                .foregroundStyle(IronHerTheme.primaryText)

            VStack(spacing: 0) {
                ForEach(AdaptationIntent.allCases) { intent in
                    Button {
                        selectedIntent = intent
                        showProposals = false
                        proposals = []
                        applyPresetEquipment(for: intent)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: selectedIntent == intent ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(
                                    selectedIntent == intent
                                        ? IronHerTheme.accent
                                        : IronHerTheme.secondaryText
                                )
                            VStack(alignment: .leading, spacing: 4) {
                                Text(intent.title)
                                    .font(SheLiftsFont.bodyMedium)
                                    .foregroundStyle(IronHerTheme.primaryText)
                                Text(intent.subtitle)
                                    .font(SheLiftsFont.caption)
                                    .foregroundStyle(IronHerTheme.secondaryText)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)

                    if intent != AdaptationIntent.allCases.last {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 14)
            .background(IronHerTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous))
        }
    }

    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l10n.t(.adapt_equipment_title))
                .font(SheLiftsFont.section)
                .foregroundStyle(IronHerTheme.primaryText)
            GymEquipmentPicker(selection: $selectedKinds)
        }
    }

    private var adaptButton: some View {
        Button {
            generateProposals()
        } label: {
            Text(l10n.t(.adapt_workout))
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!canGenerate)
    }

    private var proposalsSection: some View {
        Group {
            if proposals.isEmpty {
                Text(l10n.t(.adapt_no_alternatives))
                    .font(SheLiftsFont.body)
                    .foregroundStyle(IronHerTheme.secondaryText)
            } else {
                WorkoutAdaptationProposalsSection(
                    proposals: proposals,
                    actionTitle: l10n.t(.adapt_save_action)
                ) {
                    applyAdaptation()
                }
            }
        }
    }

    private func applyPresetEquipment(for intent: AdaptationIntent) {
        switch intent {
        case .homeWorkout:
            selectedKinds = GymEquipmentPreset.dumbbellsOnly.equipment
        case .hotelGym:
            selectedKinds = [
                .dumbbells, .kettlebells, .cableStation, .flatBench, .adjustableBench,
                .legPress, .chestPressMachine, .latPulldownMachine, .seatedRowMachine,
                .pullUpBar, .bodyweight, .resistanceBands,
            ]
        case .availableEquipment, .differentGym:
            if selectedKinds.isEmpty {
                selectedKinds = GymEquipmentPreset.fullGym.equipment
            }
        case .refreshVariety, .replaceSeveral:
            break
        }
    }

    private func generateProposals() {
        guard let workoutId = selectedWorkoutId,
              let workout = workoutStore.workout(id: workoutId),
              let intent = selectedIntent
        else { return }

        let mode: WorkoutRefreshMode
        switch intent {
        case .refreshVariety, .replaceSeveral:
            mode = .sameEquipment
        case .homeWorkout, .hotelGym, .availableEquipment, .differentGym:
            mode = .detailedEquipment(selectedKinds)
        }

        proposals = WorkoutAdaptationService.proposeRefresh(for: workout, mode: mode)
        showProposals = true
    }

    private func applyAdaptation() {
        guard let workoutId = selectedWorkoutId,
              let workout = workoutStore.workout(id: workoutId),
              let intent = selectedIntent
        else { return }

        guard subscriptionStore.canCreateWorkoutPlan(currentCount: workoutStore.savedWorkoutCount) else {
            showPremiumUpgrade = true
            return
        }

        let mode: WorkoutRefreshMode
        switch intent {
        case .refreshVariety, .replaceSeveral:
            mode = .sameEquipment
        case .homeWorkout, .hotelGym, .availableEquipment, .differentGym:
            mode = .detailedEquipment(selectedKinds)
        }

        let adapted = WorkoutAdaptationService.buildRefreshedWorkout(
            from: workout,
            proposals: proposals,
            mode: mode
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
            .environment(LocalizationStore())
    }
}
