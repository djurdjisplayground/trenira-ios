import CryptoKit
import Foundation

enum EmailAuthError: LocalizedError {
    case invalidEmail
    case passwordTooShort
    case accountAlreadyExists
    case accountNotFound
    case incorrectPassword

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Enter a valid email address."
        case .passwordTooShort:
            return "Password must be at least 8 characters."
        case .accountAlreadyExists:
            return "An account with this email already exists."
        case .accountNotFound:
            return "No account found for this email."
        case .incorrectPassword:
            return "Incorrect password. Please try again."
        }
    }
}

enum EmailAuthService {
    private static let accountsKey = "emailAuthAccounts"

    struct StoredAccount: Codable {
        let userId: String
        let email: String
        let passwordHash: String
    }

    static func createAccount(email: String, password: String) throws -> StoredAccount {
        let normalizedEmail = normalize(email)
        guard isValidEmail(normalizedEmail) else { throw EmailAuthError.invalidEmail }
        guard password.count >= 8 else { throw EmailAuthError.passwordTooShort }

        var accounts = loadAccounts()
        guard accounts[normalizedEmail] == nil else { throw EmailAuthError.accountAlreadyExists }

        let account = StoredAccount(
            userId: UUID().uuidString,
            email: normalizedEmail,
            passwordHash: hash(password)
        )
        accounts[normalizedEmail] = account
        saveAccounts(accounts)
        return account
    }

    static func signIn(email: String, password: String) throws -> StoredAccount {
        let normalizedEmail = normalize(email)
        guard isValidEmail(normalizedEmail) else { throw EmailAuthError.invalidEmail }

        guard let account = loadAccounts()[normalizedEmail] else {
            throw EmailAuthError.accountNotFound
        }
        guard account.passwordHash == hash(password) else {
            throw EmailAuthError.incorrectPassword
        }
        return account
    }

    private static func normalize(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        return email.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func hash(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func loadAccounts() -> [String: StoredAccount] {
        guard let data = UserDefaults.standard.data(forKey: accountsKey),
              let decoded = try? JSONDecoder().decode([String: StoredAccount].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private static func saveAccounts(_ accounts: [String: StoredAccount]) {
        guard let data = try? JSONEncoder().encode(accounts) else { return }
        UserDefaults.standard.set(data, forKey: accountsKey)
    }
}
