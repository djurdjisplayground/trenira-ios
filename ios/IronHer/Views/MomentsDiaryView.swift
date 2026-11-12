import SwiftUI

struct MomentsDiaryView: View {
    @Environment(UserDataCoordinator.self) private var dataCoordinator
    @State private var revision = 0

    private var ownerId: String { dataCoordinator.currentOwner.rawValue }

    private var records: [MovementRecord] {
        MovementRecordStore.load(ownerId: ownerId)
            .sorted { $0.activityDate > $1.activityDate }
    }

    private var weekRecords: [MovementRecord] {
        MovementDiary.records(records, inWeekOf: .now)
    }

    private var summary: DiarySummary {
        MovementDiary.summary(of: weekRecords)
    }

    var body: some View {
        Group {
            if records.isEmpty {
                VStack(spacing: 16) {
                    ContentUnavailableView(
                        "No moments yet",
                        systemImage: "leaf",
                        description: Text("When you save a moment, it will show up here. You can also log a past day.")
                    )
                    NavigationLink {
                        AddMovementView(ownerId: ownerId) { revision += 1 }
                    } label: {
                        Text("Log movement")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(TreniraPrimaryButtonStyle())
                    .padding(.horizontal, TreniraSpace.screen)
                }
            } else {
                List {
                    Section {
                        NavigationLink {
                            AddMovementView(ownerId: ownerId) { revision += 1 }
                        } label: {
                            Text("Log movement")
                        }
                    }
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(DiaryReflection.weekly(activityCount: summary.activityCount))
                                .font(TreniraType.displayTitle)
                                .foregroundStyle(TreniraColor.label)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(summaryLine)
                                .font(TreniraType.body)
                                .foregroundStyle(TreniraColor.labelSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .listRowBackground(TreniraColor.ivory)
                    }
                    ForEach(dayGroups, id: \.day) { group in
                        Section(dayTitle(group.day)) {
                            ForEach(group.records) { record in
                                NavigationLink {
                                    AddMovementView(ownerId: ownerId, existing: record) {
                                        revision += 1
                                    }
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(record.title)
                                            .font(TreniraType.bodyMedium)
                                            .foregroundStyle(TreniraColor.label)
                                        Text(MovementDurationFormat.exactLabel(
                                            seconds: record.actualDurationSeconds,
                                            minutes: record.actualDurationSeconds == nil ? record.actualMinutes : nil
                                        ))
                                        .font(TreniraType.caption)
                                        .foregroundStyle(TreniraColor.labelSecondary)
                                        if let notes = record.notes, !notes.isEmpty {
                                            Text(notes)
                                                .font(TreniraType.caption)
                                                .foregroundStyle(TreniraColor.labelSecondary)
                                        }
                                    }
                                    .accessibilityElement(children: .combine)
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(TreniraColor.ivory)
        .navigationTitle("My Moments")
        .navigationBarTitleDisplayMode(.inline)
        .profileToolbar()
        .id(revision)
    }

    private var summaryLine: String {
        let activities = summary.activityCount == 1 ? "1 activity" : "\(summary.activityCount) activities"
        let days = summary.dayCount == 1 ? "1 day" : "\(summary.dayCount) days"
        let duration = MovementDurationFormat.exact(summary.activeSeconds)
        let categories = summary.categories.isEmpty ? "" : " · \(summary.categories.joined(separator: ", "))"
        return "\(days) · \(activities) · \(duration)\(categories)"
    }

    private var dayGroups: [(day: Date, records: [MovementRecord])] {
        let calendar = Calendar.current
        var groups: [(Date, [MovementRecord])] = []
        for record in records {
            let day = calendar.startOfDay(for: record.activityDate)
            if let index = groups.firstIndex(where: { calendar.isDate($0.0, inSameDayAs: day) }) {
                groups[index].1.append(record)
            } else {
                groups.append((day, [record]))
            }
        }
        return groups.map { (day: $0.0, records: $0.1) }
    }

    private func dayTitle(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(date: .abbreviated, time: .omitted)
    }
}
