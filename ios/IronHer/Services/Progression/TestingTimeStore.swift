import Foundation

/// DEBUG-only perceived-time offset for return-after-break testing.
/// Advances the clock used by break detection without mutating workout history.
@Observable
@MainActor
final class TestingTimeStore {
    private let defaultsKey = "testingTimeSimulatedDaysOffset"

    /// Days added to real `Date()` when evaluating return-after-break.
    private(set) var simulatedDaysOffset: Int = 0
    private(set) var revision = 0

    init() {
        guard DevelopmentConfig.isDevelopmentMode else {
            simulatedDaysOffset = 0
            return
        }
        simulatedDaysOffset = max(0, UserDefaults.standard.integer(forKey: defaultsKey))
    }

    /// Perceived "now" for return-after-break. Always real time outside development mode.
    var now: Date {
        guard DevelopmentConfig.isDevelopmentMode, simulatedDaysOffset != 0 else {
            return .now
        }
        return Calendar.current.date(byAdding: .day, value: simulatedDaysOffset, to: .now) ?? .now
    }

    var isSimulating: Bool {
        DevelopmentConfig.isDevelopmentMode && simulatedDaysOffset != 0
    }

    /// Visible banner text while simulation is active (DEBUG only).
    var testModeBannerText: String? {
        guard isSimulating else { return nil }
        return "TEST MODE: +\(simulatedDaysOffset) days simulated"
    }

    func setSimulatedDaysPassed(_ days: Int) {
        guard DevelopmentConfig.isDevelopmentMode else { return }
        let next = max(0, days)
        guard next != simulatedDaysOffset else {
            revision += 1
            return
        }
        simulatedDaysOffset = next
        persist()
        revision += 1
    }

    func reset() {
        guard DevelopmentConfig.isDevelopmentMode else { return }
        simulatedDaysOffset = 0
        persist()
        revision += 1
    }

    private func persist() {
        if simulatedDaysOffset == 0 {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
        } else {
            UserDefaults.standard.set(simulatedDaysOffset, forKey: defaultsKey)
        }
    }
}

/// Presets for the Developer → Simulate Time Passed UI.
enum SimulatedTimePreset: String, CaseIterable, Identifiable {
    case none
    case threeDays
    case oneWeek
    case twoWeeks
    case threeWeeks
    case oneMonth
    case twoMonths

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "No time passed"
        case .threeDays: return "+3 days"
        case .oneWeek: return "1 week (+7)"
        case .twoWeeks: return "2 weeks (+14)"
        case .threeWeeks: return "3 weeks (+21)"
        case .oneMonth: return "1 month (+28)"
        case .twoMonths: return "2 months (+56)"
        }
    }

    var days: Int {
        switch self {
        case .none: return 0
        case .threeDays: return 3
        case .oneWeek: return 7
        case .twoWeeks: return 14
        case .threeWeeks: return 21
        case .oneMonth: return 28
        case .twoMonths: return 56
        }
    }

    static func matching(days: Int) -> SimulatedTimePreset? {
        allCases.first { $0.days == days }
    }
}
