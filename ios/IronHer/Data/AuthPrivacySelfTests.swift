import AuthenticationServices
import Foundation

#if DEBUG
/// DEBUG assertions for authentication data minimization and privacy invariants.
enum AuthPrivacySelfTests {
    struct Outcome: Sendable {
        var passed: Int
        var failed: Int
        var lines: [String]

        var summary: String {
            "\(passed) passed, \(failed) failed\n" + lines.joined(separator: "\n")
        }
    }

    static func runAll() -> Outcome {
        var passed = 0
        var failed = 0
        var lines: [String] = []

        func check(_ name: String, _ condition: @autoclosure () -> Bool) {
            if condition() {
                passed += 1
                lines.append("✓ \(name)")
            } else {
                failed += 1
                lines.append("✗ \(name)")
            }
        }

        // MARK: Apple scopes

        let scopes = AppleSignInRequestFactory.requestedScopes
        check("Apple request has no .email scope", !scopes.contains(.email))
        check("Apple request has no .fullName scope", !scopes.contains(.fullName))
        check("Apple requestedScopes is empty", scopes.isEmpty)

        // MARK: AuthState display (no email)

        check(
            "Google display name is neutral",
            AuthState.google(userId: "g-user-1").displayName == "Signed in with Google"
        )
        check(
            "Apple display name is neutral",
            AuthState.apple(userId: "a-user-1").displayName == "Signed in with Apple"
        )

        // MARK: Local vault ownership via provider user ID

        let appleOwner = AuthState.apple(userId: "apple-stable-1").dataOwnerID(guestID: "unused")
        let googleOwner = AuthState.google(userId: "google-stable-1").dataOwnerID(guestID: "unused")
        check(
            "Apple user ID maps to stable vault owner",
            appleOwner?.rawValue == "account:apple:apple-stable-1"
        )
        check(
            "Google user ID maps to stable vault owner",
            googleOwner?.rawValue == "account:google:google-stable-1"
        )

        // MARK: Google nil / empty user ID

        check("nil Google user ID is incomplete", GoogleAccountIdentity.stableUserID(from: nil) == nil)
        check("empty Google user ID is incomplete", GoogleAccountIdentity.stableUserID(from: "") == nil)
        check("whitespace Google user ID is incomplete", GoogleAccountIdentity.stableUserID(from: "  ") == nil)
        check(
            "valid Google user ID is preserved",
            GoogleAccountIdentity.stableUserID(from: "google-123") == "google-123"
        )

        // MARK: Migration — googleEmail / legacy email / accountUserIdentifier

        let suiteName = "trenira.authPrivacySelfTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            check("create isolated UserDefaults suite", false)
            return Outcome(passed: passed, failed: failed + 1, lines: lines)
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let provider = "apple"
        let stableID = "migration-apple-user"
        let workoutKey = "savedWorkouts"
        let workoutPayload = Data(#"[{"id":"w1"}]"#.utf8)
        let previousKeychainID = SecureAccountIdentityStore.load(provider: provider)
        defer {
            if let previousKeychainID {
                SecureAccountIdentityStore.save(provider: provider, userID: previousKeychainID)
            } else {
                SecureAccountIdentityStore.clear(provider: provider)
            }
        }

        defaults.set("apple", forKey: "authMode")
        defaults.set(stableID, forKey: "accountUserIdentifier")
        defaults.set("user@example.com", forKey: "googleEmail")
        defaults.set("legacy@example.com", forKey: "emailAddress")
        defaults.set(["x"], forKey: "emailAuthAccounts")
        defaults.set(workoutPayload, forKey: workoutKey)
        SecureAccountIdentityStore.clear(provider: provider)
        AuthDataMinimizationMigration.resetCompletionFlagForTests(defaults: defaults)

        let first = AuthDataMinimizationMigration.runIfNeeded(defaults: defaults)
        check("migration not already completed on first run", !first.alreadyCompleted)
        check("migration promoted provider ID to Keychain", first.migratedProviders.contains(provider))
        check(
            "Keychain holds stable Apple ID after migration",
            SecureAccountIdentityStore.load(provider: provider) == stableID
        )
        check("googleEmail removed", defaults.object(forKey: "googleEmail") == nil)
        check("emailAddress removed", defaults.object(forKey: "emailAddress") == nil)
        check("emailAuthAccounts removed", defaults.object(forKey: "emailAuthAccounts") == nil)
        check("accountUserIdentifier removed", defaults.object(forKey: "accountUserIdentifier") == nil)
        check("authMode preserved", defaults.string(forKey: "authMode") == "apple")
        check("workout data untouched by migration", defaults.data(forKey: workoutKey) == workoutPayload)
        check(
            "migration completion flag set",
            defaults.bool(forKey: AuthDataMinimizationMigration.completionKey)
        )

        // Re-seed obsolete keys to prove second run does not mutate when already completed.
        defaults.set("again@example.com", forKey: "googleEmail")
        let second = AuthDataMinimizationMigration.runIfNeeded(defaults: defaults)
        check("second migration run reports already completed", second.alreadyCompleted)
        check("second migration removes nothing", second.removedKeys.isEmpty)
        check("second migration migrates nothing", second.migratedProviders.isEmpty)
        // Completion short-circuit leaves re-seeded key (proves no second-pass cleanup).
        // Production code never rewrites googleEmail; AuthenticationManager also clears leftovers on persist.
        check(
            "stable Keychain ID unchanged after second run",
            SecureAccountIdentityStore.load(provider: provider) == stableID
        )

        SecureAccountIdentityStore.clear(provider: provider)

        // MARK: Erasure inventory still lists obsolete keys for leftover cleanup

        let erasure = Set(LocalDataErasureService.userContentUserDefaultsKeys)
        check("erasure inventory still lists googleEmail", erasure.contains("googleEmail"))
        check("erasure inventory still lists accountUserIdentifier", erasure.contains("accountUserIdentifier"))
        check("erasure inventory still lists emailAddress", erasure.contains("emailAddress"))

        // MARK: Privacy manifest presence + structure

        let manifestURL = Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy")
        check("PrivacyInfo.xcprivacy is in app bundle", manifestURL != nil)
        if let manifestURL,
           let data = try? Data(contentsOf: manifestURL),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            check("NSPrivacyTracking is false", plist["NSPrivacyTracking"] as? Bool == false)
            let collected = plist["NSPrivacyCollectedDataTypes"] as? [Any] ?? ["missing"]
            check("no first-party collected data types declared", collected.isEmpty)
            let domains = plist["NSPrivacyTrackingDomains"] as? [Any] ?? ["missing"]
            check("no tracking domains declared", domains.isEmpty)
            let apis = plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]] ?? []
            let userDefaultsAPI = apis.first {
                ($0["NSPrivacyAccessedAPIType"] as? String) == "NSPrivacyAccessedAPICategoryUserDefaults"
            }
            let reasons = userDefaultsAPI?["NSPrivacyAccessedAPITypeReasons"] as? [String] ?? []
            check("UserDefaults required-reason includes CA92.1", reasons.contains("CA92.1"))
        } else {
            check("PrivacyInfo.xcprivacy parses", false)
        }

        return Outcome(passed: passed, failed: failed, lines: lines)
    }
}
#endif
