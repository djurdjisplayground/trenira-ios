import Foundation

enum MovementEquipment: String, Codable, CaseIterable, Identifiable, Equatable {
    case none
    case dumbbells
    case bands
    case mat
    case chair
    case ball

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "No equipment"
        case .dumbbells: "Dumbbells"
        case .bands: "Resistance bands"
        case .mat: "Exercise mat"
        case .chair: "Chair/support"
        case .ball: "Pilates ball"
        }
    }

    var summary: String {
        switch self {
        case .none: "Bodyweight, walking, dancing"
        case .dumbbells: "Dumbbell strength"
        case .bands: "Band-based exercises"
        case .mat: "Yoga, stretching, mat-based movement"
        case .chair: "Supported and seated movements"
        case .ball: "Appropriate ball-based movements"
        }
    }
}

enum TodayEquipmentChoice: Equatable {
    case focused(MovementEquipment)
    case surprise

    var storageValue: String {
        switch self {
        case .focused(let equipment): equipment.rawValue
        case .surprise: "surprise"
        }
    }

    init(storageValue: String?) {
        if storageValue == Self.surprise.storageValue {
            self = .surprise
            return
        }
        if let storageValue, let equipment = MovementEquipment(rawValue: storageValue) {
            self = .focused(equipment)
            return
        }
        self = .focused(.none)
    }
}

enum EquipmentSelection: Equatable {
    case focused(MovementEquipment)
    case surprise(Set<MovementEquipment>)
}

enum CatalogCategory: String, Codable, CaseIterable, Identifiable, Equatable {
    case walking
    case dancing
    case mobility
    case stretching
    case yogaInspired
        case bodyweightStrength
        case dumbbellStrength
        case band
        case chairSupport
        case ball
        /// General movement while a baby is safely nearby. Not a baby-lifting workout.
        case withBabyNearby

    var id: String { rawValue }

    var title: String {
        switch self {
        case .walking: "Walking"
        case .dancing: "Dancing"
        case .mobility: "Gentle mobility"
        case .stretching: "Stretching"
        case .yogaInspired: "Yoga-inspired"
        case .bodyweightStrength: "Bodyweight strength"
        case .dumbbellStrength: "Dumbbell strength"
        case .band: "Resistance bands"
        case .chairSupport: "Chair support"
        case .ball: "Pilates ball"
        case .withBabyNearby: "With baby nearby"
        }
    }

    var recordKind: MovementRecordKind {
        switch self {
        case .walking: .walking
        case .dancing: .dancing
        case .mobility: .guided
        case .stretching: .stretching
        case .yogaInspired: .yoga
        case .withBabyNearby: .withBaby
        case .bodyweightStrength, .dumbbellStrength, .band, .chairSupport, .ball: .other
        }
    }
}

enum CatalogFormat: String, Codable, Equatable {
    case single
    case miniSession
    case selfDirected
}

enum CatalogPosition: String, Codable, Equatable {
    case standing
    case seated
    case floor
}

enum CatalogSafety: String, Codable, Equatable {
    /// General movement reviewed for this pilot. Not postpartum rehabilitation.
    case reviewedGeneral
    /// Draft copy. Visible for review, and not cleared for public release.
    case pendingProfessionalReview
}

struct CatalogActivity: Identifiable, Equatable {
    var id: String
    var name: String
    var category: CatalogCategory
    var format: CatalogFormat
    var minimumMinutes: Int
    var maximumMinutes: Int
    var energies: [MovementEnergy]
    var equipment: MovementEquipment
    var position: CatalogPosition
    var instructions: [String]
    var easier: String
    var caution: String
    var safety: CatalogSafety
    /// Lower numbers are simpler.
    var simplicity: Int

    var durationLabel: String {
        if minimumMinutes == maximumMinutes { return "\(minimumMinutes) min" }
        return "\(minimumMinutes)–\(maximumMinutes) min"
    }
}

enum MovementCatalog {
    static let safetyLine = "Move only in a range that feels comfortable, and stop if something doesn't feel right. These are general ideas, not a treatment, a workout plan, or postpartum advice. They are not a claim that every movement is safe after birth."

    static let postpartumNote = "If you are recently postpartum, don't assume a core or strength idea is right for you yet. If you have symptoms or complications, ask your own clinician before trying something new. trenira does not provide rehabilitation."

    /// Shown on draft entries. Not a clearance for public release.
    static let draftReviewLine = "Draft for professional content review before public release. Your baby stays in a safe place nearby and is not part of the movement. This is not a postpartum program, and it does not claim the idea suits every stage after birth."

    static let avatarAssetName = "trenira_companion_avatar"

    static let all: [CatalogActivity] = [
        activity(
            id: "shoulder-rolls",
            name: "Shoulder rolls",
            category: .mobility,
            format: .single,
            minimum: 2,
            maximum: 5,
            energies: [.low, .okay, .high],
            equipment: .none,
            position: .standing,
            instructions: [
                "Let your shoulders rest.",
                "Circle them slowly, only through a range that feels easy.",
                "Let them rest again. Repeat if you'd like."
            ],
            easier: "Make the circle smaller, or stay seated.",
            simplicity: 1
        ),
        activity(
            id: "seated-side-bend",
            name: "Seated side bend",
            category: .stretching,
            format: .single,
            minimum: 2,
            maximum: 5,
            energies: [.low, .okay],
            equipment: .none,
            position: .seated,
            instructions: [
                "Sit comfortably with both feet supported.",
                "Lean a little to one side, only as far as feels easy.",
                "Come back to the middle. The other side is optional."
            ],
            easier: "Keep the lean very small, or skip the second side.",
            simplicity: 1
        ),
        activity(
            id: "standing-reach",
            name: "Standing reach",
            category: .yogaInspired,
            format: .single,
            minimum: 2,
            maximum: 5,
            energies: [.low, .okay, .high],
            equipment: .none,
            position: .standing,
            instructions: [
                "Stand with your arms relaxed.",
                "Raise them only as far as feels comfortable.",
                "Lower them slowly."
            ],
            easier: "Reach forward instead of up, or stay seated.",
            simplicity: 1
        ),
        activity(
            id: "easy-walk",
            name: "Easy walk",
            category: .walking,
            format: .selfDirected,
            minimum: 2,
            maximum: 30,
            energies: [.low, .okay, .high],
            equipment: .none,
            position: .standing,
            instructions: [
                "Walk at a pace that feels comfortable for the time you have.",
                "Stop whenever you want. A short walk still counts."
            ],
            easier: "Walk more slowly, or walk indoors.",
            simplicity: 2
        ),
        activity(
            id: "dance-in-place",
            name: "Dance in place",
            category: .dancing,
            format: .selfDirected,
            minimum: 2,
            maximum: 30,
            energies: [.low, .okay, .high],
            equipment: .none,
            position: .standing,
            instructions: [
                "Put on music if you want, or move without it.",
                "Sway, step, or dance in whatever way feels good.",
                "Stop whenever you want."
            ],
            easier: "Stay seated and sway.",
            simplicity: 2
        ),
        activity(
            id: "standing-trio",
            name: "Easy standing trio",
            category: .mobility,
            format: .miniSession,
            minimum: 5,
            maximum: 15,
            energies: [.low, .okay],
            equipment: .none,
            position: .standing,
            instructions: [
                "Shoulder rolls, only as far as feels easy.",
                "A small standing reach. Skip it if you prefer.",
                "March softly in place, then rest."
            ],
            easier: "Do only the first movement.",
            simplicity: 3
        ),
        activity(
            id: "march-in-place",
            name: "March in place",
            category: .mobility,
            format: .single,
            minimum: 5,
            maximum: 10,
            energies: [.okay, .high],
            equipment: .none,
            position: .standing,
            instructions: [
                "March gently where you are.",
                "Keep the pace easy.",
                "Stop when you want a rest."
            ],
            easier: "Lift your feet less, or hold a chair.",
            simplicity: 3
        ),
        activity(
            id: "wall-press",
            name: "Wall press",
            category: .bodyweightStrength,
            format: .single,
            minimum: 5,
            maximum: 10,
            energies: [.okay, .high],
            equipment: .none,
            position: .standing,
            instructions: [
                "Place your hands on a wall at shoulder height.",
                "Bend your elbows a little, then press back to standing.",
                "Do as many as feel comfortable. There is no target number."
            ],
            easier: "Stand closer to the wall so the press is smaller.",
            simplicity: 4
        ),
        activity(
            id: "calf-raise",
            name: "Calf raise",
            category: .bodyweightStrength,
            format: .single,
            minimum: 5,
            maximum: 10,
            energies: [.okay, .high],
            equipment: .none,
            position: .standing,
            instructions: [
                "Hold a chair or wall if you want support.",
                "Rise onto the balls of your feet, then lower slowly.",
                "Stop when it feels like enough."
            ],
            easier: "Hold the chair the whole time, and rise only a little.",
            simplicity: 4
        ),
        activity(
            id: "mat-seated-fold",
            name: "Mat seated fold",
            category: .stretching,
            format: .single,
            minimum: 5,
            maximum: 15,
            energies: [.low, .okay],
            equipment: .mat,
            position: .floor,
            instructions: [
                "Sit on a mat with your legs comfortable.",
                "Fold forward only as far as feels easy.",
                "Come back up slowly."
            ],
            easier: "Stay upright and only reach toward your knees.",
            simplicity: 3
        ),
        activity(
            id: "dumbbell-arm-raise",
            name: "Light dumbbell raise",
            category: .dumbbellStrength,
            format: .single,
            minimum: 2,
            maximum: 15,
            energies: [.okay, .high],
            equipment: .dumbbells,
            position: .standing,
            instructions: [
                "Hold a light dumbbell in each hand, or one dumbbell in both hands.",
                "Raise your arms only as high as feels comfortable.",
                "Lower them slowly. Rest whenever you need."
            ],
            easier: "Use a lighter weight, or raise only one arm.",
            simplicity: 5
        ),
        activity(
            id: "dumbbell-pair",
            name: "Two easy dumbbell moves",
            category: .dumbbellStrength,
            format: .miniSession,
            minimum: 10,
            maximum: 20,
            energies: [.high],
            equipment: .dumbbells,
            position: .standing,
            instructions: [
                "Hold light dumbbells at your sides.",
                "Raise your arms only as far as feels comfortable.",
                "Either move can be skipped."
            ],
            easier: "Do only the arm raise.",
            simplicity: 6
        ),
        activity(
            id: "light-dumbbell-hold",
            name: "Light dumbbell hold",
            category: .dumbbellStrength,
            format: .single,
            minimum: 2,
            maximum: 5,
            energies: [.low, .okay],
            equipment: .dumbbells,
            position: .seated,
            instructions: [
                "Sit and hold a light dumbbell in each hand.",
                "Rest the weights on your thighs, then lift them a little.",
                "Lower them when you want to stop."
            ],
            easier: "Use one lighter dumbbell in both hands.",
            simplicity: 2
        ),
        activity(
            id: "dumbbell-curl",
            name: "Easy dumbbell curl",
            category: .dumbbellStrength,
            format: .single,
            minimum: 5,
            maximum: 12,
            energies: [.okay, .high],
            equipment: .dumbbells,
            position: .standing,
            instructions: [
                "Hold a light dumbbell in each hand.",
                "Bend your elbows only as far as feels comfortable.",
                "Lower the weights slowly. There is no target number."
            ],
            easier: "Curl one arm, or use a lighter weight.",
            simplicity: 4
        ),
        activity(
            id: "dumbbell-press",
            name: "Small dumbbell press",
            category: .dumbbellStrength,
            format: .single,
            minimum: 5,
            maximum: 15,
            energies: [.high, .okay],
            equipment: .dumbbells,
            position: .standing,
            instructions: [
                "Hold light dumbbells near your shoulders.",
                "Press them up only as high as feels comfortable.",
                "Bring them back down and rest whenever you need."
            ],
            easier: "Press one arm, or stop at shoulder height.",
            simplicity: 5
        ),
        activity(
            id: "band-pull-apart",
            name: "Band pull-apart",
            category: .band,
            format: .single,
            minimum: 2,
            maximum: 8,
            energies: [.low, .okay, .high],
            equipment: .bands,
            position: .standing,
            instructions: [
                "Hold a light band in front of you with both hands.",
                "Pull your hands apart only as far as feels easy.",
                "Let the band return slowly."
            ],
            easier: "Hold the band wider so the pull is smaller.",
            simplicity: 2
        ),
        activity(
            id: "band-row",
            name: "Band row",
            category: .band,
            format: .single,
            minimum: 5,
            maximum: 12,
            energies: [.okay, .high],
            equipment: .bands,
            position: .standing,
            instructions: [
                "Anchor a band at a comfortable height, or hold it under your feet if that feels steady.",
                "Pull your hands toward you, then let them return.",
                "Stop when you want a rest."
            ],
            easier: "Use a lighter band, or pull a shorter distance.",
            simplicity: 4
        ),
        activity(
            id: "band-press",
            name: "Band press",
            category: .band,
            format: .single,
            minimum: 5,
            maximum: 12,
            energies: [.okay, .high],
            equipment: .bands,
            position: .standing,
            instructions: [
                "Hold a band at chest height.",
                "Press your hands forward only as far as feels comfortable.",
                "Return slowly."
            ],
            easier: "Shorten the press, or use a lighter band.",
            simplicity: 4
        ),
        activity(
            id: "band-pair",
            name: "Two easy band moves",
            category: .band,
            format: .miniSession,
            minimum: 10,
            maximum: 20,
            energies: [.high, .okay],
            equipment: .bands,
            position: .standing,
            instructions: [
                "Pull the band apart a few times.",
                "Then press it forward, only as far as you want.",
                "Either move can be skipped."
            ],
            easier: "Do only the pull-apart.",
            simplicity: 5
        ),
        activity(
            id: "mat-reach",
            name: "Seated mat reach",
            category: .yogaInspired,
            format: .single,
            minimum: 2,
            maximum: 5,
            energies: [.low, .okay],
            equipment: .mat,
            position: .seated,
            instructions: [
                "Sit on your mat with your feet comfortable.",
                "Reach forward only as far as feels easy.",
                "Sit tall again."
            ],
            easier: "Reach toward your knees and stop there.",
            simplicity: 2
        ),
        activity(
            id: "mat-rest",
            name: "Mat rest pose",
            category: .stretching,
            format: .single,
            minimum: 2,
            maximum: 8,
            energies: [.low, .okay],
            equipment: .mat,
            position: .floor,
            instructions: [
                "Come onto the mat in any comfortable kneeling or seated rest.",
                "Let your arms relax.",
                "Stay only as long as it feels good."
            ],
            easier: "Stay seated upright instead of folding.",
            simplicity: 1
        ),
        activity(
            id: "mat-pair",
            name: "Two mat stretches",
            category: .stretching,
            format: .miniSession,
            minimum: 10,
            maximum: 15,
            energies: [.low, .okay],
            equipment: .mat,
            position: .floor,
            instructions: [
                "Sit on the mat and fold forward a little.",
                "Then rest in a comfortable position.",
                "Either one can be skipped."
            ],
            easier: "Do only the seated reach.",
            simplicity: 3
        ),
        activity(
            id: "chair-reach",
            name: "Seated chair reach",
            category: .chairSupport,
            format: .single,
            minimum: 2,
            maximum: 5,
            energies: [.low, .okay, .high],
            equipment: .chair,
            position: .seated,
            instructions: [
                "Sit on a steady chair with your feet supported.",
                "Reach your arms forward or up, only as far as feels easy.",
                "Bring them back down."
            ],
            easier: "Keep your hands on your thighs and lift them only a little.",
            simplicity: 1
        ),
        activity(
            id: "chair-twist",
            name: "Seated chair twist",
            category: .chairSupport,
            format: .single,
            minimum: 2,
            maximum: 5,
            energies: [.low, .okay],
            equipment: .chair,
            position: .seated,
            instructions: [
                "Sit tall on a chair.",
                "Turn your chest a little to one side, holding the chair if you like.",
                "Come back to the middle. The other side is optional."
            ],
            easier: "Make the turn smaller.",
            simplicity: 2
        ),
        activity(
            id: "chair-stand",
            name: "Chair sit to stand",
            category: .chairSupport,
            format: .single,
            minimum: 5,
            maximum: 12,
            energies: [.okay, .high],
            equipment: .chair,
            position: .standing,
            instructions: [
                "Sit on a steady chair.",
                "Stand up using your legs, then sit back down.",
                "Use your hands on the chair if you want support. Stop whenever you need."
            ],
            easier: "Rise only part of the way, with your hands on the chair.",
            simplicity: 3
        ),
        activity(
            id: "chair-pair",
            name: "Two chair moves",
            category: .chairSupport,
            format: .miniSession,
            minimum: 10,
            maximum: 15,
            energies: [.okay, .high],
            equipment: .chair,
            position: .seated,
            instructions: [
                "Reach from the chair a few times.",
                "Then stand and sit, only as many times as you want.",
                "Either move can be skipped."
            ],
            easier: "Stay seated and only do the reach.",
            simplicity: 4
        ),
        activity(
            id: "ball-reach",
            name: "Ball arm reach",
            category: .ball,
            format: .single,
            minimum: 2,
            maximum: 5,
            energies: [.low, .okay, .high],
            equipment: .ball,
            position: .standing,
            instructions: [
                "Hold a Pilates ball in both hands.",
                "Reach it forward or up, only as far as feels comfortable.",
                "Bring it back in."
            ],
            easier: "Hold the ball close to your body and sway a little.",
            simplicity: 2
        ),
        activity(
            id: "ball-shift",
            name: "Seated ball shift",
            category: .ball,
            format: .single,
            minimum: 5,
            maximum: 10,
            energies: [.okay, .low],
            equipment: .ball,
            position: .seated,
            instructions: [
                "Sit on a steady Pilates ball with your feet on the floor.",
                "Shift your weight a little from side to side.",
                "Stop if you feel unsteady, and move to a chair instead."
            ],
            easier: "Hold a wall or chair while you sit on the ball.",
            simplicity: 3
        ),
        activity(
            id: "ball-wall",
            name: "Ball against the wall",
            category: .ball,
            format: .single,
            minimum: 5,
            maximum: 12,
            energies: [.okay, .high],
            equipment: .ball,
            position: .standing,
            instructions: [
                "Place the ball between your back and a wall.",
                "Bend your knees a little, then return to standing.",
                "Keep the range small."
            ],
            easier: "Only lean into the ball, without bending your knees.",
            simplicity: 4
        ),
        activity(
            id: "ball-pair",
            name: "Two ball moves",
            category: .ball,
            format: .miniSession,
            minimum: 10,
            maximum: 15,
            energies: [.high, .okay],
            equipment: .ball,
            position: .standing,
            instructions: [
                "Reach the ball forward a few times.",
                "Then place it against the wall for a small knee bend.",
                "Either move can be skipped."
            ],
            easier: "Do only the arm reach.",
            simplicity: 5
        ),
        activity(
            id: "baby-nearby-sway",
            name: "Quiet sway",
            category: .withBabyNearby,
            format: .single,
            minimum: 2,
            maximum: 5,
            energies: [.low, .okay],
            equipment: .none,
            position: .standing,
            instructions: [
                "Your baby stays in a safe place you can see, such as a crib or a seat. You are not holding your baby.",
                "Stand and sway gently from side to side.",
                "Stop whenever you want."
            ],
            easier: "Sit and sway instead.",
            caution: MovementCatalog.draftReviewLine,
            safety: .pendingProfessionalReview,
            simplicity: 1
        ),
        activity(
            id: "baby-nearby-shoulders",
            name: "Seated shoulder rolls",
            category: .withBabyNearby,
            format: .single,
            minimum: 2,
            maximum: 5,
            energies: [.low, .okay, .high],
            equipment: .none,
            position: .seated,
            instructions: [
                "Sit where your baby is safely nearby. You are not holding your baby.",
                "Roll your shoulders slowly, only through a range that feels easy.",
                "Let them rest when you are done."
            ],
            easier: "Make the circle smaller, or pause after one roll.",
            caution: MovementCatalog.draftReviewLine,
            safety: .pendingProfessionalReview,
            simplicity: 1
        ),
        activity(
            id: "baby-nearby-reach",
            name: "Small standing reach",
            category: .withBabyNearby,
            format: .single,
            minimum: 2,
            maximum: 5,
            energies: [.low, .okay],
            equipment: .none,
            position: .standing,
            instructions: [
                "Keep your baby in a safe place nearby. This reach is only for your arms.",
                "Raise your arms only as far as feels comfortable.",
                "Lower them slowly."
            ],
            easier: "Reach forward instead of up, or stay seated.",
            caution: MovementCatalog.draftReviewLine,
            safety: .pendingProfessionalReview,
            simplicity: 2
        ),
        activity(
            id: "baby-nearby-walk",
            name: "Easy walk with the baby nearby",
            category: .withBabyNearby,
            format: .selfDirected,
            minimum: 5,
            maximum: 20,
            energies: [.okay, .high],
            equipment: .none,
            position: .standing,
            instructions: [
                "Walk at an easy pace while your baby is safely nearby, for example resting in a stroller.",
                "The walk is for you. Your baby is not part of the exercise.",
                "Turn back whenever you want. A short walk still counts."
            ],
            easier: "Walk more slowly, or walk indoors.",
            caution: MovementCatalog.draftReviewLine,
            safety: .pendingProfessionalReview,
            simplicity: 2
        ),
        activity(
            id: "baby-nearby-quiet-minutes",
            name: "A few quiet minutes",
            category: .withBabyNearby,
            format: .miniSession,
            minimum: 5,
            maximum: 10,
            energies: [.okay],
            equipment: .none,
            position: .standing,
            instructions: [
                "Your baby stays in a safe spot nearby. You are not holding your baby.",
                "A few slow shoulder rolls.",
                "A small arm reach, then rest. Either part can be skipped."
            ],
            easier: "Do only the shoulder rolls.",
            caution: MovementCatalog.draftReviewLine,
            safety: .pendingProfessionalReview,
            simplicity: 3
        )
    ]

    static func activity(id: String) -> CatalogActivity? {
        all.first { $0.id == id }
    }

    private static func activity(
        id: String,
        name: String,
        category: CatalogCategory,
        format: CatalogFormat,
        minimum: Int,
        maximum: Int,
        energies: [MovementEnergy],
        equipment: MovementEquipment,
        position: CatalogPosition,
        instructions: [String],
        easier: String,
        caution: String = "Stop if it doesn't feel right. This is one general idea, not a program.",
        safety: CatalogSafety = .reviewedGeneral,
        simplicity: Int
    ) -> CatalogActivity {
        CatalogActivity(
            id: id,
            name: name,
            category: category,
            format: format,
            minimumMinutes: minimum,
            maximumMinutes: maximum,
            energies: energies,
            equipment: equipment,
            position: position,
            instructions: instructions,
            easier: easier,
            caution: caution,
            safety: safety,
            simplicity: simplicity
        )
    }
}

struct RecommendationQuery: Equatable {
    var minutes: Int
    var energy: MovementEnergy
    var selection: EquipmentSelection
    var preferred: Set<CatalogCategory>
    var avoidFloor: Bool
    var excludeIDs: Set<String> = []

    var timeUpperBound: Int { minutes >= 20 ? 30 : minutes }
}

enum MovementCatalogRecommender {
    static let noMatchMessage = "No suitable match for this equipment, time, and energy. Change the selection, or do your own thing."

    static func suggestions(
        for query: RecommendationQuery,
        catalog: [CatalogActivity] = MovementCatalog.all
    ) -> [CatalogActivity] {
        let eligible = catalog.filter { matches($0, query: query) }
        let pool = eligible.filter { $0.energies.contains(query.energy) }
        guard !pool.isEmpty else { return [] }

        var ranked = pool.sorted { rank($0, query: query) < rank($1, query: query) }
        if !query.excludeIDs.isEmpty {
            let unseen = ranked.filter { !query.excludeIDs.contains($0.id) }
            guard !unseen.isEmpty else { return [] }
            ranked = unseen
        }

        var result: [CatalogActivity] = []
        func add(_ item: CatalogActivity?) {
            guard let item, result.count < 3, !result.contains(where: { $0.id == item.id }) else { return }
            result.append(item)
        }

        for category in diversityOrder(for: query) {
            add(ranked.first { $0.category == category })
        }
        var guardrail = 0
        while result.count < 3 && guardrail < ranked.count {
            let before = result.count
            add(ranked.first { candidate in !result.contains { $0.id == candidate.id } })
            if result.count == before { break }
            guardrail += 1
        }
        return result
    }

    private static func diversityOrder(for query: RecommendationQuery) -> [CatalogCategory] {
        switch query.selection {
        case .focused(.none):
            if query.energy == .low {
                return [.walking, .dancing, .mobility, .stretching, .yogaInspired]
            }
            if query.energy == .high {
                return [.walking, .dancing, .bodyweightStrength, .mobility]
            }
            return [.walking, .dancing, .bodyweightStrength, .mobility, .stretching]
        case .surprise(let owned):
            let allowed = owned.isEmpty ? Set([MovementEquipment.none]) : owned
            if allowed.count > 1 {
                return []
            }
            if allowed == [.none] {
                return diversityOrder(for: RecommendationQuery(
                    minutes: query.minutes,
                    energy: query.energy,
                    selection: .focused(.none),
                    preferred: query.preferred,
                    avoidFloor: query.avoidFloor
                ))
            }
            return []
        case .focused:
            return []
        }
    }

    private static func matches(_ activity: CatalogActivity, query: RecommendationQuery) -> Bool {
        switch activity.safety {
        case .reviewedGeneral, .pendingProfessionalReview:
            break
        }
        if query.avoidFloor && activity.position == .floor { return false }
        if activity.minimumMinutes > query.timeUpperBound { return false }
        switch query.selection {
        case .focused(let equipment):
            return activity.equipment == equipment
        case .surprise(let owned):
            let allowed = owned.isEmpty ? Set([MovementEquipment.none]) : owned
            return allowed.contains(activity.equipment)
        }
    }

    private static func rank(_ activity: CatalogActivity, query: RecommendationQuery) -> (Int, Int, Int, String) {
        let preference = query.preferred.contains(activity.category) ? 0 : 1
        let formatFit: Int
        if query.minutes <= 2 {
            formatFit = activity.format == .single ? 0 : 1
        } else if query.minutes <= 5 {
            formatFit = activity.format == .miniSession || activity.format == .single ? 0 : 1
        } else {
            formatFit = activity.format == .miniSession || activity.format == .selfDirected ? 0 : 1
        }
        return (preference, formatFit, activity.simplicity, activity.id)
    }
}

struct DiarySummary: Equatable {
    var dayCount: Int
    var activeSeconds: TimeInterval
    var activityCount: Int
    var categories: [String]
}

enum DiaryReflection {
    static let withMovement = "Look at what you made happen this week."
    static let noMovement = "Some weeks are full in other ways. You can come back whenever you're ready."
    static let welcomeBack = "Welcome back. Let's find something that fits today."
    static let interrupted = "Life happens. Take your time."

    static func weekly(activityCount: Int) -> String {
        activityCount == 0 ? noMovement : withMovement
    }
}

enum MovementDiary {
    static func summary(of records: [MovementRecord], calendar: Calendar = .current) -> DiarySummary {
        var days = Set<Date>()
        var seconds: TimeInterval = 0
        var categories: [String] = []
        for record in records {
            days.insert(calendar.startOfDay(for: record.activityDate))
            seconds += record.loggedSeconds
            let name = record.kind.recordTitle
            if !categories.contains(name) { categories.append(name) }
        }
        return DiarySummary(
            dayCount: days.count,
            activeSeconds: seconds,
            activityCount: records.count,
            categories: categories
        )
    }

    static func records(
        _ records: [MovementRecord],
        inWeekOf day: Date,
        calendar: Calendar = .current
    ) -> [MovementRecord] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: day) else { return [] }
        return records.filter { interval.contains($0.activityDate) }
    }

    static func records(
        _ records: [MovementRecord],
        on day: Date,
        calendar: Calendar = .current
    ) -> [MovementRecord] {
        records.filter { calendar.isDate($0.activityDate, inSameDayAs: day) }
    }
}

struct TodayCheckInMemory: Codable, Equatable {
    var minutes: Int
    var energy: String
    var equipment: [String]
    /// "surprise" or one equipment raw value. Missing on older saves.
    var selection: String?
}

enum TodayCheckInStore {
    static let storageKey = "trenira.todayCheckIn.v1"

    static func load(defaults: UserDefaults = .standard) -> TodayCheckInMemory? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(TodayCheckInMemory.self, from: data)
    }

    static func save(_ memory: TodayCheckInMemory, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(memory) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

enum MovementFavoriteStore {
    static let storageKey = "trenira.movementFavorites.v1"

    static func ids(defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: storageKey) ?? [])
    }

    static func toggle(_ id: String, defaults: UserDefaults = .standard) {
        var current = ids(defaults: defaults)
        if current.contains(id) {
            current.remove(id)
        } else {
            current.insert(id)
        }
        defaults.set(Array(current).sorted(), forKey: storageKey)
    }
}

extension CompanionProfile {
    var catalogPreferences: Set<CatalogCategory> {
        if let preferredKinds, !preferredKinds.isEmpty {
            return Set(preferredKinds.compactMap(CatalogCategory.init(rawValue:)))
        }
        var mapped: Set<CatalogCategory> = []
        if formats.contains(.walking) { mapped.insert(.walking) }
        if formats.contains(.yoga) { mapped.insert(.yogaInspired) }
        if formats.contains(.dancing) { mapped.insert(.dancing) }
        if formats.contains(.strength) { mapped.insert(.bodyweightStrength) }
        return mapped
    }

    var availableEquipment: Set<MovementEquipment> {
        let stored = Set(equipment ?? [])
        return stored.isEmpty ? [.none] : stored
    }

    var avoidsFloor: Bool { avoidFloorMoves ?? false }
}
