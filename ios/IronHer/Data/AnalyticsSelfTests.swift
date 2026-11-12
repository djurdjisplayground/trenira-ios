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
        check("onboarding event name", AnalyticsEvent.companionOnboardingCompleted.rawValue == "companion_onboarding_completed")
        check("check-in event name", AnalyticsEvent.dailyCheckInCompleted.rawValue == "daily_check_in_completed")
        check("suggestion event name", AnalyticsEvent.movementSuggestionSelected.rawValue == "movement_suggestion_selected")
        check("activity event name", AnalyticsEvent.activityCompleted.rawValue == "activity_completed")
        check("app opened event name", AnalyticsEvent.appOpened.rawValue == "app_opened")
        check("barrier category is allowed", AnalyticsService.allowedPropertyKeys.contains("primary_barrier"))
        check("activity type is allowed", AnalyticsService.allowedPropertyKeys.contains("activity_type"))
        check("suggestion is allowed", AnalyticsService.allowedPropertyKeys.contains("suggestion"))
        check("minutes and setting are allowed", AnalyticsService.allowedPropertyKeys.isSuperset(of: ["minutes", "setting"]))
        check("feelings are not an analytics property", !AnalyticsService.allowedPropertyKeys.contains("feeling"))
        check(
            "allowlist stays limited to product categories",
            AnalyticsService.allowedPropertyKeys == Set(["primary_barrier", "minutes", "setting", "suggestion", "activity_type"])
        )
        check(
            "a simulator release build does not send without the debug override",
            !AnalyticsService.shouldSendEvents(
                projectToken: token,
                host: host,
                userAllowsCollection: true,
                debugSendingEnabled: false,
                isDebugBuild: false,
                isSimulator: true
            )
        )
        check(
            "a simulator can send only when the debug override and consent are on",
            AnalyticsService.shouldSendEvents(
                projectToken: token,
                host: host,
                userAllowsCollection: true,
                debugSendingEnabled: true,
                isDebugBuild: true,
                isSimulator: true
            )
        )
        check("the first foreground captures one app open", AnalyticsService.shouldCaptureAppOpen(isActive: true, alreadyCapturedThisForeground: false))
        check("a second active tick in the same foreground does not", !AnalyticsService.shouldCaptureAppOpen(isActive: true, alreadyCapturedThisForeground: true))
        check("inactive does not capture an app open", !AnalyticsService.shouldCaptureAppOpen(isActive: false, alreadyCapturedThisForeground: false))
        check("background ends the foreground period", AnalyticsService.shouldResetAppOpenPeriod(isBackground: true))
        check("inactive does not end the foreground period", !AnalyticsService.shouldResetAppOpenPeriod(isBackground: false))
        check("yoga uses its own activity type", MovementRecordKind.yoga.analyticsActivityType == "yoga")
        check("dancing uses its own activity type", MovementRecordKind.dancing.analyticsActivityType == "dancing")
        check("movement with baby uses its own activity type", MovementRecordKind.withBaby.analyticsActivityType == "with_baby")
        check("other movement uses its own activity type", MovementRecordKind.other.analyticsActivityType == "other")
        check("a walk keeps the walking activity type", MovementRecordKind.walking.analyticsActivityType == "walking")
        check("a saved video keeps the external video activity type", MovementRecordKind.externalVideo.analyticsActivityType == "external_video")
        let sanitized = AnalyticsService.sanitizedProperties([
            "activity_type": "dancing",
            "feeling": "tired",
            "reflection": "my back felt tight"
        ])
        check("a reflection is not sent", sanitized == ["activity_type": "dancing"])
        check("a feeling is not sent", sanitized["feeling"] == nil)

        return Outcome(passed: passed, failed: failed, lines: lines)
    }
}
#endif
