import Foundation

enum MovementRecordKind: String, Codable, Equatable {
    case walking
    case externalVideo
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

    init(
        id: UUID = UUID(),
        kind: MovementRecordKind,
        title: String,
        completedAt: Date = .now,
        actualMinutes: Int,
        plannedMinutes: Int? = nil,
        feeling: MovementFeeling? = nil,
        videoId: UUID? = nil,
        ownerId: String = ""
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.completedAt = completedAt
        self.actualMinutes = max(1, actualMinutes)
        self.plannedMinutes = plannedMinutes
        self.feeling = feeling
        self.videoId = videoId
        self.ownerId = ownerId
    }

    var finishedEarlier: Bool {
        guard let plannedMinutes else { return false }
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
}

struct MovementWeekSummary: Equatable {
    var activityCount: Int
    var recordedMinutes: Int
    var kinds: [MovementHistoryKind]
    var strengthCountWithoutMinutes: Int
}

enum MovementJournal {
    static func items(
        records: [MovementRecord],
        strengthLogs: [StrengthHistorySnapshot]
    ) -> [MovementHistoryItem] {
        let recorded = records.map { record in
            MovementHistoryItem(
                id: "record-\(record.id.uuidString)",
                kind: record.kind == .walking ? .walking : .externalVideo,
                title: record.title,
                completedAt: record.completedAt,
                actualMinutes: record.actualMinutes,
                plannedMinutes: record.plannedMinutes,
                feeling: record.feeling
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
        return MovementWeekSummary(
            activityCount: week.count,
            recordedMinutes: week.compactMap(\.actualMinutes).reduce(0, +),
            kinds: kinds,
            strengthCountWithoutMinutes: week.filter { $0.kind == .strength }.count
        )
    }

    /// Never prints unknown strength time as zero minutes.
    static func weekLine(_ summary: MovementWeekSummary) -> String {
        if summary.activityCount == 0 {
            return "Nothing recorded this week. Your journey continues whenever you're ready."
        }
        let activities = summary.activityCount == 1 ? "1 activity" : "\(summary.activityCount) activities"
        if summary.recordedMinutes == 0 {
            return "\(activities) this week. Session length isn't recorded for every activity."
        }
        return "\(activities) this week · \(summary.recordedMinutes) minutes recorded. Nothing is overdue."
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
