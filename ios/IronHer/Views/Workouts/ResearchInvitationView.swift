import SwiftUI

/// Founder note asking whether the user will share feedback. Not a marketing popup.
struct ResearchInvitationView: View {
    @Environment(\.openURL) private var openURL
    @AccessibilityFocusState private var titleFocused: Bool
    @State private var showOpenError = false

    /// Called once the invitation is actually on screen.
    let onPresented: () -> Void
    /// Maybe later. Does not permanently opt out.
    let onLater: () -> Void
    /// Closes the invitation after Don't ask again or a successful form open.
    let onFinished: (_ action: String) -> Void

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(ResearchInvitationCopy.title)
                        .font(SheLiftsFont.largeTitle)
                        .foregroundStyle(IronHerTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Help shape trenira")
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($titleFocused)

                    Text(ResearchInvitationCopy.message)
                        .font(SheLiftsFont.body)
                        .foregroundStyle(IronHerTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 28)

                    VStack(spacing: 12) {
                        Button(action: accept) {
                            Text(ResearchInvitationCopy.acceptTitle)
                                .multilineTextAlignment(.center)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(AppConfiguration.researchInvitationFormURL == nil)
                        .accessibilityHint("Opens a short research form in your browser")

                        Button(action: onLater) {
                            Text(ResearchInvitationCopy.laterTitle)
                                .multilineTextAlignment(.center)
                        }
                        .buttonStyle(OutlineButtonStyle())
                        .accessibilityHint("Closes this invitation for today")

                        Button(action: optOut) {
                            Text(ResearchInvitationCopy.optOutTitle)
                                .font(SheLiftsFont.body)
                                .foregroundStyle(IronHerTheme.secondaryText)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                        .accessibilityHint("Stops automatic invitations on this device")
                    }
                }
                .padding(.horizontal, IronHerTheme.screenPadding)
                .padding(.top, 36)
                .padding(.bottom, 24)
                .frame(maxWidth: 520, alignment: .leading)
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height, alignment: .top)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(IronHerTheme.background.ignoresSafeArea())
        .onAppear {
            titleFocused = true
            onPresented()
        }
        .alert(ResearchInvitationCopy.openFailedTitle, isPresented: $showOpenError) {
            Button(ResearchInvitationCopy.tryAgainTitle, action: accept)
            Button("Not Now", role: .cancel) {}
        } message: {
            Text(ResearchInvitationCopy.openFailedMessage)
        }
    }

    private func accept() {
        showOpenError = false
        guard let url = AppConfiguration.researchInvitationFormURL else {
            showOpenError = true
            return
        }
        // Leave this screen only after the system accepts the URL, so closing it does not cancel the open.
        #if DEBUG
        FeedbackInvitationLog.line("action=openForm")
        #endif
        openURL(url) { accepted in
            if ResearchInvitationPolicy.recordOpenedForm(didOpen: accepted) {
                AnalyticsService.capture(.researchInvitationAccepted)
                #if DEBUG
                FeedbackInvitationLog.line("form open succeeded")
                #endif
                DispatchQueue.main.async {
                    onFinished("openedForm")
                }
            } else {
                #if DEBUG
                FeedbackInvitationLog.line("form open failed; status was not changed")
                #endif
                showOpenError = true
            }
        }
    }

    private func optOut() {
        #if DEBUG
        FeedbackInvitationLog.line("action=dontAskAgain")
        #endif
        ResearchInvitationStore.markOptedOut()
        onFinished("dontAskAgain")
    }
}

#Preview {
    ResearchInvitationView(onPresented: {}, onLater: {}, onFinished: { _ in })
}
