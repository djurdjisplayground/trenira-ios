import SwiftUI

struct ActiveWorkoutView: View {
    @Environment(WorkoutStore.self) private var workoutStore
    @Environment(WeightHistoryStore.self) private var historyStore
    @Environment(UserSettingsStore.self) private var settingsStore
    @Environment(ExerciseProgressionStore.self) private var progressionStore
    @Environment(GlobalExerciseProgressStore.self) private var globalProgressStore
    @Environment(WorkoutSessionStore.self) private var sessionStore
    @Environment(TestingTimeStore.self) private var testingTimeStore
    @Environment(LocalizationStore.self) private var l10n
    @Environment(\.dismiss) private var dismiss

    let workoutId: UUID
    /// When true, open the lighter-start sheet after the session is ready.
    var preferLighterStart: Bool = false
    /// When true, discard any in-progress session for this workout and start clean.
    var forceFreshSession: Bool = false
    /// Optional close handler when presented inside a fullScreenCover flow.
    var onRequestClose: (() -> Void)? = nil

    @State private var showWorkoutComplete = false
    @State private var showExerciseNavigation = false
    @State private var showLighterStartSheet = false
    @State private var showExerciseDetails = false
    @State private var didPresentLighterStart = false
    @State private var encouragementMessage: String?
    @State private var celebrationMessage = WorkoutCompletionCopy.randomMessage()
    @State private var nextProgressionSummary: String?
    @State private var pendingUnitChange: PendingWeightUnitChange?

    private var workout: Workout? {
        workoutStore.workout(id: workoutId)
    }

    private var exercises: [WorkoutExerciseEntry] {
        workoutStore.sortedExercises(for: workoutId)
    }

    private var session: ActiveWorkoutSession? {
        sessionStore.activeSession?.workoutId == workoutId ? sessionStore.activeSession : nil
    }

    private var activeEntry: WorkoutExerciseEntry? {
        guard let activeId = session?.activeEntryId else { return nil }
        return exercises.first { $0.id == activeId }
    }

    private var nextIncompleteEntry: WorkoutExerciseEntry? {
        guard let currentId = session?.activeEntryId else {
            return exercises.first { entry in
                !(session?.state(for: entry.id)?.isFullyCompleted ?? false)
            }
        }
        guard let currentIndex = exercises.firstIndex(where: { $0.id == currentId }) else { return nil }
        let rotated = Array(exercises[(currentIndex + 1)...]) + Array(exercises[..<currentIndex])
        return rotated.first { entry in
            !(session?.state(for: entry.id)?.isFullyCompleted ?? false)
        }
    }

    private var currentExerciseIndex: Int? {
        guard let currentId = session?.activeEntryId else { return nil }
        return exercises.firstIndex(where: { $0.id == currentId })
    }

    /// Previous exercise in workout order (not wrap-around).
    private var previousOrderedEntry: WorkoutExerciseEntry? {
        guard let index = currentExerciseIndex, index > 0 else { return nil }
        return exercises[index - 1]
    }

    /// Next exercise in workout order (not wrap-around).
    private var nextOrderedEntry: WorkoutExerciseEntry? {
        guard let index = currentExerciseIndex, index + 1 < exercises.count else { return nil }
        return exercises[index + 1]
    }

    private var isLastOrderedExercise: Bool {
        guard let index = currentExerciseIndex else { return false }
        return index >= exercises.count - 1
    }

    var body: some View {
        Group {
            if let entry = activeEntry, let exercise = ExerciseCatalog.exercise(id: entry.exerciseId) {
                exerciseDetailView(entry: entry, exercise: exercise)
            } else {
                exerciseHubView
            }
        }
        .background(IronHerTheme.background)
        .navigationTitle(workout?.name ?? "Workout")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(showWorkoutComplete)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if session?.activeEntryId != nil, !showWorkoutComplete {
                    Button("Exercises") {
                        sessionStore.clearActiveExercise()
                    }
                    .font(SheLiftsFont.subheadline)
                    .foregroundStyle(IronHerTheme.secondaryText)
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if DevelopmentConfig.isDevelopmentMode, testingTimeStore.isSimulating {
                TestModeBanner()
            }
        }
        .onAppear {
            ensureSession()
            if preferLighterStart, !didPresentLighterStart, workout != nil {
                didPresentLighterStart = true
                // Delay so the full-screen cover transition can finish first.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    showLighterStartSheet = true
                }
            }
        }
        .sheet(isPresented: $showLighterStartSheet) {
            if let workout {
                LighterStartSheet(workout: workout) {
                    // Session weights already applied; stay in workout.
                }
            }
        }
        .sheet(isPresented: $showExerciseNavigation) {
            ExerciseNavigationSheet(
                hasNextExercise: nextOrderedEntry != nil,
                nextProgressionSummary: nextProgressionSummary,
                onNext: {
                    showExerciseNavigation = false
                    nextProgressionSummary = nil
                    if let next = nextOrderedEntry {
                        sessionStore.selectExercise(entryId: next.id)
                    }
                },
                onFinish: {
                    showExerciseNavigation = false
                    nextProgressionSummary = nil
                    finishWorkout()
                },
                onChoose: {
                    showExerciseNavigation = false
                    nextProgressionSummary = nil
                    sessionStore.clearActiveExercise()
                }
            )
        }
        .sheet(isPresented: $showExerciseDetails) {
            if let entry = activeEntry, let exercise = ExerciseCatalog.exercise(id: entry.exerciseId) {
                NavigationStack {
                    ExerciseDetailsView(exercise: exercise, showsSettingsLink: false)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button(l10n.t(.ok)) {
                                    showExerciseDetails = false
                                }
                            }
                        }
                }
            }
        }
        .fullScreenCover(isPresented: $showWorkoutComplete) {
            WorkoutCelebrationView(
                message: celebrationMessage,
                onDone: finishAndDismiss,
                onReopen: settingsStore.showsReopenWorkoutButton ? reopenWorkoutForDevelopment : nil
            )
        }
        .confirmationDialog(
            pendingUnitChange?.title ?? "Change weight unit",
            isPresented: Binding(
                get: { pendingUnitChange != nil },
                set: { if !$0 { pendingUnitChange = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let pending = pendingUnitChange {
                Button(pending.convertTitle) {
                    applyUnitChange(pending, mode: .convert)
                }
                Button(pending.keepTitle) {
                    applyUnitChange(pending, mode: .keepNumber)
                }
                Button("Cancel", role: .cancel) {
                    pendingUnitChange = nil
                }
            }
        } message: {
            Text("Would you like to convert the current value or keep the same number?")
        }
    }

    // MARK: - Hub

    private var exerciseHubView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                hubProgressHeader

                VStack(spacing: 12) {
                    ForEach(exercises) { entry in
                        if let exercise = ExerciseCatalog.exercise(id: entry.exerciseId) {
                            exerciseHubRow(entry: entry, exercise: exercise)
                        }
                    }
                }

                Button {
                    finishWorkout()
                } label: {
                    Text("Finish workout")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 8)
            }
            .padding(.horizontal, IronHerTheme.screenPadding)
            .padding(.vertical, 24)
        }
    }

    private var hubProgressHeader: some View {
        let completed = session?.fullyCompletedExerciseCount ?? 0
        let total = max(exercises.count, 1)

        return VStack(alignment: .leading, spacing: 8) {
            Text("\(completed) of \(exercises.count) exercises complete")
                .font(SheLiftsFont.subheadline)
                .foregroundStyle(IronHerTheme.secondaryText)

            ProgressView(value: Double(completed), total: Double(total))
                .tint(IronHerTheme.primaryText)

            Text("Start any exercise. Leave and return anytime — sets are saved.")
                .font(SheLiftsFont.caption)
                .foregroundStyle(IronHerTheme.secondaryText)
        }
    }

    private func exerciseHubRow(entry: WorkoutExerciseEntry, exercise: Exercise) -> some View {
        let state = session?.state(for: entry.id) ?? ExerciseSessionState(from: entry)

        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(exercise.localizedName(using: l10n))
                    .font(SheLiftsFont.bodyMedium)
                    .foregroundStyle(IronHerTheme.primaryText)

                Text(hubSubtitle(entry: entry, state: state, exercise: exercise))
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)

                ProgressView(value: state.progressFraction)
                    .tint(state.isFullyCompleted ? IronHerTheme.primaryText : IronHerTheme.secondaryText)
            }

            Spacer(minLength: 8)

            Button {
                encouragementMessage = nil
                sessionStore.selectExercise(entryId: entry.id)
            } label: {
                Image(systemName: state.isFullyCompleted ? "checkmark.circle.fill" : "play.circle.fill")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(IronHerTheme.primaryText)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(IronHerTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous)
                .stroke(IronHerTheme.separator.opacity(0.6), lineWidth: 0.5)
        }
    }

    private func hubSubtitle(entry: WorkoutExerciseEntry, state: ExerciseSessionState, exercise: Exercise) -> String {
        let setProgress = "\(state.completedSetCount)/\(entry.sets) sets"
        let weight = WeightFormatter.format(kg: entry.startingWeight, unit: weightUnit(for: exercise.id))
        let perHand = exercise.displaysWeightPerHand ? " per hand" : ""

        switch exercise.measurementUnit {
        case .weight:
            return "\(setProgress) · \(entry.reps) reps · \(weight)\(perHand)"
        case .weightAndTime:
            return "\(setProgress) · \(weight)\(perHand) · \(ExerciseTrackingFormatter.formatDuration(seconds: entry.durationSeconds))"
        case .time:
            return "\(setProgress) · \(ExerciseTrackingFormatter.formatDuration(seconds: entry.durationSeconds))"
        case .distance:
            return "\(setProgress) · \(ExerciseTrackingFormatter.formatDistance(meters: entry.distanceMeters, unit: settingsStore.weightUnit))"
        case .repsWithOptionalWeight:
            if entry.startingWeight > 0 {
                return "\(setProgress) · \(entry.reps) reps · \(weight)\(perHand)"
            }
            return "\(setProgress) · \(entry.reps) reps"
        case .reps, .bodyweight:
            return "\(setProgress) · \(entry.reps) reps"
        }
    }

    // MARK: - Exercise detail

    private func exerciseDetailView(entry: WorkoutExerciseEntry, exercise: Exercise) -> some View {
        let state = session?.state(for: entry.id) ?? ExerciseSessionState(from: entry)

        return ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                exerciseCard(entry: entry, exercise: exercise)
                setCompletionSection(entry: entry, exercise: exercise, state: state)

                if let encouragementMessage, settingsStore.showsEncouragement {
                    Text(encouragementMessage)
                        .font(SheLiftsFont.subheadline)
                        .foregroundStyle(IronHerTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .notesCard(padding: 14)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                exerciseNavigationControls
            }
            .padding(.horizontal, IronHerTheme.screenPadding)
            .padding(.vertical, 24)
        }
    }

    private var exerciseNavigationControls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    if let previous = previousOrderedEntry {
                        encouragementMessage = nil
                        sessionStore.selectExercise(entryId: previous.id)
                    }
                } label: {
                    Text("Previous")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(OutlineButtonStyle())
                .disabled(previousOrderedEntry == nil)
                .opacity(previousOrderedEntry == nil ? 0.4 : 1)

                if isLastOrderedExercise {
                    Button {
                        finishWorkout()
                    } label: {
                        Text("Finish Workout")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button {
                        if let next = nextOrderedEntry {
                            encouragementMessage = nil
                            sessionStore.selectExercise(entryId: next.id)
                        }
                    } label: {
                        Text("Next")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(nextOrderedEntry == nil)
                }
            }

            Button {
                sessionStore.clearActiveExercise()
            } label: {
                Text("Exercises")
            }
            .buttonStyle(OutlineButtonStyle())
        }
    }

    private func exerciseCard(entry: WorkoutExerciseEntry, exercise: Exercise) -> some View {
        let plannedWeight = globalProgressStore.resolvedWeight(
            for: entry.exerciseId,
            entryWeight: entry.startingWeight
        )
        let plannedReps = globalProgressStore.resolvedReps(
            for: entry.exerciseId,
            entryReps: entry.reps
        )
        let plannedSets = globalProgressStore.targetSets(for: entry.exerciseId)
            ?? progressionStore.configuration(for: entry.exerciseId).targetSets
        let rule = progressionStore.rule(
            for: exercise,
            weightIncrementKg: settingsStore.incrementKg(for: exercise)
        )

        return VStack(spacing: 20) {
            if exercise.hasVisualAsset {
                ExerciseThumbnailView(exercise: exercise, size: 72)
            }

            HStack(spacing: 8) {
                Text(exercise.localizedName(using: l10n))
                    .font(SheLiftsFont.title)
                    .foregroundStyle(IronHerTheme.primaryText)
                    .multilineTextAlignment(.center)

                if exercise.hasExerciseDetailsContent {
                    Button {
                        showExerciseDetails = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(IronHerTheme.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(l10n.t(.exercise_info_accessibility))
                }
            }

            Text(exercise.listSubtitle)
                .font(SheLiftsFont.subheadline)
                .foregroundStyle(IronHerTheme.secondaryText)

            if exercise.showsWeightDuringSession, plannedWeight > 0 {
                VStack(spacing: 4) {
                    Text(exercise.weightFieldLabel)
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)
                    Text(
                        WeightFormatter.format(
                            kg: plannedWeight,
                            unit: weightUnit(for: exercise.id)
                        )
                    )
                        .font(SheLiftsFont.title)
                        .foregroundStyle(IronHerTheme.primaryText)
                }
            }

            if rule.automaticProgression,
               exercise.showsRepsDuringSession {
                VStack(spacing: 4) {
                    Text("Target")
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)
                    Text("\(plannedSets) × \(plannedReps)")
                        .font(SheLiftsFont.title)
                        .foregroundStyle(IronHerTheme.primaryText)
                    if exercise.laterality != .bilateral {
                        Text(exercise.repsFieldLabel)
                            .font(SheLiftsFont.caption)
                            .foregroundStyle(IronHerTheme.secondaryText)
                    }
                }

                if rule.method == .repsOnly, rule.repIncrement > 0 {
                    Text("Progression: +\(rule.repIncrement) reps")
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)
                } else if rule.method == .doubleProgression {
                    Text(rule.normalizedRepSteps.map(String.init).joined(separator: " → "))
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)
                }
            } else if rule.automaticProgression,
                      rule.method == .durationCycle || exercise.measurementUnit == .time || exercise.measurementUnit == .weightAndTime {
                let plannedDuration = globalProgressStore.resolvedDurationSeconds(
                    for: entry.exerciseId,
                    entryDurationSeconds: entry.durationSeconds
                )
                VStack(spacing: 4) {
                    Text("Target")
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)
                    Text("\(plannedSets) × \(ExerciseTrackingFormatter.formatDuration(seconds: plannedDuration))")
                        .font(SheLiftsFont.title)
                        .foregroundStyle(IronHerTheme.primaryText)
                }
                if rule.durationIncrementSeconds > 0 {
                    Text("Progression: +\(rule.durationIncrementSeconds) sec")
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)
                }
            } else {
                HStack(spacing: 12) {
                    statPill(title: "Sets", value: "\(entry.sets)")
                    exerciseStats(entry: entry, exercise: exercise)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .notesCard(padding: 24)
    }

    private func setCompletionSection(
        entry: WorkoutExerciseEntry,
        exercise: Exercise,
        state: ExerciseSessionState
    ) -> some View {
        let showsWeight = exercise.showsWeightDuringSession
        let showsReps = exercise.showsRepsDuringSession
        let showsDuration = exercise.showsDurationDuringSession
        let showsDistance = exercise.showsDistanceDuringSession
        let unit = weightUnit(for: exercise.id)
        let plannedDuration = globalProgressStore.resolvedDurationSeconds(
            for: entry.exerciseId,
            entryDurationSeconds: entry.durationSeconds
        )
        let plannedDistance = globalProgressStore.resolvedDistanceMeters(
            for: entry.exerciseId,
            entryDistanceMeters: entry.distanceMeters
        )
        let incrementDisplay = max(
            WeightFormatter.displayValue(
                kg: settingsStore.incrementKg(for: exercise),
                unit: unit
            ),
            unit == .pounds ? 1.0 : 0.5
        )

        return VStack(alignment: .leading, spacing: 12) {
            Text("Sets")
                .font(SheLiftsFont.section)
                .foregroundStyle(IronHerTheme.primaryText)

            Text(sessionGuidance(
                showsWeight: showsWeight,
                showsReps: showsReps,
                showsDuration: showsDuration,
                showsDistance: showsDistance
            ))
                .font(SheLiftsFont.caption)
                .foregroundStyle(IronHerTheme.secondaryText)

            if showsWeight {
                Button {
                    requestUnitChange(for: entry, exercise: exercise, state: state)
                } label: {
                    HStack {
                        Text("Unit: \(unit.shortLabel)")
                            .font(SheLiftsFont.caption)
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.caption)
                        Spacer()
                        Text("Change")
                            .font(SheLiftsFont.caption)
                    }
                    .foregroundStyle(IronHerTheme.secondaryText)
                }
                .buttonStyle(.plain)
            }

            if let progressLine = progressionProgressLine(entry: entry, exercise: exercise, state: state) {
                Text(progressLine)
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.primaryText)
            }

            ForEach(0..<state.plannedSets, id: \.self) { index in
                let isComplete = state.completedSetFlags.indices.contains(index)
                    && state.completedSetFlags[index]
                let performance = state.performance(at: index) ?? SetPerformance(from: entry)

                ActiveSetRow(
                    setNumber: index + 1,
                    isComplete: isComplete,
                    showsWeight: showsWeight,
                    showsReps: showsReps,
                    showsDuration: showsDuration,
                    showsDistance: showsDistance,
                    weightLabel: exercise.weightFieldLabel,
                    weightUnitLabel: unit.shortLabel,
                    weightDisplay: WeightFormatter.displayValue(
                        kg: performance.weightKg,
                        unit: unit
                    ),
                    weightStep: incrementDisplay,
                    repsLabel: exercise.repsStepperLabel,
                    reps: performance.reps,
                    durationSeconds: performance.durationSeconds > 0
                        ? performance.durationSeconds
                        : plannedDuration,
                    distanceMeters: performance.distanceMeters > 0
                        ? performance.distanceMeters
                        : plannedDistance,
                    onToggle: {
                        handleSetToggle(entry: entry, setIndex: index, wasComplete: isComplete)
                    },
                    onWeightChange: { displayValue in
                        let kg = WeightFormatter.kilograms(from: displayValue, unit: unit)
                        sessionStore.updateSetWeight(entryId: entry.id, setIndex: index, weightKg: kg)
                    },
                    onRepsChange: { reps in
                        sessionStore.updateSetReps(entryId: entry.id, setIndex: index, reps: reps)
                    },
                    onDurationChange: { seconds in
                        sessionStore.updateSetDuration(
                            entryId: entry.id,
                            setIndex: index,
                            durationSeconds: seconds
                        )
                    },
                    onDistanceChange: { meters in
                        sessionStore.updateSetDistance(
                            entryId: entry.id,
                            setIndex: index,
                            distanceMeters: meters
                        )
                    }
                )
            }
        }
        .notesCard()
    }

    private func weightUnit(for exerciseId: String) -> WeightUnit {
        globalProgressStore.resolvedWeightUnit(
            for: exerciseId,
            defaultUnit: settingsStore.weightUnit
        )
    }

    private func requestUnitChange(
        for entry: WorkoutExerciseEntry,
        exercise: Exercise,
        state: ExerciseSessionState
    ) {
        let currentUnit = weightUnit(for: exercise.id)
        let targetUnit: WeightUnit = currentUnit == .kilograms ? .pounds : .kilograms
        let sampleKg = state.setPerformances.first(where: { $0.weightKg > 0 })?.weightKg
            ?? globalProgressStore.resolvedWeight(for: entry.exerciseId, entryWeight: entry.startingWeight)
        let currentDisplay = WeightFormatter.displayValue(kg: sampleKg, unit: currentUnit)
        let convertedDisplay = WeightFormatter.convertDisplay(currentDisplay, from: currentUnit, to: targetUnit)

        pendingUnitChange = PendingWeightUnitChange(
            entryId: entry.id,
            exerciseId: exercise.id,
            fromUnit: currentUnit,
            toUnit: targetUnit,
            currentDisplay: currentDisplay,
            convertedDisplay: convertedDisplay
        )
    }

    private enum UnitChangeMode {
        case convert
        case keepNumber
    }

    private func applyUnitChange(_ pending: PendingWeightUnitChange, mode: UnitChangeMode) {
        defer { pendingUnitChange = nil }

        globalProgressStore.setWeightUnitPreference(
            .from(pending.toUnit),
            for: pending.exerciseId
        )

        guard let state = sessionStore.activeSession?.state(for: pending.entryId) else { return }

        switch mode {
        case .convert:
            // Keep kg values; only the display unit changes.
            break
        case .keepNumber:
            for index in state.setPerformances.indices {
                let currentKg = state.setPerformances[index].weightKg
                let displayInOld = WeightFormatter.displayValue(kg: currentKg, unit: pending.fromUnit)
                let newKg = WeightFormatter.kilograms(from: displayInOld, unit: pending.toUnit)
                sessionStore.updateSetWeight(
                    entryId: pending.entryId,
                    setIndex: index,
                    weightKg: newKg
                )
            }
            // Also update global working weight with the kept-number interpretation.
            if let first = state.setPerformances.first {
                let displayInOld = WeightFormatter.displayValue(kg: first.weightKg, unit: pending.fromUnit)
                let newKg = WeightFormatter.kilograms(from: displayInOld, unit: pending.toUnit)
                globalProgressStore.updateWeight(
                    for: pending.exerciseId,
                    weightKg: newKg,
                    into: workoutStore
                )
            }
        }
    }

    private func sessionGuidance(
        showsWeight: Bool,
        showsReps: Bool,
        showsDuration: Bool,
        showsDistance: Bool
    ) -> String {
        if showsWeight && showsDuration {
            return "Adjust weight and duration. Tap the circle when the set is done."
        }
        if showsWeight && showsDistance {
            return "Adjust weight and distance. Tap the circle when the set is done."
        }
        if showsDistance && showsDuration {
            return "Adjust distance and duration. Tap the circle when the set is done."
        }
        if showsDuration && !showsReps {
            return "Use the timer or adjust duration. Tap the circle when the set is done."
        }
        if showsDistance {
            return "Adjust distance as needed. Tap the circle when the set is done."
        }
        if showsWeight && showsReps {
            return "Adjust weight and reps freely. Tap the circle when a set is done."
        }
        return "Adjust as needed. Tap the circle when a set is done."
    }

    private func progressionProgressLine(
        entry: WorkoutExerciseEntry,
        exercise: Exercise,
        state: ExerciseSessionState
    ) -> String? {
        let rule = progressionStore.rule(
            for: exercise,
            weightIncrementKg: settingsStore.incrementKg(for: exercise)
        )
        let plannedReps = globalProgressStore.resolvedReps(
            for: entry.exerciseId,
            entryReps: entry.reps
        )
        return ProgressionTargetProgress.summary(
            rule: rule,
            state: state,
            currentPlannedReps: plannedReps,
            currentPlannedDuration: globalProgressStore.resolvedDurationSeconds(
                for: entry.exerciseId,
                entryDurationSeconds: entry.durationSeconds
            )
        )
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(IronHerTheme.secondaryText)
            Text(value)
                .font(.headline)
                .foregroundStyle(IronHerTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(IronHerTheme.groupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadiusSmall, style: .continuous))
    }

    @ViewBuilder
    private func exerciseStats(entry: WorkoutExerciseEntry, exercise: Exercise) -> some View {
        let unit = weightUnit(for: exercise.id)
        switch exercise.measurementUnit {
        case .weight:
            statPill(title: exercise.repsFieldLabel, value: "\(entry.reps)")
            statPill(
                title: exercise.displaysWeightPerHand ? "Per hand" : "Weight",
                value: WeightFormatter.format(kg: entry.startingWeight, unit: unit)
            )
        case .bodyweight, .reps:
            statPill(title: exercise.repsFieldLabel, value: "\(entry.reps)")
        case .time:
            statPill(
                title: "Duration",
                value: ExerciseTrackingFormatter.formatDuration(seconds: entry.durationSeconds)
            )
        case .distance:
            statPill(title: "Distance", value: String(format: "%.0f m", entry.distanceMeters))
        case .weightAndTime:
            statPill(
                title: exercise.id == "farmer-carry" || exercise.displaysWeightPerHand ? "Per hand" : "Weight",
                value: WeightFormatter.format(kg: entry.startingWeight, unit: unit)
            )
            statPill(
                title: "Duration",
                value: ExerciseTrackingFormatter.formatDuration(seconds: entry.durationSeconds)
            )
        case .repsWithOptionalWeight:
            statPill(title: exercise.repsFieldLabel, value: "\(entry.reps)")
            if entry.startingWeight > 0 {
                statPill(
                    title: exercise.displaysWeightPerHand ? "Per hand" : "Weight",
                    value: WeightFormatter.format(kg: entry.startingWeight, unit: unit)
                )
            }
        }
    }

    // MARK: - Set handling

    private func handleSetToggle(entry: WorkoutExerciseEntry, setIndex: Int, wasComplete: Bool) {
        withAnimation(.easeOut(duration: 0.15)) {
            sessionStore.toggleSet(entryId: entry.id, setIndex: setIndex)
        }

        if wasComplete {
            withAnimation(.easeOut(duration: 0.2)) {
                encouragementMessage = nil
            }
            if showExerciseNavigation {
                showExerciseNavigation = false
            }
            return
        }

        guard let state = sessionStore.activeSession?.state(for: entry.id) else { return }

        if settingsStore.showsEncouragement,
           let message = WorkoutEncouragement.message(
               completedSets: state.completedSetCount,
               plannedSets: state.plannedSets
           ) {
            withAnimation(.easeOut(duration: 0.2)) {
                encouragementMessage = message
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.2))
                if encouragementMessage == message {
                    withAnimation(.easeOut(duration: 0.25)) {
                        encouragementMessage = nil
                    }
                }
            }
        }

        if state.isFullyCompleted {
            handleExerciseCompleted(entry: entry)
        }
    }

    /// Evaluate progression for this exercise immediately — never wait for Finish Workout.
    private func handleExerciseCompleted(entry: WorkoutExerciseEntry) {
        guard let exercise = ExerciseCatalog.exercise(id: entry.exerciseId) else {
            nextProgressionSummary = nil
            showExerciseNavigation = true
            return
        }
        guard let state = sessionStore.activeSession?.state(for: entry.id) else {
            nextProgressionSummary = nil
            showExerciseNavigation = true
            return
        }

        nextProgressionSummary = nil

        if !state.didEvaluateProgression {
            sessionStore.markProgressionEvaluated(entryId: entry.id)

            let outcome = evaluateProgression(for: entry, exercise: exercise, state: state)
            if case .applied(let update) = outcome {
                applyProgressionUpdate(update)
                nextProgressionSummary = nextTimeSummary(for: update, exercise: exercise)
            }
        }

        showExerciseNavigation = true
    }

    private func nextTimeSummary(for update: AppliedProgressionUpdate, exercise: Exercise) -> String? {
        let unit = weightUnit(for: exercise.id)
        var parts: [String] = []
        if let weight = update.nextWeightKg, weight > 0, exercise.showsWeightDuringSession {
            parts.append(WeightFormatter.format(kg: weight, unit: unit))
        }
        if let reps = update.nextReps, exercise.showsRepsDuringSession {
            parts.append("\(reps) \(exercise.repsStepperLabel)")
        }
        if let duration = update.nextDurationSeconds, exercise.showsDurationDuringSession, duration > 0 {
            parts.append(ExerciseTrackingFormatter.formatDuration(seconds: duration))
        }
        guard !parts.isEmpty else { return nil }
        return "Next time: " + parts.joined(separator: " × ")
    }

    // MARK: - Finish & progression

    private func ensureSession() {
        guard let workout else {
            dismiss()
            return
        }
        globalProgressStore.applyAll(to: workoutStore)
        let plan = workoutStore.workout(id: workoutId) ?? workout
        if forceFreshSession {
            _ = sessionStore.startFresh(workout: plan)
        } else {
            sessionStore.startOrResume(workout: plan)
        }
    }

    private func finishWorkout() {
        showExerciseNavigation = false
        celebrationMessage = WorkoutCompletionCopy.randomMessage()

        let workoutName = workout?.name ?? "Workout"

        sessionStore.logCompletedWorkoutPerformance(
            workoutId: workoutId,
            workoutName: workoutName,
            exercises: exercises,
            weightUnitForExercise: { exerciseId in
                globalProgressStore.resolvedWeightUnit(
                    for: exerciseId,
                    defaultUnit: settingsStore.weightUnit
                )
            }
        )

        for entry in exercises {
            guard let state = session?.state(for: entry.id),
                  state.completedSetCount > 0 else { continue }

            let unit = globalProgressStore.resolvedWeightUnit(
                for: entry.exerciseId,
                defaultUnit: settingsStore.weightUnit
            )
            globalProgressStore.recordActualPerformance(
                exerciseId: entry.exerciseId,
                workoutName: workoutName,
                planned: entry,
                state: state,
                into: workoutStore,
                historyStore: historyStore,
                updatePrescription: !state.progressionPrescriptionLocked,
                displayUnit: unit
            )
        }

        sessionStore.markCompletedThisWeek(
            workoutId: workoutId,
            workoutName: workoutName
        )

        // End the session now so the next start is a fresh evaluation (return-after-break can run).
        // Reopen (dev) creates a new session from the plan.
        sessionStore.endSession(markWeeklyCompletion: false)

        showWorkoutComplete = true
    }

    @discardableResult
    private func evaluateProgression(
        for entry: WorkoutExerciseEntry,
        exercise: Exercise,
        state: ExerciseSessionState
    ) -> ProgressionOutcome {
        let plannedWeight = globalProgressStore.resolvedWeight(
            for: entry.exerciseId,
            entryWeight: entry.startingWeight
        )
        let plannedReps = globalProgressStore.resolvedReps(
            for: entry.exerciseId,
            entryReps: entry.reps
        )
        let plannedDuration = globalProgressStore.resolvedDurationSeconds(
            for: entry.exerciseId,
            entryDurationSeconds: entry.durationSeconds
        )

        let completedReps: [Int] = state.completedSetFlags.indices.compactMap { index in
            guard state.completedSetFlags[index] else { return nil }
            return state.performance(at: index)?.reps ?? entry.reps
        }
        let completedDurations: [Int] = state.completedSetFlags.indices.compactMap { index in
            guard state.completedSetFlags[index] else { return nil }
            return state.performance(at: index)?.durationSeconds ?? entry.durationSeconds
        }
        let completedDistances: [Double] = state.completedSetFlags.indices.compactMap { index in
            guard state.completedSetFlags[index] else { return nil }
            return state.performance(at: index)?.distanceMeters ?? entry.distanceMeters
        }

        let actualWeight: Double = {
            let completed = zip(state.completedSetFlags, state.setPerformances)
                .compactMap { done, perf -> Double? in done ? perf.weightKg : nil }
            return completed.last ?? plannedWeight
        }()

        let plannedDistance = globalProgressStore.resolvedDistanceMeters(
            for: entry.exerciseId,
            entryDistanceMeters: entry.distanceMeters
        )

        let sessionResult = ProgressionSessionResult(
            exerciseId: entry.exerciseId,
            currentWeightKg: exercise.showsWeightDuringSession ? actualWeight : plannedWeight,
            currentPlannedReps: plannedReps,
            plannedDurationSeconds: plannedDuration,
            plannedDistanceMeters: plannedDistance,
            completedSetReps: completedReps,
            completedSetDurations: completedDurations,
            completedSetDistances: completedDistances,
            allPlannedSetsCompleted: state.isFullyCompleted
        )

        return progressionStore.evaluateAfterExercise(
            session: sessionResult,
            exercise: exercise,
            weightIncrementKg: settingsStore.incrementKg(for: exercise)
        )
    }

    private func applyProgressionUpdate(_ update: AppliedProgressionUpdate) {
        let weight = update.nextWeightKg ?? 0
        let reps = update.nextReps ?? globalProgressStore.targetReps(for: update.exerciseId) ?? 8
        let duration = update.nextDurationSeconds
            ?? globalProgressStore.progress(for: update.exerciseId)?.targetDurationSeconds
            ?? 0
        let distance = update.nextDistanceMeters
            ?? globalProgressStore.progress(for: update.exerciseId)?.targetDistanceMeters
            ?? 0
        let previousSets = globalProgressStore.targetSets(for: update.exerciseId)

        globalProgressStore.sync(
            exerciseId: update.exerciseId,
            weightKg: weight,
            reps: reps,
            sets: update.targetSets,
            durationSeconds: duration,
            distanceMeters: distance,
            into: workoutStore
        )

        if let previous = update.previousWeightKg,
           let next = update.nextWeightKg,
           next > previous + 0.001 {
            historyStore.recordProgression(
                exerciseId: update.exerciseId,
                from: previous,
                to: next
            )
        } else if let previousReps = update.previousReps,
                  let nextReps = update.nextReps,
                  nextReps > previousReps {
            historyStore.recordRepProgression(
                exerciseId: update.exerciseId,
                from: previousReps,
                to: nextReps
            )
        }

        if update.kind == .nextSetTarget,
           let previousSets,
           update.targetSets > previousSets {
            historyStore.recordSetProgression(
                exerciseId: update.exerciseId,
                from: previousSets,
                to: update.targetSets
            )
        }

        sessionStore.lockProgressionPrescription(exerciseId: update.exerciseId, in: exercises)
    }

    private func finishAndDismiss() {
        showWorkoutComplete = false
        if sessionStore.activeSession?.workoutId == workoutId {
            sessionStore.endSession(markWeeklyCompletion: false)
        }
        if let onRequestClose {
            onRequestClose()
        } else {
            dismiss()
        }
    }

    /// Development only: reopen the same plan without treating it as a return-after-break.
    private func reopenWorkoutForDevelopment() {
        guard settingsStore.showsReopenWorkoutButton, let workout else { return }

        sessionStore.clearCompletedThisWeek(workoutId: workoutId)
        _ = sessionStore.startOrResume(workout: workout)
        sessionStore.prepareSessionForReopen()

        encouragementMessage = nil
        showExerciseNavigation = false
        showWorkoutComplete = false
        didPresentLighterStart = false
    }
}

private struct PendingWeightUnitChange: Identifiable {
    let id = UUID()
    let entryId: UUID
    let exerciseId: String
    let fromUnit: WeightUnit
    let toUnit: WeightUnit
    let currentDisplay: Double
    let convertedDisplay: Double

    var title: String { "Change weight unit" }

    var convertTitle: String {
        let from = WeightFormatter.formatDisplay(currentDisplay, unit: fromUnit)
        let to = WeightFormatter.formatDisplay(convertedDisplay, unit: toUnit)
        return "Convert \(from) to \(to)"
    }

    var keepTitle: String {
        let number = WeightFormatter.formatDisplay(currentDisplay, unit: fromUnit, includeUnit: false)
        return "Keep \(number) and change to \(toUnit.shortLabel)"
    }
}

// MARK: - Per-set editor row

private struct ActiveSetRow: View {
    let setNumber: Int
    let isComplete: Bool
    let showsWeight: Bool
    let showsReps: Bool
    let showsDuration: Bool
    let showsDistance: Bool
    let weightLabel: String
    let weightUnitLabel: String
    let weightDisplay: Double
    let weightStep: Double
    let repsLabel: String
    let reps: Int
    let durationSeconds: Int
    let distanceMeters: Double
    let onToggle: () -> Void
    let onWeightChange: (Double) -> Void
    let onRepsChange: (Int) -> Void
    let onDurationChange: (Int) -> Void
    let onDistanceChange: (Double) -> Void

    @State private var weightInput: Double = 0
    @State private var repsInput: Int = 0
    @State private var durationInput: Int = 0
    @State private var distanceInput: Double = 0
    @State private var isTimerRunning = false
    @State private var timerElapsed = 0
    @State private var timerStartedAt: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button(action: onToggle) {
                    Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isComplete ? IronHerTheme.primaryText : IronHerTheme.secondaryText.opacity(0.5))
                        .frame(width: 32, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Text("Set \(setNumber)")
                    .font(SheLiftsFont.body)
                    .foregroundStyle(IronHerTheme.primaryText)

                Spacer()
            }

            if showsWeight {
                stepperRow(
                    label: "\(weightLabel) (\(weightUnitLabel))",
                    valueText: formatWeight(weightInput)
                ) {
                    adjustWeight(by: -weightStep)
                } increment: {
                    adjustWeight(by: weightStep)
                }
            }

            if showsReps {
                stepperRow(label: repsLabel, valueText: "\(repsInput)") {
                    repsInput = max(0, repsInput - 1)
                    onRepsChange(repsInput)
                } increment: {
                    repsInput += 1
                    onRepsChange(repsInput)
                }
            }

            if showsDuration {
                durationControls
            }

            if showsDistance {
                stepperRow(
                    label: "distance (m)",
                    valueText: String(format: "%.0f", distanceInput)
                ) {
                    distanceInput = max(0, distanceInput - 5)
                    onDistanceChange(distanceInput)
                } increment: {
                    distanceInput += 5
                    onDistanceChange(distanceInput)
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            weightInput = weightDisplay
            repsInput = reps
            durationInput = max(0, durationSeconds)
            distanceInput = max(0, distanceMeters)
            timerElapsed = 0
            isTimerRunning = false
            timerStartedAt = nil
        }
        .onChange(of: weightDisplay) { _, newValue in
            if abs(newValue - weightInput) > 0.001 {
                weightInput = newValue
            }
        }
        .onChange(of: reps) { _, newValue in
            if newValue != repsInput {
                repsInput = newValue
            }
        }
        .onChange(of: durationSeconds) { _, newValue in
            if !isTimerRunning, newValue != durationInput {
                durationInput = newValue
            }
        }
        .onChange(of: distanceMeters) { _, newValue in
            if abs(newValue - distanceInput) > 0.001 {
                distanceInput = newValue
            }
        }
        .onDisappear {
            stopTimer(commit: false)
        }
    }

    private var durationControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            stepperRow(
                label: "duration",
                valueText: ExerciseTrackingFormatter.formatDuration(seconds: displayedDuration)
            ) {
                commitDuration(max(0, durationInput - 5))
            } increment: {
                commitDuration(min(600, durationInput + 5))
            }

            HStack(spacing: 10) {
                Button(isTimerRunning ? "Pause" : (timerElapsed > 0 ? "Resume" : "Start")) {
                    toggleTimer()
                }
                .font(SheLiftsFont.caption)
                .foregroundStyle(IronHerTheme.primaryText)

                Button("Reset") {
                    resetTimer()
                }
                .font(SheLiftsFont.caption)
                .foregroundStyle(IronHerTheme.secondaryText)

                Spacer()

                if isTimerRunning || timerElapsed > 0 {
                    Text(ExerciseTrackingFormatter.formatDuration(seconds: displayedDuration))
                        .font(SheLiftsFont.bodyMedium)
                        .foregroundStyle(IronHerTheme.primaryText)
                        .monospacedDigit()
                }
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
            guard isTimerRunning, let started = timerStartedAt else { return }
            let live = timerElapsed + max(0, Int(date.timeIntervalSince(started)))
            durationInput = live
            onDurationChange(durationInput)
        }
    }

    private var displayedDuration: Int {
        if isTimerRunning, let started = timerStartedAt {
            return max(0, timerElapsed + Int(Date().timeIntervalSince(started)))
        }
        return durationInput
    }

    private func toggleTimer() {
        if isTimerRunning {
            stopTimer(commit: true)
        } else {
            timerStartedAt = Date()
            isTimerRunning = true
        }
    }

    private func stopTimer(commit: Bool) {
        if isTimerRunning, let started = timerStartedAt {
            timerElapsed += Int(Date().timeIntervalSince(started))
        }
        timerStartedAt = nil
        isTimerRunning = false
        if commit {
            durationInput = max(0, timerElapsed)
            onDurationChange(durationInput)
        }
    }

    private func resetTimer() {
        isTimerRunning = false
        timerStartedAt = nil
        timerElapsed = 0
        durationInput = max(0, durationSeconds)
        onDurationChange(durationInput)
    }

    private func commitDuration(_ seconds: Int) {
        stopTimer(commit: false)
        timerElapsed = seconds
        durationInput = seconds
        onDurationChange(seconds)
    }

    private func stepperRow(
        label: String,
        valueText: String,
        decrement: @escaping () -> Void,
        increment: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Button(action: decrement) {
                Image(systemName: "minus")
                    .font(.body.weight(.medium))
                    .frame(width: 36, height: 36)
                    .background(IronHerTheme.groupedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadiusSmall, style: .continuous))
            }
            .buttonStyle(.plain)

            Text(valueText)
                .font(SheLiftsFont.bodyMedium)
                .foregroundStyle(IronHerTheme.primaryText)
                .frame(minWidth: 64)
                .multilineTextAlignment(.center)

            Text(label)
                .font(SheLiftsFont.caption)
                .foregroundStyle(IronHerTheme.secondaryText)

            Button(action: increment) {
                Image(systemName: "plus")
                    .font(.body.weight(.medium))
                    .frame(width: 36, height: 36)
                    .background(IronHerTheme.groupedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadiusSmall, style: .continuous))
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
    }

    private func adjustWeight(by delta: Double) {
        weightInput = WeightFormatter.roundToTenth(max(0, weightInput + delta))
        onWeightChange(weightInput)
    }

    private func formatWeight(_ value: Double) -> String {
        WeightFormatter.isWholeNumber(value)
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}

#Preview {
    NavigationStack {
        ActiveWorkoutView(workoutId: UUID())
            .environment(WorkoutStore())
            .environment(WeightHistoryStore())
            .environment(UserSettingsStore())
            .environment(ExerciseProgressionStore())
            .environment(GlobalExerciseProgressStore())
            .environment(WorkoutSessionStore())
            .environment(TestingTimeStore())
            .environment(LocalizationStore())
    }
}
