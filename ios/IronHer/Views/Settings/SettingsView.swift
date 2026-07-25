import SwiftUI

struct SettingsView: View {
    @Environment(UserSettingsStore.self) private var settingsStore
    @Environment(SubscriptionStore.self) private var subscriptionStore
    @Environment(CustomExerciseStore.self) private var customExerciseStore
    @Environment(LocalizationStore.self) private var l10n

    var body: some View {
        @Bindable var settings = settingsStore

        Form {
            Section(l10n.t(.membership)) {
                HStack {
                    Text(l10n.t(.current_plan))
                    Spacer()
                    Text(subscriptionStore.currentTier.label)
                        .foregroundStyle(IronHerTheme.secondaryText)
                }

                NavigationLink {
                    PremiumUpgradeView()
                } label: {
                    Text(subscriptionStore.isPremium ? l10n.t(.manage_premium) : l10n.t(.view_premium))
                }

                if subscriptionStore.isPremium {
                    Button(l10n.t(.switch_to_free)) {
                        subscriptionStore.downgradeToFree()
                    }
                    .foregroundStyle(IronHerTheme.secondaryText)
                }

                if !subscriptionStore.isPremium {
                    Text(l10n.t(.free_premium_blurb))
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)
                }
            }

            Section(l10n.t(.units)) {
                Picker(l10n.t(.weight_unit), selection: $settings.weightUnit) {
                    ForEach(WeightUnit.allCases) { unit in
                        Text(unit.localizedLabel(l10n)).tag(unit)
                    }
                }
                Text("Default for new exercises. Each exercise can override this (kg or lb) based on the equipment you use.")
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
            }

            Section(l10n.t(.appearance)) {
                Picker(l10n.t(.theme), selection: $settings.appTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.localizedLabel(l10n)).tag(theme)
                    }
                }
            }

            Section(l10n.t(.exercise_library)) {
                NavigationLink(l10n.t(.browse_exercises)) {
                    ExerciseMasterView()
                }
                Text("\(ExerciseCatalog.all.count) exercises · \(customExerciseStore.count) custom")
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
            }

            Section(l10n.t(.session_feedback)) {
                Picker(l10n.t(.style), selection: $settings.coachingMode) {
                    ForEach(CoachingMode.allCases) { mode in
                        Text(mode.localizedLabel(l10n)).tag(mode)
                    }
                }
                Text(settings.coachingMode.localizedDetail(l10n))
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
            }

            if DevelopmentConfig.isDevelopmentMode {
                Section("Developer") {
                    NavigationLink("Developer Settings") {
                        DeveloperSettingsView()
                    }
                    Text("Testing tools — not shown in production builds.")
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)
                }
            }
        }
        .id(subscriptionStore.revision)
        .navigationTitle(l10n.t(.settings))
        .navigationBarTitleDisplayMode(.inline)
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
                            ExerciseDetailSettingsView(exercise: exercise)
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
                        ExerciseDetailSettingsView(exercise: exercise)
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

// MARK: - Developer Settings (DEBUG only entry from SettingsView)

struct DeveloperSettingsView: View {
    @Environment(UserSettingsStore.self) private var settingsStore
    @Environment(SubscriptionStore.self) private var subscriptionStore
    @Environment(WorkoutSessionStore.self) private var sessionStore
    @Environment(WeightHistoryStore.self) private var historyStore
    @Environment(ExerciseProgressionStore.self) private var progressionStore
    @Environment(GlobalExerciseProgressStore.self) private var globalProgressStore
    @Environment(TestingTimeStore.self) private var testingTimeStore

    @State private var confirmResetWeekly = false
    @State private var confirmClearHistory = false
    @State private var confirmResetProgression = false
    @State private var customDaysText = "21"

    var body: some View {
        @Bindable var settings = settingsStore

        Form {
            Section {
                Text("Tools for development and testing only. Hidden in production builds.")
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
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

            Section("Membership") {
                HStack {
                    Text("Current plan")
                    Spacer()
                    Text(subscriptionStore.currentTier.label)
                        .foregroundStyle(IronHerTheme.secondaryText)
                }

                Button("Unlock Premium") {
                    subscriptionStore.unlockPremiumForTesting()
                    settingsStore.noteDeveloperAction("Premium unlocked.")
                }

                Button("Reset to Free") {
                    subscriptionStore.resetToFreeForTesting()
                    settingsStore.noteDeveloperAction("Plan reset to Free.")
                }
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
    }
}
