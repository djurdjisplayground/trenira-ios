import Foundation

/// Fine-grained gym equipment used for profiles and workout generation filters.
/// Coarser `EquipmentType` remains for exercise categorization.
enum GymEquipmentKind: String, Codable, CaseIterable, Identifiable, Hashable {
    // Free weights
    case dumbbells
    case barbell
    case weightPlates
    case kettlebells
    case ezCurlBar
    case smithMachine

    // Cable
    case cableStation
    case highPulley
    case lowPulley
    case dualAdjustablePulley
    case cableAttachments

    // Machines
    case legPress
    case legExtension
    case seatedLegCurl
    case lyingLegCurl
    case hipAbductor
    case hipAdductor
    case chestPressMachine
    case shoulderPressMachine
    case latPulldownMachine
    case seatedRowMachine
    case assistedPullUpMachine
    case pecDeck
    case rearDeltMachine
    case hackSquat
    case hipThrustMachine
    case gluteKickbackMachine
    case calfRaiseMachine
    case tricepExtensionMachine
    case preacherCurlMachine

    // Benches & stations
    case flatBench
    case adjustableBench
    case squatRack
    case pullUpBar
    case dipStation
    case backExtensionBench

    // Other
    case resistanceBands
    case suspensionTrainer
    case medicineBall
    case stabilityBall
    case bodyweight

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dumbbells: return "Dumbbells"
        case .barbell: return "Barbell"
        case .weightPlates: return "Weight plates"
        case .kettlebells: return "Kettlebells"
        case .ezCurlBar: return "EZ curl bar"
        case .smithMachine: return "Smith machine"
        case .cableStation: return "Cable station"
        case .highPulley: return "High pulley"
        case .lowPulley: return "Low pulley"
        case .dualAdjustablePulley: return "Dual adjustable pulley"
        case .cableAttachments: return "Cable attachments"
        case .legPress: return "Leg press"
        case .legExtension: return "Leg extension"
        case .seatedLegCurl: return "Seated leg curl"
        case .lyingLegCurl: return "Lying leg curl"
        case .hipAbductor: return "Hip abductor"
        case .hipAdductor: return "Hip adductor"
        case .chestPressMachine: return "Chest press"
        case .shoulderPressMachine: return "Shoulder press"
        case .latPulldownMachine: return "Lat pulldown"
        case .seatedRowMachine: return "Seated row"
        case .assistedPullUpMachine: return "Assisted pull-up"
        case .pecDeck: return "Pec deck"
        case .rearDeltMachine: return "Rear-delt machine"
        case .hackSquat: return "Hack squat"
        case .hipThrustMachine: return "Hip thrust machine"
        case .gluteKickbackMachine: return "Glute kickback machine"
        case .calfRaiseMachine: return "Calf raise machine"
        case .tricepExtensionMachine: return "Tricep extension machine"
        case .preacherCurlMachine: return "Preacher curl machine"
        case .flatBench: return "Flat bench"
        case .adjustableBench: return "Adjustable bench"
        case .squatRack: return "Squat rack"
        case .pullUpBar: return "Pull-up bar"
        case .dipStation: return "Dip station"
        case .backExtensionBench: return "Back-extension bench"
        case .resistanceBands: return "Resistance bands"
        case .suspensionTrainer: return "Suspension trainer"
        case .medicineBall: return "Medicine ball"
        case .stabilityBall: return "Stability ball"
        case .bodyweight: return "Bodyweight only"
        }
    }

    var category: GymEquipmentCategory {
        switch self {
        case .dumbbells, .barbell, .weightPlates, .kettlebells, .ezCurlBar, .smithMachine:
            return .freeWeights
        case .cableStation, .highPulley, .lowPulley, .dualAdjustablePulley, .cableAttachments:
            return .cables
        case .legPress, .legExtension, .seatedLegCurl, .lyingLegCurl, .hipAbductor, .hipAdductor,
             .chestPressMachine, .shoulderPressMachine, .latPulldownMachine, .seatedRowMachine,
             .assistedPullUpMachine, .pecDeck, .rearDeltMachine, .hackSquat, .hipThrustMachine,
             .gluteKickbackMachine, .calfRaiseMachine, .tricepExtensionMachine, .preacherCurlMachine:
            return .machines
        case .flatBench, .adjustableBench, .squatRack, .pullUpBar, .dipStation, .backExtensionBench:
            return .benchesAndStations
        case .resistanceBands, .suspensionTrainer, .medicineBall, .stabilityBall, .bodyweight:
            return .other
        }
    }

    /// Coarse equipment type this kind maps to for legacy filtering.
    var equipmentType: EquipmentType? {
        switch category {
        case .freeWeights:
            switch self {
            case .dumbbells: return .dumbbell
            case .barbell, .weightPlates, .ezCurlBar, .smithMachine: return .barbell
            case .kettlebells: return .kettlebell
            default: return .barbell
            }
        case .cables: return .cable
        case .machines: return .machine
        case .benchesAndStations: return nil
        case .other:
            switch self {
            case .bodyweight, .resistanceBands, .suspensionTrainer: return .bodyweight
            default: return .bodyweight
            }
        }
    }
}

enum GymEquipmentCategory: String, CaseIterable, Identifiable {
    case freeWeights
    case cables
    case machines
    case benchesAndStations
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .freeWeights: return "Free weights"
        case .cables: return "Cable equipment"
        case .machines: return "Machines"
        case .benchesAndStations: return "Benches and stations"
        case .other: return "Other"
        }
    }

    var kinds: [GymEquipmentKind] {
        GymEquipmentKind.allCases.filter { $0.category == self }
    }
}

/// Quick presets for generate / adapt flows.
enum GymEquipmentPreset: String, CaseIterable, Identifiable {
    case fullGym
    case dumbbellsOnly
    case machinesOnly
    case hotelGym
    case homeGym
    case bodyweightOnly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fullGym: return "Full gym"
        case .dumbbellsOnly: return "Dumbbells only"
        case .machinesOnly: return "Machines only"
        case .hotelGym: return "Hotel gym"
        case .homeGym: return "Home gym"
        case .bodyweightOnly: return "Bodyweight only"
        }
    }

    var equipment: Set<GymEquipmentKind> {
        switch self {
        case .fullGym:
            return Set(GymEquipmentKind.allCases)
        case .dumbbellsOnly:
            return [.dumbbells, .flatBench, .adjustableBench, .bodyweight]
        case .machinesOnly:
            return Set(GymEquipmentCategory.machines.kinds + [.bodyweight, .pullUpBar, .dipStation])
        case .hotelGym:
            return [
                .dumbbells, .adjustableBench, .cableStation, .highPulley, .lowPulley,
                .latPulldownMachine, .seatedRowMachine, .chestPressMachine, .legPress,
                .legExtension, .seatedLegCurl, .shoulderPressMachine, .pullUpBar, .bodyweight
            ]
        case .homeGym:
            return [
                .dumbbells, .kettlebells, .resistanceBands, .adjustableBench,
                .pullUpBar, .bodyweight, .stabilityBall
            ]
        case .bodyweightOnly:
            return [.bodyweight, .pullUpBar, .dipStation]
        }
    }
}

extension EquipmentType {
    /// Default required kinds when an exercise does not declare specific equipment.
    var defaultRequiredEquipment: [GymEquipmentKind] {
        switch self {
        case .dumbbell: return [.dumbbells]
        case .barbell: return [.barbell, .weightPlates]
        case .machine: return [] // machine exercises should declare a specific kind
        case .cable: return [.cableStation]
        case .kettlebell: return [.kettlebells]
        case .bodyweight: return [.bodyweight]
        }
    }
}

enum WeightInterpretation: String, Codable, CaseIterable, Hashable {
    case totalLoad
    case perHand
    case perArm
    case machineSetting
    case bodyweight
    case none

    var label: String {
        switch self {
        case .totalLoad: return "Total load"
        case .perHand: return "Per hand"
        case .perArm: return "Per arm"
        case .machineSetting: return "Machine setting"
        case .bodyweight: return "Bodyweight"
        case .none: return "—"
        }
    }

    var shortCaption: String? {
        switch self {
        case .totalLoad: return "Enter the total weight on the bar or machine."
        case .perHand: return "Enter the weight of each dumbbell / hand, not the total."
        case .perArm: return "Enter the weight used for each arm."
        case .machineSetting: return "Enter the weight shown on the machine stack or pin."
        case .bodyweight, .none: return nil
        }
    }
}
