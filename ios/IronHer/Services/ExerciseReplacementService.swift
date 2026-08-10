import Foundation

/// Ranks substitute exercises for a single swap. Logic stays out of SwiftUI views.
struct ExerciseReplacementService {
    /// Reps at/above this prefer harder variations over adding more reps.
    static let highRepThreshold = 20

    func recommendations(
        for exercise: Exercise,
        reason: ExerciseReplacementReason,
        from allExercises: [Exercise],
        currentReps: Int = 10,
        unavailableEquipment: Set<GymEquipmentKind> = [],
        availableEquipment: Set<GymEquipmentKind>? = nil
    ) -> [ExerciseRecommendation] {
        let candidates = allExercises.filter { $0.id != exercise.id }
        var scored: [ExerciseRecommendation] = []
        var seen = Set<String>()

        for candidate in candidates {
            guard let result = score(
                candidate: candidate,
                original: exercise,
                reason: reason,
                currentReps: currentReps,
                unavailableEquipment: unavailableEquipment,
                availableEquipment: availableEquipment
            ) else { continue }
            scored.append(result)
            seen.insert(result.exercise.id)
        }

        // Always surface same-muscle options when ranking found nothing usable.
        if scored.isEmpty || scored.allSatisfy(\.isBroaderAlternative) {
            for candidate in candidates where !seen.contains(candidate.id) {
                guard candidate.primaryMuscleGroup == exercise.primaryMuscleGroup
                    || candidate.secondaryMuscleGroups.contains(exercise.primaryMuscleGroup)
                    || exercise.secondaryMuscleGroups.contains(candidate.primaryMuscleGroup)
                    || candidate.category == exercise.category
                else { continue }

                if let availableEquipment, !candidate.isCompatible(with: availableEquipment) {
                    continue
                }

                scored.append(
                    ExerciseRecommendation(
                        exercise: candidate,
                        suitabilityReason: "Broader alternative — same primary muscle group (\(candidate.primaryMuscleGroup.label)).",
                        score: candidate.primaryMuscleGroup == exercise.primaryMuscleGroup ? 35 : 20,
                        isBroaderAlternative: true
                    )
                )
                seen.insert(candidate.id)
            }
        }

        if reason == .cannotIncreaseWeight {
            // Prefer harder / unilateral / intensity variations at the top.
            scored.sort { lhs, rhs in
                let lBoost = harderPriorityBoost(for: lhs.exercise, original: exercise)
                let rBoost = harderPriorityBoost(for: rhs.exercise, original: exercise)
                if lBoost != rBoost { return lBoost > rBoost }
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.exercise.name.localizedCaseInsensitiveCompare(rhs.exercise.name) == .orderedAscending
            }
        } else {
            scored.sort { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.exercise.name.localizedCaseInsensitiveCompare(rhs.exercise.name) == .orderedAscending
            }
        }

        return scored
    }

    private func harderPriorityBoost(for candidate: Exercise, original: Exercise) -> Int {
        let mods = Self.inferredModifiers(for: candidate)
        var boost = 0
        if candidate.movementFamily == original.movementFamily, original.movementFamily != .other {
            boost += 40
        }
        if Self.sharesNormalizedNameFamily(candidate, original) {
            boost += 36
        }
        if candidate.laterality == .unilateral || mods.contains(.unilateral) {
            boost += 30
        }
        if mods.contains(.paused) { boost += 24 }
        if mods.contains(.tempo) { boost += 22 }
        if mods.contains(.extendedRangeOfMotion) { boost += 18 }
        if candidate.primaryMuscleGroup == original.primaryMuscleGroup {
            boost += 10
        }
        return boost
    }

    /// Name-based family match when `movementFamily` is missing / `.other`.
    static func sharesNormalizedNameFamily(_ a: Exercise, _ b: Exercise) -> Bool {
        let left = normalizedBaseName(a)
        let right = normalizedBaseName(b)
        guard !left.isEmpty, !right.isEmpty else { return false }
        return left == right || left.contains(right) || right.contains(left)
    }

    private static func normalizedBaseName(_ exercise: Exercise) -> String {
        var name = (exercise.name + " " + exercise.id)
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
        let junk = [
            "barbell", "dumbbell", "smith", "machine", "cable", "kettlebell",
            "single leg", "single-leg", "one leg", "b stance", "b-stance",
            "paused", "pause", "tempo", "slow", "deficit", "elevated",
            "(", ")",
        ]
        for token in junk {
            name = name.replacingOccurrences(of: token, with: " ")
        }
        return name
            .split(separator: " ")
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Harder-path methods for “Cannot increase the weight”.
    func harderMethods(
        for exercise: Exercise,
        currentReps: Int,
        from allExercises: [Exercise]
    ) -> [(method: ExerciseHarderMethod, recommendation: ExerciseRecommendation?)] {
        var results: [(ExerciseHarderMethod, ExerciseRecommendation?)] = []

        let unilateral = bestVariation(
            of: exercise,
            from: allExercises,
            prefer: { $0.laterality == .unilateral || Self.inferredModifiers(for: $0).contains(.unilateral) },
            reason: "Targets the same muscles using one leg or one side."
        )
        results.append((.unilateralVariation, unilateral))

        let paused = bestVariation(
            of: exercise,
            from: allExercises,
            prefer: { Self.inferredModifiers(for: $0).contains(.paused) || $0.name.localizedCaseInsensitiveContains("pause") },
            reason: "Same movement pattern with a pause — harder with limited weight."
        )
        results.append((.addPause, paused))

        let tempo = bestVariation(
            of: exercise,
            from: allExercises,
            prefer: {
                Self.inferredModifiers(for: $0).contains(.tempo)
                    || $0.name.localizedCaseInsensitiveContains("tempo")
                    || $0.name.localizedCaseInsensitiveContains("slow")
            },
            reason: "Same movement pattern, harder with limited weight."
        )
        results.append((.slowerTempo, tempo))

        let rom = bestVariation(
            of: exercise,
            from: allExercises,
            prefer: {
                Self.inferredModifiers(for: $0).contains(.extendedRangeOfMotion)
                    || $0.name.localizedCaseInsensitiveContains("deficit")
                    || $0.name.localizedCaseInsensitiveContains("deep")
            },
            reason: "Similar movement with greater range of motion."
        )
        results.append((.increaseRangeOfMotion, rom))

        if currentReps < Self.highRepThreshold {
            results.append((.increaseReps, nil))
        }

        return results
    }

    /// Builds a plan prescription for a replacement without copying incompatible load blindly.
    func prescription(
        replacing originalEntry: WorkoutExerciseEntry,
        with newExercise: Exercise,
        globalWeightKg: Double?,
        globalReps: Int?,
        globalSets: Int?,
        globalDuration: Int?,
        globalDistance: Double?
    ) -> WorkoutExerciseEntry {
        let sets = globalSets ?? originalEntry.sets
        let reps: Int
        let weight: Double
        let duration: Int
        let distance: Double

        switch newExercise.measurementUnit {
        case .weight, .weightAndTime, .repsWithOptionalWeight:
            weight = globalWeightKg ?? 0
            reps = globalReps ?? max(1, originalEntry.reps)
            duration = newExercise.measurementUnit == .weightAndTime
                ? (globalDuration ?? max(originalEntry.durationSeconds, 20))
                : 0
            distance = 0
        case .bodyweight, .reps:
            weight = 0
            reps = globalReps ?? max(1, originalEntry.reps)
            duration = 0
            distance = 0
        case .time:
            weight = 0
            reps = 0
            duration = globalDuration ?? max(originalEntry.durationSeconds, 30)
            distance = 0
        case .distance:
            weight = 0
            reps = 0
            duration = 0
            distance = globalDistance ?? max(originalEntry.distanceMeters, 100)
        }

        return WorkoutExerciseEntry(
            id: originalEntry.id,
            exerciseId: newExercise.id,
            sets: max(1, sets),
            reps: reps,
            startingWeight: weight,
            durationSeconds: duration,
            distanceMeters: distance,
            order: originalEntry.order,
            restDurationOverride: originalEntry.restDurationOverride
        )
    }

    // MARK: - Scoring

    private func score(
        candidate: Exercise,
        original: Exercise,
        reason: ExerciseReplacementReason,
        currentReps: Int,
        unavailableEquipment: Set<GymEquipmentKind>,
        availableEquipment: Set<GymEquipmentKind>?
    ) -> ExerciseRecommendation? {
        if let availableEquipment, !candidate.isCompatible(with: availableEquipment) {
            return nil
        }

        // Equipment unavailable: treat explicit blocked kit, else the original's required kit.
        if reason == .equipmentUnavailable {
            let blocked: Set<GymEquipmentKind> = unavailableEquipment.isEmpty
                ? Set(original.requiredEquipment.isEmpty
                    ? original.equipment.defaultRequiredEquipment
                    : original.requiredEquipment)
                : unavailableEquipment
            let required = Set(candidate.requiredEquipment.isEmpty
                ? candidate.equipment.defaultRequiredEquipment
                : candidate.requiredEquipment)
            if !blocked.isEmpty, !required.isDisjoint(with: blocked) {
                return nil
            }
        }

        var score = 0
        var reasons: [String] = []
        var isBroader = false

        if candidate.primaryMuscleGroup == original.primaryMuscleGroup {
            score += 40
            reasons.append("same primary muscle")
        } else if original.secondaryMuscleGroups.contains(candidate.primaryMuscleGroup)
            || candidate.secondaryMuscleGroups.contains(original.primaryMuscleGroup)
        {
            score += 12
            reasons.append("related muscle focus")
        } else {
            return nil
        }

        if candidate.movementPattern == original.movementPattern {
            score += 30
            reasons.append("same movement pattern")
        } else if patternsAreRelated(candidate.movementPattern, original.movementPattern) {
            score += 14
            reasons.append("similar movement pattern")
        }

        if candidate.category == original.category {
            score += 12
        }

        if candidate.movementFamily != .other, candidate.movementFamily == original.movementFamily {
            score += 22
            reasons.append("same movement family")
        } else if Self.sharesNormalizedNameFamily(candidate, original) {
            score += 18
            reasons.append("same movement family")
        }

        if original.suggestedAlternatives.contains(candidate.id) {
            score += 18
            reasons.append("curated alternative")
        }

        let candidateMods = Self.inferredModifiers(for: candidate)
        let originalMods = Self.inferredModifiers(for: original)

        switch reason {
        case .equipmentUnavailable:
            if candidate.equipment != original.equipment {
                score += 20
                reasons.append("different equipment")
            } else {
                score -= 8
            }
            if Set(candidate.requiredEquipment).isDisjoint(with: Set(original.requiredEquipment)) {
                score += 10
            }

        case .cannotIncreaseWeight:
            if candidate.laterality == .unilateral || candidateMods.contains(.unilateral) {
                score += 28
                reasons.append("unilateral variation")
            }
            if candidateMods.contains(.paused) {
                score += 22
                reasons.append("paused variation")
            }
            if candidateMods.contains(.tempo) {
                score += 20
                reasons.append("tempo variation")
            }
            if candidateMods.contains(.extendedRangeOfMotion) {
                score += 16
                reasons.append("greater range of motion")
            }
            if candidate.movementFamily == original.movementFamily {
                score += 10
            }
            // Prefer not needing more external load.
            if candidate.equipment == .bodyweight || candidate.measurementUnit == .bodyweight || candidate.measurementUnit == .reps {
                score += 8
            }
            _ = currentReps

        case .discomfort:
            if candidate.equipment != original.equipment {
                score += 14
                reasons.append("different equipment")
            }
            if candidate.laterality != original.laterality {
                score += 8
            }
            // Slightly prefer machine / supported variations when available.
            if candidate.equipment == .machine {
                score += 6
            }

        case .variety:
            if candidate.equipment != original.equipment {
                score += 8
            }
            if candidate.id != original.id {
                score += 4
            }
            // Prefer not an exact difficulty clone of the original.
            if candidateMods != originalMods {
                score += 4
            }

        case .other:
            break
        }

        // Strong match threshold — otherwise mark as broader muscle-only alternative.
        let strong = score >= 55
            || (candidate.movementPattern == original.movementPattern && candidate.primaryMuscleGroup == original.primaryMuscleGroup)
            || (candidate.movementFamily == original.movementFamily && candidate.movementFamily != .other)
            || Self.sharesNormalizedNameFamily(candidate, original)
            || original.suggestedAlternatives.contains(candidate.id)
            || (reason == .cannotIncreaseWeight && (
                candidate.laterality == .unilateral
                    || Self.inferredModifiers(for: candidate).contains(.unilateral)
                    || Self.inferredModifiers(for: candidate).contains(.paused)
                    || Self.inferredModifiers(for: candidate).contains(.tempo)
            ))

        if !strong {
            guard candidate.primaryMuscleGroup == original.primaryMuscleGroup else { return nil }
            isBroader = true
            score = min(score, 45)
        }

        let suitability = suitabilityCopy(
            reasons: reasons,
            original: original,
            candidate: candidate,
            reason: reason,
            isBroader: isBroader
        )

        return ExerciseRecommendation(
            exercise: candidate,
            suitabilityReason: suitability,
            score: score,
            isBroaderAlternative: isBroader
        )
    }

    private func suitabilityCopy(
        reasons: [String],
        original: Exercise,
        candidate: Exercise,
        reason: ExerciseReplacementReason,
        isBroader: Bool
    ) -> String {
        if isBroader {
            return "Broader alternative — same primary muscle group (\(candidate.primaryMuscleGroup.label))."
        }

        if reason == .cannotIncreaseWeight {
            if candidate.laterality == .unilateral || Self.inferredModifiers(for: candidate).contains(.unilateral) {
                return "Targets the same muscles using one side — harder with limited weight."
            }
            if Self.inferredModifiers(for: candidate).contains(.paused)
                || Self.inferredModifiers(for: candidate).contains(.tempo)
            {
                return "Same movement pattern, harder with limited weight."
            }
            if candidate.primaryMuscleGroup == .glutes {
                return "Similar glute-focused movement with different stimulus."
            }
        }

        if reason == .equipmentUnavailable, candidate.equipment != original.equipment {
            return "Similar \(original.primaryMuscleGroup.label.lowercased())-focused movement with different equipment."
        }

        if reasons.contains("same movement family") || reasons.contains("same movement pattern") {
            return "Same movement pattern — preserves training intent."
        }

        if reasons.contains("curated alternative") {
            return "Suggested alternative for this exercise."
        }

        return "Targets the same primary muscles (\(candidate.primaryMuscleGroup.label))."
    }

    private func patternsAreRelated(_ a: MovementPattern, _ b: MovementPattern) -> Bool {
        let groups: [Set<MovementPattern>] = [
            [.squat, .lunge],
            [.hinge, .lunge],
            [.horizontalPush, .verticalPush],
            [.horizontalPull, .verticalPull],
            [.core, .isolation],
        ]
        return groups.contains { $0.contains(a) && $0.contains(b) }
    }

    private func bestVariation(
        of exercise: Exercise,
        from allExercises: [Exercise],
        prefer: (Exercise) -> Bool,
        reason: String
    ) -> ExerciseRecommendation? {
        let matches = allExercises.filter { candidate in
            guard candidate.id != exercise.id else { return false }
            guard prefer(candidate) else { return false }
            let sameFamily = candidate.movementFamily == exercise.movementFamily && exercise.movementFamily != .other
            let samePattern = candidate.movementPattern == exercise.movementPattern
                && candidate.primaryMuscleGroup == exercise.primaryMuscleGroup
            return sameFamily || samePattern
        }

        guard let best = matches.max(by: { lhs, rhs in
            let ls = (lhs.movementFamily == exercise.movementFamily ? 2 : 0)
                + (lhs.primaryMuscleGroup == exercise.primaryMuscleGroup ? 1 : 0)
            let rs = (rhs.movementFamily == exercise.movementFamily ? 2 : 0)
                + (rhs.primaryMuscleGroup == exercise.primaryMuscleGroup ? 1 : 0)
            return ls < rs
        }) else { return nil }

        return ExerciseRecommendation(
            exercise: best,
            suitabilityReason: reason,
            score: 90,
            isBroaderAlternative: false
        )
    }

    static func inferredModifiers(for exercise: Exercise) -> Set<ExerciseDifficultyModifier> {
        var mods: Set<ExerciseDifficultyModifier> = []
        let name = exercise.name.lowercased()
        let id = exercise.id.lowercased()

        if exercise.laterality == .unilateral
            || name.contains("single-leg")
            || name.contains("single leg")
            || name.contains("single-arm")
            || name.contains("one-arm")
            || name.contains("bulgarian")
            || name.contains("b-stance")
            || name.contains("b stance")
            || id.contains("single-leg")
            || id.contains("bulgarian")
        {
            mods.insert(.unilateral)
        } else if exercise.laterality == .bilateral {
            mods.insert(.bilateral)
        }

        if name.contains("pause") || name.contains("paused") || id.contains("pause") {
            mods.insert(.paused)
        }
        if name.contains("tempo") || name.contains("slow") || id.contains("tempo") {
            mods.insert(.tempo)
        }
        if name.contains("deficit") || name.contains("deep") || name.contains("full range")
            || id.contains("deficit")
        {
            mods.insert(.extendedRangeOfMotion)
        }

        if mods.isEmpty {
            mods.insert(.standard)
        }
        return mods
    }
}
