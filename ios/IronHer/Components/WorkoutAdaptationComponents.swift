import SwiftUI

struct WorkoutPickerSection: View {
    let title: String
    let workouts: [Workout]
    let selectedWorkoutId: UUID?
    let emptyMessage: String
    let onSelect: (Workout) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(IronHerTheme.primaryText)

            if workouts.isEmpty {
                Text(emptyMessage)
                    .font(.subheadline)
                    .foregroundStyle(IronHerTheme.secondaryText)
            } else {
                ForEach(workouts) { workout in
                    Button {
                        onSelect(workout)
                    } label: {
                        HStack {
                            Text(workout.name)
                                .foregroundStyle(IronHerTheme.primaryText)
                            Spacer()
                            if selectedWorkoutId == workout.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(IronHerTheme.primaryText)
                            }
                        }
                        .padding(14)
                        .background(IronHerTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous)
                                .stroke(IronHerTheme.separator.opacity(0.6), lineWidth: 0.5)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct WorkoutAdaptationProposalsSection: View {
    @Binding var proposals: [WorkoutAdaptationProposal]
    let actionTitle: String
    let onApply: () -> Void

    @State private var swapTarget: WorkoutAdaptationProposal?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let swapCount = proposals.filter(\.isVarietySwap).count

            Text("Suggested changes")
                .font(.headline)
                .foregroundStyle(IronHerTheme.primaryText)

            Text("\(swapCount) exercise\(swapCount == 1 ? "" : "s") updated · sets, reps & weights stay the same")
                .font(.caption)
                .foregroundStyle(IronHerTheme.secondaryText)

            ForEach(proposals) { proposal in
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        if proposal.isVarietySwap {
                            Text("\(proposal.originalName) → \(proposal.proposedName)")
                                .font(.body.weight(.medium))
                                .foregroundStyle(IronHerTheme.primaryText)
                            Text("\(proposal.proposedEquipment) · \(proposal.sets)×\(proposal.reps)")
                                .font(.caption)
                                .foregroundStyle(IronHerTheme.secondaryText)
                        } else {
                            Text(proposal.proposedName)
                                .font(.body.weight(.medium))
                                .foregroundStyle(IronHerTheme.primaryText)
                            Text("Best available match · \(proposal.proposedEquipment)")
                                .font(.caption)
                                .foregroundStyle(IronHerTheme.secondaryText)
                        }
                    }

                    Button {
                        swapTarget = proposal
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
                    .accessibilityLabel("Swap \(proposal.proposedName)")
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(IronHerTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Button(action: onApply) {
                Text(actionTitle)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .sheet(item: $swapTarget) { proposal in
            AdaptSwapExercisePicker(
                originalName: proposal.originalName,
                originalExerciseId: proposal.originalExerciseId,
                excludedIds: excludedIds(for: proposal)
            ) { exercise in
                applySwap(proposalID: proposal.id, exercise: exercise)
            }
        }
    }

    private func excludedIds(for proposal: WorkoutAdaptationProposal) -> Set<String> {
        var ids = Set(proposals.map(\.proposedExerciseId))
        ids.insert(proposal.originalExerciseId)
        return ids
    }

    private func applySwap(proposalID: UUID, exercise: Exercise) {
        guard let index = proposals.firstIndex(where: { $0.id == proposalID }) else { return }
        proposals[index].applyManualSwap(to: exercise)
    }
}

/// Search-and-pick a different exercise for one suggested adaptation. Dismiss without selecting to cancel.
struct AdaptSwapExercisePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LocalizationStore.self) private var l10n
    @Environment(CustomExerciseStore.self) private var customExerciseStore

    let originalName: String
    let originalExerciseId: String
    let excludedIds: Set<String>
    var compatibleEquipment: Set<GymEquipmentKind>? = nil
    let onSelect: (Exercise) -> Void

    @State private var searchText = ""
    @State private var filterEquipment: EquipmentType?
    @State private var filterMuscle: MuscleGroup?
    @FocusState private var isSearchFocused: Bool

    init(
        originalName: String,
        originalExerciseId: String,
        excludedIds: Set<String>,
        compatibleEquipment: Set<GymEquipmentKind>? = nil,
        onSelect: @escaping (Exercise) -> Void
    ) {
        self.originalName = originalName
        self.originalExerciseId = originalExerciseId
        self.excludedIds = excludedIds
        self.compatibleEquipment = compatibleEquipment
        self.onSelect = onSelect
        _filterMuscle = State(initialValue: ExerciseCatalog.exercise(id: originalExerciseId)?.primaryMuscleGroup)
    }

    private var searchFilters: ExerciseSearchFilters {
        ExerciseSearchFilters(muscleGroup: filterMuscle, equipment: filterEquipment)
    }

    private var filteredExercises: [Exercise] {
        let preferred = Set(ExerciseCatalog.exercise(id: originalExerciseId)?.suggestedAlternatives ?? [])
        var results = ExerciseCatalog.search(searchText, filters: searchFilters)
            .filter { !excludedIds.contains($0.id) }
        if let compatibleEquipment {
            results = results.filter { $0.isCompatible(with: compatibleEquipment) }
        }
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let capped: [Exercise]
        if trimmed.isEmpty {
            capped = Array(results.prefix(80))
        } else {
            capped = Array(results.prefix(120))
        }
        if trimmed.isEmpty {
            return capped.sorted { lhs, rhs in
                let leftPreferred = preferred.contains(lhs.id)
                let rightPreferred = preferred.contains(rhs.id)
                if leftPreferred != rightPreferred { return leftPreferred && !rightPreferred }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }
        return capped
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(IronHerTheme.secondaryText)
                    TextField("Search e.g. RDL, row, curl", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($isSearchFocused)
                }
                .padding(14)
                .background(IronHerTheme.groupedBackground)
                .clipShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadiusSmall, style: .continuous))
                .padding(.horizontal)
                .padding(.top)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip("All equipment", selected: filterEquipment == nil) { filterEquipment = nil }
                        ForEach(EquipmentType.allCases) { type in
                            filterChip(type.label, selected: filterEquipment == type) {
                                filterEquipment = filterEquipment == type ? nil : type
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip("All muscles", selected: filterMuscle == nil) { filterMuscle = nil }
                        ForEach([MuscleGroup.chest, .back, .shoulders, .biceps, .triceps, .quads, .hamstrings, .glutes, .core], id: \.self) { group in
                            filterChip(group.label, selected: filterMuscle == group) {
                                filterMuscle = filterMuscle == group ? nil : group
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 6)
                    .padding(.bottom, 4)
                }

                if filteredExercises.isEmpty {
                    Text("No matching exercises.")
                        .font(SheLiftsFont.body)
                        .foregroundStyle(IronHerTheme.secondaryText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredExercises) { exercise in
                        Button {
                            onSelect(exercise)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(exercise.localizedName(using: l10n))
                                    .font(SheLiftsFont.bodyMedium)
                                    .foregroundStyle(IronHerTheme.primaryText)
                                Text(exercise.listSubtitle)
                                    .font(SheLiftsFont.caption)
                                    .foregroundStyle(IronHerTheme.secondaryText)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(IronHerScreenBackground())
            .navigationTitle("Swap exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                Text("Choose a replacement for \(originalName). Cancel to keep the current suggestion.")
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .background(IronHerTheme.background)
            }
            .onAppear {
                isSearchFocused = true
                ExerciseCatalog.syncCustomExercises(customExerciseStore.exercises)
            }
        }
        .presentationDetents([.large])
    }

    private func filterChip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(SheLiftsFont.caption)
                .foregroundStyle(selected ? IronHerTheme.accentForeground : IronHerTheme.primaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(selected ? IronHerTheme.accent : IronHerTheme.cardBackground)
                .clipShape(Capsule())
                .overlay {
                    if !selected {
                        Capsule()
                            .stroke(IronHerTheme.separator.opacity(0.6), lineWidth: 0.5)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}
