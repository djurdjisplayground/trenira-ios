import Foundation

/// Answers from the movement-companion onboarding. Stored separately from strength workouts.
struct CompanionProfile: Codable, Equatable {
    var goal: MovementGoal?
    var barriers: [MovementBarrier]
    var primaryBarrier: MovementBarrier?
    var formats: [MovementFormat]
    var skipped: Bool
    var updatedAt: Date

    init(
        goal: MovementGoal? = nil,
        barriers: [MovementBarrier] = [],
        primaryBarrier: MovementBarrier? = nil,
        formats: [MovementFormat] = [],
        skipped: Bool = false,
        updatedAt: Date = .now
    ) {
        self.goal = goal
        self.barriers = barriers
        self.primaryBarrier = primaryBarrier
        self.formats = formats
        self.skipped = skipped
        self.updatedAt = updatedAt
    }

    /// A saved profile means the launch questions have been answered or skipped.
    var hasAnswers: Bool {
        goal != nil || !barriers.isEmpty || !formats.isEmpty
    }
}

enum MovementGoal: String, Codable, CaseIterable, Identifiable {
    case feelMoreActive
    case feelStronger
    case findRhythm
    case makeTimeForMyself

    var id: String { rawValue }

    var title: String {
        switch self {
        case .feelMoreActive: "Feel more active"
        case .feelStronger: "Feel stronger"
        case .findRhythm: "Find my rhythm"
        case .makeTimeForMyself: "Make time for myself"
        }
    }

    var homeLine: String {
        switch self {
        case .feelMoreActive: "Your aim is to feel more active."
        case .feelStronger: "Your aim is to feel stronger."
        case .findRhythm: "Your aim is to find a rhythm that fits."
        case .makeTimeForMyself: "Your aim is to make time for yourself."
        }
    }
}

enum MovementBarrier: String, Codable, CaseIterable, Identifiable {
    case notEnoughTime
    case difficultyStarting
    case unpredictableSchedule
    case cantGetToGym
    case guilt
    case returningAfterBreak

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notEnoughTime: "Not enough time"
        case .difficultyStarting: "Difficulty getting started"
        case .unpredictableSchedule: "Unpredictable schedule"
        case .cantGetToGym: "Can't get to the gym"
        case .guilt: "Guilt about taking time for myself"
        case .returningAfterBreak: "Difficulty returning after a break"
        }
    }
}

enum MovementFormat: String, Codable, CaseIterable, Identifiable {
    case strength
    case walking
    case videos
    case yoga
    case notSure

    var id: String { rawValue }

    var title: String {
        switch self {
        case .strength: "Strength training"
        case .walking: "Walking"
        case .videos: "Workout videos"
        case .yoga: "Yoga or Pilates-inspired movement"
        case .notSure: "Not sure yet"
        }
    }
}

enum MovementMinutes: Int, CaseIterable, Identifiable {
    case two = 2
    case five = 5
    case ten = 10
    case twenty = 20

    var id: Int { rawValue }

    var title: String { "\(rawValue) minutes" }
}

enum MovementEnergy: String, CaseIterable, Identifiable {
    case low
    case okay
    case high

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low: "Low"
        case .okay: "Okay"
        case .high: "High"
        }
    }
}

enum MovementSetting: String, CaseIterable, Identifiable {
    case home
    case outdoors
    case gym

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .outdoors: "Outdoors"
        case .gym: "Gym"
        }
    }
}

struct MovementCheckIn: Equatable {
    var minutes: MovementMinutes
    var energy: MovementEnergy
    var setting: MovementSetting
}

/// A saved strength plan the recommender may offer. This is not a `Workout`.
struct SavedStrengthOption: Equatable, Identifiable {
    var id: UUID
    var name: String
}

enum MovementSuggestionKind: String, Equatable {
    case walk
    case strengthWorkout
    case video
    case unavailable
}

struct MovementSuggestion: Equatable, Identifiable {
    var id: String
    var kind: MovementSuggestionKind
    var title: String
    var detail: String
    var reason: String
    /// True when the app can start a saved workout, record a walk, or open a saved video.
    var isActionable: Bool
    var workoutId: UUID?
    var videoId: UUID?
}
