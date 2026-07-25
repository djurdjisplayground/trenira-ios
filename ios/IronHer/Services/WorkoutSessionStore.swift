import Foundation

@Observable
@MainActor
final class WorkoutSessionStore {
    private(set) var weeklyCompletions: [WorkoutWeeklyCompletion] = []
    private(set) var activeSession: ActiveWorkoutSession?
    /// Immutable completed-session records — the source of truth for Progress History timelines.
    private(set) var performanceLogs: [LoggedWorkoutPerformance] = []

    private let completionsKey = "workoutWeeklyCompletions"
    private let activeSessionKey = "activeWorkoutSession"
    private let performanceLogsKey = "workoutPerformanceLogs"

    init() {
        loadCompletions()
        loadActiveSession()
        performanceLogs = loadPerformanceLogs()
    }

    // MARK: - Weekly tracking

    func isCompletedThisWeek(workoutId: UUID) -> Bool {
        weeklyCompletions.contains {
            $0.workoutId == workoutId && WorkoutWeekCalendar.isInCurrentWeek($0.completedAt)
        }
    }

    func completionsThisWeek() -> [WorkoutWeeklyCompletion] {
        weeklyCompletions.filter { WorkoutWeekCalendar.isInCurrentWeek($0.completedAt) }
    }

    func markCompletedThisWeek(workoutId: UUID, workoutName: String) {
        weeklyCompletions.removeAll {
            $0.workoutId == workoutId && WorkoutWeekCalendar.isInCurrentWeek($0.completedAt)
        }
        weeklyCompletions.insert(
            WorkoutWeeklyCompletion(workoutId: workoutId, workoutName: workoutName),
            at: 0
        )
        saveCompletions()
    }

    func clearCompletedThisWeek(workoutId: UUID) {
        weeklyCompletions.removeAll {
            $0.workoutId == workoutId && WorkoutWeekCalendar.isInCurrentWeek($0.completedAt)
        }
        saveCompletions()
    }

    /// Toggles this-week completion for a workout (persists to the same store as session finish).
    func toggleCompletedThisWeek(workoutId: UUID, workoutName: String) {
        if isCompletedThisWeek(workoutId: workoutId) {
            clearCompletedThisWeek(workoutId: workoutId)
        } else {
            markCompletedThisWeek(workoutId: workoutId, workoutName: workoutName)
        }
    }

    func clearAllWeeklyCompletions() {
        weeklyCompletions = []
        saveCompletions()
    }

    /// Development helper: keep the same session and set progress, but allow finish/progression again.
    func prepareSessionForReopen() {
        guard var session = activeSession else { return }
        session.activeEntryId = nil
        for key in Array(session.exerciseStates.keys) {
            guard var state = session.exerciseStates[key] else { continue }
            state.didEvaluateProgression = false
            state.progressionPrescriptionLocked = false
            session.exerciseStates[key] = state
        }
        activeSession = session
        saveActiveSession()
    }

    func thisWeekSummary(for workouts: [Workout]) -> (completed: Int, total: Int, items: [(id: UUID, name: String, completed: Bool)]) {
        let eligible = workouts.filter { !$0.exercises.isEmpty }
        let items = eligible.map { workout in
            (id: workout.id, name: workout.name, completed: isCompletedThisWeek(workoutId: workout.id))
        }
        let completed = items.filter(\.completed).count
        return (completed, items.count, items)
    }

    // MARK: - Active session

    @discardableResult
    func startOrResume(workout: Workout) -> ActiveWorkoutSession {
        if let activeSession, activeSession.workoutId == workout.id {
            var session = syncSession(activeSession, with: workout)
            self.activeSession = session
            saveActiveSession()
            return session
        }

        let states = Dictionary(uniqueKeysWithValues: workout.exercises.map { entry in
            (entry.id, ExerciseSessionState(from: entry))
        })

        let session = ActiveWorkoutSession(
            workoutId: workout.id,
            workoutName: workout.name,
            exerciseStates: states
        )
        activeSession = session
        saveActiveSession()
        return session
    }

    func selectExercise(entryId: UUID) {
        guard var session = activeSession else { return }
        session.activeEntryId = entryId
        activeSession = session
        saveActiveSession()
    }

    func clearActiveExercise() {
        guard var session = activeSession else { return }
        session.activeEntryId = nil
        activeSession = session
        saveActiveSession()
    }

    func toggleSet(entryId: UUID, setIndex: Int) {
        guard var session = activeSession,
              var state = session.exerciseStates[entryId] else { return }
        state.toggleSet(at: setIndex)
        session.exerciseStates[entryId] = state
        activeSession = session
        saveActiveSession()
    }

    func updateSetWeight(entryId: UUID, setIndex: Int, weightKg: Double) {
        updateSetPerformance(entryId: entryId, setIndex: setIndex) { performance in
            performance.weightKg = max(0, weightKg)
        }
    }

    /// Applies a session-only weight to every set of an exercise. Does not touch global progression.
    func applyWeightToAllSets(entryId: UUID, weightKg: Double) {
        guard let state = activeSession?.exerciseStates[entryId] else { return }
        for index in state.setPerformances.indices {
            updateSetWeight(entryId: entryId, setIndex: index, weightKg: weightKg)
        }
    }

    /// Most recent completed workout date across all performance logs.
    var lastCompletedWorkoutDate: Date? {
        performanceLogs.map(\.completedAt).max()
    }

    func updateSetReps(entryId: UUID, setIndex: Int, reps: Int) {
        updateSetPerformance(entryId: entryId, setIndex: setIndex) { performance in
            performance.reps = max(0, reps)
        }
    }

    func updateSetDuration(entryId: UUID, setIndex: Int, durationSeconds: Int) {
        updateSetPerformance(entryId: entryId, setIndex: setIndex) { performance in
            performance.durationSeconds = max(0, durationSeconds)
        }
    }

    private func updateSetPerformance(
        entryId: UUID,
        setIndex: Int,
        update: (inout SetPerformance) -> Void
    ) {
        guard var session = activeSession,
              var state = session.exerciseStates[entryId] else { return }
        state.updatePerformance(at: setIndex, update)
        session.exerciseStates[entryId] = state
        activeSession = session
        saveActiveSession()
    }

    func markProgressionEvaluated(entryId: UUID) {
        guard var session = activeSession,
              var state = session.exerciseStates[entryId] else { return }
        state.didEvaluateProgression = true
        session.exerciseStates[entryId] = state
        activeSession = session
        saveActiveSession()
    }

    func lockProgressionPrescription(entryId: UUID) {
        guard var session = activeSession,
              var state = session.exerciseStates[entryId] else { return }
        state.progressionPrescriptionLocked = true
        session.exerciseStates[entryId] = state
        activeSession = session
        saveActiveSession()
    }

    func lockProgressionPrescription(exerciseId: String, in exercises: [WorkoutExerciseEntry]) {
        for entry in exercises where entry.exerciseId == exerciseId {
            lockProgressionPrescription(entryId: entry.id)
        }
    }

    /// Saves actual set performance for history / future progression analysis.
    func logCompletedWorkoutPerformance(
        workoutId: UUID,
        workoutName: String,
        exercises: [WorkoutExerciseEntry],
        weightUnitForExercise: (String) -> WeightUnit = { _ in .kilograms }
    ) {
        guard let session = activeSession, session.workoutId == workoutId else { return }

        let loggedExercises: [LoggedExercisePerformance] = exercises.compactMap { entry in
            guard let state = session.state(for: entry.id) else { return nil }
            let unit = weightUnitForExercise(entry.exerciseId)
            let sets = state.completedSetFlags.indices.map { index in
                let performance = state.performance(at: index) ?? SetPerformance(from: entry)
                let entered = performance.weightKg > 0
                    ? WeightFormatter.displayValue(kg: performance.weightKg, unit: unit)
                    : nil
                return LoggedSetPerformance(
                    setIndex: index,
                    completed: state.completedSetFlags[index],
                    weightKg: performance.weightKg,
                    reps: performance.reps,
                    durationSeconds: performance.durationSeconds,
                    distanceMeters: performance.distanceMeters,
                    enteredWeight: entered,
                    enteredWeightUnit: entered != nil ? unit : nil
                )
            }
            return LoggedExercisePerformance(
                entryId: entry.id,
                exerciseId: entry.exerciseId,
                plannedSets: entry.sets,
                plannedReps: entry.reps,
                plannedWeightKg: entry.startingWeight,
                sets: sets
            )
        }

        guard !loggedExercises.isEmpty else { return }

        performanceLogs.insert(
            LoggedWorkoutPerformance(
                workoutId: workoutId,
                workoutName: workoutName,
                exercises: loggedExercises
            ),
            at: 0
        )
        if performanceLogs.count > 100 {
            performanceLogs = Array(performanceLogs.prefix(100))
        }
        savePerformanceLogs(performanceLogs)
    }

    /// Chronological actual performances for one exercise across all completed sessions.
    func performanceHistory(for exerciseId: String) -> [ExerciseSessionHistoryItem] {
        performanceLogs.flatMap { log in
            log.exercises
                .filter { $0.exerciseId == exerciseId && $0.sets.contains(where: \.completed) }
                .map { exercise in
                    ExerciseSessionHistoryItem(
                        id: "\(log.id.uuidString)-\(exercise.entryId.uuidString)",
                        logId: log.id,
                        workoutName: log.workoutName,
                        completedAt: log.completedAt,
                        exercise: exercise
                    )
                }
        }
        .sorted { $0.completedAt > $1.completedAt }
    }

    /// Exercises that have at least one logged actual performance.
    var exerciseHistorySummaries: [ExerciseHistorySummary] {
        var latestByExercise: [String: ExerciseSessionHistoryItem] = [:]
        var counts: [String: Int] = [:]

        for item in performanceLogs.flatMap({ log in
            log.exercises
                .filter { $0.sets.contains(where: \.completed) }
                .map { exercise in
                    ExerciseSessionHistoryItem(
                        id: "\(log.id.uuidString)-\(exercise.entryId.uuidString)",
                        logId: log.id,
                        workoutName: log.workoutName,
                        completedAt: log.completedAt,
                        exercise: exercise
                    )
                }
        }) {
            counts[item.exercise.exerciseId, default: 0] += 1
            if latestByExercise[item.exercise.exerciseId] == nil
                || item.completedAt > latestByExercise[item.exercise.exerciseId]!.completedAt {
                latestByExercise[item.exercise.exerciseId] = item
            }
        }

        return latestByExercise.values.compactMap { item in
            guard let exercise = ExerciseCatalog.exercise(id: item.exercise.exerciseId) else { return nil }
            return ExerciseHistorySummary(
                exerciseId: item.exercise.exerciseId,
                exerciseName: exercise.name,
                sessionCount: counts[item.exercise.exerciseId] ?? 0,
                lastCompletedAt: item.completedAt,
                lastPerformance: item.exercise
            )
        }
        .sorted { $0.lastCompletedAt > $1.lastCompletedAt }
    }

    func clearAllPerformanceLogs() {
        performanceLogs = []
        savePerformanceLogs([])
    }

    func fullyCompletedEntryIds() -> [UUID] {
        guard let activeSession else { return [] }
        return activeSession.exerciseStates.compactMap { id, state in
            state.isFullyCompleted ? id : nil
        }
    }

    /// Starts a brand-new session for this workout, discarding any in-progress state for it.
    @discardableResult
    func startFresh(workout: Workout) -> ActiveWorkoutSession {
        if activeSession?.workoutId == workout.id {
            endSession(markWeeklyCompletion: false)
        }
        return startOrResume(workout: workout)
    }

    /// Latest completed performance log for a workout plan (if any).
    func latestPerformance(for workoutId: UUID) -> LoggedWorkoutPerformance? {
        performanceLogs
            .filter { $0.workoutId == workoutId }
            .max(by: { $0.completedAt < $1.completedAt })
    }

    func endSession(markWeeklyCompletion: Bool) {
        if markWeeklyCompletion, let session = activeSession {
            markCompletedThisWeek(workoutId: session.workoutId, workoutName: session.workoutName)
        }
        activeSession = nil
        clearPersistedActiveSession()
    }

    // MARK: - Persistence

    private func syncSession(_ session: ActiveWorkoutSession, with workout: Workout) -> ActiveWorkoutSession {
        var session = session
        var states = session.exerciseStates
        let entryIds = Set(workout.exercises.map(\.id))

        for entry in workout.exercises {
            if var existing = states[entry.id] {
                existing.align(with: entry)
                states[entry.id] = existing
            } else {
                states[entry.id] = ExerciseSessionState(from: entry)
            }
        }

        states = states.filter { entryIds.contains($0.key) }
        session.exerciseStates = states
        if let active = session.activeEntryId, !entryIds.contains(active) {
            session.activeEntryId = nil
        }
        return session
    }

    private func loadCompletions() {
        guard let data = UserDefaults.standard.data(forKey: completionsKey),
              let decoded = try? JSONDecoder().decode([WorkoutWeeklyCompletion].self, from: data) else {
            weeklyCompletions = []
            return
        }
        weeklyCompletions = decoded
    }

    private func saveCompletions() {
        guard let data = try? JSONEncoder().encode(weeklyCompletions) else { return }
        UserDefaults.standard.set(data, forKey: completionsKey)
    }

    private func loadPerformanceLogs() -> [LoggedWorkoutPerformance] {
        guard let data = UserDefaults.standard.data(forKey: performanceLogsKey),
              let decoded = try? JSONDecoder().decode([LoggedWorkoutPerformance].self, from: data) else {
            return []
        }
        return decoded
    }

    private func savePerformanceLogs(_ logs: [LoggedWorkoutPerformance]) {
        guard let data = try? JSONEncoder().encode(logs) else { return }
        UserDefaults.standard.set(data, forKey: performanceLogsKey)
    }

    private func loadActiveSession() {
        guard let data = UserDefaults.standard.data(forKey: activeSessionKey),
              let decoded = try? JSONDecoder().decode(ActiveWorkoutSession.self, from: data) else {
            activeSession = nil
            return
        }
        activeSession = decoded
    }

    private func saveActiveSession() {
        guard let activeSession,
              let data = try? JSONEncoder().encode(activeSession) else { return }
        UserDefaults.standard.set(data, forKey: activeSessionKey)
    }

    private func clearPersistedActiveSession() {
        UserDefaults.standard.removeObject(forKey: activeSessionKey)
    }
}
