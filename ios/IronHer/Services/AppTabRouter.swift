import Foundation
import SwiftUI

enum AppTab: Hashable {
    case home
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

    func requestInvitationCheck() {
        invitationCheck += 1
    }

    func openProgress() {
        selectedTab = .progress
    }

    func openMyWorkouts() {
        selectedTab = .myWorkouts
    }
}
