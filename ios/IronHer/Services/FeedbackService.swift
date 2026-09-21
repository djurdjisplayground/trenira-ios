import Foundation
import UIKit

/// Builds production-neutral feedback email payloads without attaching workout or account PII.
enum FeedbackService {
    static var recipient: String { AppConfiguration.feedbackEmail }

    static let subject = "trenira feedback"

    static func emailBody() -> String {
        """
        Hello,

        I would like to share feedback about trenira.

        What I was trying to do:


        What happened:


        What I expected:


        Anything that felt confusing:


        Additional notes:


        App version: \(AppVersion.marketing)
        Build: \(AppVersion.build)
        iOS version: \(UIDevice.current.systemVersion)
        Device: \(deviceModelIdentifier())

        Thank you.
        """
    }

    static func clipboardPayload() -> String {
        """
        To: \(recipient)
        Subject: \(subject)

        \(emailBody())
        """
    }

    static func mailtoURL() -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: emailBody()),
        ]
        return components.url
    }

    /// Hardware model identifier only (e.g. iPhone15,2) — not a personal identifier.
    static func deviceModelIdentifier() -> String {
        var info = utsname()
        uname(&info)
        let mirror = Mirror(reflecting: info.machine)
        let identifier = mirror.children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result.append(Character(UnicodeScalar(UInt8(value))))
        }
        return identifier.isEmpty ? UIDevice.current.model : identifier
    }
}
