import SwiftUI

struct WeeklyWorkoutProgressView: View {
    @Environment(WorkoutStore.self) private var workoutStore
    @Environment(WorkoutSessionStore.self) private var sessionStore

    var body: some View {
        let summary = sessionStore.thisWeekSummary(for: workoutStore.workouts)

        if summary.total > 0 {
            VStack(alignment: .leading, spacing: 12) {
                Text("This Week")
                    .font(SheLiftsFont.section)
                    .foregroundStyle(IronHerTheme.primaryText)

                FlowWorkoutStatusRow(items: summary.items)

                Text("\(summary.completed) of \(summary.total) workouts completed")
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .notesCard(padding: 16)
        }
    }
}

private struct FlowWorkoutStatusRow: View {
    let items: [(id: UUID, name: String, completed: Bool)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.id) { item in
                HStack(spacing: 10) {
                    Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(
                            item.completed
                                ? IronHerTheme.primaryText
                                : IronHerTheme.secondaryText.opacity(0.55)
                        )

                    Text(item.name)
                        .font(SheLiftsFont.body)
                        .foregroundStyle(
                            item.completed
                                ? IronHerTheme.primaryText
                                : IronHerTheme.secondaryText
                        )
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
            }
        }
    }
}

#Preview {
    WeeklyWorkoutProgressView()
        .padding()
        .environment(WorkoutStore())
        .environment(WorkoutSessionStore())
}
