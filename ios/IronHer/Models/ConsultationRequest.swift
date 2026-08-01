import Foundation

enum ConsultationTrainingExperience: String, CaseIterable, Identifiable, Codable, Hashable {
    case beginner
    case intermediate
    case advanced

    var id: String { rawValue }

    var label: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }
}

/// Local draft for a Founder Consultation request (device-only; not a remote submission).
struct ConsultationRequest: Codable, Equatable, Hashable {
    var name: String = ""
    var email: String = ""
    /// Legacy field retained for draft decode compatibility; no longer collected in the UI.
    var mainGoal: String = ""
    var experience: ConsultationTrainingExperience = .intermediate
    var helpWith: String = ""
    var preferredTimezone: String = ""
    var optionalNotes: String = ""
    var updatedAt: Date = .now

    static let maxNameLength = 100
    static let maxEmailLength = 254
    static let maxTimezoneLength = 80
    static let maxHelpWithLength = 2_000
    static let maxNotesLength = 2_000

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedHelpWith: String { helpWith.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedTimezone: String { preferredTimezone.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedNotes: String { optionalNotes.trimmingCharacters(in: .whitespacesAndNewlines) }

    var isBlank: Bool {
        trimmedName.isEmpty
            && trimmedEmail.isEmpty
            && trimmedHelpWith.isEmpty
            && trimmedTimezone.isEmpty
            && trimmedNotes.isEmpty
    }

    /// Clamps text fields to safe maximum lengths after trimming edges for storage.
    mutating func clampFieldLengths() {
        name = String(trimmedName.prefix(Self.maxNameLength))
        email = String(trimmedEmail.prefix(Self.maxEmailLength))
        preferredTimezone = String(trimmedTimezone.prefix(Self.maxTimezoneLength))
        helpWith = String(helpWith.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxHelpWithLength))
        optionalNotes = String(optionalNotes.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxNotesLength))
        mainGoal = ""
    }
}

enum ConsultationValidationError: Equatable, Hashable {
    case emptyName
    case emptyEmail
    case invalidEmail
    case emptyHelpWith
    case disclaimerNotAccepted

    var message: String {
        switch self {
        case .emptyName: return "Enter your name."
        case .emptyEmail: return "Enter your email."
        case .invalidEmail: return "Enter a valid email address."
        case .emptyHelpWith: return "Tell us what you’d like help with."
        case .disclaimerNotAccepted: return "Confirm you understand the scope of the consultation."
        }
    }
}

/// Outcome of presenting the mail composer or copy fallback (no network logging of PII).
enum ConsultationMailOutcome: Equatable {
    case sent
    case saved
    case cancelled
    case failed
    case copiedRequest
    case copiedEmailAddress
}

struct ConsultationMailOutcomeEffect: Equatable {
    /// Clear the on-device draft (only after a real send).
    var clearDraft: Bool
    /// Show the post-send success screen.
    var showSentSuccess: Bool
    /// Neutral status message for alerts / banners (nil = stay quiet).
    var statusMessage: String?
}
