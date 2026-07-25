import SwiftUI

struct TrackThisWeekView: View {
    @Environment(WorkoutStore.self) private var workoutStore
    @Environment(WorkoutSessionStore.self) private var sessionStore
    @Environment(UserSettingsStore.self) private var settingsStore
    @Environment(GlobalExerciseProgressStore.self) private var globalProgressStore
    @Environment(WeightHistoryStore.self) private var historyStore
    @Environment(LocalizationStore.self) private var l10n
    @Environment(TestingTimeStore.self) private var testingTimeStore

    private var summary: (completed: Int, total: Int, items: [(id: UUID, name: String, completed: Bool)]) {
        sessionStore.thisWeekSummary(for: workoutStore.workouts)
    }

    private var progressReport: WeeklyProgressReport {
        WeeklyProgressAnalyzer.report(
            logs: sessionStore.performanceLogs,
            weightHistory: historyStore.entries,
            globalProgress: globalProgressStore,
            settings: settingsStore,
            localization: l10n,
            now: testingTimeStore.now
        )
    }

    var body: some View {
        let week = summary
        let report = progressReport
        let canToggle = settingsStore.allowsManualWorkoutCompletionToggle

        Group {
            if week.total == 0 && report.isEmpty {
                ContentUnavailableView(
                    l10n.t(.track_this_week_empty_title),
                    systemImage: "calendar",
                    description: Text(l10n.t(.track_this_week_empty_body))
                )
            } else {
                List {
                    Section {
                        if report.highlights.isEmpty {
                            Text(l10n.t(.track_this_week_no_improvements))
                                .font(SheLiftsFont.body)
                                .foregroundStyle(IronHerTheme.secondaryText)
                                .padding(.vertical, 4)
                        } else {
                            ForEach(report.highlights) { highlight in
                                improvementRow(highlight)
                            }
                        }
                    } header: {
                        Text(l10n.t(.what_improved))
                    } footer: {
                        Text(l10n.t(.track_this_week_improvements_footer))
                            .font(SheLiftsFont.caption)
                    }

                    if week.total > 0 {
                        Section {
                            ForEach(week.items, id: \.id) { item in
                                HStack(spacing: 12) {
                                    Button {
                                        guard canToggle else { return }
                                        sessionStore.toggleCompletedThisWeek(
                                            workoutId: item.id,
                                            workoutName: item.name
                                        )
                                    } label: {
                                        Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 18, weight: .light))
                                            .foregroundStyle(
                                                item.completed
                                                    ? IronHerTheme.primaryText
                                                    : IronHerTheme.secondaryText.opacity(0.5)
                                            )
                                            .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(!canToggle)

                                    Text(item.name)
                                        .font(SheLiftsFont.bodyMedium)
                                        .foregroundStyle(IronHerTheme.primaryText)

                                    Spacer()
                                }
                                .padding(.vertical, 2)
                            }
                        } header: {
                            Text(l10n.t(.workouts))
                        } footer: {
                            Text("\(week.completed) of \(week.total)")
                                .font(SheLiftsFont.caption)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .background(IronHerTheme.groupedBackground)
        .navigationTitle(l10n.t(.track_this_week))
        .navigationBarTitleDisplayMode(.inline)
        .id(testingTimeStore.revision)
    }

    @ViewBuilder
    private func improvementRow(_ highlight: WeeklyProgressHighlight) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(highlight.exerciseName)
                .font(SheLiftsFont.bodyMedium)
                .foregroundStyle(IronHerTheme.primaryText)
            Spacer(minLength: 12)
            if let delta = highlight.deltaOnlyLine {
                Text(delta)
                    .font(SheLiftsFont.bodyMedium)
                    .foregroundStyle(IronHerTheme.primaryText)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        TrackThisWeekView()
            .environment(WorkoutStore())
            .environment(WorkoutSessionStore())
            .environment(UserSettingsStore())
            .environment(GlobalExerciseProgressStore())
            .environment(WeightHistoryStore())
            .environment(LocalizationStore())
            .environment(TestingTimeStore())
    }
}
