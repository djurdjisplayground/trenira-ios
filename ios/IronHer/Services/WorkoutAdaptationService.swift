import Foundation

enum WorkoutRefreshMode: Equatable {
    case sameEquipment
    case customEquipment(Set<GymEquipmentOption>)
    case detailedEquipment(Set<GymEquipmentKind>)
}

struct WorkoutAdaptationProposal: Identifiable {
    let id = UUID()
    let originalExerciseId: String
    let originalName: String
    let proposedExerciseId: String
    let proposedName: String
    let proposedEquipment: String
    let sets: Int
    let reps: Int
    let startingWeight: Double
    let isVarietySwap: Bool
}

enum WorkoutAdaptationService {
    /// Preferred swaps when gym equipment changes. Keys are source exercise IDs.
    private static let swapMap: [String: [String: String]] = makeSwapMap()

    /// Curated variety swaps — same equipment, different movement, same muscle focus.
    private static let sameEquipmentVariety: [String: [String]] = makeSameEquipmentVariety()

    /// Builds a dictionary without trapping on accidental duplicate keys.
    private static func dictionary<Value>(
        _ entries: [(String, Value)],
        merge: ((Value, Value) -> Value)? = nil
    ) -> [String: Value] {
        var result: [String: Value] = [:]
        result.reserveCapacity(entries.count)
        for (key, value) in entries {
            if let existing = result[key], let merge {
                result[key] = merge(existing, value)
            } else {
                result[key] = value
            }
        }
        return result
    }

    private static func makeSwapMap() -> [String: [String: String]] {
        dictionary([
            ("hip-thrust", ["Machine": "smith-hip-thrust", "Cable": "cable-kickback", "Dumbbell": "dumbbell-hip-thrust"]),
            ("smith-hip-thrust", ["Barbell": "hip-thrust", "Cable": "cable-kickback", "Dumbbell": "dumbbell-hip-thrust"]),
            ("cable-kickback", [
                "Dumbbell": "dumbbell-donkey-kick",
                "Bodyweight": "quadruped-hip-extension",
                "Machine": "machine-glute-kickback",
            ]),
            ("barbell-back-squat", ["Machine": "hack-squat", "Dumbbell": "goblet-squat"]),
            ("goblet-squat", ["Barbell": "barbell-back-squat", "Machine": "leg-press"]),
            ("hack-squat", ["Barbell": "barbell-back-squat", "Dumbbell": "goblet-squat"]),
            ("smith-squat", ["Dumbbell": "goblet-squat", "Machine": "leg-press"]),
            ("leg-press", ["Dumbbell": "goblet-squat", "Barbell": "barbell-back-squat"]),
            ("barbell-bench-press", ["Dumbbell": "dumbbell-bench-press", "Machine": "chest-press-machine"]),
            ("dumbbell-bench-press", ["Barbell": "barbell-bench-press", "Machine": "chest-press-machine"]),
            ("chest-press-machine", ["Dumbbell": "dumbbell-bench-press", "Barbell": "barbell-bench-press"]),
            ("incline-dumbbell-press", ["Machine": "chest-press-machine", "Barbell": "barbell-bench-press"]),
            ("push-up", ["Machine": "chest-press-machine", "Dumbbell": "dumbbell-bench-press"]),
            ("pec-deck", ["Cable": "cable-fly", "Dumbbell": "dumbbell-fly"]),
            ("cable-fly", ["Machine": "pec-deck", "Dumbbell": "dumbbell-fly"]),
            ("lat-pulldown", ["Machine": "assisted-pull-up", "Bodyweight": "pull-up"]),
            ("pull-up", ["Machine": "assisted-pull-up", "Cable": "lat-pulldown"]),
            ("assisted-pull-up", ["Bodyweight": "pull-up", "Cable": "lat-pulldown"]),
            ("barbell-row", ["Dumbbell": "one-arm-dumbbell-row", "Cable": "seated-cable-row", "Machine": "machine-row"]),
            ("one-arm-dumbbell-row", ["Cable": "seated-cable-row", "Barbell": "barbell-row", "Machine": "machine-row"]),
            ("seated-cable-row", ["Dumbbell": "one-arm-dumbbell-row", "Barbell": "barbell-row", "Machine": "machine-row"]),
            ("overhead-press", ["Dumbbell": "dumbbell-shoulder-press", "Machine": "machine-shoulder-press"]),
            ("dumbbell-shoulder-press", ["Barbell": "overhead-press", "Machine": "machine-shoulder-press"]),
            ("barbell-curl", ["Dumbbell": "dumbbell-curl", "Cable": "cable-curl"]),
            ("dumbbell-curl", ["Barbell": "barbell-curl", "Cable": "cable-curl"]),
            ("tricep-pushdown", ["Dumbbell": "overhead-tricep-extension", "Barbell": "skull-crusher"]),
            ("romanian-deadlift", ["Dumbbell": "dumbbell-rdl", "Machine": "lying-leg-curl"]),
            ("walking-lunge", ["Machine": "leg-press", "Bodyweight": "walking-lunge"]),
            ("step-up", ["Machine": "leg-extension", "Bodyweight": "step-up", "Dumbbell": "glute-focused-step-up"]),
        ])
    }

    private static func makeSameEquipmentVariety() -> [String: [String]] {
        dictionary(
            [
                ("hip-thrust", ["sumo-deadlift"]),
                ("sumo-deadlift", ["hip-thrust", "romanian-deadlift"]),
                ("romanian-deadlift", ["sumo-deadlift"]),
                ("barbell-back-squat", ["sumo-deadlift"]),
                ("goblet-squat", ["bulgarian-split-squat", "walking-lunge", "step-up"]),
                ("bulgarian-split-squat", ["walking-lunge", "goblet-squat", "step-up"]),
                ("walking-lunge", ["bulgarian-split-squat", "step-up"]),
                ("step-up", ["walking-lunge", "bulgarian-split-squat"]),
                ("barbell-bench-press", ["incline-dumbbell-press"]),
                ("dumbbell-bench-press", ["incline-dumbbell-press", "cable-fly"]),
                ("incline-dumbbell-press", ["dumbbell-bench-press", "cable-fly"]),
                ("cable-fly", ["pec-deck", "dumbbell-bench-press"]),
                ("pec-deck", ["cable-fly"]),
                ("chest-press-machine", ["dumbbell-bench-press", "pec-deck"]),
                ("push-up", ["dumbbell-bench-press"]),
                ("lat-pulldown", ["straight-arm-pulldown", "seated-cable-row"]),
                ("seated-cable-row", ["one-arm-dumbbell-row", "barbell-row", "lat-pulldown"]),
                ("barbell-row", ["one-arm-dumbbell-row", "seated-cable-row"]),
                ("one-arm-dumbbell-row", ["barbell-row", "seated-cable-row"]),
                ("pull-up", ["lat-pulldown"]),
                ("assisted-pull-up", ["lat-pulldown"]),
                ("straight-arm-pulldown", ["lat-pulldown"]),
                ("overhead-press", ["dumbbell-shoulder-press", "arnold-press", "smith-overhead-press"]),
                ("dumbbell-shoulder-press", ["overhead-press", "arnold-press", "single-arm-dumbbell-overhead-press"]),
                ("arnold-press", ["dumbbell-shoulder-press", "overhead-press"]),
                ("lateral-raise", ["face-pull", "reverse-pec-deck"]),
                ("face-pull", ["lateral-raise", "reverse-pec-deck"]),
                ("reverse-pec-deck", ["face-pull", "lateral-raise"]),
                ("barbell-curl", ["dumbbell-curl", "hammer-curl"]),
                ("dumbbell-curl", ["hammer-curl", "barbell-curl"]),
                ("hammer-curl", ["dumbbell-curl", "barbell-curl"]),
                ("tricep-pushdown", ["overhead-tricep-extension", "skull-crusher"]),
                ("skull-crusher", ["dumbbell-skull-crusher", "ez-bar-skull-crusher", "overhead-tricep-extension", "tricep-pushdown"]),
                ("overhead-tricep-extension", ["tricep-pushdown", "skull-crusher"]),
                ("dips", ["tricep-pushdown", "skull-crusher"]),
                ("tricep-dip", ["tricep-pushdown", "skull-crusher"]),
                ("chest-dip", ["dumbbell-bench-press"]),
                ("leg-press", ["hack-squat", "leg-extension"]),
                ("hack-squat", ["leg-press", "leg-extension"]),
                ("leg-extension", ["leg-press", "step-up"]),
                ("leg-curl", ["romanian-deadlift"]),
                ("cable-kickback", ["dumbbell-donkey-kick", "band-glute-kickback", "quadruped-hip-extension", "glute-focused-step-up"]),
                ("smith-hip-thrust", ["hip-thrust", "dumbbell-hip-thrust"]),
                ("smith-squat", ["hack-squat", "leg-press"]),
                ("plank", ["dead-bug", "russian-twist"]),
                ("dead-bug", ["plank", "russian-twist"]),
                ("russian-twist", ["dead-bug", "cable-crunch"]),
                ("cable-crunch", ["russian-twist", "dead-bug"]),
                ("hanging-leg-raise", ["plank", "dead-bug"]),
                ("kettlebell-swing", ["clean-and-press"]),
                ("clean-and-press", ["kettlebell-swing"]),
                ("farmer-carry", ["walking-lunge"]),
                ("tricep-extension", ["overhead-tricep-extension", "rope-tricep-extension", "machine-tricep-extension"]),
            ],
            merge: { left, right in
                var merged = left
                for item in right where !merged.contains(item) {
                    merged.append(item)
                }
                return merged
            }
        )
    }

    static func equipmentInWorkout(_ workout: Workout) -> Set<GymEquipmentOption> {
        let equipmentNames = Set(
            workout.exercises.compactMap { ExerciseCatalog.exercise(id: $0.exerciseId)?.equipment.rawValue }
        )

        return Set(GymEquipmentOption.allCases.filter { equipmentNames.contains($0.rawValue) })
    }

    static func proposeRefresh(
        for workout: Workout,
        mode: WorkoutRefreshMode
    ) -> [WorkoutAdaptationProposal] {
        switch mode {
        case .sameEquipment:
            return proposeSameEquipmentRefresh(for: workout)
        case .customEquipment(let equipment):
            var kinds = Set<GymEquipmentKind>()
            for option in equipment {
                kinds.formUnion(option.expandedKinds)
            }
            return proposeEquipmentAdaptation(for: workout, availableEquipment: kinds)
        case .detailedEquipment(let kinds):
            return proposeEquipmentAdaptation(for: workout, availableEquipment: kinds)
        }
    }

    static func proposeAdaptations(
        for workout: Workout,
        availableEquipment: Set<GymEquipmentOption>
    ) -> [WorkoutAdaptationProposal] {
        var kinds = Set<GymEquipmentKind>()
        for option in availableEquipment {
            kinds.formUnion(option.expandedKinds)
        }
        return proposeEquipmentAdaptation(for: workout, availableEquipment: kinds)
    }

    static func proposeAdaptations(
        for workout: Workout,
        availableKinds: Set<GymEquipmentKind>
    ) -> [WorkoutAdaptationProposal] {
        proposeEquipmentAdaptation(for: workout, availableEquipment: availableKinds)
    }

    static func buildRefreshedWorkout(
        from workout: Workout,
        proposals: [WorkoutAdaptationProposal],
        mode: WorkoutRefreshMode
    ) -> Workout {
        let suffix: String
        switch mode {
        case .sameEquipment:
            suffix = " (Refreshed)"
        case .customEquipment, .detailedEquipment:
            suffix = " (Adapted)"
        }

        let exercises = proposals.enumerated().map { index, proposal in
            WorkoutExerciseEntry(
                exerciseId: proposal.proposedExerciseId,
                sets: proposal.sets,
                reps: proposal.reps,
                startingWeight: proposal.startingWeight,
                order: index
            )
        }

        return Workout(
            name: "\(workout.name)\(suffix)",
            exercises: exercises
        )
    }

    static func buildAdaptedWorkout(
        from workout: Workout,
        proposals: [WorkoutAdaptationProposal]
    ) -> Workout {
        buildRefreshedWorkout(from: workout, proposals: proposals, mode: .customEquipment([]))
    }

    static func proposeSingleReplacement(
        for entry: WorkoutExerciseEntry,
        in workout: Workout
    ) -> WorkoutAdaptationProposal? {
        guard let original = ExerciseCatalog.exercise(id: entry.exerciseId) else { return nil }

        let usedIds = Set(workout.exercises.map(\.exerciseId)).subtracting([original.id])
        let replacement = sameEquipmentReplacement(for: original, excluding: usedIds) ?? original

        return WorkoutAdaptationProposal(
            originalExerciseId: original.id,
            originalName: original.name,
            proposedExerciseId: replacement.id,
            proposedName: replacement.name,
            proposedEquipment: replacement.equipment.label,
            sets: entry.sets,
            reps: entry.reps,
            startingWeight: entry.startingWeight,
            isVarietySwap: replacement.id != original.id
        )
    }

    // MARK: - Same equipment refresh

    private static func proposeSameEquipmentRefresh(for workout: Workout) -> [WorkoutAdaptationProposal] {
        let sortedEntries = workout.exercises.sorted { $0.order < $1.order }
        var usedExerciseIds = Set(sortedEntries.map(\.exerciseId))

        return sortedEntries.compactMap { entry in
            guard let original = ExerciseCatalog.exercise(id: entry.exerciseId) else { return nil }

            let replacement = sameEquipmentReplacement(
                for: original,
                excluding: usedExerciseIds
            )

            let proposed = replacement ?? original
            usedExerciseIds.insert(proposed.id)

            return WorkoutAdaptationProposal(
                originalExerciseId: original.id,
                originalName: original.name,
                proposedExerciseId: proposed.id,
                proposedName: proposed.name,
                proposedEquipment: proposed.equipment.label,
                sets: entry.sets,
                reps: entry.reps,
                startingWeight: entry.startingWeight,
                isVarietySwap: proposed.id != original.id
            )
        }
    }

    private static func sameEquipmentReplacement(
        for exercise: Exercise,
        excluding usedIds: Set<String>
    ) -> Exercise? {
        if let curated = sameEquipmentVariety[exercise.id] {
            let curatedMatches = curated
                .compactMap { ExerciseCatalog.exercise(id: $0) }
                .filter {
                    $0.equipment == exercise.equipment
                        && !usedIds.contains($0.id)
                        && $0.id != exercise.id
                }
            if let pick = curatedMatches.randomElement() {
                return pick
            }
        }

        let muscleMatches = ExerciseCatalog.all.filter {
            $0.primaryMuscleGroup == exercise.primaryMuscleGroup
                && $0.equipment == exercise.equipment
                && $0.id != exercise.id
                && !usedIds.contains($0.id)
        }
        if let pick = muscleMatches.randomElement() {
            return pick
        }

        let relatedMuscles = relatedMuscleGroups(for: exercise.primaryMuscleGroup)
        let relatedMatches = ExerciseCatalog.all.filter {
            relatedMuscles.contains($0.primaryMuscleGroup)
                && $0.equipment == exercise.equipment
                && $0.id != exercise.id
                && !usedIds.contains($0.id)
        }
        return relatedMatches.randomElement()
    }

    // MARK: - Equipment change adaptation

    private static func proposeEquipmentAdaptation(
        for workout: Workout,
        availableEquipment: Set<GymEquipmentKind>
    ) -> [WorkoutAdaptationProposal] {
        let sortedEntries = workout.exercises.sorted { $0.order < $1.order }
        var usedExerciseIds = Set<String>()

        return sortedEntries.compactMap { entry in
            guard let original = ExerciseCatalog.exercise(id: entry.exerciseId) else { return nil }

            let proposed: Exercise
            let isSwap: Bool

            if original.isCompatible(with: availableEquipment) {
                let variety = sameEquipmentReplacement(for: original, excluding: usedExerciseIds.union([original.id]))
                if let variety, variety.id != original.id, variety.isCompatible(with: availableEquipment) {
                    proposed = variety
                    isSwap = true
                } else {
                    proposed = original
                    isSwap = false
                }
            } else if let replacement = bestReplacement(
                for: original,
                availableEquipment: availableEquipment,
                excluding: usedExerciseIds
            ) {
                proposed = replacement
                isSwap = true
            } else {
                return nil
            }

            usedExerciseIds.insert(proposed.id)

            // Preserve progression weight only when keeping the same exercise.
            let weight = proposed.id == original.id ? entry.startingWeight : 0

            return WorkoutAdaptationProposal(
                originalExerciseId: original.id,
                originalName: original.name,
                proposedExerciseId: proposed.id,
                proposedName: proposed.name,
                proposedEquipment: proposed.equipment.label,
                sets: entry.sets,
                reps: entry.reps,
                startingWeight: weight,
                isVarietySwap: isSwap
            )
        }
    }

    private static func bestReplacement(
        for exercise: Exercise,
        availableEquipment: Set<GymEquipmentKind>,
        excluding: Set<String>
    ) -> Exercise? {
        let alternatives = ExerciseCatalog.compatibleAlternatives(
            for: exercise,
            availableEquipment: availableEquipment,
            excluding: excluding
        )
        if let first = alternatives.first {
            return first
        }

        // Legacy coarse swap map keyed by EquipmentType.rawValue.
        let coarse = Set(
            availableEquipment.compactMap(\.equipmentType).map(\.rawValue)
        )
        if let mapped = swapMap[exercise.id] {
            for equipmentName in coarse {
                if let candidateId = mapped[equipmentName],
                   let candidate = ExerciseCatalog.exercise(id: candidateId),
                   candidate.isCompatible(with: availableEquipment),
                   !excluding.contains(candidate.id) {
                    return candidate
                }
            }
        }

        return ExerciseCatalog.all.first {
            $0.primaryMuscleGroup == exercise.primaryMuscleGroup
                && $0.isCompatible(with: availableEquipment)
                && $0.id != exercise.id
                && !excluding.contains($0.id)
        }
    }

    private static func replacementExerciseId(
        for exercise: Exercise,
        availableEquipment: Set<String>
    ) -> String? {
        if let mapped = swapMap[exercise.id] {
            for equipment in availableEquipment {
                if let candidate = mapped[equipment] {
                    return candidate
                }
            }
        }

        return ExerciseCatalog.all.first {
            $0.primaryMuscleGroup == exercise.primaryMuscleGroup
                && availableEquipment.contains($0.equipment.rawValue)
                && $0.id != exercise.id
        }?.id
    }

    private static func relatedMuscleGroups(for muscle: MuscleGroup) -> Set<MuscleGroup> {
        switch muscle {
        case .glutes: return [.glutes, .hamstrings, .quads]
        case .hamstrings: return [.hamstrings, .glutes, .quads]
        case .quads: return [.quads, .glutes, .hamstrings]
        case .chest: return [.chest, .shoulders]
        case .back: return [.back, .shoulders]
        case .shoulders: return [.shoulders, .back, .chest]
        case .biceps: return [.biceps, .triceps]
        case .triceps: return [.triceps, .biceps, .chest]
        case .core: return [.core, .fullBody]
        case .fullBody: return [.fullBody, .core, .quads]
        case .calves: return [.calves, .quads]
        }
    }
}
