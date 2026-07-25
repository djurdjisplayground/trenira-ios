import GoogleSignIn
import SwiftUI

@main
struct IronHerApp: App {
    @State private var authManager = AuthenticationManager()
    @State private var workoutStore = WorkoutStore()
    @State private var historyStore = WeightHistoryStore()
    @State private var settingsStore = UserSettingsStore()
    @State private var subscriptionStore = SubscriptionStore()
    @State private var customExerciseStore = CustomExerciseStore()
    @State private var progressionStore = ExerciseProgressionStore()
    @State private var globalProgressStore = GlobalExerciseProgressStore()
    @State private var sessionStore = WorkoutSessionStore()
    @State private var localizationStore = LocalizationStore()
    @State private var testingTimeStore = TestingTimeStore()
    @State private var gymProfileStore = GymEquipmentProfileStore()
    @State private var tabRouter = AppTabRouter()

    init() {
        GoogleSignInService.configureIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authManager)
                .environment(workoutStore)
                .environment(historyStore)
                .environment(settingsStore)
                .environment(subscriptionStore)
                .environment(customExerciseStore)
                .environment(progressionStore)
                .environment(globalProgressStore)
                .environment(sessionStore)
                .environment(localizationStore)
                .environment(testingTimeStore)
                .environment(gymProfileStore)
                .environment(tabRouter)
                .environment(\.locale, Locale(identifier: "en"))
                .onAppear {
                    ExerciseCatalog.syncCustomExercises(customExerciseStore.exercises)
                    globalProgressStore.seed(from: workoutStore)
                }
                .preferredColorScheme(settingsStore.appTheme.colorScheme)
                .tint(IronHerTheme.accent)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
