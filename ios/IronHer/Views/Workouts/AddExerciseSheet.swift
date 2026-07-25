import SwiftUI

struct AddExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WorkoutStore.self) private var workoutStore
    @Environment(UserSettingsStore.self) private var settingsStore
    @Environment(CustomExerciseStore.self) private var customExerciseStore
    @Environment(GlobalExerciseProgressStore.self) private var globalProgressStore
    @Environment(ExerciseProgressionStore.self) private var progressionStore
    @Environment(LocalizationStore.self) private var l10n

    let onAdd: (DraftWorkoutExercise) -> Void

    @State private var searchText = ""
    @State private var selectedExercise: Exercise?
    @State private var sets = 3
    @State private var reps = 10
    @State private var startingWeightInput = 0.0
    @State private var durationSeconds = 60
    @State private var distanceMeters = 40.0
    @State private var showCreateCustom = false
    @State private var speechService = SpeechSearchService()
    @FocusState private var isSearchFocused: Bool
    @State private var filterEquipment: EquipmentType?
    @State private var filterMuscle: MuscleGroup?
    @State private var pendingIncrementExercise: Exercise?
    @State private var pendingDraft: DraftWorkoutExercise?

    private var searchFilters: ExerciseSearchFilters {
        ExerciseSearchFilters(muscleGroup: filterMuscle, equipment: filterEquipment)
    }

    private var filteredExercises: [Exercise] {
        ExerciseCatalog.search(searchText, filters: searchFilters)
    }

    private var showEmptyState: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && filteredExercises.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if let selectedExercise {
                    exerciseDetailForm(for: selectedExercise)
                } else {
                    exerciseSearchList
                }
            }
            .navigationTitle(selectedExercise == nil ? "Add Exercise" : "Exercise Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(selectedExercise == nil ? "Cancel" : "Back") {
                        if selectedExercise == nil {
                            dismiss()
                        } else {
                            self.selectedExercise = nil
                        }
                    }
                }
            }
            .onChange(of: speechService.transcript) { _, transcript in
                guard !transcript.isEmpty else { return }
                searchText = transcript
            }
            .onDisappear {
                speechService.stopListening()
            }
            .task {
                await speechService.requestAuthorization()
            }
            .sheet(isPresented: $showCreateCustom) {
                CreateCustomExerciseSheet(initialName: searchText) { exercise in
                    selectExercise(exercise)
                }
            }
            .sheet(item: $pendingIncrementExercise, onDismiss: {
                if pendingDraft != nil {
                    commitPendingDraft()
                }
            }) { exercise in
                ExerciseIncrementPromptSheet(exercise: exercise) {
                    commitPendingDraft()
                }
            }
        }
    }

    private var exerciseSearchList: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(IronHerTheme.secondaryText)

                TextField("Search e.g. RDL, row, curl", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isSearchFocused)

                Button {
                    toggleVoiceSearch()
                } label: {
                    Image(systemName: speechService.isListening ? "mic.fill" : "mic")
                        .foregroundStyle(speechService.isListening ? IronHerTheme.primaryText : IronHerTheme.secondaryText)
                        .symbolEffect(.pulse, isActive: speechService.isListening)
                }
                .buttonStyle(.plain)
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

            if showEmptyState {
                emptySearchState
            } else {
                List(filteredExercises) { exercise in
                    Button {
                        selectExercise(exercise)
                    } label: {
                        exerciseRow(exercise)
                    }
                }
                .listStyle(.plain)
            }
        }
        .onAppear {
            isSearchFocused = true
            ExerciseCatalog.syncCustomExercises(customExerciseStore.exercises)
        }
    }

    private var emptySearchState: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("Can't find your exercise?")
                .font(SheLiftsFont.section)
                .foregroundStyle(IronHerTheme.primaryText)

            Button {
                showCreateCustom = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Create Custom Exercise")
                }
                .font(SheLiftsFont.bodyMedium)
                .foregroundStyle(IronHerTheme.primaryText)
            }
            .buttonStyle(SheLiftsPressStyle())

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, IronHerTheme.screenPadding)
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        ExerciseThumbnailSlot(exercise: exercise) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(exercise.localizedName(using: l10n))
                        .font(SheLiftsFont.bodyMedium)
                        .foregroundStyle(IronHerTheme.primaryText)

                    if exercise.isCustom {
                        Text("Custom")
                            .font(SheLiftsFont.caption)
                            .foregroundStyle(IronHerTheme.secondaryText)
                    }
                }

                Text(exercise.listSubtitle)
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)

                if let weight = globalProgressStore.workingWeightKg(for: exercise.id) ?? workoutStore.knownStartingWeight(for: exercise.id),
                   weight > 0,
                   exercise.measurementUnit != .reps,
                   exercise.measurementUnit != .bodyweight {
                    let unit = globalProgressStore.resolvedWeightUnit(
                        for: exercise.id,
                        defaultUnit: settingsStore.weightUnit
                    )
                    Text("Saved: \(WeightFormatter.format(kg: weight, unit: unit))")
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)
                } else if let reps = globalProgressStore.targetReps(for: exercise.id),
                          exercise.measurementUnit == .reps || exercise.measurementUnit == .bodyweight {
                    Text("Saved: \(reps) reps")
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func exerciseDetailForm(for exercise: Exercise) -> some View {
        Form {
            Section {
                ExerciseThumbnailSlot(exercise: exercise, size: 72) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.localizedName(using: l10n))
                            .font(SheLiftsFont.section)
                            .foregroundStyle(IronHerTheme.primaryText)

                        Text(exercise.listSubtitle)
                            .font(SheLiftsFont.subheadline)
                            .foregroundStyle(IronHerTheme.secondaryText)

                        Text(ExerciseTrackingFormatter.trackingLabel(for: exercise))
                            .font(SheLiftsFont.caption)
                            .foregroundStyle(IronHerTheme.secondaryText)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Tracking") {
                ExerciseTrackingFields(
                    exercise: exercise,
                    sets: $sets,
                    reps: $reps,
                    weightInput: $startingWeightInput,
                    durationSeconds: $durationSeconds,
                    distanceMeters: $distanceMeters
                )

                if usesWeightInput(for: exercise.measurementUnit) {
                    Text("Weight and reps update across every workout that includes this exercise.")
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)
                }
            }

            ProgressionConfigurationPicker(exerciseId: exercise.id) { configuration in
                sets = configuration.targetSets
            }

            Section {
                Button("Add to workout") {
                    addExercise(exercise)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundStyle(IronHerTheme.accent)
            }
        }
    }

    private func addExercise(_ exercise: Exercise) {
        let weightKg: Double
        if usesWeightInput(for: exercise.measurementUnit) {
            let unit = globalProgressStore.resolvedWeightUnit(
                for: exercise.id,
                defaultUnit: settingsStore.weightUnit
            )
            weightKg = WeightFormatter.kilograms(from: startingWeightInput, unit: unit)
        } else {
            weightKg = 0
        }

        let draft = DraftWorkoutExercise(
            exercise: exercise,
            sets: sets,
            reps: reps,
            startingWeight: weightKg,
            durationSeconds: durationSeconds,
            distanceMeters: distanceMeters
        )

        if settingsStore.needsContextualIncrementPrompt(for: exercise),
           progressionStore.dimension(for: exercise) == .weight {
            pendingDraft = draft
            pendingIncrementExercise = exercise
            return
        }

        onAdd(draft)
        dismiss()
    }

    private func commitPendingDraft() {
        guard let draft = pendingDraft else {
            dismiss()
            return
        }
        onAdd(draft)
        pendingDraft = nil
        dismiss()
    }

    private func usesWeightInput(for measurement: MeasurementUnit) -> Bool {
        measurement == .weight || measurement == .weightAndTime || measurement == .repsWithOptionalWeight
    }

    private func selectExercise(_ exercise: Exercise) {
        speechService.stopListening()
        selectedExercise = exercise
        let philosophy = progressionStore.configuration(for: exercise.id)
        sets = philosophy.targetSets
        durationSeconds = ExerciseTrackingFormatter.defaultDurationSeconds(for: exercise.measurementUnit)
        distanceMeters = ExerciseTrackingFormatter.defaultDistanceMeters(for: exercise.measurementUnit)

        if let savedSets = globalProgressStore.targetSets(for: exercise.id) {
            sets = savedSets
        }

        if let savedReps = globalProgressStore.targetReps(for: exercise.id) ?? workoutStore.knownReps(for: exercise.id) {
            reps = savedReps
        } else {
            reps = philosophy.startingReps
        }

        switch exercise.measurementUnit {
        case .reps, .bodyweight:
            startingWeightInput = 0
        default:
            if let saved = globalProgressStore.workingWeightKg(for: exercise.id) ?? workoutStore.knownStartingWeight(for: exercise.id) {
                let unit = globalProgressStore.resolvedWeightUnit(
                    for: exercise.id,
                    defaultUnit: settingsStore.weightUnit
                )
                startingWeightInput = WeightFormatter.displayValue(kg: saved, unit: unit)
            } else {
                startingWeightInput = 0
            }
        }

        if let progress = globalProgressStore.progress(for: exercise.id) {
            if progress.targetDurationSeconds > 0 {
                durationSeconds = progress.targetDurationSeconds
            }
            if progress.targetDistanceMeters > 0 {
                distanceMeters = progress.targetDistanceMeters
            }
        }
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

    private func toggleVoiceSearch() {
        if speechService.isListening {
            speechService.stopListening()
        } else {
            speechService.startListening()
        }
    }
}

#Preview {
    AddExerciseSheet { _ in }
        .environment(WorkoutStore())
        .environment(UserSettingsStore())
        .environment(CustomExerciseStore())
        .environment(GlobalExerciseProgressStore())
        .environment(ExerciseProgressionStore())
        .environment(LocalizationStore())
}
