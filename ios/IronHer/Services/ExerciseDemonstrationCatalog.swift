import Foundation

/// Resolves demonstration specs from stable exercise IDs.
/// Accuracy over completeness: wrong equipment visuals are hidden, not shown.
enum ExerciseDemonstrationCatalog {
    struct Spec: Hashable {
        let motion: DemonstrationMotion
        let prop: DemonstrationProp
        let framing: DemonstrationFraming
        let camera: DemonstrationCamera
        let unilateral: Bool
        let quality: DemonstrationQuality
    }

    /// Priority + high-traffic IDs with verified teaching motions.
    private static let idOverrides: [String: Spec] = [
        // Overhead press
        "overhead-press": Spec(.barbellOverheadPress, .barbell, .standing, .front, false, .verified),
        "dumbbell-shoulder-press": Spec(.dumbbellOverheadPress, .dumbbells, .standing, .front, false, .verified),
        "machine-shoulder-press": Spec(.machineShoulderPress, .machine, .seated, .threeQuarter, false, .verified),
        "single-arm-dumbbell-overhead-press": Spec(.singleArmDumbbellPress, .singleDumbbell, .standing, .threeQuarter, true, .verified),
        "smith-overhead-press": Spec(.smithOverheadPress, .smithMachine, .standing, .threeQuarter, false, .verified),
        "arnold-press": Spec(.arnoldPress, .dumbbells, .standing, .front, false, .needsRefinement),
        "push-press": Spec(.barbellOverheadPress, .barbell, .standing, .front, false, .needsRefinement),
        "kettlebell-press": Spec(.kettlebellPress, .kettlebell, .standing, .threeQuarter, true, .needsRefinement),

        // Chest
        "barbell-bench-press": Spec(.barbellBenchPress, .barbell, .lying, .side, false, .needsRefinement),
        "dumbbell-bench-press": Spec(.dumbbellBenchPress, .dumbbells, .lying, .side, false, .verified),
        "incline-dumbbell-press": Spec(.dumbbellBenchPress, .dumbbells, .lying, .side, false, .needsRefinement),
        "dumbbell-fly": Spec(.chestFlyDumbbell, .dumbbells, .lying, .side, false, .verified),
        "incline-dumbbell-fly": Spec(.chestFlyDumbbell, .dumbbells, .lying, .side, false, .needsRefinement),
        "cable-fly": Spec(.chestFlyCable, .cable, .standing, .front, false, .needsRefinement),
        "chest-press-machine": Spec(.machineChestPress, .machine, .seated, .threeQuarter, false, .needsRefinement),
        "push-up": Spec(.pushUp, .none, .plank, .side, false, .verified),

        // Pull
        "pull-up": Spec(.pullUp, .bodyweightBar, .standing, .front, false, .verified),
        "lat-pulldown": Spec(.latPulldown, .cable, .seated, .threeQuarter, false, .verified),
        "one-arm-dumbbell-row": Spec(.oneArmDumbbellRow, .singleDumbbell, .hinged, .side, true, .verified),
        "vertical-row": Spec(.verticalRow, .machine, .seated, .threeQuarter, false, .verified),
        "barbell-row": Spec(.barbellRow, .barbell, .hinged, .side, false, .needsRefinement),
        "seated-cable-row": Spec(.seatedCableRow, .cable, .seated, .side, false, .needsRefinement),
        "face-pull": Spec(.facePull, .rope, .standing, .threeQuarter, false, .needsRefinement),

        // Triceps
        "overhead-tricep-extension": Spec(.overheadTricepTwoHand, .singleDumbbell, .standing, .threeQuarter, false, .verified),
        "single-arm-dumbbell-tricep-extension": Spec(.singleArmTricepExtension, .singleDumbbell, .standing, .threeQuarter, true, .verified),
        "dumbbell-skull-crusher": Spec(.skullCrusherDumbbell, .dumbbells, .lying, .side, false, .verified),
        "skull-crusher": Spec(.skullCrusherBarbell, .barbell, .lying, .side, false, .verified),
        "ez-bar-skull-crusher": Spec(.skullCrusherEZ, .ezBar, .lying, .side, false, .verified),
        "cable-skull-crusher": Spec(.skullCrusherCable, .cable, .lying, .side, false, .needsRefinement),
        "tricep-extension": Spec(.overheadTricepCable, .cable, .standing, .threeQuarter, false, .verified),
        "cable-overhead-extension": Spec(.overheadTricepCable, .cable, .standing, .threeQuarter, false, .verified),
        "tricep-pushdown": Spec(.tricepPushdown, .cable, .standing, .side, false, .verified),
        "rope-pushdown": Spec(.ropePushdown, .rope, .standing, .side, false, .verified),
        "machine-tricep-extension": Spec(.machineTricepExtension, .machine, .seated, .threeQuarter, false, .needsRefinement),
        "dumbbell-tricep-kickback": Spec(.tricepKickback, .singleDumbbell, .hinged, .side, true, .needsRefinement),

        // Arms / shoulders
        "dumbbell-curl": Spec(.dumbbellCurl, .dumbbells, .standing, .front, false, .verified),
        "hammer-curl": Spec(.hammerCurl, .dumbbells, .standing, .front, false, .verified),
        "barbell-curl": Spec(.barbellCurl, .barbell, .standing, .side, false, .needsRefinement),
        "lateral-raise": Spec(.lateralRaise, .dumbbells, .standing, .front, false, .verified),

        // Lower
        "romanian-deadlift": Spec(.romanianDeadlift, .barbell, .hinged, .side, false, .verified),
        "dumbbell-rdl": Spec(.romanianDeadlift, .dumbbells, .hinged, .side, false, .verified),
        "single-leg-rdl": Spec(.singleLegRDL, .singleDumbbell, .hinged, .side, true, .verified),
        "goblet-squat": Spec(.gobletSquat, .singleDumbbell, .standing, .side, false, .verified),
        "barbell-back-squat": Spec(.backSquat, .barbell, .standing, .side, false, .needsRefinement),
        "bulgarian-split-squat": Spec(.bulgarianSplitSquat, .dumbbells, .standing, .side, true, .verified),
        "forward-lunge": Spec(.forwardLunge, .dumbbells, .standing, .side, true, .verified),
        "reverse-lunge": Spec(.reverseLunge, .dumbbells, .standing, .side, true, .verified),
        "walking-lunge": Spec(.walkingLunge, .dumbbells, .standing, .side, true, .verified),
        "step-up": Spec(.stepUp, .dumbbells, .standing, .side, true, .verified),
        "single-leg-glute-bridge": Spec(.singleLegGluteBridge, .none, .lying, .side, true, .verified),
        "glute-bridge": Spec(.hipThrust, .none, .lying, .side, false, .needsRefinement),
        "hip-thrust": Spec(.hipThrust, .barbell, .lying, .side, false, .needsRefinement),
        "leg-press": Spec(.legPress, .machine, .seated, .side, false, .needsRefinement),
        "conventional-deadlift": Spec(.conventionalDeadlift, .barbell, .hinged, .side, false, .needsRefinement),

        // Core / carry
        "plank": Spec(.plank, .none, .plank, .side, false, .verified),
        "side-plank": Spec(.sidePlank, .none, .sidePlank, .front, true, .verified),
        "farmer-carry": Spec(.farmerCarry, .dumbbells, .standing, .threeQuarter, false, .verified),
    ]

    private static let priorityIDs: Set<String> = Set(idOverrides.keys)

    static func demonstration(for exercise: Exercise) -> ExerciseDemonstration {
        let spec = resolve(exercise)
        return ExerciseDemonstration(
            exerciseId: exercise.id,
            demonstrationAsset: "demo-\(exercise.id)",
            demonstrationType: .video,
            thumbnailAsset: "thumb-\(exercise.id)",
            motion: spec.motion,
            prop: spec.prop,
            framing: spec.framing,
            camera: spec.camera,
            unilateral: spec.unilateral,
            quality: spec.quality
        )
    }

    static func demonstration(for exerciseId: String) -> ExerciseDemonstration {
        if let exercise = ExerciseCatalog.builtInExercise(id: exerciseId) {
            return demonstration(for: exercise)
        }
        return .none(exerciseId: exerciseId)
    }

    static func demonstration(forCustom exercise: Exercise) -> ExerciseDemonstration {
        let spec = resolveFromPattern(exercise)
        return ExerciseDemonstration(
            exerciseId: exercise.id,
            demonstrationAsset: nil,
            demonstrationType: .none,
            thumbnailAsset: nil,
            motion: spec.motion,
            prop: spec.prop,
            framing: spec.framing,
            camera: spec.camera,
            unilateral: spec.unilateral,
            quality: .needsRefinement
        )
    }

    static func missingBundledVideoAssets(in exercises: [Exercise] = ExerciseDatabase.all) -> [String] {
        exercises.map(\.id).filter { !demonstration(for: $0).hasBundledMedia }.sorted()
    }

    /// Development audit of procedural demonstration quality.
    static func auditReport(in exercises: [Exercise] = ExerciseDatabase.all) -> DemonstrationAuditReport {
        var verified: [String] = []
        var needsRefinement: [String] = []
        var hidden: [String] = []
        var mismatches: [String] = []

        for exercise in exercises {
            let demo = demonstration(for: exercise)
            switch demo.quality {
            case .verified: verified.append(exercise.id)
            case .needsRefinement: needsRefinement.append(exercise.id)
            case .hiddenUntilCorrected: hidden.append(exercise.id)
            }
            if !propMatchesEquipment(demo.prop, exercise: exercise) {
                mismatches.append(
                    "\(exercise.id): prop \(demo.prop.rawValue) vs equipment \(exercise.equipment.label)"
                )
            }
        }

        return DemonstrationAuditReport(
            verifiedIDs: verified.sorted(),
            needsRefinementIDs: needsRefinement.sorted(),
            hiddenIDs: hidden.sorted(),
            equipmentMismatches: mismatches.sorted(),
            priorityMissingVerification: priorityIDs
                .subtracting(verified)
                .sorted()
        )
    }

    // MARK: - Resolution

    private static func resolve(_ exercise: Exercise) -> Spec {
        if let override = idOverrides[exercise.id] {
            return override
        }
        var spec = resolveFromPattern(exercise)
        // Non-priority derived demos stay hidden unless clearly safe generics.
        if spec.quality == .verified {
            spec = Spec(
                motion: spec.motion,
                prop: spec.prop,
                framing: spec.framing,
                camera: spec.camera,
                unilateral: spec.unilateral,
                quality: .needsRefinement
            )
        }
        return spec
    }

    private static func resolveFromPattern(_ exercise: Exercise) -> Spec {
        let unilateral = exercise.laterality != .bilateral
        let prop = defaultProp(for: exercise, unilateral: unilateral)

        switch exercise.movementFamily {
        case .overheadPress:
            switch exercise.equipment {
            case .barbell:
                return Spec(.barbellOverheadPress, .barbell, .standing, .front, unilateral, .needsRefinement)
            case .dumbbell:
                return unilateral
                    ? Spec(.singleArmDumbbellPress, .singleDumbbell, .standing, .threeQuarter, true, .needsRefinement)
                    : Spec(.dumbbellOverheadPress, .dumbbells, .standing, .front, false, .needsRefinement)
            case .machine:
                return Spec(.machineShoulderPress, .machine, .seated, .threeQuarter, false, .needsRefinement)
            case .kettlebell:
                return Spec(.kettlebellPress, .kettlebell, .standing, .threeQuarter, true, .needsRefinement)
            default:
                return Spec(.genericStanding, prop, .standing, .front, unilateral, .hiddenUntilCorrected)
            }
        case .benchPress, .inclinePress, .declinePress:
            switch exercise.equipment {
            case .barbell: return Spec(.barbellBenchPress, .barbell, .lying, .side, false, .needsRefinement)
            case .dumbbell: return Spec(.dumbbellBenchPress, .dumbbells, .lying, .side, false, .needsRefinement)
            case .machine: return Spec(.machineChestPress, .machine, .seated, .threeQuarter, false, .needsRefinement)
            case .bodyweight: return Spec(.pushUp, .none, .plank, .side, false, .needsRefinement)
            default: return Spec(.genericLying, prop, .lying, .side, false, .hiddenUntilCorrected)
            }
        case .chestFly:
            return exercise.equipment == .cable
                ? Spec(.chestFlyCable, .cable, .standing, .front, false, .needsRefinement)
                : Spec(.chestFlyDumbbell, .dumbbells, .lying, .side, false, .needsRefinement)
        case .row:
            switch exercise.equipment {
            case .dumbbell: return Spec(.oneArmDumbbellRow, .singleDumbbell, .hinged, .side, true, .needsRefinement)
            case .barbell: return Spec(.barbellRow, .barbell, .hinged, .side, unilateral, .needsRefinement)
            case .cable: return Spec(.seatedCableRow, .cable, .seated, .side, unilateral, .needsRefinement)
            case .machine: return Spec(.verticalRow, .machine, .seated, .threeQuarter, false, .needsRefinement)
            default: return Spec(.genericStanding, prop, .hinged, .side, unilateral, .hiddenUntilCorrected)
            }
        case .pulldown:
            return Spec(.latPulldown, .cable, .seated, .threeQuarter, false, .needsRefinement)
        case .pullUp:
            return Spec(.pullUp, .bodyweightBar, .standing, .front, false, .needsRefinement)
        case .skullCrusher:
            switch exercise.equipment {
            case .dumbbell: return Spec(.skullCrusherDumbbell, .dumbbells, .lying, .side, false, .needsRefinement)
            case .cable: return Spec(.skullCrusherCable, .cable, .lying, .side, false, .needsRefinement)
            case .barbell:
                return exercise.id.contains("ez")
                    ? Spec(.skullCrusherEZ, .ezBar, .lying, .side, false, .needsRefinement)
                    : Spec(.skullCrusherBarbell, .barbell, .lying, .side, false, .needsRefinement)
            default: return Spec(.genericLying, prop, .lying, .side, false, .hiddenUntilCorrected)
            }
        case .tricepExtension:
            switch exercise.equipment {
            case .machine: return Spec(.machineTricepExtension, .machine, .seated, .threeQuarter, false, .needsRefinement)
            case .cable: return Spec(.overheadTricepCable, .cable, .standing, .threeQuarter, unilateral, .needsRefinement)
            case .dumbbell:
                return unilateral
                    ? Spec(.singleArmTricepExtension, .singleDumbbell, .standing, .threeQuarter, true, .needsRefinement)
                    : Spec(.overheadTricepTwoHand, .singleDumbbell, .standing, .threeQuarter, false, .needsRefinement)
            default: return Spec(.genericStanding, prop, .standing, .front, unilateral, .hiddenUntilCorrected)
            }
        case .tricepPushdown:
            return exercise.id.contains("rope")
                ? Spec(.ropePushdown, .rope, .standing, .side, false, .needsRefinement)
                : Spec(.tricepPushdown, .cable, .standing, .side, false, .needsRefinement)
        case .bicepCurl:
            switch exercise.equipment {
            case .barbell: return Spec(.barbellCurl, .barbell, .standing, .side, false, .needsRefinement)
            case .dumbbell:
                return exercise.id.contains("hammer")
                    ? Spec(.hammerCurl, .dumbbells, .standing, .front, false, .needsRefinement)
                    : Spec(.dumbbellCurl, .dumbbells, .standing, .front, false, .needsRefinement)
            default: return Spec(.genericStanding, prop, .standing, .front, unilateral, .hiddenUntilCorrected)
            }
        case .lateralRaise:
            return Spec(.lateralRaise, .dumbbells, .standing, .front, false, .needsRefinement)
        case .squat:
            switch exercise.equipment {
            case .dumbbell: return Spec(.gobletSquat, .singleDumbbell, .standing, .side, false, .needsRefinement)
            case .machine: return Spec(.legPress, .machine, .seated, .side, false, .needsRefinement)
            default: return Spec(.backSquat, .barbell, .standing, .side, false, .needsRefinement)
            }
        case .hinge:
            if exercise.id.contains("single-leg") {
                return Spec(.singleLegRDL, .singleDumbbell, .hinged, .side, true, .needsRefinement)
            }
            return Spec(.romanianDeadlift, prop, .hinged, .side, false, .needsRefinement)
        case .hipThrust:
            return Spec(.hipThrust, prop, .lying, .side, unilateral, .needsRefinement)
        case .lunge:
            if exercise.id.contains("bulgarian") {
                return Spec(.bulgarianSplitSquat, .dumbbells, .standing, .side, true, .needsRefinement)
            }
            if exercise.id.contains("step") {
                return Spec(.stepUp, .dumbbells, .standing, .side, true, .needsRefinement)
            }
            if exercise.id.contains("reverse") {
                return Spec(.reverseLunge, .dumbbells, .standing, .side, true, .needsRefinement)
            }
            return Spec(.forwardLunge, .dumbbells, .standing, .side, true, .needsRefinement)
        case .legCurl:
            return Spec(.legCurl, .machine, .lying, .side, false, .needsRefinement)
        case .legExtension:
            return Spec(.legExtension, .machine, .seated, .side, false, .needsRefinement)
        case .calfRaise:
            return Spec(.calfRaise, prop, .standing, .side, unilateral, .needsRefinement)
        case .carry:
            return Spec(.farmerCarry, .dumbbells, .standing, .threeQuarter, false, .needsRefinement)
        case .core:
            return exercise.id.contains("side")
                ? Spec(.sidePlank, .none, .sidePlank, .front, true, .needsRefinement)
                : Spec(.plank, .none, .plank, .side, false, .needsRefinement)
        case .other:
            break
        }

        switch exercise.movementPattern {
        case .verticalPush:
            return resolveFromPattern(withFamily(.overheadPress, exercise))
        case .horizontalPush:
            return resolveFromPattern(withFamily(.benchPress, exercise))
        case .verticalPull:
            return exercise.equipment == .bodyweight
                ? Spec(.pullUp, .bodyweightBar, .standing, .front, false, .needsRefinement)
                : Spec(.latPulldown, .cable, .seated, .threeQuarter, false, .needsRefinement)
        case .horizontalPull:
            return resolveFromPattern(withFamily(.row, exercise))
        case .squat:
            return resolveFromPattern(withFamily(.squat, exercise))
        case .hinge:
            return resolveFromPattern(withFamily(.hinge, exercise))
        case .lunge:
            return resolveFromPattern(withFamily(.lunge, exercise))
        case .carry:
            return Spec(.farmerCarry, .dumbbells, .standing, .threeQuarter, false, .needsRefinement)
        case .core, .rotation:
            return Spec(.plank, .none, .plank, .side, false, .needsRefinement)
        case .isolation:
            if exercise.primaryMuscleGroup == .triceps {
                return resolveFromPattern(withFamily(.tricepExtension, exercise))
            }
            if exercise.primaryMuscleGroup == .biceps {
                return resolveFromPattern(withFamily(.bicepCurl, exercise))
            }
            if exercise.primaryMuscleGroup == .shoulders {
                return Spec(.lateralRaise, .dumbbells, .standing, .front, false, .needsRefinement)
            }
            return Spec(.genericStanding, prop, .standing, .front, unilateral, .hiddenUntilCorrected)
        case .olympic:
            return Spec(.conventionalDeadlift, .barbell, .hinged, .side, false, .hiddenUntilCorrected)
        case .conditioning:
            return Spec(.genericStanding, prop, .standing, .front, unilateral, .hiddenUntilCorrected)
        }

        return Spec(.genericStanding, prop, .standing, .front, unilateral, .hiddenUntilCorrected)
    }

    private static func defaultProp(for exercise: Exercise, unilateral: Bool) -> DemonstrationProp {
        switch exercise.equipment {
        case .barbell: return .barbell
        case .dumbbell: return unilateral ? .singleDumbbell : .dumbbells
        case .kettlebell: return .kettlebell
        case .cable: return .cable
        case .machine: return .machine
        case .bodyweight: return .none
        }
    }

    private static func propMatchesEquipment(_ prop: DemonstrationProp, exercise: Exercise) -> Bool {
        switch (prop, exercise.equipment) {
        case (.barbell, .barbell), (.ezBar, .barbell), (.smithMachine, .barbell):
            return true
        case (.dumbbells, .dumbbell), (.singleDumbbell, .dumbbell):
            return true
        case (.kettlebell, .kettlebell):
            return true
        case (.cable, .cable), (.rope, .cable):
            return true
        case (.machine, .machine):
            return true
        case (.none, .bodyweight), (.bodyweightBar, .bodyweight), (.bench, .bodyweight):
            return true
        case (.none, _) where exercise.measurementUnit == .reps || exercise.measurementUnit == .bodyweight || exercise.measurementUnit == .time:
            return exercise.equipment == .bodyweight
        default:
            return false
        }
    }

    private static func withFamily(_ family: MovementFamily, _ exercise: Exercise) -> Exercise {
        Exercise(
            id: exercise.id,
            name: exercise.name,
            aliases: exercise.aliases,
            primaryMuscleGroup: exercise.primaryMuscleGroup,
            secondaryMuscleGroups: exercise.secondaryMuscleGroups,
            equipment: exercise.equipment,
            category: exercise.category,
            movementPattern: exercise.movementPattern,
            laterality: exercise.laterality,
            measurementUnit: exercise.measurementUnit,
            trackingProfile: exercise.trackingProfile,
            progressionMethod: exercise.progressionMethod,
            supportsProgressiveOverload: exercise.supportsProgressiveOverload,
            isCustom: exercise.isCustom,
            movementFamily: family,
            requiredEquipment: exercise.requiredEquipment,
            suggestedAlternatives: exercise.suggestedAlternatives,
            weightInterpretation: exercise.weightInterpretation,
            ownerId: exercise.ownerId
        )
    }
}

extension ExerciseDemonstrationCatalog.Spec {
    init(
        _ motion: DemonstrationMotion,
        _ prop: DemonstrationProp,
        _ framing: DemonstrationFraming,
        _ camera: DemonstrationCamera,
        _ unilateral: Bool,
        _ quality: DemonstrationQuality
    ) {
        self.motion = motion
        self.prop = prop
        self.framing = framing
        self.camera = camera
        self.unilateral = unilateral
        self.quality = quality
    }
}

struct DemonstrationAuditReport: Equatable {
    let verifiedIDs: [String]
    let needsRefinementIDs: [String]
    let hiddenIDs: [String]
    let equipmentMismatches: [String]
    let priorityMissingVerification: [String]

    var markdown: String {
        var lines: [String] = [
            "# Exercise Demonstration Audit",
            "",
            "Generated for trenira procedural demonstrations.",
            "",
            "## Summary",
            "",
            "- Verified: \(verifiedIDs.count)",
            "- Needs refinement: \(needsRefinementIDs.count)",
            "- Hidden until corrected: \(hiddenIDs.count)",
            "- Equipment mismatches: \(equipmentMismatches.count)",
            "- Priority still unverified: \(priorityMissingVerification.count)",
            "",
            "## Verified",
            "",
        ]
        lines += verifiedIDs.map { "- `\($0)`" }
        lines += ["", "## Needs refinement", ""]
        lines += needsRefinementIDs.map { "- `\($0)`" }
        lines += ["", "## Hidden until corrected", ""]
        lines += hiddenIDs.map { "- `\($0)`" }
        if !equipmentMismatches.isEmpty {
            lines += ["", "## Equipment mismatches", ""]
            lines += equipmentMismatches.map { "- \($0)" }
        }
        if !priorityMissingVerification.isEmpty {
            lines += ["", "## Priority exercises still unverified", ""]
            lines += priorityMissingVerification.map { "- `\($0)`" }
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
