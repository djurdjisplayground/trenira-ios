import SwiftUI

struct MovementHistoryView: View {
    var ownerId: String
    var strengthLogs: [StrengthHistorySnapshot]

    private var items: [MovementHistoryItem] {
        MovementJournal.items(
            records: MovementRecordStore.load(ownerId: ownerId),
            strengthLogs: strengthLogs
        )
    }

    private var summary: MovementWeekSummary {
        MovementJournal.weekSummary(items: items)
    }

    var body: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView(
                    "Nothing recorded yet",
                    systemImage: "figure.walk",
                    description: Text("When you save a walk, a video, or finish a strength workout, it will show up here. There's nothing to catch up on.")
                )
            } else {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(summaryLine)
                                .font(TreniraType.body)
                                .foregroundStyle(TreniraColor.label)
                            if summary.strengthCountWithoutMinutes > 0 {
                                Text("Strength workouts are counted. Their minutes aren't, because trenira doesn't time the whole session.")
                                    .font(TreniraType.caption)
                                    .foregroundStyle(TreniraColor.labelSecondary)
                            }
                        }
                        .listRowBackground(TreniraColor.elevated)
                    } header: {
                        Text("This week")
                    }
                    Section("Recent") {
                        ForEach(items) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(TreniraType.bodyMedium)
                                    .foregroundStyle(TreniraColor.label)
                                Text(detail(item))
                                    .font(TreniraType.caption)
                                    .foregroundStyle(TreniraColor.labelSecondary)
                            }
                            .accessibilityElement(children: .combine)
                            .listRowBackground(TreniraColor.elevated)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(TreniraColor.canvas)
        .navigationTitle("Movement")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryLine: String {
        MovementJournal.weekLine(summary)
    }

    private func detail(_ item: MovementHistoryItem) -> String {
        let day = item.completedAt.formatted(date: .abbreviated, time: .omitted)
        let kind: String
        switch item.kind {
        case .strength: kind = "Strength"
        case .walking: kind = "Walk"
        case .externalVideo: kind = "Video"
        }
        let minutes = item.actualMinutes.map { "\($0) min" } ?? "Minutes not recorded"
        return "\(kind) · \(minutes) · \(day)"
    }
}
