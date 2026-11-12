import SwiftUI

/// Records a walk or video only after the person chooses to save it.
struct MovementCompletionView: View {
    var title: String
    var kind: MovementRecordKind
    var plannedMinutes: Int?
    var initialActualMinutes: Int
    var videoId: UUID?
    var ownerId: String
    var onSaved: () -> Void

    @State private var actualMinutes: Int
    @State private var feeling: MovementFeeling?
    @State private var didSave = false

    init(
        title: String,
        kind: MovementRecordKind,
        plannedMinutes: Int?,
        initialActualMinutes: Int,
        videoId: UUID? = nil,
        ownerId: String,
        onSaved: @escaping () -> Void
    ) {
        self.title = title
        self.kind = kind
        self.plannedMinutes = plannedMinutes
        self.initialActualMinutes = initialActualMinutes
        self.videoId = videoId
        self.ownerId = ownerId
        self.onSaved = onSaved
        _actualMinutes = State(initialValue: max(1, initialActualMinutes))
    }

    private var finishedEarlier: Bool {
        guard let plannedMinutes else { return false }
        return actualMinutes < plannedMinutes
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TreniraSpace.section) {
                Text(finishedEarlier ? "You stopped when you needed to." : "You made some time for yourself today.")
                    .font(TreniraType.title)
                    .foregroundStyle(TreniraColor.label)
                    .accessibilityAddTraits(.isHeader)
                Text(finishedEarlier ? "A little movement is still movement." : "Every session counts.")
                    .font(TreniraType.body)
                    .foregroundStyle(TreniraColor.labelSecondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(TreniraType.section)
                        .foregroundStyle(TreniraColor.label)
                    Stepper(value: $actualMinutes, in: 1...180) {
                        Text("\(actualMinutes) minutes")
                            .font(TreniraType.body)
                            .foregroundStyle(TreniraColor.label)
                    }
                    .accessibilityLabel("Actual minutes")
                    if let plannedMinutes {
                        Text("You had about \(plannedMinutes) minutes in mind.")
                            .font(TreniraType.caption)
                            .foregroundStyle(TreniraColor.labelSecondary)
                    }
                }
                .treniraCard()

                VStack(alignment: .leading, spacing: TreniraSpace.stack) {
                    Text("How do you feel? You can skip this.")
                        .font(TreniraType.section)
                        .foregroundStyle(TreniraColor.label)
                    ForEach(MovementFeeling.allCases) { item in
                        TreniraChoiceRow(title: item.title, isSelected: feeling == item) {
                            feeling = feeling == item ? nil : item
                        }
                    }
                }

                Button("Save") {
                    guard !didSave else { return }
                    didSave = true
                    MovementRecordStore.add(
                        MovementRecord(
                            kind: kind,
                            title: title,
                            actualMinutes: actualMinutes,
                            plannedMinutes: plannedMinutes,
                            feeling: feeling,
                            videoId: videoId,
                            ownerId: ownerId
                        )
                    )
                    AnalyticsService.capture(
                        .activityCompleted,
                        properties: ["activity_type": kind.analyticsActivityType]
                    )
                    onSaved()
                }
                .buttonStyle(TreniraPrimaryButtonStyle())
            }
            .padding(TreniraSpace.screen)
        }
        .background(TreniraColor.canvas)
        .navigationTitle("Record")
        .navigationBarTitleDisplayMode(.inline)
    }
}
