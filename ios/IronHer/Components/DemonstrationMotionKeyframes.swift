import CoreGraphics

/// Keyframed poses for procedural demonstrations.
/// `phase` is 0…1 along the concentric path (the view ping-pongs for the eccentric).
enum DemonstrationMotionKeyframes {
    typealias Pose = DemonstrationFigureDrawing.Pose

    static func pose(motion: DemonstrationMotion, phase: CGFloat) -> Pose {
        let p = max(0, min(1, phase))
        var pose = Pose()

        switch motion {
        // MARK: Overhead press family
        case .dumbbellOverheadPress:
            // Start near shoulders → press vertically. Two dumbbells.
            pose.elevL = 0.28 + p * 0.72
            pose.elevR = pose.elevL
            pose.elbowL = 0.62 - p * 0.48
            pose.elbowR = pose.elbowL
            pose.abdL = 0.18
            pose.abdR = 0.18

        case .barbellOverheadPress, .smithOverheadPress:
            pose.elevL = 0.30 + p * 0.70
            pose.elevR = pose.elevL
            pose.elbowL = 0.58 - p * 0.45
            pose.elbowR = pose.elbowL
            pose.abdL = 0.08
            pose.abdR = 0.08

        case .machineShoulderPress:
            pose.elevL = 0.25 + p * 0.7
            pose.elevR = pose.elevL
            pose.elbowL = 0.55 - p * 0.4
            pose.elbowR = pose.elbowL
            pose.squatDepth = 0.12

        case .singleArmDumbbellPress:
            pose.elevR = 0.28 + p * 0.72
            pose.elbowR = 0.6 - p * 0.45
            pose.elevL = 0.02
            pose.elbowL = 0.12
            pose.abdL = 0.05
            pose.torsoPitch = -0.03

        case .arnoldPress:
            pose.elevL = 0.22 + p * 0.75
            pose.elevR = pose.elevL
            pose.elbowL = 0.7 - p * 0.5
            pose.elbowR = pose.elbowL
            pose.abdL = 0.25 - p * 0.1
            pose.abdR = pose.abdL

        case .kettlebellPress:
            pose.elevR = 0.28 + p * 0.72
            pose.elbowR = 0.58 - p * 0.42
            pose.elevL = 0.02
            pose.elbowL = 0.1

        // MARK: Chest
        case .dumbbellBenchPress, .barbellBenchPress:
            pose.pressL = p
            pose.pressR = p
            pose.elbowL = 0.7 - p * 0.4
            pose.elbowR = pose.elbowL
            pose.elevL = 0.35 + p * 0.2
            pose.elevR = pose.elevL

        case .chestFlyDumbbell:
            // Open → hug. Upper arms wide, slight elbow bend constant.
            pose.pressL = p
            pose.pressR = p
            pose.elbowL = 0.22
            pose.elbowR = 0.22
            pose.elevL = 0.35
            pose.elevR = 0.35

        case .chestFlyCable:
            pose.abdL = 0.85 - p * 0.55
            pose.abdR = pose.abdL
            pose.elevL = 0.35
            pose.elevR = 0.35
            pose.elbowL = 0.2
            pose.elbowR = 0.2
            pose.pressL = p
            pose.pressR = p

        case .machineChestPress:
            pose.pressL = p
            pose.pressR = p
            pose.elbowL = 0.65 - p * 0.4
            pose.elbowR = pose.elbowL
            pose.elevL = 0.4
            pose.elevR = 0.4
            pose.squatDepth = 0.1

        case .pushUp:
            // phase 0 = high plank, 1 = low
            pose.elbowL = p
            pose.elbowR = p

        // MARK: Pull
        case .pullUp:
            pose.elevL = 0.95
            pose.elevR = 0.95
            pose.elbowL = 0.15 + p * 0.7
            pose.elbowR = pose.elbowL
            pose.squatDepth = -0.05 + p * 0.08

        case .latPulldown:
            pose.elevL = 0.95 - p * 0.55
            pose.elevR = pose.elevL
            pose.elbowL = 0.2 + p * 0.5
            pose.elbowR = pose.elbowL
            pose.torsoPitch = 0.06
            pose.squatDepth = 0.1

        case .oneArmDumbbellRow:
            pose.hipHinge = 0.85
            pose.torsoPitch = 0.05
            pose.kneeL = 0.28
            pose.kneeR = 0.22
            pose.split = 0.85
            pose.elevR = 0.15 + p * 0.25
            pose.elbowR = 0.25 + p * 0.55
            pose.pressR = p
            pose.elevL = 0.05
            pose.elbowL = 0.12
            pose.abdL = 0.1

        case .barbellRow:
            pose.hipHinge = 0.9
            pose.kneeL = 0.25
            pose.kneeR = 0.25
            pose.elevL = 0.12 + p * 0.22
            pose.elevR = pose.elevL
            pose.elbowL = 0.25 + p * 0.5
            pose.elbowR = pose.elbowL
            pose.pressL = p
            pose.pressR = p

        case .seatedCableRow, .machineRow, .verticalRow:
            pose.squatDepth = 0.12
            pose.elevL = 0.2 + p * 0.15
            pose.elevR = pose.elevL
            pose.elbowL = 0.25 + p * 0.5
            pose.elbowR = pose.elbowL
            pose.pressL = p
            pose.pressR = p
            pose.torsoPitch = 0.1 - p * 0.06

        case .facePull:
            pose.elevL = 0.45
            pose.elevR = 0.45
            pose.abdL = 0.35 + p * 0.4
            pose.abdR = pose.abdL
            pose.elbowL = 0.45 + p * 0.3
            pose.elbowR = pose.elbowL

        // MARK: Triceps
        case .skullCrusherDumbbell, .skullCrusherBarbell, .skullCrusherEZ, .skullCrusherCable:
            // 0 = extended over chest/face, 1 = flexed toward sides of head
            pose.elbowL = p
            pose.elbowR = p
            pose.elevL = 0.85
            pose.elevR = 0.85
            pose.lyingUpperArm = -.pi / 2

        case .overheadTricepTwoHand:
            // Two hands on one DB; start extended overhead, flex behind the head.
            pose.elevL = 0.95
            pose.elevR = 0.95
            pose.elbowL = 0.2 + p * 0.65
            pose.elbowR = pose.elbowL
            pose.abdL = 0.08
            pose.abdR = 0.08

        case .singleArmTricepExtension:
            pose.elevR = 0.95
            pose.elbowR = 0.2 + p * 0.65
            pose.elevL = 0.02
            pose.elbowL = 0.12

        case .overheadTricepCable:
            pose.elevL = 0.9
            pose.elevR = 0.9
            pose.elbowL = 0.25 + p * 0.55
            pose.elbowR = pose.elbowL

        case .tricepPushdown, .ropePushdown:
            pose.elevL = 0.08
            pose.elevR = 0.08
            pose.elbowL = 0.75 - p * 0.6
            pose.elbowR = pose.elbowL
            pose.abdL = 0.05
            pose.abdR = 0.05

        case .machineTricepExtension:
            pose.squatDepth = 0.1
            pose.elevL = 0.15
            pose.elevR = 0.15
            pose.elbowL = 0.7 - p * 0.5
            pose.elbowR = pose.elbowL

        case .tricepKickback:
            pose.hipHinge = 0.8
            pose.split = 0.7
            pose.kneeL = 0.25
            pose.kneeR = 0.2
            pose.elevR = 0.25 + p * 0.35
            pose.elbowR = 0.7 - p * 0.55
            pose.elevL = 0.05

        // MARK: Arms / raises
        case .dumbbellCurl, .hammerCurl:
            pose.elevL = 0.05
            pose.elevR = 0.05
            pose.elbowL = 0.15 + p * 0.7
            pose.elbowR = pose.elbowL
            pose.abdL = 0.08
            pose.abdR = 0.08

        case .barbellCurl:
            pose.elevL = 0.05
            pose.elevR = 0.05
            pose.elbowL = 0.15 + p * 0.7
            pose.elbowR = pose.elbowL

        case .lateralRaise:
            pose.abdL = p
            pose.abdR = p
            pose.elevL = 0.08 + p * 0.28
            pose.elevR = pose.elevL
            pose.elbowL = 0.12
            pose.elbowR = 0.12

        // MARK: Lower body
        case .romanianDeadlift:
            // Start tall → hinge → return (ping-pong handles the return).
            pose.hipHinge = 0.15 + p * 0.75
            pose.kneeL = 0.12 + p * 0.06
            pose.kneeR = pose.kneeL
            pose.elevL = 0.05
            pose.elevR = 0.05
            pose.elbowL = 0.1
            pose.elbowR = 0.1

        case .singleLegRDL:
            pose.hipHinge = 0.2 + p * 0.7
            pose.kneeL = 0.18
            pose.kneeR = 0.12
            pose.rearSupport = 0.2 + p * 0.5
            pose.split = 0.4
            pose.elevR = 0.05
            pose.elbowR = 0.1
            pose.elevL = 0.05

        case .conventionalDeadlift:
            pose.hipHinge = 0.35 + (1 - p) * 0.5
            pose.kneeL = 0.25 + (1 - p) * 0.35
            pose.kneeR = pose.kneeL
            pose.squatDepth = (1 - p) * 0.12
            pose.elevL = 0.05
            pose.elevR = 0.05

        case .gobletSquat:
            pose.squatDepth = p
            pose.kneeL = 0.15 + p * 0.55
            pose.kneeR = pose.kneeL
            pose.hipHinge = p * 0.2
            pose.elevL = 0.35
            pose.elevR = 0.35
            pose.elbowL = 0.7
            pose.elbowR = 0.7

        case .backSquat:
            pose.squatDepth = p
            pose.kneeL = 0.15 + p * 0.55
            pose.kneeR = pose.kneeL
            pose.hipHinge = p * 0.22
            pose.elevL = 0.55
            pose.elevR = 0.55
            pose.elbowL = 0.55
            pose.elbowR = 0.55

        case .bulgarianSplitSquat:
            pose.split = 1.0
            pose.rearSupport = 0.85
            pose.squatDepth = p
            pose.kneeL = 0.2 + p * 0.5
            pose.kneeR = 0.25
            pose.hipHinge = p * 0.1
            pose.elevL = 0.05
            pose.elevR = 0.05
            pose.elbowL = 0.12
            pose.elbowR = 0.12

        case .forwardLunge, .walkingLunge:
            pose.split = 0.7 + p * 0.35
            pose.squatDepth = p * 0.85
            pose.kneeL = 0.2 + p * 0.5
            pose.kneeR = 0.25 + p * 0.35
            pose.hipHinge = p * 0.08
            pose.elevL = 0.05
            pose.elevR = 0.05

        case .reverseLunge:
            pose.split = 0.55 + p * 0.45
            pose.squatDepth = p * 0.85
            pose.kneeL = 0.2 + p * 0.45
            pose.kneeR = 0.3 + p * 0.35
            pose.elevL = 0.05
            pose.elevR = 0.05

        case .stepUp:
            pose.split = 0.5
            pose.rearSupport = 0.2 + p * 0.7
            pose.squatDepth = (1 - p) * 0.25
            pose.kneeL = 0.35 - p * 0.2
            pose.kneeR = 0.15 + (1 - p) * 0.35
            pose.elevL = 0.05
            pose.elevR = 0.05

        case .hipThrust:
            pose.squatDepth = p // used as hip lift
            pose.kneeL = 0.45
            pose.kneeR = 0.45

        case .singleLegGluteBridge:
            pose.squatDepth = p
            pose.kneeL = 0.45
            pose.kneeR = 0.2

        case .legPress:
            pose.squatDepth = 0.1
            pose.kneeL = 0.7 - p * 0.5
            pose.kneeR = pose.kneeL
            pose.elevL = 0.15
            pose.elevR = 0.15

        case .legCurl:
            pose.kneeL = 0.2 + p * 0.6
            pose.kneeR = pose.kneeL

        case .legExtension:
            pose.squatDepth = 0.1
            pose.kneeL = 0.7 - p * 0.55
            pose.kneeR = pose.kneeL

        case .calfRaise:
            pose.squatDepth = -p * 0.04
            pose.kneeL = 0.05
            pose.kneeR = 0.05

        // MARK: Core / carry
        case .plank:
            pose.elbowL = 0.05
            pose.elbowR = 0.05

        case .sidePlank:
            pose.squatDepth = 0.02

        case .farmerCarry:
            // Walk cycle — upright, both arms loaded, no lift.
            pose.walk = p
            pose.elevL = 0.02
            pose.elevR = 0.02
            pose.elbowL = 0.12
            pose.elbowR = 0.12
            pose.abdL = 0.05
            pose.abdR = 0.05
            pose.kneeL = 0.12 + abs(sin(p * .pi * 2)) * 0.12
            pose.kneeR = 0.12 + abs(sin(p * .pi * 2 + .pi)) * 0.12
            pose.split = 0.2

        case .genericStanding:
            pose.elevL = 0.05 + p * 0.25
            pose.elevR = pose.elevL
            pose.elbowL = 0.2 + p * 0.3
            pose.elbowR = pose.elbowL

        case .genericSeated:
            pose.squatDepth = 0.12
            pose.elevL = 0.15 + p * 0.3
            pose.elevR = pose.elevL
            pose.elbowL = 0.25 + p * 0.3
            pose.elbowR = pose.elbowL

        case .genericLying:
            pose.pressL = p
            pose.pressR = p
            pose.elbowL = 0.55 - p * 0.25
            pose.elbowR = pose.elbowL
        }

        return pose
    }
}
