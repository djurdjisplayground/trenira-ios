import Foundation

/// Placeholder for future personalized training recommendations
/// (e.g. cycle-aware guidance). Kept intentionally empty for V1.
struct TrainingPreferences: Codable, Equatable, Hashable {
    /// Reserved for future preference flags without breaking persistence.
    var schemaVersion: Int = 1
}

/// Extensible context for future personalization layers.
/// Do not surface cycle tracking in V1 — evidence and product fit come later.
struct PersonalizationContext: Codable, Equatable, Hashable {
    var preferences: TrainingPreferences = TrainingPreferences()
}
