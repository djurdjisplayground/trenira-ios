import SwiftUI

/// Full-screen Welcome Back experience shown before a workout starts after a training gap.
/// Never auto-deloads or changes progression state.
struct WelcomeBackView: View {
    @Environment(LocalizationStore.self) private var l10n
    @Environment(UserSettingsStore.self) private var settingsStore
    @Environment(GlobalExerciseProgressStore.self) private var globalProgressStore
    @Environment(TestingTimeStore.self) private var testingTimeStore

    let evaluation: ReturnAfterBreak.Evaluation
    let onContinue: () -> Void
    let onStartLighter: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if DevelopmentConfig.isDevelopmentMode {
                        TestModeDebugPanel(evaluation: evaluation)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text(l10n.t(.welcome_back_training))
                            .font(SheLiftsFont.largeTitle)
                            .foregroundStyle(IronHerTheme.primaryText)

                        Text(timeAwayCopy)
                            .font(SheLiftsFont.subheadline)
                            .foregroundStyle(IronHerTheme.secondaryText)

                        Text(bodyCopy)
                            .font(SheLiftsFont.body)
                            .foregroundStyle(IronHerTheme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !evaluation.exerciseSummaries.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("You were previously lifting:")
                                .font(SheLiftsFont.section)
                                .foregroundStyle(IronHerTheme.primaryText)

                            ForEach(evaluation.exerciseSummaries) { item in
                                HStack {
                                    Text(item.name)
                                        .font(SheLiftsFont.body)
                                        .foregroundStyle(IronHerTheme.primaryText)
                                    Spacer()
                                    Text(
                                        WeightFormatter.format(
                                            kg: item.weightKg,
                                            unit: globalProgressStore.resolvedWeightUnit(
                                                for: item.exerciseId,
                                                defaultUnit: settingsStore.weightUnit
                                            )
                                        )
                                    )
                                        .font(SheLiftsFont.bodyMedium)
                                        .foregroundStyle(IronHerTheme.primaryText)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(IronHerTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadius, style: .continuous))
                    }

                    Text("How would you like to start today?")
                        .font(SheLiftsFont.subheadline)
                        .foregroundStyle(IronHerTheme.secondaryText)

                    VStack(spacing: 12) {
                        Button(action: onContinue) {
                            Text(continueTitle)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        Button(action: onStartLighter) {
                            Text(l10n.t(.start_lighter))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(OutlineButtonStyle())

                        Text(l10n.t(.take_it_at_your_pace))
                            .font(SheLiftsFont.caption)
                            .foregroundStyle(IronHerTheme.secondaryText)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, IronHerTheme.screenPadding)
                .padding(.top, 28)
                .padding(.bottom, 40)
            }
            .background(IronHerTheme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(l10n.t(.close), action: onContinue)
                        .foregroundStyle(IronHerTheme.secondaryText)
                }
            }
        }
    }

    private var timeAwayCopy: String {
        let days = evaluation.daysSinceLastWorkout
        if days >= 14, days % 7 == 0 {
            let weeks = days / 7
            return l10n.t(.welcome_back_weeks, weeks)
        }
        return l10n.t(.welcome_back_days, days)
    }

    private var bodyCopy: String {
        switch evaluation.severity {
        case .none:
            return l10n.t(.ready_when_you_are)
        case .mild:
            return l10n.t(.welcome_back_body_mild)
        case .suggestLighter:
            return "Your current workout is ready based on your previous progression."
        case .stronglySuggest:
            return l10n.t(.welcome_back_body_strong)
        }
    }

    private var continueTitle: String {
        if let weight = evaluation.referenceWeightKg, weight > 0 {
            let exerciseId = evaluation.exerciseSummaries.first(where: { abs($0.weightKg - weight) < 0.01 })?.exerciseId
                ?? evaluation.exerciseSummaries.first?.exerciseId
            let unit: WeightUnit
            if let exerciseId {
                unit = globalProgressStore.resolvedWeightUnit(
                    for: exerciseId,
                    defaultUnit: settingsStore.weightUnit
                )
            } else {
                unit = settingsStore.weightUnit
            }
            let formatted = WeightFormatter.format(kg: weight, unit: unit)
            return l10n.t(.continue_with_weight, formatted)
        }
        return l10n.t(.continue_with_current_weight)
    }
}

/// Backward-compatible sheet wrapper used by older call sites.
struct WelcomeBackSheet: View {
    let evaluation: ReturnAfterBreak.Evaluation
    let onContinue: () -> Void
    let onStartLighter: () -> Void

    var body: some View {
        WelcomeBackView(
            evaluation: evaluation,
            onContinue: onContinue,
            onStartLighter: onStartLighter
        )
    }
}

/// DEBUG-only panel showing perceived dates used by return-after-break.
struct TestModeDebugPanel: View {
    @Environment(TestingTimeStore.self) private var testingTimeStore
    var evaluation: ReturnAfterBreak.Evaluation?

    var body: some View {
        if DevelopmentConfig.isDevelopmentMode, testingTimeStore.isSimulating || evaluation != nil {
            VStack(alignment: .leading, spacing: 6) {
                if let banner = testingTimeStore.testModeBannerText {
                    Text(banner)
                        .font(SheLiftsFont.bodyMedium)
                }
                if let last = evaluation?.lastCompletedAt ?? nil {
                    Text("Last completed workout: \(last.formatted(date: .abbreviated, time: .omitted))")
                } else if testingTimeStore.isSimulating {
                    Text("Last completed workout: (none logged yet)")
                }
                Text("Effective current date: \(testingTimeStore.now.formatted(date: .abbreviated, time: .omitted))")
                if let days = evaluation?.daysSinceLastWorkout {
                    Text("Elapsed time: \(days) days")
                }
            }
            .font(SheLiftsFont.caption)
            .foregroundStyle(IronHerTheme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(IronHerTheme.groupedBackground)
            .clipShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadiusSmall, style: .continuous))
        }
    }
}

/// Compact banner for Home / Start screens while simulation is active.
struct TestModeBanner: View {
    @Environment(TestingTimeStore.self) private var testingTimeStore
    @Environment(WorkoutSessionStore.self) private var sessionStore

    var body: some View {
        if DevelopmentConfig.isDevelopmentMode, testingTimeStore.isSimulating {
            let last = ReturnAfterBreak.lastCompletedWorkoutDate(
                performanceLogs: sessionStore.performanceLogs,
                weeklyCompletions: sessionStore.weeklyCompletions
            )
            let elapsed = ReturnAfterBreak.daysSinceLastCompletedWorkout(
                performanceLogs: sessionStore.performanceLogs,
                weeklyCompletions: sessionStore.weeklyCompletions,
                now: testingTimeStore.now
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(testingTimeStore.testModeBannerText ?? "TEST MODE")
                    .font(SheLiftsFont.bodyMedium)
                if let last {
                    Text("Last completed workout: \(last.formatted(date: .abbreviated, time: .omitted))")
                } else {
                    Text("Last completed workout: (none)")
                }
                Text("Effective current date: \(testingTimeStore.now.formatted(date: .abbreviated, time: .omitted))")
                if let elapsed {
                    Text("Elapsed time: \(elapsed) days")
                }
            }
            .font(SheLiftsFont.caption)
            .foregroundStyle(IronHerTheme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(IronHerTheme.groupedBackground)
            .clipShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadiusSmall, style: .continuous))
        }
    }
}
