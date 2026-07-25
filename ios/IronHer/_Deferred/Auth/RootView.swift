import SwiftUI

struct RootView: View {
    @Environment(AuthenticationManager.self) private var authManager

    var body: some View {
        Group {
            if authManager.canAccessApp {
                HomeView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: authManager.canAccessApp)
        .task {
            await authManager.restoreSessionIfNeeded()
        }
    }
}

#Preview {
    RootView()
        .environment(AuthenticationManager())
}
