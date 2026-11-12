import Foundation

enum MovementReminderFrequency: String, Codable, CaseIterable, Identifiable {
    case daily
    case selectedDays
    case weeklyReflection

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: "Daily"
        case .selectedDays: "Selected days"
        case .weeklyReflection: "Weekly reflection"
        }
    }

    var summary: String {
        switch self {
        case .daily: "One reminder each day, at the time you choose."
        case .selectedDays: "Only the days you pick."
        case .weeklyReflection: "One reminder to shape the week, on the day you pick."
        }
    }
}

/// Local reminder choices for one person. Missing data stays off.
struct MovementReminderPreferences: Codable, Equatable {
    var enabled: Bool
    var frequency: MovementReminderFrequency
    var weekdays: [Int]
    /// Calendar weekday, 1 = Sunday, for the weekly reflection.
    var weeklyWeekday: Int
    var hour: Int
    var minute: Int

    static let off = MovementReminderPreferences(
        enabled: false,
        frequency: .daily,
        weekdays: [],
        weeklyWeekday: 1,
        hour: 9,
        minute: 0
    )

    func sanitized() -> MovementReminderPreferences {
        var copy = self
        copy.hour = min(23, max(0, hour))
        copy.minute = min(59, max(0, minute))
        copy.weekdays = Array(Set(weekdays.filter { (1...7).contains($0) })).sorted()
        if !(1...7).contains(copy.weeklyWeekday) {
            copy.weeklyWeekday = 1
        }
        return copy
    }

    init(enabled: Bool, frequency: MovementReminderFrequency, weekdays: [Int], weeklyWeekday: Int, hour: Int, minute: Int) {
        self.enabled = enabled
        self.frequency = frequency
        self.weekdays = weekdays
        self.weeklyWeekday = weeklyWeekday
        self.hour = hour
        self.minute = minute
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        frequency = (try? container.decode(MovementReminderFrequency.self, forKey: .frequency)) ?? .daily
        weekdays = try container.decodeIfPresent([Int].self, forKey: .weekdays) ?? []
        weeklyWeekday = try container.decodeIfPresent(Int.self, forKey: .weeklyWeekday) ?? 1
        hour = try container.decodeIfPresent(Int.self, forKey: .hour) ?? 9
        minute = try container.decodeIfPresent(Int.self, forKey: .minute) ?? 0
    }
}

enum MovementReminderCopy {
    static let gentle = [
        "A little time for you? Even five minutes of movement counts. 💜",
        "Your day, your pace. Ready to find a moment to move?",
        "Life gets busy. Your movement can fit around it."
    ]
    static let weekly = "Ready to shape a flexible week that works for you?"

    static func body(weekday: Int?, destination: String) -> String {
        if destination == MovementReminderDestination.week.rawValue {
            return weekly
        }
        let index = max(0, (weekday ?? 1) - 1) % gentle.count
        return gentle[index]
    }
}

enum MovementReminderDestination: String, Identifiable, Equatable {
    case home
    case week

    var id: String { rawValue }

    init(userInfo: [AnyHashable: Any]) {
        if (userInfo["destination"] as? String) == Self.week.rawValue {
            self = .week
        } else {
            self = .home
        }
    }
}

struct MovementReminderRequest: Equatable {
    var identifier: String
    var title: String
    var body: String
    /// Nil means every day. Otherwise a calendar weekday, 1 = Sunday.
    var weekday: Int?
    var hour: Int
    var minute: Int
    var destination: String
}

enum MovementReminderPlan {
    static let identifierPrefix = "trenira.movement.reminder."

    static func requests(for preferences: MovementReminderPreferences, ownerId: String) -> [MovementReminderRequest] {
        let prefs = preferences.sanitized()
        guard prefs.enabled else { return [] }
        switch prefs.frequency {
        case .daily:
            return [make(slot: "daily", weekday: nil, destination: .home, preferences: prefs, ownerId: ownerId)]
        case .selectedDays:
            return prefs.weekdays.map { day in
                make(slot: "day-\(day)", weekday: day, destination: .home, preferences: prefs, ownerId: ownerId)
            }
        case .weeklyReflection:
            return [make(slot: "week-\(prefs.weeklyWeekday)", weekday: prefs.weeklyWeekday, destination: .week, preferences: prefs, ownerId: ownerId)]
        }
    }

    static func userInfo(for request: MovementReminderRequest) -> [String: String] {
        ["destination": request.destination]
    }

    private static func make(
        slot: String,
        weekday: Int?,
        destination: MovementReminderDestination,
        preferences: MovementReminderPreferences,
        ownerId: String
    ) -> MovementReminderRequest {
        MovementReminderRequest(
            identifier: "\(identifierPrefix)\(ownerToken(ownerId)).\(slot)",
            title: "trenira",
            body: MovementReminderCopy.body(weekday: weekday, destination: destination.rawValue),
            weekday: weekday,
            hour: preferences.hour,
            minute: preferences.minute,
            destination: destination.rawValue
        )
    }

    private static func ownerToken(_ ownerId: String) -> String {
        var hash: UInt32 = 2_166_136_261
        for byte in ownerId.utf8 {
            hash = (hash ^ UInt32(byte)) &* 16_777_619
        }
        return String(hash)
    }
}

enum MovementReminderStore {
    static let storageKey = "trenira.movementReminders.v1"

    static func load(ownerId: String, defaults: UserDefaults = .standard) -> MovementReminderPreferences {
        all(defaults: defaults)[ownerId]?.sanitized() ?? .off
    }

    static func save(_ preferences: MovementReminderPreferences, ownerId: String, defaults: UserDefaults = .standard) {
        var stored = all(defaults: defaults)
        stored[ownerId] = preferences.sanitized()
        persist(stored, defaults: defaults)
    }

    static func removeAll(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
    }

    private static func all(defaults: UserDefaults) -> [String: MovementReminderPreferences] {
        guard let data = defaults.data(forKey: storageKey),
              let stored = try? JSONDecoder().decode([String: MovementReminderPreferences].self, from: data) else {
            return [:]
        }
        return stored
    }

    private static func persist(_ stored: [String: MovementReminderPreferences], defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(stored) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
