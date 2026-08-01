import MessageUI
import SwiftUI

/// Shared mail composer result (no personal logging).
enum MailComposeResultKind: Equatable {
    case sent
    case saved
    case cancelled
    case failed
}

/// Reusable SwiftUI wrapper around `MFMailComposeViewController`.
/// When presented in a SwiftUI `.sheet`, the parent dismisses the sheet.
struct MailComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let subject: String
    let body: String
    var onFinished: (MailComposeResultKind) -> Void

    static var canSendMail: Bool {
        MFMailComposeViewController.canSendMail()
    }

    static func outcome(from result: MFMailComposeResult) -> MailComposeResultKind {
        switch result {
        case .sent: return .sent
        case .saved: return .saved
        case .cancelled: return .cancelled
        case .failed: return .failed
        @unknown default: return .failed
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinished: onFinished)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients(recipients)
        controller.setSubject(subject)
        controller.setMessageBody(body, isHTML: false)
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinished: (MailComposeResultKind) -> Void

        init(onFinished: @escaping (MailComposeResultKind) -> Void) {
            self.onFinished = onFinished
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            _ = error
            onFinished(Self.map(result))
        }

        private static func map(_ result: MFMailComposeResult) -> MailComposeResultKind {
            MailComposeView.outcome(from: result)
        }
    }
}
