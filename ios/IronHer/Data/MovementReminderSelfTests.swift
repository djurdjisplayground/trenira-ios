import Foundation

#if DEBUG
enum MovementReminderSelfTests {
    struct Outcome: Sendable {
        var passed: Int
        var failed: Int
        var lines: [String]

        var summary: String {
            "\(passed) passed, \(failed) failed\n" + lines.joined(separator: "\n")
        }
    }

    static func runAll() -> Outcome {
        let box = ResultBox()
        let semaphore = DispatchSemaphore(value: 0)
        Task.detached {
            await run(into: box)
            semaphore.signal()
        }
        semaphore.wait()
        return box.outcome
    }

    private static func run(into box: ResultBox) async {
        var passed = 0
        var failed = 0
        var lines: [String] = []

        func check(_ name: String, _ condition: Bool) {
            if condition {
                passed += 1
                lines.append("✓ \(name)")
            } else {
                failed += 1
                lines.append("✗ \(name)")
            }
        }

        let defaults = UserDefaults(suiteName: "trenira.reminderSelfTests.\(UUID().uuidString)")!
        let scheduler = FakeReminderScheduler()
        let controller = MovementReminderController(scheduler: scheduler, defaults: defaults)
        defer { MovementReminderStore.removeAll(defaults: defaults) }

        check("missing preferences stay off", MovementReminderStore.load(ownerId: "guest:a", defaults: defaults) == .off)
        check(
            "off schedules nothing",
            MovementReminderPlan.requests(for: .off, ownerId: "guest:a").isEmpty
        )
        check(
            "erasure inventory contains reminder preferences",
            LocalDataErasureService.userContentUserDefaultsKeys.contains(MovementReminderStore.storageKey)
        )

        let legacy = """
        {"enabled":true,"hour":7,"minute":15}
        """.data(using: .utf8)!
        let decoded = try? JSONDecoder().decode(MovementReminderPreferences.self, from: legacy)
        check("older preferences still decode", decoded?.enabled == true && decoded?.hour == 7 && decoded?.minute == 15)
        check("older preferences default to a daily reminder", decoded?.frequency == .daily)

        scheduler.status = .denied
        var preferences = MovementReminderPreferences.off
        let denied = await controller.setEnabled(true, ownerId: "guest:a", preferences: preferences)
        check("denied permission does not enable reminders", denied.0.enabled == false && denied.1 == .needsPermission)
        check("denied permission does not request again", scheduler.requestCount == 0)
        check("denied permission schedules nothing", scheduler.scheduled.isEmpty)

        scheduler.status = .notDetermined
        scheduler.grantResult = .denied
        let prompted = await controller.setEnabled(true, ownerId: "guest:a", preferences: preferences)
        check("the prompt is shown only when permission is undecided", scheduler.requestCount == 1)
        check("a denied prompt leaves reminders off", prompted.0.enabled == false)

        scheduler.status = .notDetermined
        scheduler.grantResult = .allowed
        preferences.hour = 8
        preferences.minute = 30
        let enabled = await controller.setEnabled(true, ownerId: "guest:a", preferences: preferences)
        check("allowed permission enables reminders", enabled.0.enabled && enabled.1 == .scheduled)
        check("daily is one reminder", scheduler.scheduled.count == 1)
        check("daily uses the chosen time", scheduler.scheduled.first?.hour == 8 && scheduler.scheduled.first?.minute == 30)
        check("daily opens home", scheduler.scheduled.first?.destination == "home")
        check("daily has no weekday limit", scheduler.scheduled.first?.weekday == nil)
        check(
            "a reminder uses supportive copy",
            scheduler.scheduled.first?.body == MovementReminderCopy.gentle[0]
        )

        preferences = enabled.0
        preferences.hour = 18
        let rescheduled = await controller.save(preferences, ownerId: "guest:a", sessionActive: true)
        check("changing the time reschedules", rescheduled == .scheduled && scheduler.scheduled.first?.hour == 18)
        check("rescheduling does not add a second daily reminder", scheduler.scheduled.count == 1)

        preferences.frequency = .selectedDays
        preferences.weekdays = [2, 4, 2, 9]
        _ = await controller.save(preferences, ownerId: "guest:a", sessionActive: true)
        check("selected days schedule only the valid days", scheduler.scheduled.map(\.weekday) == [2, 4])
        check("an empty day selection sends nothing", {
            var empty = preferences
            empty.weekdays = []
            return MovementReminderPlan.requests(for: empty.sanitized(), ownerId: "guest:a").isEmpty
        }())

        preferences.frequency = .weeklyReflection
        preferences.weeklyWeekday = 6
        preferences.hour = 10
        _ = await controller.save(preferences, ownerId: "guest:a", sessionActive: true)
        check("weekly reflection is one reminder", scheduler.scheduled.count == 1)
        check("weekly reflection uses the chosen day and time", scheduler.scheduled.first?.weekday == 6 && scheduler.scheduled.first?.hour == 10)
        check("weekly reflection opens the week", scheduler.scheduled.first?.destination == "week")
        check("weekly reflection uses the week copy", scheduler.scheduled.first?.body == MovementReminderCopy.weekly)
        let weeklyRequest = scheduler.scheduled.first

        let kept = MovementReminderStore.load(ownerId: "guest:a", defaults: defaults)
        _ = await controller.apply(ownerId: "guest:b", sessionActive: true)
        check("another account does not receive these reminders", scheduler.scheduled.isEmpty)
        check("the first account's preferences remain", MovementReminderStore.load(ownerId: "guest:a", defaults: defaults) == kept)
        _ = await controller.apply(ownerId: "guest:a", sessionActive: true)
        check("switching back restores that account's reminder", scheduler.scheduled.count == 1 && scheduler.scheduled.first?.weekday == 6)

        _ = await controller.apply(ownerId: "guest:a", sessionActive: false)
        check("logout clears scheduled reminders", scheduler.scheduled.isEmpty)
        check("logout keeps the saved preferences", MovementReminderStore.load(ownerId: "guest:a", defaults: defaults).enabled)

        let disabled = await controller.setEnabled(false, ownerId: "guest:a", preferences: kept)
        check("turning reminders off disables them", disabled.0.enabled == false && disabled.1 == .cleared)
        check("turning reminders off cancels them", scheduler.scheduled.isEmpty)

        _ = await controller.setEnabled(true, ownerId: "guest:a", preferences: MovementReminderPreferences.off)
        await controller.erase()
        check("erasure removes saved reminders", MovementReminderStore.load(ownerId: "guest:a", defaults: defaults) == .off)
        check("erasure cancels scheduled reminders", scheduler.scheduled.isEmpty)

        let bodies = MovementReminderCopy.gentle + [MovementReminderCopy.weekly]
        check(
            "reminder copy does not mention missed workouts or streaks",
            bodies.allSatisfy { body in
                let text = body.lowercased()
                return !text.contains("missed") && !text.contains("streak") && !text.contains("failed")
            }
        )
        if let weeklyRequest {
            let info = MovementReminderPlan.userInfo(for: weeklyRequest)
            check("notification details do not include the account id", info == ["destination": "week"])
        } else {
            check("notification details do not include the account id", false)
        }
        check(
            "a week notification opens the reflection",
            MovementReminderDestination(userInfo: ["destination": "week"]) == .week
        )
        check(
            "any other notification opens home",
            MovementReminderDestination(userInfo: [:]) == .home
        )

        box.outcome = Outcome(passed: passed, failed: failed, lines: lines)
    }

    private final class ResultBox: @unchecked Sendable {
        var outcome = Outcome(passed: 0, failed: 1, lines: ["✗ reminder tests did not finish"])
    }

    private final class FakeReminderScheduler: MovementReminderScheduling, @unchecked Sendable {
        var status: MovementReminderAuthorization = .notDetermined
        var grantResult: MovementReminderAuthorization = .denied
        var requestCount = 0
        var scheduled: [MovementReminderRequest] = []

        func authorization() async -> MovementReminderAuthorization { status }

        func requestAuthorization() async -> MovementReminderAuthorization {
            requestCount += 1
            if status == .notDetermined {
                status = grantResult
            }
            return status
        }

        func replace(with requests: [MovementReminderRequest]) async {
            scheduled = requests
        }

        func cancelAll() async {
            scheduled = []
        }
    }
}
#endif
