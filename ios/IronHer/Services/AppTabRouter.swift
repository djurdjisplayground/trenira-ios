import Foundation
import SwiftUI

enum AppTab: Hashable {
    case home
    case moments
    case explore
    case myWorkouts
    case adapt
    case progress
    case settings
}

/// Shared tab selection for cross-tab navigation (e.g. Home → Progress).
@Observable
@MainActor
final class AppTabRouter {
    var selectedTab: AppTab = .home
    /// True while a workout is covering the tabs, so the invitation does not interrupt it.
    var isWorkoutFlowPresented = false
    /// Bumped when the home invitation should be considered again.
    var invitationCheck = 0
    /// Set when a reminder asks to open the weekly reflection. Home opens without a cover.
    var reminderDestination: MovementReminderDestination?
    /// Debug launch only. The community preview stays off the beta navigation.
    var showsCirclePreview = false

    func requestInvitationCheck() {
        invitationCheck += 1
    }

    /// Workout, progress, and adapt are not in the tab bar. These stay on Today.
    func openProgress() {
        selectedTab = .home
    }

    func openMyWorkouts() {
        selectedTab = .home
    }

    func openReminder(_ destination: MovementReminderDestination) {
        selectedTab = .home
        reminderDestination = destination == .week ? .week : nil
    }
}
