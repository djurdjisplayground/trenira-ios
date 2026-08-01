import Foundation

struct WorkoutWeeklyCompletion: Identifiable, Codable, Hashable {
    let id: UUID
    let workoutId: UUID
    let workoutName: String
    let completedAt: Date
    var ownerId: String

    init(
        id: UUID = UUID(),
        workoutId: UUID,
        workoutName: String,
        completedAt: Date = .now,
        ownerId: String = ""
    ) {
        self.id = id
        self.workoutId = workoutId
        self.workoutName = workoutName
        self.completedAt = completedAt
        self.ownerId = ownerId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        workoutId = try container.decode(UUID.self, forKey: .workoutId)
        workoutName = try container.decode(String.self, forKey: .workoutName)
        completedAt = try container.decode(Date.self, forKey: .completedAt)
        ownerId = try container.decodeIfPresent(String.self, forKey: .ownerId) ?? ""
    }
}

/// What the athlete actually performed for one set (separate from the planned prescription).
struct SetPerformance: Codable, Equatable, Hashable {
    var weightKg: Double
    var reps: Int
    var durationSeconds: Int
    var distanceMeters: Double

    init(
        weightKg: Double = 0,
        reps: Int = 0,
        durationSeconds: Int = 0,
        distanceMeters: Double = 0
    ) {
        self.weightKg = weightKg
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
    }

    init(from entry: WorkoutExerciseEntry) {
        self.weightKg = entry.startingWeight
        self.reps = entry.reps
        self.durationSeconds = entry.durationSeconds
        self.distanceMeters = entry.distanceMeters
    }
}

struct ExerciseSessionState: Codable, Equatable, Hashable {
    var completedSetFlags: [Bool]
    /// Parallel to `completedSetFlags` — actual weight/reps (and time/distance) for each set.
    var setPerformances: [SetPerformance]
    var didEvaluateProgression: Bool
    /// When true, finish-workout must not overwrite an accepted/declined progression prescription.
    var progressionPrescriptionLocked: Bool

    init(
        plannedSets: Int,
        defaultPerformance: SetPerformance = SetPerformance(),
        completedSetFlags: [Bool]? = nil,
        setPerformances: [SetPerformance]? = nil,
        didEvaluateProgression: Bool = false,
        progressionPrescriptionLocked: Bool = false
    ) {
        let count = max(1, plannedSets)
        if let completedSetFlags, completedSetFlags.count == count {
            self.completedSetFlags = completedSetFlags
        } else {
            self.completedSetFlags = Array(repeating: false, count: count)
        }

        if let setPerformances, setPerformances.count == count {
            self.setPerformances = setPerformances
        } else if let setPerformances, !setPerformances.isEmpty {
            var padded = setPerformances
            if padded.count < count {
                padded.append(contentsOf: Array(repeating: defaultPerformance, count: count - padded.count))
            } else {
                padded = Array(padded.prefix(count))
            }
            self.setPerformances = padded
        } else {
            self.setPerformances = Array(repeating: defaultPerformance, count: count)
        }

        self.didEvaluateProgression = didEvaluateProgression
        self.progressionPrescriptionLocked = progressionPrescriptionLocked
    }

    init(from entry: WorkoutExerciseEntry) {
        self.init(
            plannedSets: entry.sets,
            defaultPerformance: SetPerformance(from: entry)
        )
    }

    var completedSetCount: Int {
        completedSetFlags.filter(\.self).count
    }

    var plannedSets: Int {
        completedSetFlags.count
    }

    var isFullyCompleted: Bool {
        !completedSetFlags.isEmpty && completedSetFlags.allSatisfy(\.self)
    }

    var progressFraction: Double {
        guard plannedSets > 0 else { return 0 }
        return Double(completedSetCount) / Double(plannedSets)
    }

    func performance(at index: Int) -> SetPerformance? {
        setPerformances.indices.contains(index) ? setPerformances[index] : nil
    }

    /// True when every completed set meets or exceeds the planned rep target.
    func metPlannedReps(_ plannedReps: Int) -> Bool {
        guard isFullyCompleted, setPerformances.count == completedSetFlags.count else { return false }
        return setPerformances.allSatisfy { $0.reps >= plannedReps }
    }

    /// True when every completed set meets or exceeds the planned duration target.
    func metPlannedDuration(_ plannedSeconds: Int) -> Bool {
        guard isFullyCompleted, plannedSeconds > 0 else { return isFullyCompleted && plannedSeconds == 0 }
        return setPerformances.allSatisfy { $0.durationSeconds >= plannedSeconds }
    }

    mutating func toggleSet(at index: Int) {
        guard completedSetFlags.indices.contains(index) else { return }
        completedSetFlags[index].toggle()
    }

    mutating func updatePerformance(at index: Int, _ update: (inout SetPerformance) -> Void) {
        guard setPerformances.indices.contains(index) else { return }
        update(&setPerformances[index])
    }

    mutating func align(with entry: WorkoutExerciseEntry) {
        let defaults = SetPerformance(from: entry)
        // Keep session set rows in lockstep with the workout template’s planned count.
        // Stale drafts (e.g. old 4-set cache vs current 3-set config) are rebuilt here.
        // Completed historical logs are never modified — only the live session state.
        resize(to: max(1, entry.sets), defaultPerformance: defaults)

        // Incomplete sets always mirror the current planned target.
        // Completed sets keep what the athlete actually performed this session.
        for index in setPerformances.indices {
            let isComplete = completedSetFlags.indices.contains(index) && completedSetFlags[index]
            if isComplete { continue }
            setPerformances[index] = defaults
        }
    }

    mutating func resize(to plannedSets: Int, defaultPerformance: SetPerformance = SetPerformance()) {
        let count = max(1, plannedSets)
        if completedSetFlags.count < count {
            completedSetFlags.append(contentsOf: Array(repeating: false, count: count - completedSetFlags.count))
        } else if completedSetFlags.count > count {
            completedSetFlags = Array(completedSetFlags.prefix(count))
        }

        if setPerformances.count < count {
            setPerformances.append(
                contentsOf: Array(repeating: defaultPerformance, count: count - setPerformances.count)
            )
        } else if setPerformances.count > count {
            setPerformances = Array(setPerformances.prefix(count))
        }
    }

    private enum CodingKeys: String, CodingKey {
        case completedSetFlags
        case setPerformances
        case didEvaluateProgression
        case progressionPrescriptionLocked
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        completedSetFlags = try container.decode([Bool].self, forKey: .completedSetFlags)
        setPerformances = try container.decodeIfPresent([SetPerformance].self, forKey: .setPerformances)
            ?? []
        didEvaluateProgression = try container.decodeIfPresent(Bool.self, forKey: .didEvaluateProgression) ?? false
        progressionPrescriptionLocked = try container.decodeIfPresent(Bool.self, forKey: .progressionPrescriptionLocked) ?? false

        // Align lengths after decoding legacy payloads that only had flags.
        if setPerformances.count != completedSetFlags.count {
            let count = completedSetFlags.count
            if setPerformances.count < count {
                setPerformances.append(
                    contentsOf: Array(repeating: SetPerformance(), count: count - setPerformances.count)
                )
            } else {
                setPerformances = Array(setPerformances.prefix(count))
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(completedSetFlags, forKey: .completedSetFlags)
        try container.encode(setPerformances, forKey: .setPerformances)
        try container.encode(didEvaluateProgression, forKey: .didEvaluateProgression)
        try container.encode(progressionPrescriptionLocked, forKey: .progressionPrescriptionLocked)
    }
}

struct ActiveWorkoutSession: Identifiable, Codable, Equatable {
    let id: UUID
    let workoutId: UUID
    let workoutName: String
    var startedAt: Date
    var exerciseStates: [UUID: ExerciseSessionState]
    var activeEntryId: UUID?
    /// Session-only exercise swaps keyed by entry id (does not rewrite the saved plan).
    var exerciseIdOverrides: [UUID: String]

    init(
        id: UUID = UUID(),
        workoutId: UUID,
        workoutName: String,
        startedAt: Date = .now,
        exerciseStates: [UUID: ExerciseSessionState] = [:],
        activeEntryId: UUID? = nil,
        exerciseIdOverrides: [UUID: String] = [:]
    ) {
        self.id = id
        self.workoutId = workoutId
        self.workoutName = workoutName
        self.startedAt = startedAt
        self.exerciseStates = exerciseStates
        self.activeEntryId = activeEntryId
        self.exerciseIdOverrides = exerciseIdOverrides
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        workoutId = try container.decode(UUID.self, forKey: .workoutId)
        workoutName = try container.decode(String.self, forKey: .workoutName)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        exerciseStates = try container.decodeIfPresent([UUID: ExerciseSessionState].self, forKey: .exerciseStates) ?? [:]
        activeEntryId = try container.decodeIfPresent(UUID.self, forKey: .activeEntryId)
        exerciseIdOverrides = try container.decodeIfPresent([UUID: String].self, forKey: .exerciseIdOverrides) ?? [:]
    }

    private enum CodingKeys: String, CodingKey {
        case id, workoutId, workoutName, startedAt, exerciseStates, activeEntryId, exerciseIdOverrides
    }

    func state(for entryId: UUID) -> ExerciseSessionState? {
        exerciseStates[entryId]
    }

    func resolvedExerciseId(for entry: WorkoutExerciseEntry) -> String {
        exerciseIdOverrides[entry.id] ?? entry.exerciseId
    }

    var fullyCompletedExerciseCount: Int {
        exerciseStates.values.filter(\.isFullyCompleted).count
    }
}

/// Persisted record of what was actually performed (separate from the planned workout).
struct LoggedWorkoutPerformance: Identifiable, Codable, Equatable {
    let id: UUID
    let workoutId: UUID
    let workoutName: String
    let completedAt: Date
    let exercises: [LoggedExercisePerformance]
    var ownerId: String

    init(
        id: UUID = UUID(),
        workoutId: UUID,
        workoutName: String,
        completedAt: Date = .now,
        exercises: [LoggedExercisePerformance],
        ownerId: String = ""
    ) {
        self.id = id
        self.workoutId = workoutId
        self.workoutName = workoutName
        self.completedAt = completedAt
        self.exercises = exercises
        self.ownerId = ownerId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        workoutId = try container.decode(UUID.self, forKey: .workoutId)
        workoutName = try container.decode(String.self, forKey: .workoutName)
        completedAt = try container.decode(Date.self, forKey: .completedAt)
        exercises = try container.decode([LoggedExercisePerformance].self, forKey: .exercises)
        ownerId = try container.decodeIfPresent(String.self, forKey: .ownerId) ?? ""
    }
}

struct LoggedExercisePerformance: Codable, Equatable, Hashable {
    let entryId: UUID
    let exerciseId: String
    let plannedSets: Int
    let plannedReps: Int
    let plannedWeightKg: Double
    let sets: [LoggedSetPerformance]
}

struct LoggedSetPerformance: Codable, Equatable, Hashable {
    let setIndex: Int
    let completed: Bool
    /// Canonical internal weight in kilograms.
    let weightKg: Double
    let reps: Int
    let durationSeconds: Int
    let distanceMeters: Double
    /// Value as entered/shown during the session (optional for legacy logs).
    let enteredWeight: Double?
    /// Unit used when the value was entered (optional for legacy logs).
    let enteredWeightUnit: WeightUnit?

    init(
        setIndex: Int,
        completed: Bool,
        weightKg: Double,
        reps: Int,
        durationSeconds: Int,
        distanceMeters: Double,
        enteredWeight: Double? = nil,
        enteredWeightUnit: WeightUnit? = nil
    ) {
        self.setIndex = setIndex
        self.completed = completed
        self.weightKg = weightKg
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.enteredWeight = enteredWeight
        self.enteredWeightUnit = enteredWeightUnit
    }

    /// Preferred display for history — preserves the unit the athlete actually used.
    func displayWeight(fallbackUnit: WeightUnit) -> (value: Double, unit: WeightUnit) {
        if let enteredWeight, let enteredWeightUnit {
            return (enteredWeight, enteredWeightUnit)
        }
        return (WeightFormatter.displayValue(kg: weightKg, unit: fallbackUnit), fallbackUnit)
    }

    func formattedWeight(fallbackUnit: WeightUnit, includeUnit: Bool = true) -> String {
        let shown = displayWeight(fallbackUnit: fallbackUnit)
        return WeightFormatter.formatDisplay(shown.value, unit: shown.unit, includeUnit: includeUnit)
    }
}

/// One exercise occurrence inside a completed workout log (for Progress History).
struct ExerciseSessionHistoryItem: Identifiable, Equatable {
    let id: String
    let logId: UUID
    let workoutName: String
    let completedAt: Date
    let exercise: LoggedExercisePerformance
}

struct ExerciseHistorySummary: Identifiable, Equatable {
    let exerciseId: String
    let exerciseName: String
    let sessionCount: Int
    let lastCompletedAt: Date
    let lastPerformance: LoggedExercisePerformance

    var id: String { exerciseId }
}

enum WorkoutWeekCalendar {
    static var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        return calendar
    }

    static func startOfWeek(for date: Date = .now) -> Date {
        let cal = calendar
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: components) ?? date
    }

    static func isInCurrentWeek(_ date: Date) -> Bool {
        let cal = calendar
        return cal.isDate(date, equalTo: .now, toGranularity: .weekOfYear)
    }
}
