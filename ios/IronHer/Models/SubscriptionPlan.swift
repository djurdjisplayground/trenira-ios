import Foundation

enum SubscriptionTier: String, Codable, CaseIterable {
    case free
    case premium

    var label: String {
        switch self {
        case .free: return "Free"
        case .premium: return "Premium"
        }
    }
}

/// Free = Everything you need to track. Premium = Go beyond tracking.
/// Access control is centralized in `SubscriptionStore.hasAccess(to:)`.
enum SubscriptionFeature: CaseIterable, Hashable {
    // Free — Track + organize + basic progression
    case workoutPlans
    case exerciseTracking
    case workoutLibrary
    case weeklyTracking
    case basicHistory
    case exerciseLibrary
    case exerciseSync
    case progressionAutomation
    case customProgression
    case multipleLanguages
    case appearanceModes

    // Premium — Expand what trenira can do
    case unlimitedWorkoutPlans
    case smartProgressHistory
    case progressTrends
    case smarterProgressionAnalysis
    case adaptWorkout
    case replaceExercise
    case generateWorkout
    case regenerateWorkout

    var title: String {
        switch self {
        case .workoutPlans: return "Create up to 3 workouts"
        case .exerciseTracking: return "Track sets, reps and weight"
        case .workoutLibrary: return "Personal workout library"
        case .weeklyTracking: return "Track this week"
        case .basicHistory: return "Workout history"
        case .exerciseLibrary: return "Exercise library & custom exercises"
        case .exerciseSync: return "Automatic synchronization between workouts"
        case .progressionAutomation: return "Automatic progression"
        case .customProgression: return "Custom progression rules"
        case .multipleLanguages: return "Multiple languages"
        case .appearanceModes: return "Light & Dark Mode"
        case .unlimitedWorkoutPlans: return "Unlimited workouts"
        case .smartProgressHistory: return "Advanced progress insights"
        case .progressTrends: return "Progress trends"
        case .smarterProgressionAnalysis: return "Smarter progression analysis"
        case .adaptWorkout: return "Equipment-aware adaptations"
        case .replaceExercise: return "Exercise substitutions"
        case .generateWorkout: return "AI workout generation"
        case .regenerateWorkout: return "Workout regeneration"
        }
    }

    var detail: String? {
        switch self {
        case .exerciseTracking:
            return "Log your sessions clearly — then keep moving."
        case .exerciseSync:
            return "When an exercise updates in one workout, it stays in sync everywhere you use it."
        case .progressionAutomation:
            return "Define how you progress. trenira remembers and updates your next targets."
        case .customProgression:
            return "Rules for weight, reps, duration, and bodyweight — on your terms."
        case .basicHistory:
            return "Look back at completed workouts, weights, reps, and sets."
        case .multipleLanguages:
            return "Train in the language that feels natural."
        case .appearanceModes:
            return "A calm interface in light or dark."
        case .smartProgressHistory:
            return "See patterns in your training with clearer, deeper insights."
        case .progressTrends:
            return "Follow how your strength changes over time."
        case .smarterProgressionAnalysis:
            return "Understand what’s working — without noise or clutter."
        case .adaptWorkout:
            return "Adjust when equipment changes, without starting over."
        case .replaceExercise:
            return "Swap a movement when needed — progression stays with you."
        case .generateWorkout:
            return "Describe your goal and get a structured plan you can still edit."
        case .regenerateWorkout:
            return "Refresh a plan while keeping your intention and progression context."
        case .unlimitedWorkoutPlans:
            return "Build as many routines as your training needs."
        case .workoutPlans:
            return "Organize the workouts you actually train."
        default:
            return nil
        }
    }

    /// Contextual upgrade headline shown on paywalls.
    var upgradeHeadline: String {
        switch self {
        case .unlimitedWorkoutPlans:
            return "Room to grow."
        case .smartProgressHistory, .progressTrends, .smarterProgressionAnalysis:
            return "See your progress more clearly."
        case .generateWorkout:
            return "Start from your goal."
        case .regenerateWorkout, .adaptWorkout:
            return "Adapt without starting over."
        case .replaceExercise:
            return "Keep training when plans change."
        default:
            return "Go beyond tracking."
        }
    }

    var upgradeBody: String {
        switch self {
        case .unlimitedWorkoutPlans:
            return "Premium expands trenira with unlimited workouts — so your library can grow with you."
        case .smartProgressHistory, .progressTrends, .smarterProgressionAnalysis:
            return "Go beyond session logs with insights, trends, and clearer progression analysis."
        case .generateWorkout:
            return "Let trenira draft a plan around what you want to achieve — you stay in control."
        case .regenerateWorkout, .adaptWorkout:
            return "Change equipment or available time while keeping your progression intact."
        case .replaceExercise:
            return "Swap exercises when equipment isn’t available — without losing your overall plan."
        default:
            return "Premium expands what trenira can do: deeper insights, smarter adaptations, and unlimited workouts."
        }
    }

    var systemImage: String {
        switch self {
        case .progressionAutomation: return "chart.line.uptrend.xyaxis"
        case .customProgression: return "slider.horizontal.3"
        case .exerciseSync: return "arrow.triangle.2.circlepath"
        case .smartProgressHistory, .progressTrends, .smarterProgressionAnalysis: return "chart.xyaxis.line"
        case .generateWorkout: return "sparkles"
        case .regenerateWorkout: return "arrow.triangle.2.circlepath"
        case .adaptWorkout: return "building.2"
        case .replaceExercise: return "arrow.left.arrow.right"
        case .unlimitedWorkoutPlans: return "infinity"
        case .basicHistory: return "clock"
        case .multipleLanguages: return "globe"
        case .appearanceModes: return "circle.lefthalf.filled"
        default: return "checkmark"
        }
    }

    /// Marketing list for the Free plan card.
    static let freeFeatures: [SubscriptionFeature] = [
        .workoutPlans,
        .exerciseTracking,
        .exerciseSync,
        .customProgression,
        .basicHistory,
        .multipleLanguages,
        .appearanceModes,
    ]

    /// Marketing list for the Premium plan card.
    static let premiumFeatures: [SubscriptionFeature] = [
        .unlimitedWorkoutPlans,
        .smartProgressHistory,
        .progressTrends,
        .generateWorkout,
        .regenerateWorkout,
        .adaptWorkout,
        .smarterProgressionAnalysis,
    ]
}
