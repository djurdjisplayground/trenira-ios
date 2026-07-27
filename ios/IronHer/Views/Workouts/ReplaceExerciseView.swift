import SwiftUI

/// Replace a single exercise in a plan or active session, with optional global sync.
/// Contained multi-step flow — Back never pops the parent workout editor.
struct ReplaceExerciseView: View {
    @Environment(WorkoutStore.self) private var workoutStore
    @Environment(GlobalExerciseProgressStore.self) private var globalProgressStore
    @Environment(WorkoutSessionStore.self) private var sessionStore
    @Environment(\.dismiss) private var dismiss

    let workoutId: UUID
    let entryId: UUID
    var isActiveSession: Bool = false

    @State private var flow: ExerciseReplacementFlowModel?
    @State private var searchText = ""
    @State private var showSessionPersistChoice = false
    @State private var showEditScopeChoice = false
    @State private var showPlanScopeChoice = false
    @State private var showGlobalConfirm = false
    @State private var showLibrarySearch = false
    @State private var loadFailed = false

    private var coordinator: ExerciseReplacementCoordinator {
        ExerciseReplacementCoordinator(
            workoutStore: workoutStore,
            sessionStore: sessionStore,
            globalProgressStore: globalProgressStore
        )
    }

    private var plansContainingOriginal: Int {
        guard let flow else { return 0 }
        return coordinator.savedPlanCount(containing: flow.originalExercise.id)
    }

    private var filteredRecommendations: [ExerciseRecommendation] {
        guard let flow else { return [] }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return flow.recommendations }
        return flow.recommendations.filter {
            $0.exercise.name.localizedCaseInsensitiveContains(query)
                || $0.exercise.primaryMuscleGroup.label.localizedCaseInsensitiveContains(query)
                || $0.exercise.equipment.label.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        Group {
            if let flow {
                flowContent(flow)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(IronHerScreenBackground())
            }
        }
        .onAppear(perform: ensureFlow)
        .sheet(isPresented: $showLibrarySearch) {
            NavigationStack {
                ExerciseMasterView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Close") { showLibrarySearch = false }
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private func flowContent(_ flow: ExerciseReplacementFlowModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let status = flow.statusMessage {
                    Text(status)
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(IronHerTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadiusSmall, style: .continuous))
                }

                Text(flow.originalExercise.name)
                    .font(SheLiftsFont.bodyMedium)
                    .foregroundStyle(IronHerTheme.primaryText)

                switch flow.step {
                case .selectReason:
                    reasonSection(flow)
                case .recommendations:
                    recommendationsSection(flow)
                case .selectScope:
                    // Scope is presented via confirmationDialog; keep list context visible.
                    recommendationsSection(flow)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(IronHerScreenBackground())
        .navigationTitle(flow.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    flow.goBack()
                } label: {
                    if case .selectReason = flow.step {
                        Text("Cancel")
                    } else {
                        Label("Back", systemImage: "chevron.left")
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if case .selectReason = flow.step {
                    EmptyView()
                } else {
                    Button("Close") { flow.cancel() }
                        .foregroundStyle(IronHerTheme.secondaryText)
                }
            }
        }
        .interactiveDismissDisabled(flow.isLoading)
        .onChange(of: flow.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss { dismiss() }
        }
        .confirmationDialog(
            "Use this replacement next time too?",
            isPresented: $showSessionPersistChoice,
            titleVisibility: .visible
        ) {
            Button("This Session Only") { commit(flow, scope: .currentSession) }
            Button("Update Workout Plan") { handleUpdateWorkoutPlanTapped(flow) }
            Button("Cancel", role: .cancel) { flow.clearSelectedReplacement() }
        }
        .confirmationDialog(
            "Where should this exercise be replaced?",
            isPresented: $showEditScopeChoice,
            titleVisibility: .visible
        ) {
            Button("This Workout Only") { commit(flow, scope: .currentWorkout) }
            if plansContainingOriginal > 1 {
                Button("All Workouts") { showGlobalConfirm = true }
            }
            Button("Cancel", role: .cancel) { flow.clearSelectedReplacement() }
        } message: {
            Text("This exercise appears in \(plansContainingOriginal) workout plans.")
        }
        .confirmationDialog(
            "Update which workout plans?",
            isPresented: $showPlanScopeChoice,
            titleVisibility: .visible
        ) {
            Button("This Workout Only") { commit(flow, scope: .currentWorkout) }
            Button("All Workouts") { showGlobalConfirm = true }
            Button("Cancel", role: .cancel) { flow.clearSelectedReplacement() }
        } message: {
            Text("This exercise appears in \(plansContainingOriginal) workout plans.")
        }
        .confirmationDialog(
            globalConfirmTitle(flow),
            isPresented: $showGlobalConfirm,
            titleVisibility: .visible
        ) {
            Button("Replace Everywhere") { commit(flow, scope: .allWorkouts) }
            Button("Cancel", role: .cancel) { flow.clearSelectedReplacement() }
        }
        .onChange(of: flow.step) { _, step in
            if case .selectScope = step {
                presentScopeChoice(flow)
            }
        }
    }

    // MARK: - Sections

    private func reasonSection(_ flow: ExerciseReplacementFlowModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Why would you like to replace this exercise?")
                .font(SheLiftsFont.section)
                .foregroundStyle(IronHerTheme.primaryText)

            VStack(spacing: 0) {
                ForEach(ExerciseReplacementReason.allCases) { reason in
                    Button {
                        loadFailed = false
                        searchText = ""
                        flow.selectReason(reason)
                    } label: {
                        HStack {
                            Text(reason.title)
                                .font(SheLiftsFont.bodyMedium)
                                .foregroundStyle(IronHerTheme.primaryText)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 12)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(IronHerTheme.secondaryText)
                        }
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(flow.isLoading)
                    .accessibilityLabel(reason.title)
                    .accessibilityAddTraits(.isButton)

                    if reason != ExerciseReplacementReason.allCases.last {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 14)
            .background(IronHerTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous))
        }
    }

    private func recommendationsSection(_ flow: ExerciseReplacementFlowModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(flow.recommendationsSupportingText)
                .font(SheLiftsFont.caption)
                .foregroundStyle(IronHerTheme.secondaryText)

            if flow.isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(
                        flow.selectedReason == .cannotIncreaseWeight
                            ? "Finding harder alternatives…"
                            : "Finding alternatives…"
                    )
                    .font(SheLiftsFont.subheadline)
                    .foregroundStyle(IronHerTheme.secondaryText)
                }
                .padding(.vertical, 8)
            }

            TextField("Search exercises", text: $searchText)
                .padding(12)
                .background(IronHerTheme.groupedBackground)
                .clipShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadiusSmall, style: .continuous))
                .disabled(flow.isLoading)

            if loadFailed {
                fallbackCard(
                    title: "Couldn't load alternatives",
                    body: "Please try again or search the exercise library.",
                    primary: "Try Again",
                    primaryAction: {
                        loadFailed = false
                        flow.retryRecommendations()
                    }
                )
            } else if case .empty = flow.loadState, !flow.isLoading {
                fallbackCard(
                    title: "No close alternatives found",
                    body: "Try a broader alternative targeting the same muscles, or search the exercise library.",
                    primary: "Search Exercise Library",
                    primaryAction: { showLibrarySearch = true }
                )
            } else if filteredRecommendations.isEmpty, !flow.isLoading, !flow.recommendations.isEmpty {
                Text("No matches for this search.")
                    .font(SheLiftsFont.subheadline)
                    .foregroundStyle(IronHerTheme.secondaryText)
            } else {
                ForEach(filteredRecommendations) { recommendation in
                    recommendationButton(flow, recommendation)
                }
            }

            if !flow.isLoading {
                Button("Search Exercise Library") {
                    showLibrarySearch = true
                }
                .buttonStyle(OutlineButtonStyle())
                .padding(.top, 4)
            }
        }
    }

    private func fallbackCard(
        title: String,
        body: String,
        primary: String,
        primaryAction: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(SheLiftsFont.bodyMedium)
                .foregroundStyle(IronHerTheme.primaryText)
            Text(body)
                .font(SheLiftsFont.caption)
                .foregroundStyle(IronHerTheme.secondaryText)

            Button(primary, action: primaryAction)
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(IronHerTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func recommendationButton(
        _ flow: ExerciseReplacementFlowModel,
        _ recommendation: ExerciseRecommendation
    ) -> some View {
        Button {
            choose(flow, recommendation)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(recommendation.exercise.name)
                    .font(SheLiftsFont.bodyMedium)
                    .foregroundStyle(IronHerTheme.primaryText)

                Text("\(recommendation.exercise.primaryMuscleGroup.label) · \(recommendation.exercise.equipment.label)")
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)

                Text(recommendation.suitabilityReason)
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)

                if recommendation.isBroaderAlternative {
                    Text("Broader alternative")
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .contentShape(Rectangle())
            .background(IronHerTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(flow.isLoading)
        .accessibilityLabel(recommendation.exercise.name)
    }

    // MARK: - Actions

    private func ensureFlow() {
        guard flow == nil else { return }
        guard let workout = workoutStore.workout(id: workoutId),
              let entry = workout.exercises.first(where: { $0.id == entryId }),
              let exercise = ExerciseCatalog.exercise(
                id: sessionStore.activeSession?.resolvedExerciseId(for: entry) ?? entry.exerciseId
              )
        else {
            dismiss()
            return
        }

        flow = ExerciseReplacementFlowModel(
            workoutId: workoutId,
            entryId: entryId,
            isActiveSession: isActiveSession,
            originalEntry: entry,
            originalExercise: exercise
        )
    }

    private func choose(_ flow: ExerciseReplacementFlowModel, _ recommendation: ExerciseRecommendation) {
        flow.selectReplacement(recommendation)
    }

    private func presentScopeChoice(_ flow: ExerciseReplacementFlowModel) {
        if isActiveSession {
            showSessionPersistChoice = true
        } else if plansContainingOriginal > 1 {
            showEditScopeChoice = true
        } else {
            commit(flow, scope: .currentWorkout)
        }
    }

    private func handleUpdateWorkoutPlanTapped(_ flow: ExerciseReplacementFlowModel) {
        if plansContainingOriginal > 1 {
            showPlanScopeChoice = true
        } else {
            commit(flow, scope: .currentWorkout)
        }
    }

    private func globalConfirmTitle(_ flow: ExerciseReplacementFlowModel) -> String {
        let from = flow.originalExercise.name
        let to = flow.selectedReplacement?.exercise.name ?? "the replacement"
        let n = plansContainingOriginal
        let plans = n == 1 ? "1 workout plan" : "\(n) workout plans"
        return "Replace \(from) with \(to) in \(plans)?"
    }

    private func commit(_ flow: ExerciseReplacementFlowModel, scope: ExerciseReplacementScope) {
        guard let recommendation = flow.selectedReplacement else { return }

        let result = coordinator.replace(
            originalExerciseId: flow.originalExercise.id,
            replacement: recommendation.exercise,
            scope: scope,
            currentWorkoutId: workoutId,
            selectedEntryId: entryId
        )

        flow.noteStatus(result.feedbackMessage)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            flow.cancel()
        }
    }
}

#Preview {
    NavigationStack {
        ReplaceExerciseView(workoutId: UUID(), entryId: UUID())
            .environment(WorkoutStore())
            .environment(GlobalExerciseProgressStore())
            .environment(WorkoutSessionStore())
    }
}
