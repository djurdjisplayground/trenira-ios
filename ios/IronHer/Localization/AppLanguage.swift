import Foundation

/// App language. MVP ships English only.
/// Add cases + string tables when localization returns in a later release.
enum AppLanguage: String, CaseIterable, Codable, Identifiable, Hashable {
    case english = "en"

    var id: String { rawValue }

    var localeIdentifier: String { "en" }

    var locale: Locale { Locale(identifier: localeIdentifier) }
}
