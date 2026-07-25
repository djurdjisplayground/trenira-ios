import Foundation

/// App language. UI copy is English-only for MVP; demonstration cues already ship EN/DE/SR/ES.
enum AppLanguage: String, CaseIterable, Codable, Identifiable, Hashable {
    case english = "en"
    case german = "de"
    case serbian = "sr"
    case spanish = "es"

    var id: String { rawValue }

    var localeIdentifier: String {
        switch self {
        case .english: return "en"
        case .german: return "de"
        case .serbian: return "sr"
        case .spanish: return "es"
        }
    }

    var locale: Locale { Locale(identifier: localeIdentifier) }
}
