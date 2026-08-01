import SwiftUI
import UIKit

struct BetaFeedbackView: View {
    @Environment(\.openURL) private var openURL

    @State private var showMailComposer = false
    @State private var showUnavailable = false
    @State private var statusMessage: String?

    var body: some View {
        Form {
            Section {
                Text("Share what you tried, what happened and what felt confusing. Your message goes to \(AppConfiguration.feedbackEmail) after you review and send it.")
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                Text(AppConfiguration.feedbackEmail)
                    .font(SheLiftsFont.bodyMedium)
                    .foregroundStyle(IronHerTheme.primaryText)
                    .textSelection(.enabled)
                    .accessibilityLabel("Feedback email address")
                    .accessibilityValue(AppConfiguration.feedbackEmail)

                Button("Copy email address") {
                    UIPasteboard.general.string = AppConfiguration.feedbackEmail
                    statusMessage = "Email address copied"
                }

                Button("Copy feedback template") {
                    UIPasteboard.general.string = FeedbackService.clipboardPayload()
                    statusMessage = "Feedback template copied"
                }
            } footer: {
                Text("Diagnostic context includes only app version, build, iOS version and device model — not workouts or account details.")
                    .font(SheLiftsFont.caption)
            }

            Section {
                Button {
                    if MailComposeView.canSendMail {
                        showMailComposer = true
                    } else {
                        showUnavailable = true
                    }
                } label: {
                    Text("Send Feedback")
                        .frame(maxWidth: .infinity)
                        .fontWeight(.semibold)
                }
                .accessibilityHint("Opens Mail with a prefilled feedback template")
            } footer: {
                if let statusMessage {
                    Text(statusMessage)
                        .font(SheLiftsFont.caption)
                } else {
                    Text("Nothing is sent until you tap Send in Mail.")
                        .font(SheLiftsFont.caption)
                }
            }
        }
        .navigationTitle("Beta Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showMailComposer) {
            MailComposeView(
                recipients: [FeedbackService.recipient],
                subject: FeedbackService.subject,
                body: FeedbackService.emailBody()
            ) { result in
                showMailComposer = false
                switch result {
                case .sent:
                    statusMessage = "Your feedback was sent."
                case .saved:
                    statusMessage = "Your email was saved as a draft."
                case .cancelled:
                    break
                case .failed:
                    statusMessage = "The email could not be sent."
                }
            }
            .ignoresSafeArea()
        }
        .alert("Mail is not configured", isPresented: $showUnavailable) {
            Button("Copy feedback template") {
                UIPasteboard.general.string = FeedbackService.clipboardPayload()
                statusMessage = "Feedback template copied"
            }
            if let mailto = FeedbackService.mailtoURL() {
                Button("Open email app") {
                    openURL(mailto)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Mail is not configured on this device. You can copy the feedback template and send it to \(AppConfiguration.feedbackEmail) using your preferred email app.")
        }
    }
}
