import SwiftUI

enum WeightUnit: String, Codable, CaseIterable, Identifiable {
    case kilograms
    case pounds

    var id: String { rawValue }

    var label: String {
        switch self {
        case .kilograms: return "Kilograms (kg)"
        case .pounds: return "Pounds (lb)"
        }
    }

    var shortLabel: String {
        switch self {
        case .kilograms: return "kg"
        case .pounds: return "lb"
        }
    }

    @MainActor
    func localizedLabel(_ l10n: LocalizationStore) -> String {
        switch self {
        case .kilograms: return l10n.t(.kilograms_kg)
        case .pounds: return l10n.t(.pounds_lb)
        }
    }
}

/// Per-exercise override for display/input unit. Default follows Settings → Weight Unit.
enum ExerciseWeightUnitPreference: String, Codable, CaseIterable, Identifiable {
    case useDefault
    case kilograms
    case pounds

    var id: String { rawValue }

    var label: String {
        switch self {
        case .useDefault: return "Use default unit"
        case .kilograms: return "Kilograms (kg)"
        case .pounds: return "Pounds (lb)"
        }
    }

    var shortLabel: String {
        switch self {
        case .useDefault: return "Default"
        case .kilograms: return "kg"
        case .pounds: return "lb"
        }
    }

    func resolved(defaultUnit: WeightUnit) -> WeightUnit {
        switch self {
        case .useDefault: return defaultUnit
        case .kilograms: return .kilograms
        case .pounds: return .pounds
        }
    }

    static func from(_ unit: WeightUnit) -> ExerciseWeightUnitPreference {
        switch unit {
        case .kilograms: return .kilograms
        case .pounds: return .pounds
        }
    }
}

enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    @MainActor
    func localizedLabel(_ l10n: LocalizationStore) -> String {
        switch self {
        case .system: return l10n.t(.system)
        case .light: return l10n.t(.light)
        case .dark: return l10n.t(.dark)
        }
    }
}

/// Session feedback style — chosen once in Settings, not asked each workout.
enum CoachingMode: String, Codable, CaseIterable, Identifiable {
    case minimal
    case encouragement

    var id: String { rawValue }

    var label: String {
        switch self {
        case .minimal: return "Minimal"
        case .encouragement: return "Encouragement"
        }
    }

    var detail: String {
        switch self {
        case .minimal:
            return "No motivational messages — just the essentials."
        case .encouragement:
            return "Subtle progress cues after each set."
        }
    }

    @MainActor
    func localizedLabel(_ l10n: LocalizationStore) -> String {
        switch self {
        case .minimal: return l10n.t(.minimal)
        case .encouragement: return l10n.t(.encouragement)
        }
    }

    @MainActor
    func localizedDetail(_ l10n: LocalizationStore) -> String {
        switch self {
        case .minimal: return l10n.t(.coaching_minimal_detail)
        case .encouragement: return l10n.t(.coaching_encouragement_detail)
        }
    }
}

enum GymEquipmentOption: String, CaseIterable, Identifiable {
    case dumbbells = "Dumbbell"
    case barbell = "Barbell"
    case machines = "Machine"
    case cables = "Cable"
    case bodyweight = "Bodyweight"
    case kettlebells = "Kettlebell"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dumbbells: return "Dumbbells"
        case .barbell: return "Barbell"
        case .machines: return "Machines"
        case .cables: return "Cables"
        case .bodyweight: return "Bodyweight"
        case .kettlebells: return "Kettlebells"
        }
    }

    /// Expands a coarse chip into fine-grained kinds for filtering.
    var expandedKinds: Set<GymEquipmentKind> {
        switch self {
        case .dumbbells:
            return [.dumbbells, .flatBench, .adjustableBench]
        case .barbell:
            return [.barbell, .weightPlates, .ezCurlBar, .smithMachine, .squatRack]
        case .machines:
            return Set(GymEquipmentCategory.machines.kinds)
        case .cables:
            return Set(GymEquipmentCategory.cables.kinds)
        case .bodyweight:
            return [.bodyweight, .pullUpBar, .dipStation, .resistanceBands]
        case .kettlebells:
            return [.kettlebells]
        }
    }
}

/// Development-only switches. Production builds keep feature entry points off.
enum DevelopmentConfig {
    /// Master gate for Developer Settings and related testing UX.
    /// Automatically `false` in Release / App Store builds.
    static var isDevelopmentMode: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }
}

/// Closed TestFlight / beta switches.
/// Premium architecture stays in the codebase — flip `isClosedBeta` to `false`
/// before public App Store launch to restore monetization.
enum BetaConfig {
    /// When `true`: unlock all Premium features, hide paywalls and purchase UI.
    static let isClosedBeta = true

    static var unlocksPremium: Bool { isClosedBeta }
    static var hidesMonetization: Bool { isClosedBeta }

    static let feedbackEmail = AppConfiguration.feedbackEmail

    static var feedbackMailtoURL: URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = feedbackEmail
        components.queryItems = [
            URLQueryItem(
                name: "subject",
                value: FeedbackService.subject
            ),
        ]
        return components.url ?? URL(string: "mailto:\(feedbackEmail)")!
    }
}

enum AppVersion {
    static var marketing: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    /// e.g. "1.0 (1)"
    static var label: String { "\(marketing) (\(build))" }
}
