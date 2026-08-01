import SwiftUI

/// Minimal first-launch introduction for trenira (max three short pages).
struct OnboardingView: View {
    /// When true, Get Started only dismisses (Settings → View Introduction).
    var isPreview: Bool = false
    var onFinished: () -> Void

    @State private var page = 0

    private let pages: [(title: String, body: String)] = [
        (
            "Build",
            "Create workouts that fit your routine."
        ),
        (
            "Adapt",
            "Replace exercises and keep progressing when life changes."
        ),
        (
            "Progress",
            "Focus on consistent strength gains without unnecessary complexity."
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

                        Text("Strength training should adapt to real life.")
                            .font(SheLiftsFont.bodyMedium)
                            .foregroundStyle(IronHerTheme.primaryText)

                        Text("Build workouts, track progression and stay consistent whether you are at your regular gym or travelling.")
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
                    Text("Get Started")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityLabel("Get Started")
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
                "\(AppConfiguration.appName) helps you organise and track strength training. It does not provide medical advice, diagnosis, physiotherapy or rehabilitation. Train within your abilities and consult an appropriately qualified professional if you have medical or injury-related concerns."
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
