import Foundation

struct ExerciseSearchFilters: Equatable {
    var muscleGroup: MuscleGroup?
    var equipment: EquipmentType?
    var movementFamily: MovementFamily?
    var laterality: Laterality?
    var measurementUnit: MeasurementUnit?

    var isEmpty: Bool {
        muscleGroup == nil
            && equipment == nil
            && movementFamily == nil
            && laterality == nil
            && measurementUnit == nil
    }
}

enum ExerciseSearchService {
    /// Common search shortcuts → extra terms that should match related exercises.
    private static let querySynonyms: [String: [String]] = [
        "tricep": ["triceps", "skull crusher", "skull crushers", "pushdown", "extension", "kickback"],
        "triceps": ["tricep", "skull crusher", "skull crushers", "pushdown", "extension"],
        "tris": ["triceps", "tricep"],
        "lat": ["lats", "latissimus", "pulldown", "pull down", "pullup", "pull up"],
        "lats": ["lat", "latissimus", "pulldown"],
        "glute": ["glutes", "gluteus", "hip thrust", "glute bridge", "kickback"],
        "glutes": ["glute", "gluteus", "hip thrust", "glute bridge", "kickback"],
        "quad": ["quads", "quadriceps", "squat", "leg extension", "lunge"],
        "quads": ["quad", "quadriceps", "squat", "leg extension"],
        "ham": ["hamstring", "hamstrings", "rdl", "leg curl", "deadlift"],
        "hamstring": ["ham", "hamstrings", "rdl", "leg curl"],
        "hamstrings": ["ham", "hamstring", "rdl", "leg curl"],
        "chest": ["pec", "pecs", "bench", "press", "fly", "flye"],
        "pec": ["chest", "pecs", "bench"],
        "pecs": ["chest", "pec", "bench"],
        "bicep": ["biceps", "curl"],
        "biceps": ["bicep", "curl"],
        "shoulder": ["shoulders", "delt", "delts", "press", "raise"],
        "shoulders": ["shoulder", "delt", "delts"],
        "delt": ["shoulder", "shoulders", "delts", "raise"],
        "back": ["lats", "row", "pulldown", "pull"],
        "core": ["abs", "ab", "oblique", "crunch"],
        "abs": ["core", "ab", "crunch"],
        "rdl": ["romanian deadlift", "romanian"],
        "skull": ["skull crusher", "skull crushers", "lying tricep"],
        "pulldown": ["pull down", "lat pulldown", "lat"],
        "kickback": ["glute kickback", "tricep kickback"],
    ]

    static func search(
        _ query: String,
        in exercises: [Exercise],
        filters: ExerciseSearchFilters = ExerciseSearchFilters()
    ) -> [Exercise] {
        let filtered = exercises.filter { exercise in
            if let muscle = filters.muscleGroup, exercise.primaryMuscleGroup != muscle { return false }
            if let equipment = filters.equipment, exercise.equipment != equipment { return false }
            if let family = filters.movementFamily, exercise.movementFamily != family { return false }
            if let laterality = filters.laterality, exercise.laterality != laterality { return false }
            if let unit = filters.measurementUnit, exercise.measurementUnit != unit { return false }
            return true
        }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return filtered }

        let normalizedQuery = trimmed.lowercased()
        let queryTokens = normalizedQuery.split(separator: " ").map(String.init)
        let expanded = expandedSearchTerms(query: normalizedQuery, tokens: queryTokens)

        let scored = filtered.compactMap { exercise -> (Exercise, Int)? in
            let score = score(
                exercise: exercise,
                normalizedQuery: normalizedQuery,
                tokens: queryTokens,
                expandedTerms: expanded
            )
            return score > 0 ? (exercise, score) : nil
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0.name.localizedCaseInsensitiveCompare(rhs.0.name) == .orderedAscending
            }
            .map(\.0)
    }

    private static func expandedSearchTerms(query: String, tokens: [String]) -> [String] {
        var terms = Set<String>()
        terms.insert(query)
        tokens.forEach { terms.insert($0) }

        for token in [query] + tokens {
            if let synonyms = querySynonyms[token] {
                synonyms.forEach { terms.insert($0) }
            }
            // Stem-ish: tricep ↔ triceps, glute ↔ glutes
            if token.hasSuffix("s"), token.count > 3 {
                terms.insert(String(token.dropLast()))
            } else {
                terms.insert(token + "s")
            }
        }

        return Array(terms)
    }

    private static func score(
        exercise: Exercise,
        normalizedQuery: String,
        tokens: [String],
        expandedTerms: [String]
    ) -> Int {
        var best = 0

        for term in exercise.searchableTerms {
            best = max(best, scoreTerm(term, normalizedQuery: normalizedQuery, tokens: tokens))
            for expanded in expandedTerms where expanded != normalizedQuery {
                best = max(best, scoreExpandedTerm(term, expanded: expanded))
            }
        }

        // Muscle-group shortcut: "tricep" → all triceps primaries.
        for muscle in [exercise.primaryMuscleGroup] + exercise.secondaryMuscleGroups {
            for synonym in muscle.searchSynonyms {
                if synonym == normalizedQuery || tokens.contains(synonym) || expandedTerms.contains(synonym) {
                    let boost = muscle == exercise.primaryMuscleGroup ? 78 : 60
                    best = max(best, boost)
                }
            }
        }

        // Equipment shortcut: "cable", "dumbbell", etc.
        let equipmentLabel = exercise.equipment.label.lowercased()
        if equipmentLabel == normalizedQuery || tokens.contains(equipmentLabel) {
            best = max(best, 70)
        }

        if tokens.count > 1 {
            let allTokensMatch = tokens.allSatisfy { token in
                exercise.searchableTerms.contains { term in
                    term.lowercased().contains(token)
                }
            }
            if allTokensMatch { best = max(best, 70) }
        }

        return best
    }

    private static func scoreExpandedTerm(_ term: String, expanded: String) -> Int {
        let normalizedTerm = term.lowercased()
        guard expanded.count >= 2 else { return 0 }
        if normalizedTerm == expanded { return 88 }
        if normalizedTerm.hasPrefix(expanded) { return 78 }
        if normalizedTerm.contains(expanded) { return 68 }
        return 0
    }

    private static func scoreTerm(_ term: String, normalizedQuery: String, tokens: [String]) -> Int {
        let normalizedTerm = term.lowercased()

        if normalizedTerm == normalizedQuery { return 100 }
        if normalizedTerm.hasPrefix(normalizedQuery) { return 90 }
        if normalizedTerm.contains(normalizedQuery) { return 80 }

        for token in tokens where token.count >= 2 {
            if normalizedTerm == token { return 85 }
            if normalizedTerm.hasPrefix(token) { return 75 }
            if normalizedTerm.contains(token) { return 65 }
        }

        if fuzzyContains(normalizedTerm, query: normalizedQuery) { return 45 }
        if levenshteinDistance(normalizedTerm, normalizedQuery) <= 2, normalizedQuery.count >= 3 { return 55 }

        return 0
    }

    private static func fuzzyContains(_ text: String, query: String) -> Bool {
        guard !query.isEmpty else { return false }
        var queryIndex = query.startIndex
        for character in text {
            if character == query[queryIndex] {
                queryIndex = query.index(after: queryIndex)
                if queryIndex == query.endIndex { return true }
            }
        }
        return false
    }

    private static func levenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs)
        let b = Array(rhs)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }

        var previous = Array(0...b.count)
        var current = Array(repeating: 0, count: b.count + 1)

        for i in 1...a.count {
            current[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = min(
                    previous[j] + 1,
                    current[j - 1] + 1,
                    previous[j - 1] + cost
                )
            }
            swap(&previous, &current)
        }
        return previous[b.count]
    }
}
