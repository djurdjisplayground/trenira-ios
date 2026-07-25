import Foundation

/// How a demonstration is presented.
enum ExerciseDemonstrationType: String, Codable, Hashable {
    case video
    case animation
    case procedural
    case none
}

/// Equipment prop — must match Exercise Details metadata.
enum DemonstrationProp: String, Hashable {
    case none
    case barbell
    case ezBar
    case dumbbells
    case singleDumbbell
    case kettlebell
    case cable
    case rope
    case machine
    case smithMachine
    case bodyweightBar
    case bench
}

enum DemonstrationFraming: String, Hashable {
    case standing
    case seated
    case lying
    case hinged
    case plank
    case sidePlank
}

/// Static camera — never rotates or zooms during playback.
enum DemonstrationCamera: String, Hashable {
    case front
    case side
    case threeQuarter
}

/// Internal quality gate so inaccurate demos are not shown as truth.
enum DemonstrationQuality: String, Hashable {
    /// Tuned for teaching; safe to show.
    case verified
    /// Recognizable but still being refined — shown with a DEV-only note.
    case needsRefinement
    /// Wrong or misleading — hidden until corrected.
    case hiddenUntilCorrected
}

/// Discrete motion templates. Different equipment variations never share one template.
enum DemonstrationMotion: String, Hashable, CaseIterable {
    case barbellOverheadPress
    case dumbbellOverheadPress
    case machineShoulderPress
    case singleArmDumbbellPress
    case arnoldPress
    case kettlebellPress
    case smithOverheadPress

    case barbellBenchPress
    case dumbbellBenchPress
    case machineChestPress
    case pushUp
    case chestFlyDumbbell
    case chestFlyCable

    case pullUp
    case latPulldown
    case barbellRow
    case oneArmDumbbellRow
    case seatedCableRow
    case machineRow
    case verticalRow
    case facePull

    case skullCrusherBarbell
    case skullCrusherDumbbell
    case skullCrusherEZ
    case skullCrusherCable
    case overheadTricepTwoHand
    case overheadTricepCable
    case tricepPushdown
    case ropePushdown
    case machineTricepExtension
    case singleArmTricepExtension
    case tricepKickback

    case barbellCurl
    case dumbbellCurl
    case hammerCurl
    case lateralRaise

    case backSquat
    case gobletSquat
    case legPress
    case romanianDeadlift
    case singleLegRDL
    case conventionalDeadlift
    case hipThrust
    case singleLegGluteBridge
    case bulgarianSplitSquat
    case forwardLunge
    case reverseLunge
    case walkingLunge
    case stepUp
    case legCurl
    case legExtension
    case calfRaise

    case plank
    case sidePlank
    case farmerCarry

    case genericStanding
    case genericSeated
    case genericLying
}

struct ExerciseDemonstration: Hashable {
    let exerciseId: String
    let demonstrationAsset: String?
    let demonstrationType: ExerciseDemonstrationType
    let thumbnailAsset: String?
    let motion: DemonstrationMotion
    let prop: DemonstrationProp
    let framing: DemonstrationFraming
    let camera: DemonstrationCamera
    let unilateral: Bool
    let quality: DemonstrationQuality

    var hasBundledMedia: Bool {
        ExerciseVisuals.resolvedDemonstrationURL(for: self) != nil
    }

    /// True only when a licensed real-human loop exists for this exercise ID.
    /// Prefer no visual over a stylized or incorrect stand-in.
    var demonstrationAvailable: Bool {
        hasBundledMedia
    }

    static func none(exerciseId: String) -> ExerciseDemonstration {
        ExerciseDemonstration(
            exerciseId: exerciseId,
            demonstrationAsset: nil,
            demonstrationType: .none,
            thumbnailAsset: nil,
            motion: .genericStanding,
            prop: .none,
            framing: .standing,
            camera: .front,
            unilateral: false,
            quality: .hiddenUntilCorrected
        )
    }
}

extension Exercise {
    var demonstration: ExerciseDemonstration {
        guard !isCustom else {
            return ExerciseDemonstrationCatalog.demonstration(forCustom: self)
        }
        return ExerciseDemonstrationCatalog.demonstration(for: self)
    }

    var demonstrationAsset: String? { demonstration.demonstrationAsset }
    var demonstrationType: ExerciseDemonstrationType { demonstration.demonstrationType }
    var thumbnailAsset: String? { demonstration.thumbnailAsset }
    var demonstrationAvailable: Bool { demonstration.demonstrationAvailable }
    var hasExerciseDetailsContent: Bool { true }
}
