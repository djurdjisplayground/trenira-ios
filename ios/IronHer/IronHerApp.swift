import GoogleSignIn
import SwiftUI

@main
struct IronHerApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var appModel = AppModel.make()

    init() {
        GoogleSignInService.configureIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel.authManager)
                .environment(appModel.workoutStore)
                .environment(appModel.historyStore)
                .environment(appModel.settingsStore)
                .environment(appModel.subscriptionStore)
                .environment(appModel.customExerciseStore)
                .environment(appModel.progressionStore)
                .environment(appModel.globalProgressStore)
                .environment(appModel.sessionStore)
                .environment(appModel.localizationStore)
                .environment(appModel.testingTimeStore)
                .environment(appModel.tabRouter)
                .environment(appModel.dataCoordinator)
                .environment(\.locale, Locale(identifier: "en"))
                .onAppear {
                    ExerciseCatalog.syncCustomExercises(appModel.customExerciseStore.exercises)
                    appModel.globalProgressStore.seed(from: appModel.workoutStore)
                }
                .task {
                    await appModel.subscriptionStore.bootstrap()
                    await appModel.dataCoordinator.syncOnLaunchOrActive(authState: appModel.authManager.authState)
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task {
                        await appModel.subscriptionStore.handleAppBecameActive()
                        await appModel.dataCoordinator.syncOnLaunchOrActive(
                            authState: appModel.authManager.authState
                        )
                    }
                }
                .onChange(of: appModel.dataCoordinator.lastMigrationMessage) { _, message in
                    if let message {
                        appModel.backupHintMessage = message
                    }
                }
                .alert(
                    "Backup",
                    isPresented: Binding(
                        get: { appModel.backupHintMessage != nil },
                        set: { if !$0 { appModel.dismissBackupHint() } }
                    )
                ) {
                    Button("OK", role: .cancel) {
                        appModel.dismissBackupHint()
                    }
                } message: {
                    Text(appModel.backupHintMessage ?? "")
                }
                .preferredColorScheme(appModel.settingsStore.appTheme.colorScheme)
                .tint(IronHerTheme.accent)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
