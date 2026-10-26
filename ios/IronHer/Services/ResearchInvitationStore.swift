import Foundation
#if DEBUG
import os
#endif

/// Visible copy for the founder feedback invitation and the Settings entry.
enum ResearchInvitationCopy {
    static let title = "Help shape trenira 💜"
    static let message = "I'm the founder of trenira, and I'd love to hear about your experience using the app. Would you be open to sharing feedback or having a quick 15-minute conversation?"
    static let acceptTitle = "I'd love to help"
    static let laterTitle = "Maybe later"
    static let optOutTitle = "Don't ask again"
    static let settingsTitle = "Talk to the founder"
    static let settingsSubtitle = "Share feedback and help shape trenira"
    static let openFailedTitle = "Couldn't open the form"
    static let openFailedMessage = "The research form didn't open. You can try again."
    static let tryAgainTitle = "Try Again"
}

/// Permanent outcome of the automatic invitation. Absence means still eligible.
enum ResearchInvitationStatus: String {
    /// "I'd love to help" opened the form. This does not mean the form was submitted.
    case accepted
    /// "Don't ask again."
    case optedOut
}

/// Local invitation state for this installation.
/// Ordinary app updates do not clear it. Account erasure does not clear it either,
/// so deleting account data does not ask the same installation again.
enum ResearchInvitationStore {
    static let statusKey = "trenira.researchInvitation.status.v2"
    static let lastPresentedDayKey = "trenira.researchInvitation.lastPresentedDay.v2"

    /// Previous one-time response (`accepted` / `dismissed`) and cohort. Removed after migration.
    static let legacyResponseKey = "trenira.researchInvitation.v1"
    static let legacyCohortKey = "trenira.researchInvitation.cohort.v1"

    #if DEBUG
    /// In-memory only. Lets a debug build show the invitation without waiting for tomorrow.
    private static var debugForcePresentation = false

    static func armImmediatePresentation() {
        debugForcePresentation = true
        FeedbackInvitationLog.line("debug force armed; saved invitation state was not changed")
    }

    static func consumeImmediatePresentation() {
        debugForcePresentation = false
    }

    static var isImmediatePresentationArmed: Bool { debugForcePresentation }
    #endif

    /// Moves a previous successful open into the new status, then deletes the old keys.
    /// "Maybe later" used to be stored as a permanent dismissal. Those installs stay eligible.
    static func migrateLegacyStateIfNeeded(defaults: UserDefaults = .standard) {
        let legacyResponse = defaults.string(forKey: legacyResponseKey)
        let hadLegacyCohort = defaults.object(forKey: legacyCohortKey) != nil
        if status(in: defaults) == nil, legacyResponse == ResearchInvitationStatus.accepted.rawValue {
            defaults.set(ResearchInvitationStatus.accepted.rawValue, forKey: statusKey)
        }
        defaults.removeObject(forKey: legacyResponseKey)
        defaults.removeObject(forKey: legacyCohortKey)
        #if DEBUG
        if legacyResponse != nil || hadLegacyCohort {
            logPersistence(
                "migrated legacy response=\(legacyResponse ?? "none") removedCohort=\(hadLegacyCohort) status=\(status(in: defaults)?.rawValue ?? "eligible")",
                defaults: defaults
            )
        }
        #endif
    }

    static func status(in defaults: UserDefaults = .standard) -> ResearchInvitationStatus? {
        guard let raw = defaults.string(forKey: statusKey) else { return nil }
        return ResearchInvitationStatus(rawValue: raw)
    }

    static func lastPresentedAt(in defaults: UserDefaults = .standard) -> Date? {
        guard let interval = defaults.object(forKey: lastPresentedDayKey) as? TimeInterval else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    static func markAccepted(in defaults: UserDefaults = .standard) {
        defaults.set(ResearchInvitationStatus.accepted.rawValue, forKey: statusKey)
        #if DEBUG
        logPersistence("persisted status=accepted", defaults: defaults)
        #endif
    }

    static func markOptedOut(in defaults: UserDefaults = .standard) {
        defaults.set(ResearchInvitationStatus.optedOut.rawValue, forKey: statusKey)
        #if DEBUG
        logPersistence("persisted status=optedOut", defaults: defaults)
        #endif
    }

    static func notePresented(
        at date: Date = .now,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(date.timeIntervalSince1970, forKey: lastPresentedDayKey)
        #if DEBUG
        logPersistence("persisted lastShown=\(Self.debugTimestamp(date))", defaults: defaults)
        #endif
    }

    #if DEBUG
    static func debugTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    static func debugStatusText(
        now: Date = .now,
        calendar: Calendar = .current,
        defaults: UserDefaults = .standard
    ) -> String {
        let status = status(in: defaults)?.rawValue ?? "eligible"
        let last = lastPresentedAt(in: defaults).map(debugTimestamp) ?? "never"
        let shownToday = lastPresentedAt(in: defaults).map { calendar.isDate($0, inSameDayAs: now) } ?? false
        let reason = ResearchInvitationPolicy.blockReason(
            homeReady: true,
            onHomeTab: true,
            workoutInterfaceVisible: false,
            now: now,
            calendar: calendar,
            defaults: defaults,
            ignoringDebugForce: true
        )
        let automatic = reason == "present" ? "would show on Home" : "would not show — \(reason)"
        let force = isImmediatePresentationArmed ? " Debug show is armed and does not write this state." : ""
        return "Status: \(status). Last shown: \(last). Shown today: \(shownToday ? "yes" : "no"). \(automatic).\(force)"
    }

    private static func logPersistence(_ message: String, defaults: UserDefaults) {
        guard defaults === UserDefaults.standard else { return }
        FeedbackInvitationLog.line(message)
    }
    #endif

    /// Eligible, and not already shown on this calendar day.
    /// A debug "show now" bypasses both gates until the invitation actually appears.
    static func canOfferAutomatically(
        now: Date = .now,
        calendar: Calendar = .current,
        defaults: UserDefaults = .standard
    ) -> Bool {
        guard AppConfiguration.researchInvitationFormURL != nil else { return false }
        #if DEBUG
        if debugForcePresentation { return true }
        #endif
        switch status(in: defaults) {
        case .accepted, .optedOut:
            return false
        case nil:
            break
        }
        if let last = lastPresentedAt(in: defaults), calendar.isDate(last, inSameDayAs: now) {
            return false
        }
        return true
    }

    #if DEBUG
    /// Clears invitation status and the last shown date. Does not touch other preferences.
    static func resetForTesting(in defaults: UserDefaults = .standard) {
        debugForcePresentation = false
        defaults.removeObject(forKey: statusKey)
        defaults.removeObject(forKey: lastPresentedDayKey)
        defaults.removeObject(forKey: legacyResponseKey)
        defaults.removeObject(forKey: legacyCohortKey)
        logPersistence("reset invitation state", defaults: defaults)
    }
    #endif
}

#if DEBUG
enum FeedbackInvitationLog {
    private static let logger = Logger(subsystem: "info.trenira.app", category: "FeedbackInvitation")

    static func line(_ message: String) {
        print("[FeedbackInvitation] \(message)")
        logger.info("[FeedbackInvitation] \(message, privacy: .public)")
    }
}
#endif

/// When the automatic invitation may appear, and how a successful open is recorded.
enum ResearchInvitationPolicy {
    /// Why an automatic invitation is shown or skipped. `present` is the only case that shows it.
    static func blockReason(
        homeReady: Bool,
        onHomeTab: Bool,
        workoutInterfaceVisible: Bool,
        now: Date = .now,
        calendar: Calendar = .current,
        defaults: UserDefaults = .standard,
        ignoringDebugForce: Bool = false
    ) -> String {
        _ = ignoringDebugForce
        if !homeReady { return "home screen is not ready" }
        if !onHomeTab { return "not on the home tab" }
        if workoutInterfaceVisible { return "a workout is active" }
        guard AppConfiguration.researchInvitationFormURL != nil else { return "form URL is missing" }
        #if DEBUG
        if !ignoringDebugForce, ResearchInvitationStore.isImmediatePresentationArmed { return "present" }
        #endif
        switch ResearchInvitationStore.status(in: defaults) {
        case .accepted:
            return "the form was already opened on this installation"
        case .optedOut:
            return "don't ask again"
        case nil:
            break
        }
        if let last = ResearchInvitationStore.lastPresentedAt(in: defaults), calendar.isDate(last, inSameDayAs: now) {
            return "already shown today"
        }
        return "present"
    }

    static func shouldPresent(
        homeReady: Bool,
        onHomeTab: Bool,
        workoutInterfaceVisible: Bool,
        now: Date = .now,
        calendar: Calendar = .current,
        defaults: UserDefaults = .standard
    ) -> Bool {
        blockReason(
            homeReady: homeReady,
            onHomeTab: onHomeTab,
            workoutInterfaceVisible: workoutInterfaceVisible,
            now: now,
            calendar: calendar,
            defaults: defaults
        ) == "present"
    }

    /// Records acceptance only after the system reports that the form opened.
    /// A failed open leaves the invitation unsettled so it can be tried again.
    @discardableResult
    static func recordOpenedForm(
        didOpen: Bool,
        formURL: URL? = AppConfiguration.researchInvitationFormURL,
        defaults: UserDefaults = .standard
    ) -> Bool {
        guard didOpen, formURL != nil else { return false }
        ResearchInvitationStore.markAccepted(in: defaults)
        return true
    }
}
