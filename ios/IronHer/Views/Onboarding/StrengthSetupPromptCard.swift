import SwiftUI

/// Shared Strength Setup entry copy. Does not replace the calibration session UI.
struct StrengthSetupPromptCard: View {
    var onStart: () -> Void
    var onMaybeLater: (() -> Void)? = nil
    var showsActions: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Not sure what weight to start with?")
                .font(SheLiftsFont.title)
                .foregroundStyle(IronHerTheme.primaryText)
                .accessibilityAddTraits(.isHeader)
                .fixedSize(horizontal: false, vertical: true)

            Text("Complete a quick strength setup and trenira can suggest starting weights for your exercises.")
                .font(SheLiftsFont.body)
                .foregroundStyle(IronHerTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("You’ll test a few simple exercises so trenira can estimate your current strength. After that, just choose your exercises and trenira can suggest your starting weights.")
                .font(SheLiftsFont.body)
                .foregroundStyle(IronHerTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if showsActions {
                Button("Start strength setup", action: onStart)
                    .buttonStyle(PrimaryButtonStyle())

                if let onMaybeLater {
                    Button("Maybe later", action: onMaybeLater)
                        .buttonStyle(OutlineButtonStyle())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
