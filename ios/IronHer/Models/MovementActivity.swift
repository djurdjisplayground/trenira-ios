import Foundation

enum MovementRecordKind: String, Codable, Equatable {
    case walking
    case externalVideo
    case yoga
    case dancing
    case withBaby
    case other
    case guided
    case stretching

    /// Value sent as `activity_type`. Free-text titles are never used.
    var analyticsActivityType: String {
        switch self {
        case .walking: "walking"
        case .externalVideo: "external_video"
        case .yoga: "yoga"
        case .dancing: "dancing"
        case .withBaby: "with_baby"
        case .other: "other"
        case .guided: "guided"
        case .stretching: "stretching"
        }
    }

    var historyKind: MovementHistoryKind {
        switch self {
        case .walking: .walking
        case .externalVideo: .externalVideo
        case .yoga: .yoga
        case .dancing: .dancing
        case .withBaby: .withBaby
        case .other: .other
        case .guided: .guided
        case .stretching: .stretching
        }
    }

    var recordTitle: String {
        switch self {
        case .walking: "Walk"
        case .externalVideo: "Saved video"
        case .yoga: "Yoga"
        case .dancing: "Dancing"
        case .withBaby: "Movement with baby"
        case .other: "Other movement"
        case .guided: "Gentle guided movement"
        case .stretching: "Dance or stretch"
        }
    }
}

enum MovementRecordSource: String, Codable, Equatable {
    case guided
    case library
    case manual
}

enum MovementFeeling: String, Codable, CaseIterable, Identifiable {
    case calm
    case okay
    case energized
    case tired

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calm: "Calm"
        case .okay: "Okay"
        case .energized: "Energized"
        case .tired: "Tired"
        }
    }
}

/// A walk or video the person chose to record. Strength sessions are not stored here.
struct MovementRecord: Codable, Identifiable, Equatable {
    var id: UUID
    var kind: MovementRecordKind
    var title: String
    var completedAt: Date
    var actualMinutes: Int
    var plannedMinutes: Int?
    var feeling: MovementFeeling?
    var videoId: UUID?
    var ownerId: String
    /// Exact active time. Older records leave this nil and keep `actualMinutes`.
    var actualDurationSeconds: TimeInterval?
    /// When the movement happened. Older records leave this nil and use `completedAt`.
    var activityAt: Date?
    var source: MovementRecordSource?
    var notes: String?
    var createdAt: Date?
    var updatedAt: Date?
    var catalogID: String?
    var sessionID: UUID?
    /// Saved moments use "saved". Absent on older records.
    var completionStatus: String?

    init(
        id: UUID = UUID(),
        kind: MovementRecordKind,
        title: String,
        completedAt: Date = .now,
        actualMinutes: Int,
        plannedMinutes: Int? = nil,
        feeling: MovementFeeling? = nil,
        videoId: UUID? = nil,
        ownerId: String = "",
        actualDurationSeconds: TimeInterval? = nil,
        activityAt: Date? = nil,
        source: MovementRecordSource? = nil,
        notes: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        catalogID: String? = nil,
        sessionID: UUID? = nil,
        completionStatus: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.completedAt = completedAt
        self.plannedMinutes = plannedMinutes
        self.feeling = feeling
        self.videoId = videoId
        self.ownerId = ownerId
        self.activityAt = activityAt
        self.source = source
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.catalogID = catalogID
        self.sessionID = sessionID
        self.completionStatus = completionStatus
        if let actualDurationSeconds {
            let seconds = max(0, actualDurationSeconds)
            self.actualDurationSeconds = seconds
            self.actualMinutes = Int(seconds / 60)
        } else {
            self.actualDurationSeconds = nil
            self.actualMinutes = max(1, actualMinutes)
        }
    }

    /// Local calendar moment the diary and weekly reflection use.
    var activityDate: Date { activityAt ?? completedAt }

    /// Exact seconds when stored. Older minute-only records use whole minutes.
    var loggedSeconds: TimeInterval {
        if let actualDurationSeconds { return max(0, actualDurationSeconds) }
        return TimeInterval(max(0, actualMinutes) * 60)
    }

    var finishedEarlier: Bool {
        guard let plannedMinutes else { return false }
        if let actualDurationSeconds {
            return actualDurationSeconds < TimeInterval(plannedMinutes * 60)
        }
        return actualMinutes < plannedMinutes
    }
}

struct SavedVideo: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var title: String
    var urlString: String
    var durationMinutes: Int?
    var savedAt: Date
    var ownerId: String

    var url: URL? { URL(string: urlString) }
}

struct SavedVideoOption: Equatable, Identifiable {
    var id: UUID
    var title: String
    var durationMinutes: Int?
}

struct StrengthHistorySnapshot: Equatable, Identifiable {
    var id: UUID
    var title: String
    var completedAt: Date
}

enum MovementHistoryKind: String, Equatable {
    case strength
    case walking
    case externalVideo
    case yoga
    case dancing
    case withBaby
    case other
    case guided
    case stretching
}

struct MovementHistoryItem: Equatable, Identifiable {
    var id: String
    var kind: MovementHistoryKind
    var title: String
    var completedAt: Date
    /// Nil when the length was never stored, which is true for strength sessions.
    var actualMinutes: Int?
    var plannedMinutes: Int?
    var feeling: MovementFeeling?
    /// Exact active seconds when the session recorded them. Nil for older minute-only records.
    var actualDurationSeconds: TimeInterval? = nil
}

struct MovementWeekSummary: Equatable {
    var activityCount: Int
    var recordedMinutes: Int
    var kinds: [MovementHistoryKind]
    var strengthCountWithoutMinutes: Int
    /// Active time from exact seconds, or from whole minutes when seconds were never stored.
    var recordedActiveSeconds: TimeInterval = 0
}

enum MovementDurationFormat {
    /// Truncates fractional seconds. A short session is never shown as a whole minute.
    static func exact(_ seconds: TimeInterval) -> String {
        let whole = max(0, Int(seconds.rounded(.down)))
        let minutes = whole / 60
        let remain = whole % 60
        if minutes == 0 {
            return whole == 1 ? "1 second" : "\(whole) seconds"
        }
        if remain == 0 {
            return minutes == 1 ? "1 minute" : "\(minutes) minutes"
        }
        let minuteLabel = minutes == 1 ? "1 min" : "\(minutes) min"
        return "\(minuteLabel) \(remain) sec"
    }

    static func exactLabel(seconds: TimeInterval?, minutes: Int?) -> String {
        if let seconds { return exact(seconds) }
        if let minutes { return minutes == 1 ? "1 min" : "\(minutes) min" }
        return "Minutes not recorded"
    }
}

enum MovementJournal {
    static func items(
        records: [MovementRecord],
        strengthLogs: [StrengthHistorySnapshot]
    ) -> [MovementHistoryItem] {
        let recorded = records.map { record in
            MovementHistoryItem(
                id: "record-\(record.id.uuidString)",
                kind: record.kind.historyKind,
                title: record.title,
                completedAt: record.completedAt,
                actualMinutes: record.actualMinutes,
                plannedMinutes: record.plannedMinutes,
                feeling: record.feeling,
                actualDurationSeconds: record.actualDurationSeconds
            )
        }
        let strength = strengthLogs.map { log in
            MovementHistoryItem(
                id: "strength-\(log.id.uuidString)",
                kind: .strength,
                title: log.title,
                completedAt: log.completedAt,
                actualMinutes: nil,
                plannedMinutes: nil,
                feeling: nil
            )
        }
        return (recorded + strength).sorted { $0.completedAt > $1.completedAt }
    }

    static func weekSummary(items: [MovementHistoryItem], now: Date = .now) -> MovementWeekSummary {
        let week = items.filter { WorkoutWeekCalendar.calendar.isDate($0.completedAt, equalTo: now, toGranularity: .weekOfYear) }
        let kinds = MovementHistoryKind.allCasesIn(week)
        let activeSeconds = week.reduce(0.0) { total, item in
            if let seconds = item.actualDurationSeconds { return total + max(0, seconds) }
            if let minutes = item.actualMinutes { return total + TimeInterval(minutes * 60) }
            return total
        }
        return MovementWeekSummary(
            activityCount: week.count,
            recordedMinutes: week.compactMap(\.actualMinutes).reduce(0, +),
            kinds: kinds,
            strengthCountWithoutMinutes: week.filter { $0.kind == .strength }.count,
            recordedActiveSeconds: activeSeconds
        )
    }

    /// Never prints unknown strength time as zero minutes.
    static func weekLine(_ summary: MovementWeekSummary) -> String {
        if summary.activityCount == 0 {
            return "Nothing recorded this week. Your journey, at your pace."
        }
        let activities = summary.activityCount == 1 ? "1 activity" : "\(summary.activityCount) activities"
        if summary.recordedActiveSeconds <= 0 {
            return "Your movement this week: \(activities). Session length isn't recorded for every activity. Every session counts."
        }
        if summary.recordedActiveSeconds != TimeInterval(summary.recordedMinutes * 60) {
            let duration = MovementDurationFormat.exact(summary.recordedActiveSeconds)
            return "Your movement this week: \(activities) · \(duration) recorded. Every session counts."
        }
        if summary.recordedMinutes == 0 {
            return "Your movement this week: \(activities). Session length isn't recorded for every activity. Every session counts."
        }
        let minutes = summary.recordedMinutes == 1 ? "1 minute" : "\(summary.recordedMinutes) minutes"
        return "Your movement this week: \(activities) · \(minutes) recorded. Every session counts."
    }
}

private extension MovementHistoryKind {
    static func allCasesIn(_ items: [MovementHistoryItem]) -> [MovementHistoryKind] {
        var seen: [MovementHistoryKind] = []
        for item in items where !seen.contains(item.kind) {
            seen.append(item.kind)
        }
        return seen
    }
}

enum YouTubeLink {
    private static let hosts: Set<String> = [
        "youtube.com",
        "www.youtube.com",
        "m.youtube.com",
        "music.youtube.com",
        "youtu.be",
        "www.youtu.be",
        "youtube-nocookie.com",
        "www.youtube-nocookie.com"
    ]

    /// Returns an https YouTube URL, or nil when the text is not one.
    static func validatedURL(from raw: String) -> URL? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if !text.contains("://") {
            text = "https://\(text)"
        }
        guard var components = URLComponents(string: text),
              let host = components.host?.lowercased(),
              hosts.contains(host),
              components.scheme == "http" || components.scheme == "https" else {
            return nil
        }
        components.scheme = "https"
        return components.url
    }
}

/// A flexible idea for this week. It is not an assignment and it cannot be missed.
struct WeekIdea: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var category: MovementFormat
    var recommendedMinutes: Int
    var shorterMinutes: Int
    /// True when the person swapped the original category. The first idea is not marked failed.
    var wasSwapped: Bool

    /// Strength sessions are not timed, so this is a visit length, not a workout duration.
    var isUntimedStrength: Bool { category == .strength }
}

struct StoredWeekPlan: Codable, Equatable, Sendable {
    var ownerId: String
    var weekOf: Date
    var preferenceKey: String
    var ideas: [WeekIdea]
}

enum WeeklyMovementPlan {
    static let defaultMinutes = 10

    static func preferenceKey(_ formats: [MovementFormat]) -> String {
        formats.map(\.rawValue).sorted().joined(separator: ",")
    }

    static func categories(preferences: [MovementFormat], records: [MovementRecord]) -> [MovementFormat] {
        let preferred = unique(preferences.filter { $0 != .notSure })
        if !preferred.isEmpty { return Array(preferred.prefix(4)) }
        let done = unique(records.compactMap { format(for: $0.kind) })
        if !done.isEmpty { return Array(done.prefix(4)) }
        return [.walking]
    }

    /// Uses the latest actual minutes. Never suggests longer than that, and never invents a strength-session length.
    static func durations(for category: MovementFormat, records: [MovementRecord]) -> (recommended: Int, shorter: Int) {
        let recommended: Int
        if category == .strength {
            recommended = defaultMinutes
        } else if let latest = records.filter({ format(for: $0.kind) == category }).max(by: { $0.completedAt < $1.completedAt }) {
            recommended = max(2, latest.actualMinutes)
        } else {
            recommended = defaultMinutes
        }
        let shorter = recommended > 2 ? max(2, recommended / 2) : 2
        return (recommended, shorter == recommended ? max(2, recommended - 1) : shorter)
    }

    static func ideas(preferences: [MovementFormat], records: [MovementRecord]) -> [WeekIdea] {
        categories(preferences: preferences, records: records).map { category in
            let times = durations(for: category, records: records)
            return WeekIdea(
                id: UUID(),
                category: category,
                recommendedMinutes: times.recommended,
                shorterMinutes: times.shorter,
                wasSwapped: false
            )
        }
    }

    static func swapping(_ idea: WeekIdea, to category: MovementFormat, records: [MovementRecord]) -> WeekIdea {
        let times = durations(for: category, records: records)
        return WeekIdea(
            id: idea.id,
            category: category,
            recommendedMinutes: times.recommended,
            shorterMinutes: times.shorter,
            wasSwapped: true
        )
    }

    static func format(for kind: MovementRecordKind) -> MovementFormat? {
        switch kind {
        case .walking: .walking
        case .externalVideo: .videos
        case .yoga: .yoga
        case .dancing: .dancing
        case .withBaby: .withBaby
        case .other: .other
        case .guided, .stretching: nil
        }
    }

    private static func unique(_ formats: [MovementFormat]) -> [MovementFormat] {
        var seen: [MovementFormat] = []
        for format in formats where !seen.contains(format) {
            seen.append(format)
        }
        return seen
    }
}

enum BabyMovementCopy {
    static let notice = "Movement with baby means moving while your baby is with you or nearby, such as a walk together or gentle movement on the floor. trenira does not suggest lifting, carrying, balancing, or using your baby as part of the exercise. These are general ideas, not medical or childcare advice."
}
