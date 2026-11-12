import StoreKit
import SwiftUI

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @Environment(UserSettingsStore.self) private var settingsStore
    @Environment(LocalizationStore.self) private var l10n
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(UserDataCoordinator.self) private var dataCoordinator
    @State private var showSignOutConfirm = false
    @State private var showIntroduction = false
    @State private var showResearchFormError = false
    @State private var allowsAnonymousAnalytics = AnalyticsService.userAllowsCollection

    var body: some View {
        @Bindable var settings = settingsStore

        Form {
            Section {
                NavigationLink("Movement preferences") {
                    CompanionPreferencesEditor()
                }
                NavigationLink("Movement reminders") {
                    MovementRemindersView()
                }
            } header: {
                Text("Movement")
            } footer: {
                Text("Change what you want from movement, what gets in the way, and what you enjoy. Reminders are off until you turn them on.")
                    .font(SheLiftsFont.caption)
            }

            Section(l10n.t(.account)) {
                Text(authManager.authState.displayName)
                    .foregroundStyle(IronHerTheme.primaryText)

                Text(dataCoordinator.currentOwner.displayLabel)
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)

                Button {
                    Task { await dataCoordinator.retrySync() }
                } label: {
                    HStack {
                        Text(dataCoordinator.syncStatus.settingsLabel)
                        Spacer()
                        if case .backingUp = dataCoordinator.syncStatus {
                            ProgressView()
                        }
                    }
                }
                .disabled({
                    if case .failed = dataCoordinator.syncStatus { return false }
                    return true
                }())
                .foregroundStyle(IronHerTheme.secondaryText)

                if authManager.authState.isGuest {
                    Text("What you save stays on this device. Cloud backup is not available yet.")
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)
                } else if authManager.authState != .signedOut {
                    Text(
                        "What you've saved stays on this device with this account. It is not backed up to the cloud yet."
                    )
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)
                }
            }

            if authManager.authState.isSignedIn && !authManager.authState.isGuest {
                Section {
                    Button(role: .destructive) {
                        showSignOutConfirm = true
                    } label: {
                        Text(l10n.t(.log_out))
                    }
                } footer: {
                    Text(l10n.t(.sign_out_confirm_message))
                        .font(SheLiftsFont.caption)
                }
            }

            if authManager.authState.isSignedIn {
                Section {
                    NavigationLink {
                        DeleteAccountView()
                    } label: {
                        Text(l10n.t(.delete_account))
                            .foregroundStyle(.red)
                    }
                } footer: {
                    Text(l10n.t(.delete_account_settings_footer))
                        .font(SheLiftsFont.caption)
                }
            }

            Section {
                LabeledContent("Version") {
                    Text(AppVersion.label)
                        .foregroundStyle(IronHerTheme.secondaryText)
                }

                Button(action: openResearchForm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ResearchInvitationCopy.settingsTitle)
                            .font(SheLiftsFont.body)
                            .foregroundStyle(IronHerTheme.primaryText)
                        Text(ResearchInvitationCopy.settingsSubtitle)
                            .font(SheLiftsFont.caption)
                            .foregroundStyle(IronHerTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .disabled(AppConfiguration.researchInvitationFormURL == nil)
                .accessibilityHint("Opens a short research form in your browser")

                Button("View Introduction") {
                    showIntroduction = true
                }
            } header: {
                Text("Support")
            }

            Section {
                Toggle("Anonymous product analytics", isOn: $allowsAnonymousAnalytics)
                    .onChange(of: allowsAnonymousAnalytics) { _, allowed in
                        AnalyticsService.setUserAllowsCollection(allowed)
                    }

                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    Text("Privacy Policy")
                }

                NavigationLink {
                    TermsAndConditionsView()
                } label: {
                    Text("Terms & Conditions")
                }
            } header: {
                Text("Legal & Privacy")
            } footer: {
                Text("Anonymous product analytics records that the app came to the foreground and that a movement was saved, including its type. It does not include how you feel, health details, or contact details. Privacy contact: \(AppConfiguration.supportEmail). Operated by \(AppConfiguration.operatorName).")
                    .font(SheLiftsFont.caption)
            }

            Section(l10n.t(.appearance)) {
                Picker(l10n.t(.theme), selection: $settings.appTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.localizedLabel(l10n)).tag(theme)
                    }
                }
            }

            #if DEBUG
            Section("Developer") {
                NavigationLink("Developer Settings") {
                    DeveloperSettingsView()
                }
                Text("Testing tools — not shown in production builds.")
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
            }
            #endif
        }
        .scrollContentBackground(.hidden)
        .background(TreniraColor.canvas)
        .navigationTitle(l10n.t(.settings))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            l10n.t(.sign_out_confirm_title),
            isPresented: $showSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button(l10n.t(.log_out), role: .destructive) {
                authManager.signOut(preparing: dataCoordinator)
            }
            Button(l10n.t(.cancel), role: .cancel) {}
        } message: {
            Text(l10n.t(.sign_out_confirm_message))
        }
        .fullScreenCover(isPresented: $showIntroduction) {
            OnboardingView(isPreview: true) {
                showIntroduction = false
            }
        }
        .alert(ResearchInvitationCopy.openFailedTitle, isPresented: $showResearchFormError) {
            Button(ResearchInvitationCopy.tryAgainTitle, action: openResearchForm)
            Button("OK", role: .cancel) {}
        } message: {
            Text(ResearchInvitationCopy.openFailedMessage)
        }
    }

    private func openResearchForm() {
        showResearchFormError = false
        guard let url = AppConfiguration.researchInvitationFormURL else {
            showResearchFormError = true
            return
        }
        openURL(url) { accepted in
            if !accepted {
                showResearchFormError = true
            }
        }
    }
}

struct ExerciseMasterView: View {
    @Environment(UserSettingsStore.self) private var settingsStore
    @Environment(CustomExerciseStore.self) private var customExerciseStore
    @Environment(LocalizationStore.self) private var l10n

    var body: some View {
        List {
            if !customExerciseStore.exercises.isEmpty {
                Section("Your exercises") {
                    ForEach(customExerciseStore.exercises) { exercise in
                        NavigationLink {
                            ExerciseDetailsView(exercise: exercise, showsSettingsLink: true)
                        } label: {
                            exerciseLabel(exercise)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            customExerciseStore.delete(id: customExerciseStore.exercises[index].id)
                        }
                        ExerciseCatalog.syncCustomExercises(customExerciseStore.exercises)
                    }
                }
            }

            Section("Built-in") {
                ForEach(ExerciseDatabase.all) { exercise in
                    NavigationLink {
                        ExerciseDetailsView(exercise: exercise, showsSettingsLink: true)
                    } label: {
                        exerciseLabel(exercise)
                    }
                }
            }
        }
        .navigationTitle("Exercise Library")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            ExerciseCatalog.syncCustomExercises(customExerciseStore.exercises)
        }
    }

    private func exerciseLabel(_ exercise: Exercise) -> some View {
        HStack(alignment: .top, spacing: 14) {
            if exercise.hasVisualAsset {
                ExerciseThumbnailView(exercise: exercise, size: 44)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.localizedName(using: l10n))
                    .font(SheLiftsFont.bodyMedium)
                Text(exercise.listSubtitle)
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
            }
        }
        .padding(.vertical, 2)
    }
}

struct ExerciseDetailSettingsView: View {
    @Environment(UserSettingsStore.self) private var settingsStore
    @Environment(GlobalExerciseProgressStore.self) private var globalProgressStore
    @Environment(LocalizationStore.self) private var l10n
    let exercise: Exercise

    private var resolvedUnit: WeightUnit {
        globalProgressStore.resolvedWeightUnit(
            for: exercise.id,
            defaultUnit: settingsStore.weightUnit
        )
    }

    private var showsWeightUnit: Bool {
        switch exercise.measurementUnit {
        case .weight, .weightAndTime, .repsWithOptionalWeight:
            return true
        default:
            return false
        }
    }

    private var unitPreferenceBinding: Binding<ExerciseWeightUnitPreference> {
        Binding(
            get: { globalProgressStore.weightUnitPreference(for: exercise.id) },
            set: { newValue in
                globalProgressStore.setWeightUnitPreference(newValue, for: exercise.id)
            }
        )
    }

    var body: some View {
        Form {
            Section("Muscles") {
                metadataRow("Primary", exercise.primaryMuscleGroup.label)
                if !exercise.secondaryMuscleGroups.isEmpty {
                    metadataRow("Secondary", exercise.secondaryMuscleGroups.map(\.label).joined(separator: ", "))
                }
            }

            Section("Movement") {
                metadataRow("Category", exercise.category.label)
                metadataRow("Pattern", exercise.movementPattern.label)
                metadataRow("Laterality", exercise.laterality.label)
                metadataRow("Equipment", exercise.equipment.label)
                metadataRow("Measurement", exercise.measurementUnit.label)
                metadataRow("Progression", exercise.progressionMethod.label)
            }

            if !exercise.aliases.isEmpty {
                Section("Also known as") {
                    Text(exercise.aliases.joined(separator: ", "))
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)
                }
            }

            if showsWeightUnit {
                Section("Weight Unit") {
                    Picker("Weight Unit", selection: unitPreferenceBinding) {
                        ForEach(ExerciseWeightUnitPreference.allCases) { preference in
                            Text(preference.label).tag(preference)
                        }
                    }
                    Text("Overrides the default from Settings for this exercise only. Used everywhere this exercise appears.")
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)
                }
            }

            if let progress = globalProgressStore.progress(for: exercise.id),
               progress.workingWeightKg > 0 {
                Section {
                    HStack {
                        Text(l10n.t(.starting_weight))
                        Spacer()
                        Text(
                            WeightFormatter.format(
                                kg: progress.workingWeightKg,
                                unit: resolvedUnit
                            )
                        )
                        .foregroundStyle(IronHerTheme.secondaryText)
                    }
                    Text(l10n.t(.starting_weight_caption))
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)
                }
            }

            ExerciseProgressionFields(exercise: exercise)
        }
        .navigationTitle(exercise.localizedName(using: l10n))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func metadataRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(IronHerTheme.secondaryText)
        }
    }
}

// MARK: - Developer Settings (DEBUG only — excluded from Release)

#if DEBUG
struct DeveloperSettingsView: View {
    @Environment(UserSettingsStore.self) private var settingsStore
    @Environment(SubscriptionStore.self) private var subscriptionStore
    @Environment(WorkoutSessionStore.self) private var sessionStore
    @Environment(WeightHistoryStore.self) private var historyStore
    @Environment(ExerciseProgressionStore.self) private var progressionStore
    @Environment(GlobalExerciseProgressStore.self) private var globalProgressStore
    @Environment(TestingTimeStore.self) private var testingTimeStore
    @Environment(AppTabRouter.self) private var tabRouter

    @State private var confirmResetWeekly = false
    @State private var confirmClearHistory = false
    @State private var confirmResetProgression = false
    @State private var customDaysText = "21"
    @State private var invitationStatusText = ""
    @State private var debugAnalyticsSending = AnalyticsService.debugSendingEnabled

    var body: some View {
        @Bindable var settings = settingsStore

        Form {
            Section {
                Text("Tools for development and testing only. Hidden in production builds.")
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
            }

            Section("Previews") {
                Text("Your circle stays off for the beta. There is no chat, no accounts, and nothing is sent.")
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
                NavigationLink("Open Your circle preview") {
                    YourCirclePreviewView()
                }
            }

            Section("Data safety") {
                Button("Export local DB backup") {
                    #if DEBUG
                    do {
                        let url = try LocalPersistenceBackup.exportToDocuments(label: "manual")
                        settingsStore.noteDeveloperAction("Backup saved: \(url.lastPathComponent)")
                    } catch {
                        settingsStore.noteDeveloperAction("Backup failed: \(error.localizedDescription)")
                    }
                    #endif
                }

                Button("Run guest migration self-tests") {
                    #if DEBUG
                    let outcome = UserDataMigrationSelfTests.runAll()
                    settingsStore.noteDeveloperAction(outcome.summary)
                    #endif
                }

                Button("Run local data protection self-tests") {
                    #if DEBUG
                    let outcome = LocalDataProtectionSelfTests.runAll()
                    settingsStore.noteDeveloperAction(outcome.summary)
                    #endif
                }

                Button("Run auth privacy self-tests") {
                    #if DEBUG
                    let outcome = AuthPrivacySelfTests.runAll()
                    settingsStore.noteDeveloperAction(outcome.summary)
                    #endif
                }

                Button("Run consultation self-tests") {
                    #if DEBUG
                    let outcome = ConsultationSelfTests.runAll()
                    settingsStore.noteDeveloperAction(outcome.summary)
                    #endif
                }

                Button("Run exercise progress series self-tests") {
                    #if DEBUG
                    let outcome = ExerciseProgressSeriesSelfTests.runAll()
                    settingsStore.noteDeveloperAction(outcome.summary)
                    #endif
                }

                Button("Run weight progression self-tests") {
                    #if DEBUG
                    let outcome = WeightProgressionSelfTests.runAll()
                    settingsStore.noteDeveloperAction(outcome.summary)
                    #endif
                }

                Button("Run starting-weight calibration self-tests") {
                    #if DEBUG
                    let outcome = StrengthCalibrationSelfTests.runAll()
                    settingsStore.noteDeveloperAction(outcome.summary)
                    #endif
                }

                Button("Run TestFlight prep self-tests") {
                    #if DEBUG
                    let outcome = TestFlightPrepSelfTests.runAll()
                    settingsStore.noteDeveloperAction(outcome.summary)
                    #endif
                }

                Button("Run replace-exercise self-tests") {
                    #if DEBUG
                    Task {
                        let ranking = ExerciseReplacementSelfTests.runAll()
                        let flow = await ExerciseReplacementFlowSelfTests.runAll()
                        settingsStore.noteDeveloperAction(ranking.summary + "\n\n" + flow.summary)
                    }
                    #endif
                }

                Button("Run rest-timer self-tests") {
                    #if DEBUG
                    Task {
                        let outcome = await RestTimerControllerSelfTests.runAll()
                        settingsStore.noteDeveloperAction(outcome.summary)
                    }
                    #endif
                }
            }

            Section {
                if let banner = testingTimeStore.testModeBannerText {
                    Text(banner)
                        .font(SheLiftsFont.bodyMedium)
                        .foregroundStyle(IronHerTheme.primaryText)
                } else {
                    Text("Using real current date/time.")
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)
                }

                Text(breakPreviewText)
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)

                ForEach(SimulatedTimePreset.allCases) { preset in
                    Button {
                        applyDays(preset.days, label: preset.title)
                    } label: {
                        HStack {
                            Text(preset.title)
                                .foregroundStyle(IronHerTheme.primaryText)
                            Spacer()
                            if testingTimeStore.simulatedDaysOffset == preset.days {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(IronHerTheme.primaryText)
                            }
                        }
                    }
                }

                HStack {
                    Text("Custom days")
                    Spacer()
                    TextField("Days", text: $customDaysText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 72)
                    Button("Apply") {
                        let days = Int(customDaysText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
                        applyDays(days, label: "+\(max(0, days)) days")
                    }
                    .font(SheLiftsFont.caption)
                }

                Button("Reset Simulation") {
                    testingTimeStore.reset()
                    customDaysText = "21"
                    settingsStore.noteDeveloperAction("Time simulation reset to real date/time.")
                }
                .disabled(!testingTimeStore.isSimulating)
            } header: {
                Text("Simulate time passed")
            } footer: {
                Text("Uses perceived date = real now + offset for return-after-break only. Does not change workout history. After setting an offset, go to Start Workout and open a plan.")
            }

            Section("Session testing") {
                Toggle("Reopen completed workouts", isOn: $settings.allowReopenCompletedWorkouts)
                Text("When enabled, the workout complete screen shows a Reopen button that restores the same session.")
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
            }

            Section("Weekly progress") {
                Toggle(
                    "Manual completion testing",
                    isOn: $settings.allowManualWorkoutCompletionTesting
                )
                Text("When enabled, Track This Week checkboxes can mark workouts complete or incomplete without finishing a session.")
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)

                Button("Reset weekly progress") {
                    confirmResetWeekly = true
                }
                Text("Clears “completed this week” labels without deleting workout plans.")
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
            }

            Section("StoreKit") {
                HStack {
                    Text("Current plan")
                    Spacer()
                    Text(subscriptionStore.currentTier.label)
                        .foregroundStyle(IronHerTheme.secondaryText)
                }

                Button("Reload StoreKit products") {
                    Task {
                        await subscriptionStore.loadProducts()
                        settingsStore.noteDeveloperAction(
                            "Products: \(subscriptionStore.orderedProducts.map(\.id).joined(separator: ", "))"
                        )
                    }
                }

                Button("Refresh entitlements") {
                    Task {
                        await subscriptionStore.refreshEntitlements()
                        settingsStore.noteDeveloperAction(
                            subscriptionStore.isPremium ? "Premium active (StoreKit)." : "Free (no StoreKit entitlement)."
                        )
                    }
                }

                Button("Restore Purchases") {
                    Task {
                        await subscriptionStore.restorePurchases()
                        settingsStore.noteDeveloperAction(
                            subscriptionStore.isPremium ? "Restore: Premium active." : "Restore: no Premium found."
                        )
                    }
                }
                .foregroundStyle(IronHerTheme.secondaryText)

                Text(
                    ProductAccessConfig.unlocksPremium
                        ? "Premium access is unlocked without purchase for this build (silent ProductAccessConfig). StoreKit state above is still real. Set ProductAccessConfig.unlocksPremiumWithoutPurchase / hidesMonetizationUI to false before enabling paywalls."
                        : "Use the scheme’s StoreKit Configuration (trenira.storekit). Premium unlocks only via verified StoreKit purchases — no debug override."
                )
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
            }

            Section("History & progression") {
                Button("Clear all workout history", role: .destructive) {
                    confirmClearHistory = true
                }
                Text("Removes Progress History sessions and weight milestones. Does not delete workout plans.")
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)

                Button("Reset progression", role: .destructive) {
                    confirmResetProgression = true
                }
                Text("Clears overload counters and global working weight / rep targets.")
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
            }

            Section("Analytics") {
                Toggle("Send analytics from this debug build", isOn: $debugAnalyticsSending)
                    .onChange(of: debugAnalyticsSending) { _, enabled in
                        AnalyticsService.setDebugSendingEnabled(enabled)
                        settingsStore.noteDeveloperAction(
                            enabled
                                ? "Debug analytics sending is on. Events go to PostHog only if the project token and host are set, and anonymous analytics is allowed in Settings."
                                : "Debug analytics sending is off. This build will not send events."
                        )
                    }
                Text("Debug builds and the simulator do not send events until this is on. Release and TestFlight builds on a device send when the token and host are set and the Settings switch is on. Workouts still save with no network.")
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)

                Button("Run analytics self-tests") {
                    let outcome = AnalyticsSelfTests.runAll()
                    settingsStore.noteDeveloperAction(outcome.summary)
                }

                Button("Run companion self-tests") {
                    let outcome = CompanionSelfTests.runAll()
                    settingsStore.noteDeveloperAction(outcome.summary)
                }

                Button("Run movement self-tests") {
                    let outcome = MovementActivitySelfTests.runAll()
                    settingsStore.noteDeveloperAction(outcome.summary)
                }
            }

            Section("Research invitation") {
                Text(invitationStatusText)
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)

                Button("Show invitation now") {
                    ResearchInvitationStore.armImmediatePresentation()
                    tabRouter.selectedTab = .home
                    tabRouter.requestInvitationCheck()
                    invitationStatusText = ResearchInvitationStore.debugStatusText()
                    settingsStore.noteDeveloperAction(
                        "Showing the invitation on Home without changing saved state. It stays hidden while a workout is open."
                    )
                }
                Button("Reset invitation state") {
                    ResearchInvitationStore.resetForTesting()
                    invitationStatusText = ResearchInvitationStore.debugStatusText()
                    settingsStore.noteDeveloperAction(
                        "Cleared the invitation status and last shown date. Workouts were not changed. Open Home to see the normal invitation."
                    )
                }
                Text("Debug builds only. The status above is this simulator's saved invitation state. Reset does not change workouts or other settings. Show invitation now does not write that state.")
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)

                Button("Run research invitation self-tests") {
                    let outcome = ResearchInvitationSelfTests.runAll()
                    settingsStore.noteDeveloperAction(outcome.summary)
                }
            }

            Section("Notifications") {
                Toggle("Enable test notifications", isOn: $settings.enableTestNotifications)
                Text("When on, you can preview a sample progress reminder.")
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)

                if settings.enableTestNotifications {
                    Button("Send test notification preview") {
                        sendTestNotificationPreview()
                    }
                }
            }

            if let message = settingsStore.lastDeveloperActionMessage {
                Section {
                    Text(message)
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)
                }
            }
        }
        .navigationTitle("Developer")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            invitationStatusText = ResearchInvitationStore.debugStatusText()
        }
        .confirmationDialog(
            "Reset weekly progress?",
            isPresented: $confirmResetWeekly,
            titleVisibility: .visible
        ) {
            Button("Reset weekly progress", role: .destructive) {
                sessionStore.clearAllWeeklyCompletions()
                settingsStore.noteDeveloperAction("Weekly progress reset.")
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Clear all workout history?",
            isPresented: $confirmClearHistory,
            titleVisibility: .visible
        ) {
            Button("Clear history", role: .destructive) {
                historyStore.clearAll()
                sessionStore.clearAllPerformanceLogs()
                settingsStore.noteDeveloperAction("Workout history cleared.")
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Reset progression?",
            isPresented: $confirmResetProgression,
            titleVisibility: .visible
        ) {
            Button("Reset progression", role: .destructive) {
                progressionStore.clearAll()
                globalProgressStore.clearAll()
                settingsStore.noteDeveloperAction("Progression reset.")
            }
            Button("Cancel", role: .cancel) {}
        }
        .onDisappear {
            settingsStore.clearDeveloperActionStatus()
        }
    }

    private var breakPreviewText: String {
        guard let days = ReturnAfterBreak.daysSinceLastCompletedWorkout(
            performanceLogs: sessionStore.performanceLogs,
            weeklyCompletions: sessionStore.weeklyCompletions,
            now: testingTimeStore.now
        ) else {
            return "No completed workouts yet — finish one via Start Workout first, then simulate time."
        }
        let severity = ReturnAfterBreak.severity(daysSince: days)
        let label: String
        switch severity {
        case .none: label = "No welcome-back prompt"
        case .mild: label = "Gentle welcome (optional)"
        case .suggestLighter: label = "Welcome Back + Continue / Start lighter"
        case .stronglySuggest: label = "Stronger lighter recommendation"
        }
        return "Perceived days since last workout: \(days) → \(label)"
    }

    private func applyDays(_ days: Int, label: String) {
        testingTimeStore.setSimulatedDaysPassed(days)
        customDaysText = "\(max(0, days))"
        settingsStore.noteDeveloperAction(
            days == 0
                ? "Time simulation cleared."
                : "Simulating \(label). Go to My Workouts → Start workout to see Welcome Back."
        )
    }

    private func sendTestNotificationPreview() {
        if let summary = historyStore.progressSummaries.first {
            let message = historyStore.notificationPreviewMessage(
                for: summary,
                unit: settingsStore.weightUnit
            )
            settingsStore.noteDeveloperAction(message)
        } else {
            settingsStore.noteDeveloperAction("No history yet — complete a weighted exercise first, then try again.")
        }
    }
}
#endif

#Preview {
    NavigationStack {
        SettingsView()
            .environment(UserSettingsStore())
            .environment(SubscriptionStore())
            .environment(CustomExerciseStore())
            .environment(LocalizationStore())
            .environment(TestingTimeStore())
            .environment(WorkoutSessionStore())
            .environment(WeightHistoryStore())
            .environment(ExerciseProgressionStore())
            .environment(GlobalExerciseProgressStore())
            .environment(StrengthCalibrationStore())
            .environment(AppTabRouter())
    }
}
