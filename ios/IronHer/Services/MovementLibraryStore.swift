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
        var all = load(defaults: defaults)
        all.insert(record, at: 0)
        save(all, defaults: defaults)
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
