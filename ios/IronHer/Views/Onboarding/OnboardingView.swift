import SwiftUI

/// Minimal first-launch introduction for trenira (max three short pages).
struct OnboardingView: View {
    /// When true, Continue / Get Started only dismisses (Settings → View Introduction).
    var isPreview: Bool = false
    var continueTitle: String = "Get Started"
    var onFinished: () -> Void

    @State private var page = 0

    private let pages: [(title: String, body: String)] = [
        (
            "Fit the day",
            "A little time for you, on the day you actually have."
        ),
        (
            "Choose",
            "Pick 2, 5, 10, 15, or 20+ minutes, then a way to move. Doing your own thing counts."
        ),
        (
            "Continue",
            "Small steps count. Nothing is overdue."
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Welcome to \(AppConfiguration.appName)")
                            .font(SheLiftsFont.title)
                            .foregroundStyle(IronHerTheme.primaryText)
                            .accessibilityAddTraits(.isHeader)

                        Text("Movement that fits your life.")
                            .font(SheLiftsFont.bodyMedium)
                            .foregroundStyle(IronHerTheme.primaryText)

                        Text("Choose a little time, then move or do your own thing. Nothing is assigned, and energy is optional.")
                            .font(SheLiftsFont.body)
                            .foregroundStyle(IronHerTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    TabView(selection: $page) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.title)
                                    .font(SheLiftsFont.section)
                                    .foregroundStyle(IronHerTheme.primaryText)
                                Text(item.body)
                                    .font(SheLiftsFont.body)
                                    .foregroundStyle(IronHerTheme.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                            .tag(index)
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .frame(height: 140)

                    healthDisclaimer
                }
                .padding(.horizontal, IronHerTheme.screenPadding)
                .padding(.top, 36)
                .padding(.bottom, 24)
            }

            VStack(spacing: 12) {
                Button(action: finish) {
                    Text(continueTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityLabel(continueTitle)
                .accessibilityHint(
                    isPreview
                        ? "Closes the introduction"
                        : "Completes the introduction and continues into trenira"
                )
            }
            .padding(.horizontal, IronHerTheme.screenPadding)
            .padding(.bottom, 28)
            .padding(.top, 8)
        }
        .background(IronHerTheme.background.ignoresSafeArea())
    }

    private var healthDisclaimer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Health & safety")
                .font(SheLiftsFont.bodyMedium)
                .foregroundStyle(IronHerTheme.primaryText)

            Text(
                "\(AppConfiguration.appName) is a movement companion, not a medical or rehabilitation service. It does not assess recovery or prescribe exercise for symptoms. Move within your abilities and consult an appropriately qualified professional if you have medical or injury-related concerns."
            )
            .font(SheLiftsFont.body)
            .foregroundStyle(IronHerTheme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(IronHerTheme.groupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: IronHerTheme.cornerRadiusSmall, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Health and safety notice")
    }

    private func finish() {
        if !isPreview {
            OnboardingStore.markCompleted()
        }
        onFinished()
    }
}

#Preview {
    OnboardingView(onFinished: {})
}
