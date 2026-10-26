import Foundation
import PostHog

/// Product events. Names are the PostHog event names.
/// Payloads stay empty so exercise names, weights, logs, health details, and notes are never attached.
enum AnalyticsEvent: String {
    case workoutCreated = "workout_created"
    case workoutStarted = "workout_started"
    case workoutCompleted = "workout_completed"
    case workoutExitedEarly = "workout_exited_early"
    case workoutAdaptationOpened = "workout_adaptation_opened"
    case workoutAdaptationApplied = "workout_adaptation_applied"
    case researchInvitationShown = "research_invitation_shown"
    case researchInvitationAccepted = "research_invitation_accepted"
    case researchInvitationDismissed = "research_invitation_dismissed"
}

/// The only place the app talks to PostHog.
/// Capture never throws and never blocks a workout save.
enum AnalyticsService {
    private static let allowsKey = "trenira.analytics.userAllowsCollection"
    private static let debugSendingKey = "trenira.analytics.debugSendingEnabled"
    private static var didStart = false

    /// Missing key means collection is allowed. Settings can turn it off.
    static var userAllowsCollection: Bool {
        if UserDefaults.standard.object(forKey: allowsKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: allowsKey)
    }

    static var debugSendingEnabled: Bool {
        UserDefaults.standard.bool(forKey: debugSendingKey)
    }

    static var isCollectionEnabled: Bool {
        shouldSendEvents(
            projectToken: AppConfiguration.postHogProjectToken,
            host: AppConfiguration.postHogHost,
            userAllowsCollection: userAllowsCollection,
            debugSendingEnabled: debugSendingEnabled,
            isDebugBuild: isDebugBuild
        )
    }

    static func shouldSendEvents(
        projectToken: String,
        host: String,
        userAllowsCollection: Bool,
        debugSendingEnabled: Bool,
        isDebugBuild: Bool
    ) -> Bool {
        let token = projectToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty, let url = URL(string: host), url.scheme == "https" else { return false }
        if isDebugBuild, !debugSendingEnabled { return false }
        return userAllowsCollection
    }

    static func setUserAllowsCollection(_ allowed: Bool) {
        UserDefaults.standard.set(allowed, forKey: allowsKey)
        applyCollectionState()
    }

    #if DEBUG
    static func setDebugSendingEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: debugSendingKey)
        applyCollectionState()
    }
    #endif

    /// Starts PostHog only when collection is allowed. Safe to call more than once.
    static func start() {
        applyCollectionState()
    }

    static func capture(_ event: AnalyticsEvent) {
        guard isCollectionEnabled else { return }
        applyCollectionState()
        guard didStart else { return }
        PostHogSDK.shared.capture(event.rawValue)
    }

    /// Drops the anonymous installation id after account data is erased.
    static func resetAnonymousIdentity() {
        guard didStart else { return }
        PostHogSDK.shared.reset()
    }

    private static func applyCollectionState() {
        guard isCollectionEnabled else {
            if didStart {
                PostHogSDK.shared.optOut()
            }
            return
        }

        if !didStart {
            let config = PostHogConfig(
                projectToken: AppConfiguration.postHogProjectToken,
                host: AppConfiguration.postHogHost
            )
            config.captureApplicationLifecycleEvents = false
            config.captureScreenViews = false
            config.captureElementInteractions = false
            config.captureSwiftUIElementInteractions = false
            config.enableSwizzling = false
            config.sessionReplay = false
            config.surveys = false
            config.preloadFeatureFlags = false
            config.sendFeatureFlagEvent = false
            config.setDefaultPersonProperties = false
            config.disableGeoIp = true
            config.personProfiles = .identifiedOnly
            config.errorTrackingConfig.autoCapture = false
            config.rageClickConfig.enabled = false
            PostHogSDK.shared.setup(config)
            didStart = true
        }
        PostHogSDK.shared.optIn()
    }

    private static var isDebugBuild: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }
}
