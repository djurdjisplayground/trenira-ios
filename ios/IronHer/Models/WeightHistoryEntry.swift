import Foundation

enum WeightHistoryEvent: String, Codable {
    case initial
    case progression
    case repProgression
    case setProgression
}

struct WeightHistoryEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let exerciseId: String
    let weightKg: Double
    let previousWeightKg: Double?
    let reps: Int?
    let previousReps: Int?
    let sets: Int?
    let previousSets: Int?
    let date: Date
    let event: WeightHistoryEvent

    init(
        id: UUID = UUID(),
        exerciseId: String,
        weightKg: Double = 0,
        previousWeightKg: Double? = nil,
        reps: Int? = nil,
        previousReps: Int? = nil,
        sets: Int? = nil,
        previousSets: Int? = nil,
        date: Date = .now,
        event: WeightHistoryEvent
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.weightKg = weightKg
        self.previousWeightKg = previousWeightKg
        self.reps = reps
        self.previousReps = previousReps
        self.sets = sets
        self.previousSets = previousSets
        self.date = date
        self.event = event
    }

    private enum CodingKeys: String, CodingKey {
        case id, exerciseId, weightKg, previousWeightKg, reps, previousReps, sets, previousSets, date, event
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        exerciseId = try container.decode(String.self, forKey: .exerciseId)
        weightKg = try container.decodeIfPresent(Double.self, forKey: .weightKg) ?? 0
        previousWeightKg = try container.decodeIfPresent(Double.self, forKey: .previousWeightKg)
        reps = try container.decodeIfPresent(Int.self, forKey: .reps)
        previousReps = try container.decodeIfPresent(Int.self, forKey: .previousReps)
        sets = try container.decodeIfPresent(Int.self, forKey: .sets)
        previousSets = try container.decodeIfPresent(Int.self, forKey: .previousSets)
        date = try container.decodeIfPresent(Date.self, forKey: .date) ?? .now
        event = try container.decode(WeightHistoryEvent.self, forKey: .event)
    }
}

struct ExerciseProgressSummary: Identifiable {
    let exerciseId: String
    let exerciseName: String
    let initialWeightKg: Double
    let currentWeightKg: Double
    let firstDate: Date
    let lastDate: Date
    let entryCount: Int

    var id: String { exerciseId }

    var gainKg: Double {
        currentWeightKg - initialWeightKg
    }

    var daySpan: Int {
        max(1, Calendar.current.dateComponents([.day], from: firstDate, to: lastDate).day ?? 0)
    }
}
