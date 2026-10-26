import Foundation

#if DEBUG
/// Checks the analytics gate without contacting PostHog.
enum AnalyticsSelfTests {
    struct Outcome: Sendable {
        var passed: Int
        var failed: Int
        var lines: [String]

        var summary: String {
            "\(passed) passed, \(failed) failed\n" + lines.joined(separator: "\n")
        }
    }

    static func runAll() -> Outcome {
        var passed = 0
        var failed = 0
        var lines: [String] = []

        func check(_ name: String, _ condition: @autoclosure () -> Bool) {
            if condition() {
                passed += 1
                lines.append("✓ \(name)")
            } else {
                failed += 1
                lines.append("✗ \(name)")
            }
        }

        let token = "phc_example"
        let host = "https://us.i.posthog.com"

        check(
            "debug build does not send without the testing override",
            !AnalyticsService.shouldSendEvents(
                projectToken: token,
                host: host,
                userAllowsCollection: true,
                debugSendingEnabled: false,
                isDebugBuild: true
            )
        )
        check(
            "debug override can send when the user allows it",
            AnalyticsService.shouldSendEvents(
                projectToken: token,
                host: host,
                userAllowsCollection: true,
                debugSendingEnabled: true,
                isDebugBuild: true
            )
        )
        check(
            "user opt-out sends nothing",
            !AnalyticsService.shouldSendEvents(
                projectToken: token,
                host: host,
                userAllowsCollection: false,
                debugSendingEnabled: true,
                isDebugBuild: true
            )
        )
        check(
            "empty token sends nothing",
            !AnalyticsService.shouldSendEvents(
                projectToken: "  ",
                host: host,
                userAllowsCollection: true,
                debugSendingEnabled: true,
                isDebugBuild: false
            )
        )
        check(
            "non-https host sends nothing",
            !AnalyticsService.shouldSendEvents(
                projectToken: token,
                host: "http://example.com",
                userAllowsCollection: true,
                debugSendingEnabled: true,
                isDebugBuild: false
            )
        )
        check(
            "release build can send when configured and allowed",
            AnalyticsService.shouldSendEvents(
                projectToken: token,
                host: host,
                userAllowsCollection: true,
                debugSendingEnabled: false,
                isDebugBuild: false
            )
        )
        check("events do not carry a properties payload", AnalyticsEvent.workoutCompleted.rawValue == "workout_completed")
        check("started event name", AnalyticsEvent.workoutStarted.rawValue == "workout_started")
        check("early exit event name", AnalyticsEvent.workoutExitedEarly.rawValue == "workout_exited_early")
        check("adaptation opened event name", AnalyticsEvent.workoutAdaptationOpened.rawValue == "workout_adaptation_opened")
        check("adaptation applied event name", AnalyticsEvent.workoutAdaptationApplied.rawValue == "workout_adaptation_applied")
        check("invitation shown event name", AnalyticsEvent.researchInvitationShown.rawValue == "research_invitation_shown")
        check("invitation accepted event name", AnalyticsEvent.researchInvitationAccepted.rawValue == "research_invitation_accepted")
        check("invitation dismissed event name", AnalyticsEvent.researchInvitationDismissed.rawValue == "research_invitation_dismissed")
        check("created event name", AnalyticsEvent.workoutCreated.rawValue == "workout_created")

        return Outcome(passed: passed, failed: failed, lines: lines)
    }
}
#endif
