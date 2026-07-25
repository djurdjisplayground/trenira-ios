import Foundation

struct Workout: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var exercises: [WorkoutExerciseEntry]
    var createdAt: Date
    var updatedAt: Date
    /// `guest:…` or `account:provider:…` — empty means legacy (pre-ownership) data.
    var ownerId: String
    /// Soft delete for sync-safe tombstones / Recently Deleted. Nil = active.
    var deletedAt: Date?
    /// Unsaved create/edit session. Drafts never count toward the free plan limit.
    var isDraft: Bool

    init(
        id: UUID = UUID(),
        name: String,
        exercises: [WorkoutExerciseEntry] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now,
        ownerId: String = "",
        deletedAt: Date? = nil,
        isDraft: Bool = false
    ) {
        self.id = id
        self.name = name
        self.exercises = exercises
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.ownerId = ownerId
        self.deletedAt = deletedAt
        self.isDraft = isDraft
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        exercises = try container.decodeIfPresent([WorkoutExerciseEntry].self, forKey: .exercises) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        ownerId = try container.decodeIfPresent(String.self, forKey: .ownerId) ?? ""
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        isDraft = try container.decodeIfPresent(Bool.self, forKey: .isDraft) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(exercises, forKey: .exercises)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(ownerId, forKey: .ownerId)
        try container.encodeIfPresent(deletedAt, forKey: .deletedAt)
        try container.encode(isDraft, forKey: .isDraft)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, exercises, createdAt, updatedAt, ownerId, deletedAt, isDraft
    }
}
