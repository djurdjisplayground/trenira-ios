import Foundation

enum ExerciseDatabase {
    static let all: [Exercise] = {
        var seen = Set<String>()
        var combined: [Exercise] = []
        for exercise in baseExercises + ExerciseDatabaseExpansion.all {
            if seen.insert(exercise.id).inserted {
                combined.append(exercise)
            }
        }
        return combined
    }()

    private static let baseExercises: [Exercise] =        chestExercises
        + backExercises
        + shoulderExercises
        + armExercises
        + quadGluteExercises
        + hamstringExercises
        + calfExercises
        + coreExercises
        + fullBodyExercises

    // MARK: - Chest

    private static let chestExercises: [Exercise] = [
        ex("barbell-bench-press", "Barbell Bench Press", .chest, .barbell, .push, .horizontalPush, secondary: [.shoulders, .triceps]),
        ex("dumbbell-bench-press", "Dumbbell Bench Press", .chest, .dumbbell, .push, .horizontalPush, secondary: [.shoulders, .triceps]),
        ex("incline-barbell-press", "Incline Barbell Press", .chest, .barbell, .push, .horizontalPush, secondary: [.shoulders, .triceps]),
        ex("incline-dumbbell-press", "Incline Dumbbell Press", .chest, .dumbbell, .push, .horizontalPush, secondary: [.shoulders, .triceps]),
        ex("decline-barbell-press", "Decline Barbell Press", .chest, .barbell, .push, .horizontalPush, secondary: [.triceps]),
        ex("decline-dumbbell-press", "Decline Dumbbell Press", .chest, .dumbbell, .push, .horizontalPush, secondary: [.triceps]),
        ex("floor-press", "Floor Press", .chest, .barbell, .push, .horizontalPush, secondary: [.shoulders, .triceps]),
        ex("chest-press-machine", "Chest Press Machine", .chest, .machine, .push, .horizontalPush, secondary: [.shoulders, .triceps]),
        ex("pec-deck", "Pec Deck", .chest, .machine, .isolation, .horizontalPush),
        ex("machine-chest-fly", "Machine Chest Fly", .chest, .machine, .isolation, .horizontalPush),
        ex("cable-fly", "Cable Fly", .chest, .cable, .isolation, .horizontalPush),
        ex("low-cable-fly", "Low Cable Fly", .chest, .cable, .isolation, .horizontalPush),
        ex("dumbbell-fly", "Dumbbell Fly", .chest, .dumbbell, .isolation, .horizontalPush),
        ex("incline-dumbbell-fly", "Incline Dumbbell Fly", .chest, .dumbbell, .isolation, .horizontalPush),
        ex("landmine-press", "Landmine Press", .chest, .barbell, .push, .horizontalPush, secondary: [.shoulders, .triceps]),
        ex("svend-press", "Svend Press", .chest, .dumbbell, .isolation, .horizontalPush),
        ex("push-up", "Push-Up", .chest, .bodyweight, .push, .horizontalPush, secondary: [.shoulders, .triceps], aliases: ["pushup"], measurement: .reps, progression: .addReps, overload: true),
        ex("incline-push-up", "Incline Push-Up", .chest, .bodyweight, .push, .horizontalPush, secondary: [.shoulders], aliases: ["incline pushup"], measurement: .reps, progression: .addReps, overload: true),
        ex("decline-push-up", "Decline Push-Up", .chest, .bodyweight, .push, .horizontalPush, secondary: [.triceps], aliases: ["decline pushup"], measurement: .reps, progression: .addReps, overload: true),
        ex("chest-dip", "Chest Dip", .chest, .bodyweight, .push, .verticalPush, secondary: [.triceps], measurement: .bodyweight, overload: false),
        ex("weighted-dip", "Weighted Dip", .chest, .dumbbell, .push, .verticalPush, secondary: [.triceps]),
    ]

    // MARK: - Back

    private static let backExercises: [Exercise] = [
        ex("pull-up", "Pull-Up", .back, .bodyweight, .pull, .verticalPull, secondary: [.biceps], aliases: ["pullup"], measurement: .repsWithOptionalWeight, progression: .addReps, overload: true),
        ex("chin-up", "Chin-Up", .back, .bodyweight, .pull, .verticalPull, secondary: [.biceps], aliases: ["chinup"], measurement: .repsWithOptionalWeight, progression: .addReps, overload: true),
        ex("assisted-pull-up", "Assisted Pull-Up", .back, .machine, .pull, .verticalPull, secondary: [.biceps]),
        ex("lat-pulldown", "Lat Pulldown (Cable)", .back, .cable, .pull, .verticalPull, secondary: [.biceps], aliases: ["lat pulldown", "lat", "pulldown"]),
        ex("wide-grip-pulldown", "Wide-Grip Pulldown", .back, .cable, .pull, .verticalPull, secondary: [.biceps]),
        ex("close-grip-pulldown", "Close-Grip Pulldown", .back, .cable, .pull, .verticalPull, secondary: [.biceps]),
        ex("straight-arm-pulldown", "Straight Arm Pulldown (Cable)", .back, .cable, .isolation, .verticalPull, aliases: ["straight arm pulldown", "lat"]),
        ex("barbell-row", "Barbell Row", .back, .barbell, .pull, .horizontalPull, secondary: [.biceps]),
        ex("pendlay-row", "Pendlay Row", .back, .barbell, .pull, .horizontalPull, secondary: [.biceps]),
        ex("one-arm-dumbbell-row", "One-Arm Dumbbell Row", .back, .dumbbell, .pull, .horizontalPull, secondary: [.biceps], laterality: .unilateral, aliases: ["dumbbell-row", "one arm row", "single arm row"]),
        ex("chest-supported-row", "Chest-Supported Row", .back, .machine, .pull, .horizontalPull, secondary: [.biceps]),
        ex("vertical-row", "Vertical Row", .back, .machine, .pull, .horizontalPull, secondary: [.biceps]),
        ex("seated-cable-row", "Seated Cable Row", .back, .cable, .pull, .horizontalPull, secondary: [.biceps]),
        ex("single-arm-cable-row", "Single-Arm Cable Row", .back, .cable, .pull, .horizontalPull, secondary: [.biceps], laterality: .unilateral),
        ex("t-bar-row", "T-Bar Row", .back, .barbell, .pull, .horizontalPull, secondary: [.biceps]),
        ex("meadows-row", "Meadows Row", .back, .barbell, .pull, .horizontalPull, secondary: [.biceps], laterality: .unilateral),
        ex("inverted-row", "Inverted Row", .back, .bodyweight, .pull, .horizontalPull, secondary: [.biceps], measurement: .bodyweight, overload: false),
        ex("rack-pull", "Rack Pull", .back, .barbell, .hinge, .hinge, secondary: [.glutes, .hamstrings]),
        ex("conventional-deadlift", "Conventional Deadlift", .back, .barbell, .hinge, .hinge, secondary: [.glutes, .hamstrings]),
        ex("sumo-deadlift", "Sumo Deadlift", .back, .barbell, .hinge, .hinge, secondary: [.glutes, .quads]),
        ex("back-extension", "Back Extension", .back, .bodyweight, .hinge, .hinge, secondary: [.glutes, .hamstrings], measurement: .bodyweight, overload: false),
        ex("face-pull", "Face Pull", .back, .cable, .pull, .horizontalPull, secondary: [.shoulders]),
    ]

    // MARK: - Shoulders

    private static let shoulderExercises: [Exercise] = [
        ex("overhead-press", "Barbell Overhead Press", .shoulders, .barbell, .push, .verticalPush, secondary: [.triceps], aliases: ["overhead press", "military press", "ohp", "barbell overhead press"]),
        ex("push-press", "Push Press", .shoulders, .barbell, .push, .verticalPush, secondary: [.triceps, .quads]),
        ex("dumbbell-shoulder-press", "Dumbbell Overhead Press", .shoulders, .dumbbell, .push, .verticalPush, secondary: [.triceps], aliases: ["dumbbell shoulder press", "db overhead press", "dumbbell press"]),
        ex("arnold-press", "Arnold Press", .shoulders, .dumbbell, .push, .verticalPush, secondary: [.triceps]),
        ex("machine-shoulder-press", "Machine Shoulder Press", .shoulders, .machine, .push, .verticalPush, secondary: [.triceps], aliases: ["shoulder press machine"]),
        ex("behind-neck-press", "Behind-Neck Press", .shoulders, .barbell, .push, .verticalPush, secondary: [.triceps]),
        ex("lateral-raise", "Lateral Raise", .shoulders, .dumbbell, .isolation, .isolation, laterality: .unilateral),
        ex("cable-lateral-raise", "Cable Lateral Raise", .shoulders, .cable, .isolation, .isolation, laterality: .unilateral),
        ex("front-raise", "Front Raise", .shoulders, .dumbbell, .isolation, .isolation, laterality: .unilateral),
        ex("cable-front-raise", "Cable Front Raise", .shoulders, .cable, .isolation, .isolation, laterality: .unilateral),
        ex("reverse-fly", "Reverse Fly", .shoulders, .dumbbell, .isolation, .isolation, secondary: [.back]),
        ex("reverse-pec-deck", "Reverse Pec Deck", .shoulders, .machine, .isolation, .isolation, secondary: [.back]),
        ex("upright-row", "Upright Row", .shoulders, .barbell, .pull, .verticalPull, secondary: [.biceps]),
        ex("barbell-shrug", "Barbell Shrug", .shoulders, .barbell, .isolation, .isolation, secondary: [.back]),
        ex("dumbbell-shrug", "Dumbbell Shrug", .shoulders, .dumbbell, .isolation, .isolation, secondary: [.back]),
        ex("landmine-lateral-raise", "Landmine Lateral Raise", .shoulders, .barbell, .isolation, .isolation, laterality: .unilateral),
    ]

    // MARK: - Arms

    private static let armExercises: [Exercise] = [
        ex("barbell-curl", "Barbell Curl", .biceps, .barbell, .isolation, .isolation),
        ex("dumbbell-curl", "Dumbbell Curl", .biceps, .dumbbell, .isolation, .isolation, laterality: .unilateral),
        ex("hammer-curl", "Hammer Curl", .biceps, .dumbbell, .isolation, .isolation, laterality: .unilateral),
        ex("incline-dumbbell-curl", "Incline Dumbbell Curl", .biceps, .dumbbell, .isolation, .isolation, laterality: .unilateral),
        ex("preacher-curl", "Preacher Curl", .biceps, .barbell, .isolation, .isolation),
        ex("spider-curl", "Spider Curl", .biceps, .dumbbell, .isolation, .isolation, laterality: .unilateral),
        ex("cable-curl", "Cable Curl", .biceps, .cable, .isolation, .isolation),
        ex("concentration-curl", "Concentration Curl", .biceps, .dumbbell, .isolation, .isolation, laterality: .unilateral),
        ex("tricep-pushdown", "Tricep Pushdown", .triceps, .cable, .isolation, .isolation),
        ex("rope-pushdown", "Rope Tricep Pushdown", .triceps, .cable, .isolation, .isolation, aliases: ["rope tricep extension", "rope pushdown"]),
        ex("tricep-extension", "Triceps Extension (Cable)", .triceps, .cable, .isolation, .isolation, aliases: ["tricep extension", "triceps extension", "cable tricep extension", "cable triceps extension"]),
        ex("skull-crusher", "Skull Crusher (Barbell)", .triceps, .barbell, .isolation, .isolation, aliases: ["skull crusher", "skull crushers", "lying tricep extension", "lying triceps extension", "barbell skull crusher"]),
        ex("overhead-tricep-extension", "Overhead Triceps Extension (Dumbbell)", .triceps, .dumbbell, .isolation, .isolation, aliases: ["overhead tricep extension", "overhead triceps extension", "dumbbell overhead extension", "tricep extension", "triceps extension"]),
        ex("cable-overhead-extension", "Cable Overhead Tricep Extension", .triceps, .cable, .isolation, .isolation),
        ex("dumbbell-tricep-kickback", "Dumbbell Tricep Kickback", .triceps, .dumbbell, .isolation, .isolation, laterality: .unilateral),
        ex("close-grip-bench", "Close-Grip Bench Press", .triceps, .barbell, .push, .horizontalPush, secondary: [.chest]),
        ex("tricep-dip", "Tricep Dip", .triceps, .bodyweight, .push, .verticalPush, secondary: [.chest], measurement: .bodyweight, overload: false),
    ]

    // MARK: - Quads & glutes

    private static let quadGluteExercises: [Exercise] = [
        ex("barbell-back-squat", "Barbell Back Squat", .quads, .barbell, .squat, .squat, secondary: [.glutes, .hamstrings]),
        ex("front-squat", "Front Squat", .quads, .barbell, .squat, .squat, secondary: [.glutes, .core]),
        ex("goblet-squat", "Goblet Squat", .quads, .dumbbell, .squat, .squat, secondary: [.glutes]),
        ex("hack-squat", "Hack Squat", .quads, .machine, .squat, .squat, secondary: [.glutes]),
        ex("leg-press", "Leg Press", .quads, .machine, .squat, .squat, secondary: [.glutes]),
        ex("belt-squat", "Belt Squat", .quads, .machine, .squat, .squat, secondary: [.glutes]),
        ex("smith-squat", "Smith Machine Squat", .quads, .machine, .squat, .squat, secondary: [.glutes]),
        ex("pendulum-squat", "Pendulum Squat", .quads, .machine, .squat, .squat, secondary: [.glutes]),
        ex("leg-extension", "Leg Extension", .quads, .machine, .isolation, .isolation),
        ex("hip-thrust", "Hip Thrust (Barbell)", .glutes, .barbell, .hinge, .hinge, secondary: [.hamstrings], aliases: ["hip thrust", "barbell hip thrust", "glute"], measurement: .repsWithOptionalWeight, overload: true),
        ex("smith-hip-thrust", "Hip Thrust (Smith)", .glutes, .machine, .hinge, .hinge, secondary: [.hamstrings], aliases: ["smith hip thrust", "smith machine hip thrust", "hip thrust", "glute"]),
        ex("glute-bridge", "Glute Bridge (Bodyweight)", .glutes, .bodyweight, .hinge, .hinge, secondary: [.hamstrings], aliases: ["glute bridge", "bridge", "glute"], measurement: .repsWithOptionalWeight, overload: false),
        ex("single-leg-glute-bridge", "Single-Leg Glute Bridge", .glutes, .bodyweight, .hinge, .hinge, secondary: [.hamstrings], laterality: .unilateral, measurement: .repsWithOptionalWeight, overload: false),
        ex("cable-kickback", "Glute Kickback (Cable)", .glutes, .cable, .isolation, .isolation, laterality: .unilateral, aliases: ["cable kickback", "cable glute kickback", "glute kickback", "kickback"]),
        ex("hip-abduction", "Hip Abduction", .glutes, .machine, .isolation, .isolation, laterality: .unilateral),
        ex("hip-adduction", "Hip Adduction", .quads, .machine, .isolation, .isolation, laterality: .unilateral),
        ex("forward-lunge", "Forward Lunge", .quads, .dumbbell, .lunge, .lunge, secondary: [.glutes], laterality: .alternating, aliases: ["forward lunges"]),
        ex("walking-lunge", "Walking Lunge", .quads, .dumbbell, .lunge, .lunge, secondary: [.glutes], laterality: .alternating, aliases: ["walking lunges"]),
        ex("reverse-lunge", "Reverse Lunge", .quads, .dumbbell, .lunge, .lunge, secondary: [.glutes], laterality: .alternating),
        ex("bulgarian-split-squat", "Bulgarian Split Squat", .quads, .dumbbell, .lunge, .lunge, secondary: [.glutes], laterality: .unilateral, measurement: .repsWithOptionalWeight, overload: true),
        ex("step-up", "Step-Up", .quads, .dumbbell, .lunge, .lunge, secondary: [.glutes], laterality: .unilateral, measurement: .repsWithOptionalWeight, overload: true),
        ex("sissy-squat", "Sissy Squat", .quads, .bodyweight, .squat, .squat, measurement: .bodyweight, overload: false),
    ]

    // MARK: - Hamstrings

    private static let hamstringExercises: [Exercise] = [
        ex("romanian-deadlift", "Romanian Deadlift (Barbell)", .hamstrings, .barbell, .hinge, .hinge, secondary: [.glutes], aliases: ["RDL", "rdl", "romanian deadlift", "barbell rdl"]),
        ex("dumbbell-rdl", "Romanian Deadlift (Dumbbell)", .hamstrings, .dumbbell, .hinge, .hinge, secondary: [.glutes], aliases: ["dumbbell rdl", "db rdl", "dumbbell romanian deadlift"]),
        ex("single-leg-rdl", "Single-Leg Romanian Deadlift", .hamstrings, .dumbbell, .hinge, .hinge, secondary: [.glutes], laterality: .unilateral, aliases: ["single leg RDL", "single leg rdl"]),
        ex("stiff-leg-deadlift", "Stiff-Leg Deadlift", .hamstrings, .barbell, .hinge, .hinge, secondary: [.glutes]),
        ex("leg-curl", "Leg Curl", .hamstrings, .machine, .isolation, .isolation),
        ex("seated-leg-curl", "Seated Leg Curl", .hamstrings, .machine, .isolation, .isolation),
        ex("nordic-curl", "Nordic Curl", .hamstrings, .bodyweight, .isolation, .isolation, measurement: .bodyweight, overload: false),
        ex("glute-ham-raise", "Glute Ham Raise", .hamstrings, .machine, .isolation, .isolation, secondary: [.glutes]),
        ex("good-morning", "Good Morning", .hamstrings, .barbell, .hinge, .hinge, secondary: [.glutes, .back]),
        ex("cable-pull-through", "Cable Pull-Through", .hamstrings, .cable, .hinge, .hinge, secondary: [.glutes]),
    ]

    // MARK: - Calves

    private static let calfExercises: [Exercise] = [
        ex("standing-calf-raise", "Standing Calf Raise", .calves, .machine, .isolation, .isolation),
        ex("seated-calf-raise", "Seated Calf Raise", .calves, .machine, .isolation, .isolation),
        ex("donkey-calf-raise", "Donkey Calf Raise", .calves, .machine, .isolation, .isolation),
        ex("leg-press-calf-raise", "Leg Press Calf Raise", .calves, .machine, .isolation, .isolation),
        ex("single-leg-calf-raise", "Single-Leg Calf Raise", .calves, .bodyweight, .isolation, .isolation, laterality: .unilateral, measurement: .bodyweight, overload: false),
    ]

    // MARK: - Core

    private static let coreExercises: [Exercise] = [
        ex("plank", "Plank", .core, .bodyweight, .core, .core, measurement: .time, overload: false),
        ex("side-plank", "Side Plank", .core, .bodyweight, .core, .core, laterality: .unilateral, measurement: .time, overload: false),
        ex("hollow-hold", "Hollow Hold", .core, .bodyweight, .core, .core, measurement: .time, overload: false),
        ex("dead-hang", "Dead Hang", .back, .bodyweight, .pull, .verticalPull, measurement: .time, overload: false),
        ex("crunch", "Crunch", .core, .bodyweight, .core, .core, measurement: .repsWithOptionalWeight, overload: false),
        ex("bicycle-crunch", "Bicycle Crunch", .core, .bodyweight, .core, .rotation, measurement: .reps, overload: false),
        ex("mountain-climber", "Mountain Climber", .core, .bodyweight, .conditioning, .conditioning, secondary: [.quads], measurement: .reps, overload: false),
        ex("bird-dog", "Bird Dog", .core, .bodyweight, .core, .core, laterality: .alternating, measurement: .reps, overload: false),
        ex("dead-bug", "Dead Bug", .core, .bodyweight, .core, .core, measurement: .bodyweight, overload: false),
        ex("bench-crunch", "Bench Crunch", .core, .bodyweight, .core, .core, measurement: .repsWithOptionalWeight, overload: false),
        ex("bench-russian-twist", "Bench Russian Twist", .core, .bodyweight, .core, .rotation, measurement: .repsWithOptionalWeight, overload: false),
        ex("bench-leg-lift", "Bench Leg Lift", .core, .bodyweight, .core, .core, measurement: .repsWithOptionalWeight, overload: false),
        ex("plank-row", "Plank Row", .core, .dumbbell, .core, .horizontalPull, secondary: [.back], aliases: ["renegade row"], measurement: .repsWithOptionalWeight, overload: false),
        ex("hanging-leg-raise", "Hanging Leg Raise", .core, .bodyweight, .core, .core, measurement: .repsWithOptionalWeight, overload: false),
        ex("toes-to-bar", "Toes to Bar", .core, .bodyweight, .core, .core, measurement: .bodyweight, overload: false),
        ex("russian-twist", "Russian Twist", .core, .bodyweight, .core, .rotation, measurement: .repsWithOptionalWeight, overload: false),
        ex("cable-crunch", "Cable Crunch", .core, .cable, .core, .core),
        ex("ab-wheel-rollout", "Ab Wheel Rollout", .core, .bodyweight, .core, .core, measurement: .bodyweight, overload: false),
        ex("v-up", "V-Up", .core, .bodyweight, .core, .core, measurement: .reps, overload: false),
        ex("flutter-kick", "Flutter Kick", .core, .bodyweight, .core, .core, measurement: .reps, overload: false),
        ex("superman", "Superman", .core, .bodyweight, .core, .core, secondary: [.back], measurement: .reps, overload: false),
        ex("sit-up", "Sit-Up", .core, .bodyweight, .core, .core, aliases: ["situp"], measurement: .repsWithOptionalWeight, overload: false),
        ex("decline-sit-up", "Decline Sit-Up", .core, .bodyweight, .core, .core, aliases: ["decline situp"], measurement: .repsWithOptionalWeight, overload: false),
        ex("weighted-sit-up", "Weighted Sit-Up", .core, .dumbbell, .core, .core),
        ex("pallof-press", "Pallof Press", .core, .cable, .core, .rotation),
        ex("cable-woodchop", "Cable Woodchop", .core, .cable, .core, .rotation),
        ex("copenhagen-plank", "Copenhagen Plank", .core, .bodyweight, .core, .core, laterality: .unilateral, measurement: .time, overload: false),
    ]

    // MARK: - Full body

    private static let fullBodyExercises: [Exercise] = [
        ex("kettlebell-swing", "Kettlebell Swing", .fullBody, .kettlebell, .hinge, .hinge, secondary: [.glutes, .hamstrings]),
        ex("kettlebell-clean", "Kettlebell Clean", .fullBody, .kettlebell, .olympic, .olympic, secondary: [.back, .shoulders]),
        ex("kettlebell-snatch", "Kettlebell Snatch", .fullBody, .kettlebell, .olympic, .olympic, secondary: [.shoulders, .glutes]),
        ex("clean-and-press", "Clean and Press", .fullBody, .barbell, .olympic, .olympic, secondary: [.shoulders]),
        ex("power-clean", "Power Clean", .fullBody, .barbell, .olympic, .olympic, secondary: [.back, .glutes]),
        ex("thruster", "Thruster", .fullBody, .barbell, .olympic, .olympic, secondary: [.quads, .shoulders]),
        ex("farmer-carry", "Farmer's Carry", .fullBody, .dumbbell, .carry, .carry, secondary: [.core, .back], measurement: .weightAndTime, progression: .addDuration, overload: false),
        ex("suitcase-carry", "Suitcase Carry", .fullBody, .dumbbell, .carry, .carry, secondary: [.core], laterality: .unilateral, measurement: .distance, overload: false),
        ex("overhead-carry", "Overhead Carry", .fullBody, .dumbbell, .carry, .carry, secondary: [.shoulders, .core], measurement: .distance, overload: false),
        ex("sled-push", "Sled Push", .fullBody, .machine, .carry, .carry, secondary: [.quads, .glutes], measurement: .distance, overload: false),
        ex("wall-ball", "Wall Ball", .fullBody, .dumbbell, .conditioning, .conditioning, secondary: [.quads, .shoulders]),
        ex("battle-ropes", "Battle Ropes", .fullBody, .bodyweight, .conditioning, .conditioning, secondary: [.shoulders], measurement: .time, overload: false),
        ex("box-jump", "Box Jump", .fullBody, .bodyweight, .conditioning, .conditioning, secondary: [.quads], measurement: .bodyweight, overload: false),
        ex("burpee", "Burpee", .fullBody, .bodyweight, .conditioning, .conditioning, measurement: .bodyweight, overload: false),
        ex("rower", "Rowing Machine", .fullBody, .machine, .conditioning, .conditioning, secondary: [.back, .quads], measurement: .time, overload: false),
    ]

    // MARK: - Builder

    private static func ex(
        _ id: String,
        _ name: String,
        _ primary: MuscleGroup,
        _ equipment: EquipmentType,
        _ category: ExerciseCategory,
        _ pattern: MovementPattern,
        secondary: [MuscleGroup] = [],
        laterality: Laterality = .bilateral,
        aliases: [String] = [],
        measurement: MeasurementUnit? = nil,
        progression: ProgressionMethod? = nil,
        overload: Bool? = nil
    ) -> Exercise {
        Exercise(
            id: id,
            name: name,
            aliases: aliases,
            primaryMuscleGroup: primary,
            secondaryMuscleGroups: secondary,
            equipment: equipment,
            category: category,
            movementPattern: pattern,
            laterality: laterality,
            measurementUnit: measurement,
            progressionMethod: progression,
            supportsProgressiveOverload: overload
        )
    }
}
