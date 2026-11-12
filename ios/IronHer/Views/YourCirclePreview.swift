import SwiftUI

/// Product flag for the community preview. Stays off so the beta does not present it as a working feature.
enum TreniraFeature {
    static let yourCirclePreviewEnabled = false
}

/// Text-only look at a future community. No messages, accounts, or network calls.
struct YourCirclePreviewView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TreniraSpace.section) {
                Text("A FUTURE IDEA")
                    .font(TreniraType.caption)
                    .foregroundStyle(TreniraColor.orchid)
                    .accessibilityAddTraits(.isHeader)
                Text("Your circle")
                    .font(TreniraType.display)
                    .foregroundStyle(TreniraColor.label)
                    .fixedSize(horizontal: false, vertical: true)
                Text("A quiet place for encouragement, movement, and the ordinary parts of motherhood. This screen is a preview of that idea.")
                    .font(TreniraType.body)
                    .foregroundStyle(TreniraColor.label)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Nothing here is shared. There is no chat, no extra account, and no notification.")
                    .font(TreniraType.body)
                    .foregroundStyle(TreniraColor.labelSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                topic(
                    title: "Encouragement",
                    detail: "A few kind words when the day has already been a lot. People could leave a note, and you could read it when you want."
                )
                topic(
                    title: "Movement",
                    detail: "Short ideas that fit the minutes you actually have. The same gentle tone as Today, shared between people who choose to be here."
                )
                topic(
                    title: "Everyday motherhood",
                    detail: "The ordinary parts of the day, told simply. Not advice, and not a place to compare how anyone is doing."
                )

                Text("This preview stays off for the beta. Opening it does not join a group or send anything.")
                    .font(TreniraType.caption)
                    .foregroundStyle(TreniraColor.labelSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(TreniraSpace.screen)
            .padding(.bottom, 24)
        }
        .background(TreniraColor.ivory)
        .navigationTitle("Your circle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Close") { dismiss() }
            }
        }
    }

    private func topic(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(TreniraType.displayTitle)
                .foregroundStyle(TreniraColor.label)
            Text(detail)
                .font(TreniraType.body)
                .foregroundStyle(TreniraColor.labelSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(TreniraSpace.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TreniraColor.lavender)
        .clipShape(RoundedRectangle(cornerRadius: TreniraSpace.cardRadius, style: .continuous))
    }
}
