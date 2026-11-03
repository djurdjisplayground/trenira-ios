import Combine
import SwiftUI

struct MovementWalkView: View {
    var plannedMinutes: Int?
    var ownerId: String
    var onFinished: () -> Void

    @State private var startedAt: Date?
    @State private var elapsed = 0
    @State private var completion: WalkCompletion?

    var body: some View {
        VStack(alignment: .leading, spacing: TreniraSpace.section) {
            Text("A walk")
                .font(TreniraType.title)
                .foregroundStyle(TreniraColor.label)
                .accessibilityAddTraits(.isHeader)
            Text(plannedMinutes.map { "About \($0) minutes, or stop sooner." } ?? "Walk for as long as you want.")
                .font(TreniraType.body)
                .foregroundStyle(TreniraColor.labelSecondary)

            Text(elapsedLabel)
                .font(TreniraType.largeTitle)
                .foregroundStyle(TreniraColor.label)
                .accessibilityLabel("Elapsed \(elapsed) minutes")

            if startedAt == nil {
                Button("Start") { startedAt = .now }
                    .buttonStyle(TreniraPrimaryButtonStyle())
            } else {
                Button("I'm done") {
                    let minutes = startedAt.map { max(1, Int(Date().timeIntervalSince($0) / 60)) } ?? 1
                    openCompletion(minutes: minutes)
                }
                .buttonStyle(TreniraPrimaryButtonStyle())
            }
            Button("I already walked") { openCompletion(minutes: plannedMinutes ?? 10) }
                .buttonStyle(TreniraSecondaryButtonStyle())
            Spacer()
        }
        .padding(TreniraSpace.screen)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(TreniraColor.canvas)
        .navigationTitle("Walk")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(Timer.publish(every: 15, on: .main, in: .common).autoconnect()) { _ in
            guard let startedAt else { return }
            elapsed = max(0, Int(Date().timeIntervalSince(startedAt) / 60))
        }
        .navigationDestination(item: $completion) { item in
            MovementCompletionView(
                title: "Walk",
                kind: .walking,
                plannedMinutes: plannedMinutes,
                initialActualMinutes: item.minutes,
                ownerId: ownerId,
                onSaved: onFinished
            )
        }
    }

    private var elapsedLabel: String {
        if startedAt == nil { return "Ready when you are" }
        return "\(elapsed) min"
    }

    private func openCompletion(minutes: Int) {
        completion = WalkCompletion(minutes: minutes)
    }
}

struct WalkCompletion: Identifiable, Hashable {
    var minutes: Int
    var id = UUID()
}
