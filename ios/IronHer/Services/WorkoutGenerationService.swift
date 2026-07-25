import Foundation

enum WorkoutTrainingGoal: String, CaseIterable, Identifiable {
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
    var goal: WorkoutTrainingGoal = .buildMuscle
    var experience: TrainingExperience = .intermediate
    var duration: WorkoutDuration = .fortyFive
    /// Fine-grained available equipment for this generation.
    var availableEquipment: Set<GymEquipmentKind> = GymEquipmentPreset.fullGym.equipment
    var muscleGroups: Set<MuscleGroup> = [.chest, .back, .glutes]
    /// Optional exercise IDs the user wants included when compatible.
    var includeExerciseIds: Set<String> = []
    /// Optional exercise IDs to avoid.
    var avoidExerciseIds: Set<String> = []
    /// Number of training days (informational for naming / future split plans).
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
}

enum WorkoutGenerationService {
    static func generateWorkout(from request: WorkoutGenerationRequest) -> Workout? {
        let candidates = ExerciseCatalog.all.filter { exercise in
            guard exercise.isCompatible(with: request.availableEquipment) else { return false }
            guard request.muscleGroups.contains(exercise.primaryMuscleGroup) else { return false }
            guard !request.avoidExerciseIds.contains(exercise.id) else { return false }
            return true
        }

        guard !candidates.isEmpty else { return nil }

        let targetCount = request.duration.targetExerciseCount.lowerBound
            + Int.random(in: 0...(request.duration.targetExerciseCount.upperBound - request.duration.targetExerciseCount.lowerBound))

        var selected = pickExercises(
            from: candidates,
            count: targetCount,
            experience: request.experience,
            muscleGroups: request.muscleGroups
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

        guard !selected.isEmpty else { return nil }

        let (sets, reps) = defaultPrescription(for: request.goal, experience: request.experience)

        let entries = selected.enumerated().map { index, exercise in
            WorkoutExerciseEntry(
                exerciseId: exercise.id,
                sets: sets,
                reps: reps,
                startingWeight: 0,
                order: index
            )
        }

        return Workout(
            name: workoutName(for: request),
            exercises: entries
        )
    }

    private static func pickExercises(
        from candidates: [Exercise],
        count: Int,
        experience: TrainingExperience,
        muscleGroups: Set<MuscleGroup>
    ) -> [Exercise] {
        var picked: [Exercise] = []
        var usedIds = Set<String>()
        let groups = muscleGroups.sorted { $0.label < $1.label }

        for group in groups {
            let groupCandidates = candidates.filter {
                $0.primaryMuscleGroup == group && !usedIds.contains($0.id)
            }
            let sorted = groupCandidates.sorted { lhs, rhs in
                score(lhs, experience: experience) > score(rhs, experience: experience)
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
                .sorted { score($0, experience: experience) > score($1, experience: experience) }

            for exercise in remaining {
                picked.append(exercise)
                usedIds.insert(exercise.id)
                if picked.count >= count { break }
            }
        }

        return picked
    }

    private static func score(_ exercise: Exercise, experience: TrainingExperience) -> Int {
        let compoundCategories: Set<ExerciseCategory> = [.push, .pull, .squat, .hinge, .lunge]
        let isCompound = compoundCategories.contains(exercise.category)

        switch experience {
        case .beginner:
            return isCompound ? 3 : 1
        case .intermediate:
            return isCompound ? 2 : 2
        case .advanced:
            return isCompound ? 1 : 3
        }
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

    private static func workoutName(for request: WorkoutGenerationRequest) -> String {
        let muscles = request.muscleGroups
            .sorted { $0.label < $1.label }
            .prefix(2)
            .map(\.label)
            .joined(separator: " & ")

        if muscles.isEmpty {
            return "\(request.goal.label) · \(request.duration.label)"
        }
        return "\(muscles) · \(request.goal.label)"
    }
}
