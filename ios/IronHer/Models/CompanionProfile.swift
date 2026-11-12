import Foundation

/// Answers from the movement-companion onboarding. Stored separately from strength workouts.
struct CompanionProfile: Codable, Equatable {
    var goal: MovementGoal?
    var barriers: [MovementBarrier]
    var primaryBarrier: MovementBarrier?
    var formats: [MovementFormat]
    var skipped: Bool
    var updatedAt: Date
    /// Equipment chosen in onboarding. Missing on older profiles.
    var equipment: [MovementEquipment]?
    /// True when floor-based ideas should be left out. Missing on older profiles.
    var avoidFloorMoves: Bool?
    /// Catalog categories the person enjoys. Missing on older profiles.
    var preferredKinds: [String]?

    init(
        goal: MovementGoal? = nil,
        barriers: [MovementBarrier] = [],
        primaryBarrier: MovementBarrier? = nil,
        formats: [MovementFormat] = [],
        skipped: Bool = false,
        updatedAt: Date = .now,
        equipment: [MovementEquipment]? = nil,
        avoidFloorMoves: Bool? = nil,
        preferredKinds: [String]? = nil
    ) {
        self.goal = goal
        self.barriers = barriers
        self.primaryBarrier = primaryBarrier
        self.formats = formats
        self.skipped = skipped
        self.updatedAt = updatedAt
        self.equipment = equipment
        self.avoidFloorMoves = avoidFloorMoves
        self.preferredKinds = preferredKinds
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
    case feelMoreConfident

    var id: String { rawValue }

    var title: String {
        switch self {
        case .feelMoreActive: "Feel more active"
        case .feelStronger: "Build strength"
        case .findRhythm: "Find my rhythm again"
        case .makeTimeForMyself: "Have a little time for myself"
        case .feelMoreConfident: "Feel more confident about moving"
        }
    }

    var homeLine: String {
        switch self {
        case .feelMoreActive: "Your aim is to feel more active."
        case .feelStronger: "Your aim is to build strength."
        case .findRhythm: "Your aim is to find your rhythm again."
        case .makeTimeForMyself: "Your aim is a little time for yourself."
        case .feelMoreConfident: "Your aim is to feel more confident about moving."
        }
    }
}

enum MovementBarrier: String, Codable, CaseIterable, Identifiable {
    case notEnoughTime
    case unpredictableSchedule
    case lowEnergy
    case difficultyStarting
    case returningAfterBreak
    case guilt
    case cantGetToGym

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notEnoughTime: "Not enough time"
        case .unpredictableSchedule: "Unpredictable days"
        case .lowEnergy: "Low energy"
        case .difficultyStarting: "Difficulty getting started"
        case .returningAfterBreak: "Difficulty returning after a break"
        case .guilt: "Guilt about taking time for myself"
        case .cantGetToGym: "Can't get to the gym"
        }
    }
}

enum MovementFormat: String, Codable, CaseIterable, Identifiable {
    case strength
    case walking
    case videos
    case yoga
    case dancing
    case withBaby
    case other
    case notSure

    var id: String { rawValue }

    /// Categories a person can choose. "Not sure yet" stays for older answers.
    static var choosable: [MovementFormat] {
        allCases.filter { $0 != .notSure }
    }

    var title: String {
        switch self {
        case .strength: "Strength training"
        case .walking: "Walking"
        case .videos: "Saved workout videos"
        case .yoga: "Yoga"
        case .dancing: "Dancing"
        case .withBaby: "Movement with baby"
        case .other: "Other movement"
        case .notSure: "Not sure yet"
        }
    }

    var summary: String {
        switch self {
        case .strength: "Your saved workouts, when you want them."
        case .walking: "A walk for the time you have."
        case .videos: "A video you already saved. It opens outside trenira."
        case .yoga: "Movement you choose. trenira does not include a guided class."
        case .dancing: "Put on music and move. trenira does not include a dance class."
        case .withBaby: "Time to move with your baby nearby. Not an exercise for the baby."
        case .other: "Any movement that fits today."
        case .notSure: "You can decide later."
        }
    }

    var symbolName: String {
        switch self {
        case .strength: "figure.strengthtraining.traditional"
        case .walking: "figure.walk"
        case .videos: "play.rectangle"
        case .yoga: "figure.mind.and.body"
        case .dancing: "figure.dance"
        case .withBaby: "figure.and.child.holdinghands"
        case .other: "sparkles"
        case .notSure: "questionmark"
        }
    }

    var recordKind: MovementRecordKind? {
        switch self {
        case .walking: .walking
        case .videos: .externalVideo
        case .yoga: .yoga
        case .dancing: .dancing
        case .withBaby: .withBaby
        case .other: .other
        case .strength, .notSure: nil
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
    case selfDirected
    case unavailable
}

struct MovementSuggestion: Equatable, Identifiable {
    var id: String
    var kind: MovementSuggestionKind
    var title: String
    var detail: String
    var reason: String
    /// True when the app can start a saved workout, record a walk, open a saved video, or record a chosen category.
    var isActionable: Bool
    var workoutId: UUID?
    var videoId: UUID?
    /// Set when the suggestion is a category the person records themselves.
    var format: MovementFormat?

    init(
        id: String,
        kind: MovementSuggestionKind,
        title: String,
        detail: String,
        reason: String,
        isActionable: Bool,
        workoutId: UUID? = nil,
        videoId: UUID? = nil,
        format: MovementFormat? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.reason = reason
        self.isActionable = isActionable
        self.workoutId = workoutId
        self.videoId = videoId
        self.format = format
    }
}
