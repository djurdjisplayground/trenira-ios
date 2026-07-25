import Foundation

enum MuscleGroup: String, Codable, CaseIterable, Hashable {
    case chest
    case back
    case shoulders
    case biceps
    case triceps
    case quads
    case hamstrings
    case glutes
    case calves
    case core
    case fullBody

    var label: String {
        switch self {
        case .chest: return "Chest"
        case .back: return "Back"
        case .shoulders: return "Shoulders"
        case .biceps: return "Biceps"
        case .triceps: return "Triceps"
        case .quads: return "Quads"
        case .hamstrings: return "Hamstrings"
        case .glutes: return "Glutes"
        case .calves: return "Calves"
        case .core: return "Core"
        case .fullBody: return "Full Body"
        }
    }

    /// Informal search terms that should map to this muscle group.
    var searchSynonyms: [String] {
        switch self {
        case .chest: return ["chest", "pec", "pecs", "pectoral"]
        case .back: return ["back", "lat", "lats", "latissimus", "upper back"]
        case .shoulders: return ["shoulder", "shoulders", "delt", "delts", "deltoid"]
        case .biceps: return ["bicep", "biceps", "bis"]
        case .triceps: return ["tricep", "triceps", "tris"]
        case .quads: return ["quad", "quads", "quadriceps"]
        case .hamstrings: return ["ham", "hams", "hamstring", "hamstrings"]
        case .glutes: return ["glute", "glutes", "gluteus", "booty"]
        case .calves: return ["calf", "calves"]
        case .core: return ["core", "abs", "ab", "oblique", "obliques"]
        case .fullBody: return ["full body", "fullbody", "total body"]
        }
    }
}

enum EquipmentType: String, Codable, CaseIterable, Hashable, Identifiable {
    case barbell = "Barbell"
    case dumbbell = "Dumbbell"
    case machine = "Machine"
    case cable = "Cable"
    case kettlebell = "Kettlebell"
    case bodyweight = "Bodyweight"

    var id: String { rawValue }
    var label: String { rawValue }
}

enum ExerciseCategory: String, Codable, CaseIterable, Hashable {
    case push
    case pull
    case squat
    case hinge
    case lunge
    case carry
    case core
    case isolation
    case olympic
    case conditioning

    var label: String {
        switch self {
        case .push: return "Push"
        case .pull: return "Pull"
        case .squat: return "Squat"
        case .hinge: return "Hinge"
        case .lunge: return "Lunge"
        case .carry: return "Carry"
        case .core: return "Core"
        case .isolation: return "Isolation"
        case .olympic: return "Olympic"
        case .conditioning: return "Conditioning"
        }
    }
}

enum MovementPattern: String, Codable, CaseIterable, Hashable {
    case horizontalPush
    case verticalPush
    case horizontalPull
    case verticalPull
    case squat
    case hinge
    case lunge
    case isolation
    case rotation
    case carry
    case olympic
    case conditioning
    case core

    var label: String {
        switch self {
        case .horizontalPush: return "Horizontal push"
        case .verticalPush: return "Vertical push"
        case .horizontalPull: return "Horizontal pull"
        case .verticalPull: return "Vertical pull"
        case .squat: return "Squat"
        case .hinge: return "Hinge"
        case .lunge: return "Lunge"
        case .isolation: return "Isolation"
        case .rotation: return "Rotation"
        case .carry: return "Carry"
        case .olympic: return "Olympic"
        case .conditioning: return "Conditioning"
        case .core: return "Core"
        }
    }
}

enum Laterality: String, Codable, CaseIterable, Hashable {
    case bilateral
    case unilateral
    case alternating

    var label: String {
        switch self {
        case .bilateral: return "Bilateral"
        case .unilateral: return "Unilateral"
        case .alternating: return "Alternating"
        }
    }
}

/// How an exercise is tracked during workouts.
enum MeasurementUnit: String, Codable, CaseIterable, Hashable {
    case weight
    case bodyweight
    case time
    case distance
    case reps
    /// Weight per set plus hold/carry duration (e.g. Farmer's Carry).
    case weightAndTime
    /// Reps with an optional external weight (empty = bodyweight).
    case repsWithOptionalWeight

    var label: String {
        switch self {
        case .weight: return "Weight + Reps"
        case .bodyweight: return "Bodyweight + Reps"
        case .time: return "Time"
        case .distance: return "Distance"
        case .reps: return "Reps"
        case .weightAndTime: return "Weight + Duration"
        case .repsWithOptionalWeight: return "Optional Weight"
        }
    }

    var shortLabel: String {
        switch self {
        case .weight: return "Weight"
        case .bodyweight: return "Bodyweight"
        case .time: return "Duration"
        case .distance: return "Distance"
        case .reps: return "Reps"
        case .weightAndTime: return "Weight + Time"
        case .repsWithOptionalWeight: return "Optional Weight"
        }
    }
}

/// Default progression strategy when an exercise is completed successfully.
enum ProgressionMethod: String, Codable, CaseIterable, Hashable {
    case addWeight
    case addReps
    case addDuration
    case addSets
    case addDistance
    case addExternalWeight

    var label: String {
        switch self {
        case .addWeight: return "Add weight"
        case .addReps: return "Add reps"
        case .addDuration: return "Longer duration"
        case .addSets: return "Add sets"
        case .addDistance: return "Add distance"
        case .addExternalWeight: return "Add external weight"
        }
    }
}

/// Shared movement intention linking equipment-specific exercise variations.
/// Progression and history stay per exercise ID — family is for search/substitution only.
enum MovementFamily: String, Codable, CaseIterable, Hashable, Identifiable {
    case overheadPress
    case benchPress
    case inclinePress
    case declinePress
    case chestFly
    case row
    case pulldown
    case pullUp
    case skullCrusher
    case tricepExtension
    case tricepPushdown
    case bicepCurl
    case lateralRaise
    case squat
    case hinge
    case hipThrust
    case lunge
    case legCurl
    case legExtension
    case calfRaise
    case carry
    case core
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .overheadPress: return "Overhead Press"
        case .benchPress: return "Bench Press"
        case .inclinePress: return "Incline Press"
        case .declinePress: return "Decline Press"
        case .chestFly: return "Chest Fly"
        case .row: return "Row"
        case .pulldown: return "Pulldown"
        case .pullUp: return "Pull-Up"
        case .skullCrusher: return "Skull Crusher"
        case .tricepExtension: return "Tricep Extension"
        case .tricepPushdown: return "Tricep Pushdown"
        case .bicepCurl: return "Bicep Curl"
        case .lateralRaise: return "Lateral Raise"
        case .squat: return "Squat"
        case .hinge: return "Hinge"
        case .hipThrust: return "Hip Thrust"
        case .lunge: return "Lunge"
        case .legCurl: return "Leg Curl"
        case .legExtension: return "Leg Extension"
        case .calfRaise: return "Calf Raise"
        case .carry: return "Carry"
        case .core: return "Core"
        case .other: return "Other"
        }
    }
}

