import SwiftUI

/// Shown when a workout is already completed this week — prevents accidental re-entry.
struct CompletedWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LocalizationStore.self) private var l10n
    @Environment(UserSettingsStore.self) private var settingsStore
    @Environment(GlobalExerciseProgressStore.self) private var globalProgressStore

    let workoutName: String
    let latestLog: LoggedWorkoutPerformance?
    let onRestart: () -> Void

    @State private var showSummary = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer(minLength: 12)

                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(IronHerTheme.primaryText)

                    Text("Workout completed")
                        .font(SheLiftsFont.title)
                        .foregroundStyle(IronHerTheme.primaryText)

                    Text(workoutName)
                        .font(SheLiftsFont.bodyMedium)
                        .foregroundStyle(IronHerTheme.secondaryText)
                        .multilineTextAlignment(.center)

                    Text("This plan is done for the week. Restart only if you want another full session.")
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }

                VStack(spacing: 12) {
                    Button {
                        dismiss()
                        onRestart()
                    } label: {
                        Text("Restart Workout")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    if latestLog != nil {
                        Button {
                            showSummary = true
                        } label: {
                            Text("View Summary")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(OutlineButtonStyle())
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("Close")
                            .font(SheLiftsFont.body)
                            .foregroundStyle(IronHerTheme.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 12)
            }
            .padding(.horizontal, IronHerTheme.screenPadding)
            .padding(.bottom, 24)
            .background(IronHerTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showSummary) {
                if let latestLog {
                    WorkoutSessionSummarySheet(log: latestLog)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct WorkoutSessionSummarySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LocalizationStore.self) private var l10n
    @Environment(UserSettingsStore.self) private var settingsStore
    @Environment(GlobalExerciseProgressStore.self) private var globalProgressStore

    let log: LoggedWorkoutPerformance

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(log.workoutName)
                        .font(SheLiftsFont.bodyMedium)
                    Text(log.completedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)
                }

                Section("Exercises") {
                    ForEach(Array(log.exercises.enumerated()), id: \.offset) { _, performance in
                        let exercise = ExerciseCatalog.exercise(id: performance.exerciseId)
                        let unit = globalProgressStore.resolvedWeightUnit(
                            for: performance.exerciseId,
                            defaultUnit: settingsStore.weightUnit
                        )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(
                                exercise?.localizedName(using: l10n)
                                    ?? l10n.exerciseName(
                                        id: performance.exerciseId,
                                        englishFallback: performance.exerciseId,
                                        isCustom: false
                                    )
                            )
                            .font(SheLiftsFont.bodyMedium)
                            .foregroundStyle(IronHerTheme.primaryText)

                            if let exercise {
                                Text(
                                    PerformanceHistoryFormatter.summaryLine(
                                        for: exercise,
                                        performance: performance,
                                        unit: unit
                                    )
                                )
                                .font(SheLiftsFont.caption)
                                .foregroundStyle(IronHerTheme.secondaryText)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
