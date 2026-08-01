import Foundation

/// Legal document links. Prefer native in-app documents while hosted pages are unset.
enum LegalLinks {
    static var privacyPolicy: URL? { AppConfiguration.privacyPolicyURL }
    static var termsOfUse: URL? { AppConfiguration.termsURL }

    /// `true` once hosted pages are live and should open instead of (or alongside) native screens.
    static var areConfigured: Bool {
        privacyPolicy != nil && termsOfUse != nil
    }
}
