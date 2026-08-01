import Foundation

/// Persists an in-progress consultation request draft on this device only.
///
/// Storage: `UserDefaults.standard` key `trenira.consultationRequestDraft.v1`
/// (JSON-encoded `ConsultationRequest`). Not synced. Cleared after a successfully
/// sent email, via Clear saved draft, or by `LocalDataErasureService`.
enum ConsultationDraftStore {
    static let storageKey = "trenira.consultationRequestDraft.v1"

    static func load() -> ConsultationRequest? {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              var decoded = try? JSONDecoder().decode(ConsultationRequest.self, from: data) else {
            return nil
        }
        // Migrate legacy “main goal” into help-with when needed.
        if decoded.trimmedHelpWith.isEmpty, !decoded.mainGoal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            decoded.helpWith = decoded.mainGoal
            decoded.mainGoal = ""
        }
        decoded.clampFieldLengths()
        return decoded
    }

    static func save(_ request: ConsultationRequest) {
        var copy = request
        copy.clampFieldLengths()
        copy.updatedAt = .now
        guard let data = try? JSONEncoder().encode(copy) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
