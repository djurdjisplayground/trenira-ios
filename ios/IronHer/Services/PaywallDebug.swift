import Foundation
import OSLog

/// Temporary paywall diagnostics — remove once dismissal bugs are verified fixed.
enum PaywallDebug {
    private static let logger = Logger(subsystem: "com.trenira.app", category: "Paywall")

    static func log(_ event: String) {
        let line = "[Paywall] \(event)"
        print(line)
        logger.debug("\(event, privacy: .public)")
    }
}
