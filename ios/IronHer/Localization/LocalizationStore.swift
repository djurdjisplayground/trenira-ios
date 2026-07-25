import Foundation
import Observation

/// English UI strings and exercise display names for MVP.
/// Kept as an injectable store so multi-language support can return later without rewriting call sites.
@Observable
@MainActor
final class LocalizationStore {
    /// Always English for MVP. Reserved for future language switching.
    let language: AppLanguage = .english

    var locale: Locale { language.locale }

    func t(_ key: L10nKey) -> String {
        UIStrings.string(key, language: language)
    }

    /// Format with one `%@` / `%lld` style placeholder using `String(format:)`.
    func t(_ key: L10nKey, _ args: CVarArg...) -> String {
        String(format: t(key), locale: locale, arguments: args)
    }

    /// Localized built-in exercise name. Custom exercises keep the user-entered name.
    func exerciseName(id: String, englishFallback: String, isCustom: Bool) -> String {
        if isCustom { return englishFallback }
        return ExerciseLocalizations.name(for: id, language: language, englishFallback: englishFallback)
    }

    func exerciseName(_ exercise: Exercise) -> String {
        exerciseName(id: exercise.id, englishFallback: exercise.name, isCustom: exercise.isCustom)
    }
}
