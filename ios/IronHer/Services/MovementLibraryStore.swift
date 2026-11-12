import Foundation

enum SavedVideoStore {
    static let storageKey = "trenira.savedVideos.v1"

    static func load(defaults: UserDefaults = .standard, ownerId: String? = nil) -> [SavedVideo] {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([SavedVideo].self, from: data) else {
            return []
        }
        let videos = decoded.sorted { $0.savedAt > $1.savedAt }
        guard let ownerId else { return videos }
        return videos.filter { $0.ownerId.isEmpty || $0.ownerId == ownerId }
    }

    static func add(_ video: SavedVideo, defaults: UserDefaults = .standard) {
        var all = load(defaults: defaults)
        all.insert(video, at: 0)
        save(all, defaults: defaults)
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
    }

    /// Replaces one owner's videos. Other owners stay. Nil means this backup did not include videos.
    static func replace(ownerId: String, videos: [SavedVideo]?, defaults: UserDefaults = .standard) {
        guard let videos else { return }
        let kept = load(defaults: defaults).filter { !$0.ownerId.isEmpty && $0.ownerId != ownerId }
        let stamped = videos.map { video in
            var copy = video
            copy.ownerId = ownerId
            return copy
        }
        save(kept + stamped, defaults: defaults)
    }

    private static func save(_ videos: [SavedVideo], defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(videos) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

enum MovementRecordStore {
    static let storageKey = "trenira.movementRecords.v1"

    static func load(defaults: UserDefaults = .standard, ownerId: String? = nil) -> [MovementRecord] {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([MovementRecord].self, from: data) else {
            return []
        }
        let records = decoded.sorted { $0.completedAt > $1.completedAt }
        guard let ownerId else { return records }
        return records.filter { $0.ownerId.isEmpty || $0.ownerId == ownerId }
    }

    static func add(_ record: MovementRecord, defaults: UserDefaults = .standard) {
        upsert(record, defaults: defaults)
    }

    /// Inserts a new record, or replaces the one with the same id. A second save does not duplicate it.
    static func upsert(_ record: MovementRecord, defaults: UserDefaults = .standard) {
        var all = load(defaults: defaults)
        if let index = all.firstIndex(where: { $0.id == record.id }) {
            all[index] = record
        } else {
            all.insert(record, at: 0)
        }
        save(all, defaults: defaults)
    }

    static func delete(id: UUID, defaults: UserDefaults = .standard) {
        let kept = load(defaults: defaults).filter { $0.id != id }
        save(kept, defaults: defaults)
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
    }

    /// Replaces one owner's records. Nil means an older backup did not include them.
    static func replace(ownerId: String, records: [MovementRecord]?, defaults: UserDefaults = .standard) {
        guard let records else { return }
        let kept = load(defaults: defaults).filter { !$0.ownerId.isEmpty && $0.ownerId != ownerId }
        let stamped = records.map { record in
            var copy = record
            copy.ownerId = ownerId
            return copy
        }
        save(kept + stamped, defaults: defaults)
    }

    private static func save(_ records: [MovementRecord], defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

enum WeekPlanStore {
    static let storageKey = "trenira.weekPlan.v1"

    static func load(defaults: UserDefaults = .standard, ownerId: String) -> StoredWeekPlan? {
        guard let data = defaults.data(forKey: storageKey),
              let plans = try? JSONDecoder().decode([StoredWeekPlan].self, from: data) else {
            return nil
        }
        return plans.first { $0.ownerId == ownerId }
    }

    static func save(_ plan: StoredWeekPlan, defaults: UserDefaults = .standard) {
        var plans = all(defaults: defaults).filter { $0.ownerId != plan.ownerId }
        plans.append(plan)
        guard let data = try? JSONEncoder().encode(plans) else { return }
        defaults.set(data, forKey: storageKey)
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
    }

    /// Keeps a swapped plan for this week and these preferences. Otherwise builds a new one.
    static func resolve(
        ownerId: String,
        preferences: [MovementFormat],
        records: [MovementRecord],
        now: Date = .now,
        defaults: UserDefaults = .standard
    ) -> StoredWeekPlan {
        let week = WorkoutWeekCalendar.calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let key = WeeklyMovementPlan.preferenceKey(preferences)
        if let saved = load(defaults: defaults, ownerId: ownerId),
           WorkoutWeekCalendar.calendar.isDate(saved.weekOf, equalTo: week, toGranularity: .weekOfYear),
           saved.preferenceKey == key,
           !saved.ideas.isEmpty {
            return saved
        }
        let plan = StoredWeekPlan(
            ownerId: ownerId,
            weekOf: week,
            preferenceKey: key,
            ideas: WeeklyMovementPlan.ideas(preferences: preferences, records: records)
        )
        save(plan, defaults: defaults)
        return plan
    }

    static func swap(
        ownerId: String,
        ideaID: UUID,
        to category: MovementFormat,
        records: [MovementRecord],
        defaults: UserDefaults = .standard
    ) {
        guard var plan = load(defaults: defaults, ownerId: ownerId),
              let index = plan.ideas.firstIndex(where: { $0.id == ideaID }) else { return }
        plan.ideas[index] = WeeklyMovementPlan.swapping(plan.ideas[index], to: category, records: records)
        save(plan, defaults: defaults)
    }

    private static func all(defaults: UserDefaults) -> [StoredWeekPlan] {
        guard let data = defaults.data(forKey: storageKey),
              let plans = try? JSONDecoder().decode([StoredWeekPlan].self, from: data) else {
            return []
        }
        return plans
    }
}
