import Foundation

/// Local companion profile. Does not read or write strength-onboarding or workout keys.
enum CompanionProfileStore {
    static let storageKey = "trenira.companionProfile.v1"

    static func load(defaults: UserDefaults = .standard) -> CompanionProfile? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(CompanionProfile.self, from: data)
    }

    static func isResolved(defaults: UserDefaults = .standard) -> Bool {
        load(defaults: defaults) != nil
    }

    static func save(_ profile: CompanionProfile, defaults: UserDefaults = .standard) {
        var stored = profile
        stored.updatedAt = profile.updatedAt
        if let primary = stored.primaryBarrier, !stored.barriers.contains(primary) {
            stored.primaryBarrier = stored.barriers.first
        } else if stored.primaryBarrier == nil {
            stored.primaryBarrier = stored.barriers.first
        }
        guard let data = try? JSONEncoder().encode(stored) else { return }
        defaults.set(data, forKey: storageKey)
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
    }
}
