import Foundation

/// Atomic writes with an explicit Data Protection class for Application Support JSON.
enum ProtectedFileWriter {
    /// Matches `com.apple.developer.default-data-protection` on the App ID / entitlements
    /// (`NSFileProtectionComplete`). Trenira does not need workout files while the device is locked.
    static let preferredProtection: FileProtectionType = .complete

    static func writeAtomically(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(
            to: url,
            options: [.atomic, .completeFileProtection]
        )
        // Atomic replace can drop attributes on some OS versions — re-apply explicitly.
        try applyProtection(at: url)
    }

    static func applyProtection(at url: URL) throws {
        try FileManager.default.setAttributes(
            [.protectionKey: preferredProtection],
            ofItemAtPath: url.path
        )
    }

    /// Best-effort upgrade for files that already exist from earlier builds.
    static func ensureProtectionIfPresent(at url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try? applyProtection(at: url)
    }
}
