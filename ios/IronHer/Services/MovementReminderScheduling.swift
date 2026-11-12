import Foundation
import UserNotifications

enum MovementReminderAuthorization: Equatable {
    case notDetermined
    case denied
    case allowed
}

enum MovementReminderApplyNote: Equatable {
    case scheduled
    case cleared
    case needsPermission
}

protocol MovementReminderScheduling: Sendable {
    func authorization() async -> MovementReminderAuthorization
    func requestAuthorization() async -> MovementReminderAuthorization
    func replace(with requests: [MovementReminderRequest]) async
    func cancelAll() async
}

struct SystemMovementReminderScheduler: MovementReminderScheduling {
    func authorization() async -> MovementReminderAuthorization {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return Self.map(settings.authorizationStatus)
    }

    func requestAuthorization() async -> MovementReminderAuthorization {
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
        if granted { return .allowed }
        return await authorization()
    }

    func replace(with requests: [MovementReminderRequest]) async {
        await cancelAll()
        let center = UNUserNotificationCenter.current()
        for request in requests {
            let content = UNMutableNotificationContent()
            content.title = request.title
            content.body = request.body
            content.sound = .default
            content.userInfo = MovementReminderPlan.userInfo(for: request)
            var components = DateComponents()
            components.hour = request.hour
            components.minute = request.minute
            if let weekday = request.weekday {
                components.weekday = weekday
            }
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let notification = UNNotificationRequest(identifier: request.identifier, content: content, trigger: trigger)
            try? await center.add(notification)
        }
    }

    func cancelAll() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let identifiers = pending.map(\.identifier).filter {
            $0.hasPrefix(MovementReminderPlan.identifierPrefix)
        }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private static func map(_ status: UNAuthorizationStatus) -> MovementReminderAuthorization {
        switch status {
        case .authorized, .provisional, .ephemeral:
            .allowed
        case .denied:
            .denied
        case .notDetermined:
            .notDetermined
        @unknown default:
            .denied
        }
    }
}

struct MovementReminderController {
    var scheduler: any MovementReminderScheduling
    var defaults: UserDefaults

    static let live = MovementReminderController(
        scheduler: SystemMovementReminderScheduler(),
        defaults: .standard
    )

    func setEnabled(_ enabled: Bool, ownerId: String, preferences: MovementReminderPreferences) async -> (MovementReminderPreferences, MovementReminderApplyNote) {
        var next = preferences.sanitized()
        if !enabled {
            next.enabled = false
            MovementReminderStore.save(next, ownerId: ownerId, defaults: defaults)
            await scheduler.cancelAll()
            return (next, .cleared)
        }

        var status = await scheduler.authorization()
        if status == .notDetermined {
            status = await scheduler.requestAuthorization()
        }
        guard status == .allowed else {
            next.enabled = false
            MovementReminderStore.save(next, ownerId: ownerId, defaults: defaults)
            await scheduler.cancelAll()
            return (next, .needsPermission)
        }

        next.enabled = true
        MovementReminderStore.save(next, ownerId: ownerId, defaults: defaults)
        let note = await apply(ownerId: ownerId, sessionActive: true)
        return (MovementReminderStore.load(ownerId: ownerId, defaults: defaults), note)
    }

    func save(_ preferences: MovementReminderPreferences, ownerId: String, sessionActive: Bool) async -> MovementReminderApplyNote {
        MovementReminderStore.save(preferences.sanitized(), ownerId: ownerId, defaults: defaults)
        return await apply(ownerId: ownerId, sessionActive: sessionActive)
    }

    func apply(ownerId: String, sessionActive: Bool) async -> MovementReminderApplyNote {
        guard sessionActive else {
            await scheduler.cancelAll()
            return .cleared
        }
        let preferences = MovementReminderStore.load(ownerId: ownerId, defaults: defaults)
        guard preferences.enabled else {
            await scheduler.cancelAll()
            return .cleared
        }
        let status = await scheduler.authorization()
        guard status == .allowed else {
            await scheduler.cancelAll()
            return .needsPermission
        }
        await scheduler.replace(with: MovementReminderPlan.requests(for: preferences, ownerId: ownerId))
        return .scheduled
    }

    func erase() async {
        MovementReminderStore.removeAll(defaults: defaults)
        await scheduler.cancelAll()
    }
}

final class MovementReminderDelegate: NSObject, UNUserNotificationCenterDelegate {
    var onOpen: (MovementReminderDestination) -> Void = { _ in }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        guard notification.request.identifier.hasPrefix(MovementReminderPlan.identifierPrefix) else {
            return []
        }
        return [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.notification.request.identifier.hasPrefix(MovementReminderPlan.identifierPrefix) else { return }
        onOpen(MovementReminderDestination(userInfo: response.notification.request.content.userInfo))
    }
}
