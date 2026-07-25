import Foundation

/// Owns shared stores + guest/account data coordination for the app lifetime.
@MainActor
@Observable
final class AppModel {
    let authManager = AuthenticationManager()
    let workoutStore: WorkoutStore
    let historyStore: WeightHistoryStore
    let settingsStore: UserSettingsStore
    let subscriptionStore = SubscriptionStore()
    let customExerciseStore: CustomExerciseStore
    let progressionStore: ExerciseProgressionStore
    let globalProgressStore: GlobalExerciseProgressStore
    let sessionStore: WorkoutSessionStore
    let localizationStore = LocalizationStore()
    let testingTimeStore = TestingTimeStore()
    let tabRouter = AppTabRouter()
    let dataCoordinator: UserDataCoordinator

    var backupHintMessage: String?

    private init(
        workoutStore: WorkoutStore,
        historyStore: WeightHistoryStore,
        settingsStore: UserSettingsStore,
        customExerciseStore: CustomExerciseStore,
        progressionStore: ExerciseProgressionStore,
        globalProgressStore: GlobalExerciseProgressStore,
        sessionStore: WorkoutSessionStore
    ) {
        self.workoutStore = workoutStore
        self.historyStore = historyStore
        self.settingsStore = settingsStore
        self.customExerciseStore = customExerciseStore
        self.progressionStore = progressionStore
        self.globalProgressStore = globalProgressStore
        self.sessionStore = sessionStore

        let coordinator = UserDataCoordinator(
            workoutStore: workoutStore,
            historyStore: historyStore,
            sessionStore: sessionStore,
            customExerciseStore: customExerciseStore,
            progressionStore: progressionStore,
            globalProgressStore: globalProgressStore,
            settingsStore: settingsStore
        )
        self.dataCoordinator = coordinator
        coordinator.bootstrap(authState: authManager.authState)

        authManager.onAuthStateSettled = { [weak self] state in
            guard let self else { return }
            Task { @MainActor in
                switch state {
                case .guest:
                    self.dataCoordinator.handleContinueAsGuest()
                case .apple, .google, .email:
                    await self.dataCoordinator.handleAuthenticatedSignIn(authState: state)
                case .signedOut:
                    break
                }
                self.backupHintMessage = self.dataCoordinator.lastMigrationMessage
            }
        }
    }

    static func make() -> AppModel {
        AppModel(
            workoutStore: WorkoutStore(),
            historyStore: WeightHistoryStore(),
            settingsStore: UserSettingsStore(),
            customExerciseStore: CustomExerciseStore(),
            progressionStore: ExerciseProgressionStore(),
            globalProgressStore: GlobalExerciseProgressStore(),
            sessionStore: WorkoutSessionStore()
        )
    }

    func dismissBackupHint() {
        backupHintMessage = nil
        dataCoordinator.clearMigrationMessage()
    }
}
