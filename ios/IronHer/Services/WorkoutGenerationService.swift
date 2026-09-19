import Foundation

enum WorkoutTrainingGoal: String, CaseIterable, Identifiable, Hashable {
    case buildMuscle
    case getStronger
    case tone
    case generalFitness

    var id: String { rawValue }

    var label: String {
        switch self {
        case .buildMuscle: return "Build muscle"
        case .getStronger: return "Get stronger"
        case .tone: return "Tone & define"
        case .generalFitness: return "General fitness"
        }
    }
}

enum TrainingExperience: String, CaseIterable, Identifiable {
    case beginner
    case intermediate
    case advanced

    var id: String { rawValue }

    var label: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }
}

enum WorkoutDuration: Int, CaseIterable, Identifiable {
    case thirty = 30
    case fortyFive = 45
    case sixty = 60
    case seventyFive = 75

    var id: Int { rawValue }

    var label: String { "\(rawValue) min" }

    var targetExerciseCount: ClosedRange<Int> {
        switch self {
        case .thirty: return 4...5
        case .fortyFive: return 5...6
        case .sixty: return 6...8
        case .seventyFive: return 8...10
        }
    }
}

struct WorkoutGenerationRequest {
    var goals: Set<WorkoutTrainingGoal> = [.buildMuscle]
    var experience: TrainingExperience = .intermediate
    var duration: WorkoutDuration = .fortyFive
    /// Fine-grained available equipment for this generation.
    var availableEquipment: Set<GymEquipmentKind> = GymEquipmentPreset.fullGym.equipment
    var muscleGroups: Set<MuscleGroup> = [.chest, .back, .glutes]
    /// Optional exercise IDs the user wants included when compatible.
    var includeExerciseIds: Set<String> = []
    /// Optional exercise IDs to avoid.
    var avoidExerciseIds: Set<String> = []
    /// Weekly training frequency. Each day becomes its own saved workout.
    var trainingDays: Int = 3

    /// Legacy bridge from coarse equipment chips.
    var equipment: Set<GymEquipmentOption> {
        get {
            var result = Set<GymEquipmentOption>()
            if availableEquipment.contains(.dumbbells) { result.insert(.dumbbells) }
            if availableEquipment.contains(.barbell) || availableEquipment.contains(.smithMachine) { result.insert(.barbell) }
            if availableEquipment.contains(where: { $0.category == .machines }) { result.insert(.machines) }
            if availableEquipment.contains(where: { $0.category == .cables }) { result.insert(.cables) }
            if availableEquipment.contains(.bodyweight) { result.insert(.bodyweight) }
            if availableEquipment.contains(.kettlebells) { result.insert(.kettlebells) }
            return result
        }
        set {
            var kinds = Set<GymEquipmentKind>()
            for option in newValue {
                kinds.formUnion(option.expandedKinds)
            }
            if kinds.isEmpty { kinds = [.bodyweight] }
            availableEquipment = kinds
        }
    }

    /// Stable display order matching `WorkoutTrainingGoal.allCases`.
    var orderedGoals: [WorkoutTrainingGoal] {
        WorkoutTrainingGoal.allCases.filter { goals.contains($0) }
    }
}

enum WorkoutGenerationService {
    /// Builds one complementary session per training day. Falls back to a single
    /// session when frequency is 1 (not currently offered in the UI).
    static func generateWorkouts(from request: WorkoutGenerationRequest) -> [Workout] {
        let days = max(1, min(6, request.trainingDays))
        guard days > 1 else {
            return generateWorkout(from: request).map { [$0] } ?? []
        }

        let focuses = dayFocuses(trainingDays: days)
        let splits = muscleSplits(selected: request.muscleGroups, focuses: focuses)

        var usedExerciseIds = request.avoidExerciseIds
        var workouts: [Workout] = []

        for (index, focus) in focuses.enumerated() {
            let dayMuscles = splits[index]
            guard !dayMuscles.isEmpty else { continue }

            var dayRequest = request
            dayRequest.muscleGroups = dayMuscles
            dayRequest.avoidExerciseIds = usedExerciseIds
            dayRequest.includeExerciseIds = request.includeExerciseIds.subtracting(usedExerciseIds)

            var workout = generateWorkout(from: dayRequest)
            if workout == nil || workout?.exercises.isEmpty == true {
                dayRequest.avoidExerciseIds = request.avoidExerciseIds
                workout = generateWorkout(from: dayRequest)
            }
            guard var session = workout, !session.exercises.isEmpty else { continue }

            let preferredHit = focus.preferred.intersection(request.muscleGroups)
            let label: String
            if preferredHit.isEmpty {
                label = dayMuscles.sorted { $0.label < $1.label }.prefix(2).map(\.label).joined(separator: " & ")
            } else {
                label = focus.label
            }
            session.name = "Day \(index + 1) · \(label)"
            usedExerciseIds.formUnion(session.exercises.map(\.exerciseId))
            workouts.append(session)
        }

        return workouts
    }

    static func generateWorkout(from request: WorkoutGenerationRequest) -> Workout? {
        guard !request.goals.isEmpty else { return nil }
        guard !request.muscleGroups.isEmpty else { return nil }
        guard !request.availableEquipment.isEmpty else { return nil }

        let candidates = ExerciseCatalog.all.filter { exercise in
            guard ExerciseCatalog.exercise(id: exercise.id) != nil else { return false }
            guard exercise.isCompatible(with: request.availableEquipment) else { return false }
            guard request.muscleGroups.contains(exercise.primaryMuscleGroup) else { return false }
            guard !request.avoidExerciseIds.contains(exercise.id) else { return false }
            return true
        }

        guard !candidates.isEmpty else { return nil }

        let range = request.duration.targetExerciseCount
        let span = max(0, range.upperBound - range.lowerBound)
        let targetCount = max(1, range.lowerBound + (span == 0 ? 0 : Int.random(in: 0...span)))

        var selected = pickExercises(
            from: candidates,
            count: targetCount,
            experience: request.experience,
            muscleGroups: request.muscleGroups,
            goals: request.goals
        )

        // Prefer including requested exercises when compatible.
        for includeId in request.includeExerciseIds {
            guard let exercise = candidates.first(where: { $0.id == includeId }) else { continue }
            if !selected.contains(where: { $0.id == exercise.id }) {
                if selected.count >= targetCount, let last = selected.indices.last {
                    selected.remove(at: last)
                }
                selected.insert(exercise, at: 0)
            }
        }

        selected = selected.filter { ExerciseCatalog.exercise(id: $0.id) != nil }
        guard !selected.isEmpty else { return nil }

        let entries = selected.enumerated().map { index, exercise in
            let (rawSets, rawReps) = prescription(
                for: exercise,
                goals: request.goals,
                experience: request.experience
            )
            return WorkoutExerciseEntry(
                exerciseId: exercise.id,
                sets: min(10, max(1, rawSets)),
                reps: min(50, max(1, rawReps)),
                startingWeight: 0,
                order: index
            )
        }

        return Workout(
            name: workoutName(for: request),
            exercises: entries
        )
    }

    /// Rebuilds one generated slot after the user picks a different catalog exercise.
    static func replacingGeneratedEntry(
        _ entry: WorkoutExerciseEntry,
        with exercise: Exercise,
        request: WorkoutGenerationRequest
    ) -> WorkoutExerciseEntry {
        let (rawSets, rawReps) = prescription(
            for: exercise,
            goals: request.goals,
            experience: request.experience
        )
        return WorkoutExerciseEntry(
            id: entry.id,
            exerciseId: exercise.id,
            sets: min(10, max(1, rawSets)),
            reps: min(50, max(1, rawReps)),
            startingWeight: 0,
            durationSeconds: 0,
            distanceMeters: 0,
            order: entry.order,
            restDurationOverride: entry.restDurationOverride
        )
    }

    private static func pickExercises(
        from candidates: [Exercise],
        count: Int,
        experience: TrainingExperience,
        muscleGroups: Set<MuscleGroup>,
        goals: Set<WorkoutTrainingGoal>
    ) -> [Exercise] {
        var picked: [Exercise] = []
        var usedIds = Set<String>()
        let groups = muscleGroups.sorted { $0.label < $1.label }

        for group in groups {
            let groupCandidates = candidates.filter {
                $0.primaryMuscleGroup == group && !usedIds.contains($0.id)
            }
            let sorted = groupCandidates.sorted { lhs, rhs in
                score(lhs, experience: experience, goals: goals) > score(rhs, experience: experience, goals: goals)
            }
            if let exercise = sorted.first {
                picked.append(exercise)
                usedIds.insert(exercise.id)
            }
            if picked.count >= count { break }
        }

        if picked.count < count {
            let remaining = candidates
                .filter { !usedIds.contains($0.id) }
                .sorted { score($0, experience: experience, goals: goals) > score($1, experience: experience, goals: goals) }

            for exercise in remaining {
                picked.append(exercise)
                usedIds.insert(exercise.id)
                if picked.count >= count { break }
            }
        }

        return picked
    }

    private static func isCompound(_ exercise: Exercise) -> Bool {
        let compoundCategories: Set<ExerciseCategory> = [.push, .pull, .squat, .hinge, .lunge]
        return compoundCategories.contains(exercise.category)
    }

    private static func score(
        _ exercise: Exercise,
        experience: TrainingExperience,
        goals: Set<WorkoutTrainingGoal>
    ) -> Int {
        let compound = isCompound(exercise)

        var value: Int
        switch experience {
        case .beginner:
            value = compound ? 3 : 1
        case .intermediate:
            value = 2
        case .advanced:
            value = compound ? 1 : 3
        }

        // Extra bias only when combining goals so a single-goal session
        // keeps the previous ranking.
        if goals.count > 1 {
            if goals.contains(.getStronger), compound { value += 2 }
            if goals.contains(.tone), !compound { value += 2 }
            if goals.contains(.buildMuscle), compound { value += 1 }
        }

        return value
    }

    private static func defaultPrescription(
        for goal: WorkoutTrainingGoal,
        experience: TrainingExperience
    ) -> (sets: Int, reps: Int) {
        switch (goal, experience) {
        case (.getStronger, _):
            return (4, 6)
        case (.tone, _), (.generalFitness, .beginner):
            return (3, 12)
        case (.buildMuscle, .advanced):
            return (4, 8)
        default:
            return (3, 8)
        }
    }

    /// Single goal: same sets/reps for every exercise as before.
    /// Multiple goals: compounds use the lower-rep prescription, accessories the higher-rep one.
    private static func prescription(
        for exercise: Exercise,
        goals: Set<WorkoutTrainingGoal>,
        experience: TrainingExperience
    ) -> (sets: Int, reps: Int) {
        let selected = goals.isEmpty ? Set([WorkoutTrainingGoal.buildMuscle]) : goals
        let options = selected.map { defaultPrescription(for: $0, experience: experience) }
        guard let first = options.first else { return (3, 8) }
        if options.count == 1 { return first }

        if isCompound(exercise) {
            return options.min { lhs, rhs in
                lhs.reps != rhs.reps ? lhs.reps < rhs.reps : lhs.sets > rhs.sets
            } ?? first
        }
        return options.max { lhs, rhs in
            lhs.reps != rhs.reps ? lhs.reps < rhs.reps : lhs.sets < rhs.sets
        } ?? first
    }

    private static func workoutName(for request: WorkoutGenerationRequest) -> String {
        let muscles = request.muscleGroups
            .sorted { $0.label < $1.label }
            .prefix(2)
            .map(\.label)
            .joined(separator: " & ")

        let goalPart = request.orderedGoals.map(\.label).joined(separator: " + ")
        let resolvedGoals = goalPart.isEmpty ? WorkoutTrainingGoal.buildMuscle.label : goalPart

        if muscles.isEmpty {
            return "\(resolvedGoals) · \(request.duration.label)"
        }
        return "\(muscles) · \(resolvedGoals)"
    }

    private struct DayFocus {
        let label: String
        let preferred: Set<MuscleGroup>
    }

    private static func dayFocuses(trainingDays: Int) -> [DayFocus] {
        let push = DayFocus(label: "Push", preferred: [.chest, .shoulders, .triceps])
        let pull = DayFocus(label: "Pull", preferred: [.back, .biceps])
        let legs = DayFocus(label: "Legs", preferred: [.quads, .hamstrings, .glutes, .calves])
        let upper = DayFocus(label: "Upper", preferred: [.chest, .back, .shoulders, .biceps, .triceps])
        let lower = DayFocus(label: "Lower", preferred: [.quads, .hamstrings, .glutes, .calves])

        switch trainingDays {
        case 2:
            return [upper, lower]
        case 3:
            return [push, pull, legs]
        case 4:
            return [upper, lower, upper, lower]
        case 5:
            return [push, pull, legs, upper, lower]
        default:
            return [push, pull, legs, push, pull, legs]
        }
    }

    private static func muscleSplits(
        selected: Set<MuscleGroup>,
        focuses: [DayFocus]
    ) -> [Set<MuscleGroup>] {
        let extras: Set<MuscleGroup> = selected.intersection([.core, .fullBody])
        var splits = focuses.map { focus in
            focus.preferred.intersection(selected).union(extras)
        }

        let ordered = selected.sorted { $0.label < $1.label }
        guard !ordered.isEmpty else { return splits }

        for index in splits.indices where splits[index].isEmpty {
            splits[index] = [ordered[index % ordered.count]]
        }

        return splits
    }
}
