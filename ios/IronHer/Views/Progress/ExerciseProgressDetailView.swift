import SwiftUI

struct ExerciseProgressDetailView: View {
    @Environment(WorkoutSessionStore.self) private var sessionStore
    @Environment(GlobalExerciseProgressStore.self) private var globalProgressStore
    @Environment(UserSettingsStore.self) private var settingsStore
    @Environment(LocalizationStore.self) private var l10n

    let overview: ExerciseProgressOverview

    @State private var selectedRange: ExerciseProgressTimeRange = .default
    @State private var selectedSessionId: UUID?

    private var exercise: Exercise? {
        ExerciseCatalog.exercise(id: overview.exerciseId)
    }

    private var weightUnit: WeightUnit {
        globalProgressStore.resolvedWeightUnit(
            for: overview.exerciseId,
            defaultUnit: settingsStore.weightUnit
        )
    }

    private var series: ExerciseProgressSeries? {
        guard let exercise else { return nil }
        return ExerciseProgressSeriesBuilder.series(
            exerciseId: overview.exerciseId,
            exercise: exercise,
            logs: sessionStore.performanceLogs,
            range: selectedRange,
            weightUnit: weightUnit
        )
    }

    var body: some View {
        List {
            headerSection

            if let series {
                rangeSection

                if series.isEmpty {
                    if sessionStore.performanceLogs.contains(where: { log in
                        log.exercises.contains {
                            $0.exerciseId == overview.exerciseId && $0.sets.contains(where: \.completed)
                        }
                    }) {
                        emptyRangeSection
                    } else {
                        emptySection
                    }
                } else {
                    summarySection(series)
                    chartSection(series)
                    if series.points.count == 1 {
                        onePointHintSection
                    }
                    historySection(series)
                }
            } else {
                emptySection
            }
        }
        .listStyle(.insetGrouped)
        .background(IronHerTheme.groupedBackground)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedRange) { _, _ in
            selectedSessionId = nil
        }
    }

    private var navigationTitle: String {
        if let exercise {
            return exercise.localizedName(using: l10n)
        }
        return overview.exerciseName
    }

    @ViewBuilder
    private var headerSection: some View {
        Section {
            if let exercise {
                HStack(alignment: .top, spacing: 14) {
                    if exercise.hasVisualAsset {
                        ExerciseThumbnailView(exercise: exercise, size: 64)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(exercise.localizedName(using: l10n))
                            .font(SheLiftsFont.section)
                            .foregroundStyle(IronHerTheme.primaryText)
                        Text(exercise.listSubtitle)
                            .font(SheLiftsFont.subheadline)
                            .foregroundStyle(IronHerTheme.secondaryText)
                    }
                }
                .padding(.vertical, 2)
            } else {
                Text(overview.exerciseName)
                    .font(SheLiftsFont.section)
                    .foregroundStyle(IronHerTheme.primaryText)
            }
        }
    }

    private var rangeSection: some View {
        Section {
            Picker("Time range", selection: $selectedRange) {
                ForEach(ExerciseProgressTimeRange.allCases) { range in
                    Text(range.label).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            .accessibilityLabel("Time range")
        }
    }

    @ViewBuilder
    private func summarySection(_ series: ExerciseProgressSeries) -> some View {
        if let summary = series.summaryText {
            Section {
                Text(summary)
                    .font(SheLiftsFont.bodyMedium)
                    .foregroundStyle(IronHerTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Progress summary")
                    .accessibilityValue(summary)
            }
        }
    }

    @ViewBuilder
    private func chartSection(_ series: ExerciseProgressSeries) -> some View {
        if let exercise {
            Section {
                ExerciseProgressChartView(
                    series: series,
                    exercise: exercise,
                    weightUnit: weightUnit,
                    selectedSessionId: $selectedSessionId
                )
                .padding(.vertical, 4)
            } header: {
                Text(chartHeader(for: series.metric))
            } footer: {
                Text(l10n.t(.progress_chart_footer))
                    .font(SheLiftsFont.caption)
            }
        }
    }

    private var onePointHintSection: some View {
        Section {
            Text(l10n.t(.progress_chart_one_point_hint))
                .font(SheLiftsFont.caption)
                .foregroundStyle(IronHerTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var emptySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(l10n.t(.progress_chart_empty_title))
                    .font(SheLiftsFont.bodyMedium)
                    .foregroundStyle(IronHerTheme.primaryText)
                Text(l10n.t(.progress_chart_empty_body))
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
        }
    }

    private var emptyRangeSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(l10n.t(.progress_chart_empty_range_title))
                    .font(SheLiftsFont.bodyMedium)
                    .foregroundStyle(IronHerTheme.primaryText)
                Text(l10n.t(.progress_chart_empty_range_body))
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private func historySection(_ series: ExerciseProgressSeries) -> some View {
        let recent = Array(series.points.reversed().prefix(12))
        if let exercise, !recent.isEmpty {
            Section {
                ForEach(recent) { point in
                    historyRow(point: point, series: series, exercise: exercise)
                }
            } header: {
                Text(l10n.t(.progress_recent_sessions))
            } footer: {
                Text(l10n.t(.progress_recent_sessions_footer))
                    .font(SheLiftsFont.caption)
            }
        }
    }

    private func historyRow(
        point: ExerciseProgressPoint,
        series: ExerciseProgressSeries,
        exercise: Exercise
    ) -> some View {
        let best = ExerciseProgressSeriesBuilder.formatHistoryBestSet(
            point: point,
            metric: series.metric,
            exercise: exercise,
            weightUnit: weightUnit
        )

        return Button {
            selectedSessionId = point.sessionId
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(point.completedAt.formatted(.dateTime.day().month(.abbreviated).year()))
                        .font(SheLiftsFont.bodyMedium)
                        .foregroundStyle(IronHerTheme.primaryText)
                    Spacer()
                    Text("\(point.completedSetCount) sets")
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)
                }

                Text(best)
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.primaryText)

                if !point.workoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(point.workoutName)
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)
                }
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Selects this session on the chart")
    }

    private func chartHeader(for metric: ExerciseProgressMetricKind) -> String {
        switch metric {
        case .estimatedStrength: return l10n.t(.progress_chart_estimated_strength)
        case .bestReps: return l10n.t(.progress_chart_best_reps)
        case .longestDuration: return l10n.t(.progress_chart_longest_duration)
        }
    }
}
