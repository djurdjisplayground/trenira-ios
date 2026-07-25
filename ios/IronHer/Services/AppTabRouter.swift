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

    func openProgress() {
        selectedTab = .progress
    }

    func openMyWorkouts() {
        selectedTab = .myWorkouts
    }
}
