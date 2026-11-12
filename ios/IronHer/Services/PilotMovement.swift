import Foundation

struct MovementPose: Identifiable, Codable, Hashable {
    var id: String
    var assetName: String
    var title: String
    var instruction: String
}

struct GuidedMovement: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var summary: String
    var poses: [MovementPose]
}

enum PilotMovementCatalog {
    static let safetyNote = "Move only in a range that feels comfortable, and stop if something doesn't feel right. These are general ideas, not a treatment, a workout plan, or postpartum advice."

    static let movements: [GuidedMovement] = [gentleReach, sideStretch, shoulderRolls]

    static let gentleReach = GuidedMovement(
        id: "gentle-reach",
        title: "Gentle reach",
        summary: "Move within a comfortable range.",
        poses: [
            MovementPose(id: "start", assetName: "gentle_reach_start", title: "Start", instruction: "Stand comfortably with your arms relaxed."),
            MovementPose(id: "reach", assetName: "gentle_reach_reach", title: "Reach", instruction: "Slowly raise your arms only as far as feels comfortable."),
            MovementPose(id: "relax", assetName: "gentle_reach_relax", title: "Relax", instruction: "Lower your arms slowly. Repeat if you'd like.")
        ]
    )

    static let sideStretch = GuidedMovement(
        id: "side-stretch",
        title: "Comfortable side stretch",
        summary: "A small side bend, only as far as you want.",
        poses: [
            MovementPose(id: "start", assetName: "side_stretch_start", title: "Start", instruction: "Stand or sit comfortably, with your arms relaxed."),
            MovementPose(id: "middle", assetName: "side_stretch_middle", title: "Side", instruction: "Lean gently to one side, only as far as feels comfortable."),
            MovementPose(id: "finish", assetName: "side_stretch_finish", title: "Finish", instruction: "Come back to the middle. The other side is optional.")
        ]
    )

    static let shoulderRolls = GuidedMovement(
        id: "shoulder-rolls",
        title: "Shoulder rolls",
        summary: "An easy circle, with no set number.",
        poses: [
            MovementPose(id: "start", assetName: "shoulder_rolls_start", title: "Start", instruction: "Let your shoulders rest."),
            MovementPose(id: "middle", assetName: "shoulder_rolls_middle", title: "Roll", instruction: "Circle your shoulders slowly, only through a range that feels easy."),
            MovementPose(id: "finish", assetName: "shoulder_rolls_finish", title: "Finish", instruction: "Let them rest again. Repeat if you'd like.")
        ]
    )

    static var illustrationAssetNames: [String] {
        movements.flatMap { $0.poses.map(\.assetName) }
    }
}

enum PilotTimeChoice: Int, CaseIterable, Identifiable {
    case two = 2
    case five = 5
    case ten = 10
    case fifteen = 15
    case twenty = 20

    var id: Int { rawValue }

    var title: String {
        self == .twenty ? "20+" : "\(rawValue)"
    }

    var accessibilityTitle: String {
        self == .twenty ? "20 or more minutes" : "\(rawValue) minutes"
    }
}

struct PilotSuggestion: Identifiable, Equatable {
    enum Action: String, Equatable {
        case guided
        case walk
        case danceStretch
        case manual
    }

    var action: Action
    var title: String
    var detail: String
    var id: String { action.rawValue }
}

enum PilotSuggestions {
    /// Energy never removes a choice. Manual movement is always one of the choices.
    static func make(minutes: Int, energy: MovementEnergy?) -> [PilotSuggestion] {
        let comfort = energy == .low ? " Keep the range easy." : ""
        let guided = minutes <= 5
            ? "One or two gentle movements can fit. Each one is optional.\(comfort)"
            : "Three gentle movements are here if you want them. Stop whenever you need to.\(comfort)"
        return [
            PilotSuggestion(action: .guided, title: "Gentle guided movement", detail: guided),
            PilotSuggestion(action: .walk, title: "Walk", detail: "About \(minutes) minutes, or stop whenever you need to."),
            PilotSuggestion(action: .danceStretch, title: "Dance or stretch", detail: "Put on music, or move in a way that feels good.\(comfort)"),
            PilotSuggestion(action: .manual, title: "Something else", detail: "Do your own thing. Record the time you actually moved.")
        ]
    }
}

/// Active time only. Pauses, and time after leaving, are not included.
struct MovementSessionClock: Equatable {
    private(set) var accumulated: TimeInterval = 0
    private(set) var runningSince: Date?
    /// Foreground time only. Wall-clock jumps and background gaps are not added.
    private(set) var runningSinceUptime: TimeInterval?

    init(accumulated: TimeInterval = 0) {
        self.accumulated = max(0, accumulated)
        self.runningSince = nil
        self.runningSinceUptime = nil
    }

    var isRunning: Bool { runningSince != nil || runningSinceUptime != nil }

    mutating func start(at now: Date) {
        guard runningSince == nil else { return }
        runningSince = now
    }

    mutating func pause(at now: Date) {
        guard let runningSince else { return }
        accumulated += max(0, now.timeIntervalSince(runningSince))
        self.runningSince = nil
    }

    mutating func resume(at now: Date) {
        guard runningSince == nil else { return }
        runningSince = now
    }

    /// A relaunch does not add the gap since the clock was last known to be running.
    mutating func settleAfterRestore() {
        runningSince = nil
        runningSinceUptime = nil
    }

    func elapsed(at now: Date) -> TimeInterval {
        var total = accumulated
        if let runningSince {
            total += max(0, now.timeIntervalSince(runningSince))
        }
        return max(0, total)
    }

    mutating func begin(atUptime uptime: TimeInterval) {
        guard runningSinceUptime == nil else { return }
        runningSinceUptime = uptime
    }

    mutating func pause(atUptime uptime: TimeInterval) {
        guard let runningSinceUptime else { return }
        accumulated += max(0, uptime - runningSinceUptime)
        self.runningSinceUptime = nil
    }

    mutating func resume(atUptime uptime: TimeInterval) {
        guard runningSinceUptime == nil else { return }
        runningSinceUptime = uptime
    }

    func elapsed(atUptime uptime: TimeInterval) -> TimeInterval {
        var total = accumulated
        if let runningSinceUptime {
            total += max(0, uptime - runningSinceUptime)
        }
        return max(0, total)
    }
}

struct PausedMovementDraft: Codable, Equatable {
    var ownerId: String
    var kind: MovementRecordKind
    var title: String
    var plannedMinutes: Int
    var movementIDs: [String]
    var movementIndex: Int
    var accumulatedSeconds: TimeInterval
    var catalogID: String? = nil
    var stepIndex: Int? = nil
}

enum PausedMovementDraftStore {
    static let storageKey = "trenira.pausedMovement.v1"

    static func load(ownerId: String, defaults: UserDefaults = .standard) -> PausedMovementDraft? {
        all(defaults: defaults).first { $0.ownerId == ownerId }
    }

    static func save(_ draft: PausedMovementDraft, defaults: UserDefaults = .standard) {
        var drafts = all(defaults: defaults).filter { $0.ownerId != draft.ownerId }
        drafts.append(draft)
        guard let data = try? JSONEncoder().encode(drafts) else { return }
        defaults.set(data, forKey: storageKey)
    }

    static func clear(ownerId: String, defaults: UserDefaults = .standard) {
        let drafts = all(defaults: defaults).filter { $0.ownerId != ownerId }
        guard let data = try? JSONEncoder().encode(drafts) else { return }
        defaults.set(data, forKey: storageKey)
    }

    static func removeAll(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
    }

    private static func all(defaults: UserDefaults) -> [PausedMovementDraft] {
        guard let data = defaults.data(forKey: storageKey),
              let drafts = try? JSONDecoder().decode([PausedMovementDraft].self, from: data) else {
            return []
        }
        return drafts
    }
}

enum MomentRecordBuilder {
    static func record(
        kind: MovementRecordKind,
        title: String,
        elapsed: TimeInterval,
        plannedMinutes: Int,
        ownerId: String,
        now: Date = .now
    ) -> MovementRecord {
        MovementRecord(
            kind: kind,
            title: title,
            completedAt: now,
            actualMinutes: 0,
            plannedMinutes: plannedMinutes,
            ownerId: ownerId,
            actualDurationSeconds: max(0, elapsed)
        )
    }
}
