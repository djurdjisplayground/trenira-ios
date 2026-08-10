import SwiftUI

struct HistoryView: View {
    @Environment(WorkoutSessionStore.self) private var sessionStore
    @Environment(WeightHistoryStore.self) private var historyStore
    @Environment(GlobalExerciseProgressStore.self) private var globalProgressStore
    @Environment(UserSettingsStore.self) private var settingsStore
    @Environment(LocalizationStore.self) private var l10n

    private var overviews: [ExerciseProgressOverview] {
        let items = sessionStore.performanceLogs.flatMap { log in
            log.exercises
                .filter { $0.sets.contains(where: \.completed) }
                .map { exercise in
                    ExerciseSessionHistoryItem(
                        id: "\(log.id.uuidString)-\(exercise.entryId.uuidString)",
                        logId: log.id,
                        workoutName: log.workoutName,
                        completedAt: log.completedAt,
                        exercise: exercise
                    )
                }
        }

        return ExerciseProgressOverviewBuilder.overviews(
            from: items,
            weightHistory: historyStore.entries,
            unitResolver: { exerciseId in
                globalProgressStore.resolvedWeightUnit(
                    for: exerciseId,
                    defaultUnit: settingsStore.weightUnit
                )
            }
        )
    }

    var body: some View {
        Group {
            if overviews.isEmpty {
                ContentUnavailableView(
                    l10n.t(.no_history_yet),
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text(l10n.t(.progress_history_empty_body))
                )
            } else {
                List {
                    Section {
                        ForEach(overviews) { overview in
                            NavigationLink {
                                ExerciseProgressDetailView(overview: overview)
                            } label: {
                                progressRow(overview)
                            }
                        }
                    } footer: {
                        Text(l10n.t(.progress_history_list_footer))
                            .font(SheLiftsFont.caption)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .background(IronHerTheme.groupedBackground)
        .navigationTitle(l10n.t(.progress_history))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func progressRow(_ overview: ExerciseProgressOverview) -> some View {
        let exercise = ExerciseCatalog.exercise(id: overview.exerciseId)

        return HStack(spacing: 14) {
            if let exercise, exercise.hasVisualAsset {
                ExerciseThumbnailView(exercise: exercise, size: 48)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(
                    exercise?.localizedName(using: l10n)
                        ?? l10n.exerciseName(
                            id: overview.exerciseId,
                            englishFallback: overview.exerciseName,
                            isCustom: false
                        )
                )
                .font(SheLiftsFont.bodyMedium)
                .foregroundStyle(IronHerTheme.primaryText)

                progressMetricLine(label: l10n.t(.progress_started), value: overview.startedValue)
                progressMetricLine(label: l10n.t(.progress_current), value: overview.currentValue)

                Text(overview.dateRangeLabel)
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
            }
        }
        .padding(.vertical, 4)
    }

    private func progressMetricLine(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(SheLiftsFont.caption)
                .foregroundStyle(IronHerTheme.secondaryText)
            Text(value)
                .font(SheLiftsFont.caption)
                .foregroundStyle(IronHerTheme.primaryText)
        }
    }
}

#Preview {
    NavigationStack {
        HistoryView()
            .environment(WorkoutSessionStore())
            .environment(WeightHistoryStore())
            .environment(GlobalExerciseProgressStore())
            .environment(UserSettingsStore())
            .environment(LocalizationStore())
    }
}
