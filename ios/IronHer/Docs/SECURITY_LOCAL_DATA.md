# Security & local data protection (trenira iOS)

**Internal only.** This document is a development / operations inventory for local
data protection and processing. It must **not** be bundled or exposed as a
public Legal & Privacy screen in the app. Public users see Privacy Policy and
Terms & Conditions only.

This document records the pre-TestFlight privacy/security changes for local-first storage.
No backend, cloud sync, or third-party security SDK was added.

## 1. iOS Data Protection entitlement

**File:** `IronHer.entitlements`

The `com.apple.developer.default-data-protection` key was **removed from the
checked-in entitlements** so automatic signing cannot fail when the App ID /
team profile uses a different protection class than the plist.

Application Support workout vaults and mirrors still receive **explicit**
`FileProtectionType.complete` via `ProtectedFileWriter` (see §2). That does not
require the default-data-protection entitlement.

**Optional (Xcode UI only):** To also set the app-wide default class, add
**Signing & Capabilities → + Capability → Data Protection** in Xcode and choose
one level. Let Xcode update both the App ID and `IronHer.entitlements` together —
do not hand-edit the entitlement string if it fights the provisioning profile.

## 2. Explicit Application Support file protection

**Helper:** `Data/ProtectedFileWriter.swift`

Writers use atomic Data writes plus `.completeFileProtection`, then re-apply
`FileProtectionType.complete` so atomic replace cannot drop attributes.

Protected writers:

- `AccountDataVault.save`
- `LocalMirrorRemoteUserDataStore.persistToDisk`
- `LocalPersistenceBackup.exportToDocuments` (DEBUG only)

Existing files are upgraded best-effort on load via `ensureProtectionIfPresent`.

No custom AES/CryptoKit encryption was added. JSON formats are unchanged.

## 3. UserDefaults review (no broad migration)

Confirmed: OAuth tokens, passwords, and private keys are **not** stored in UserDefaults.
Apple/Google tokens remain in their SDKs.

### Security-relevant UserDefaults keys

| Key | Contents | Sensitivity / note |
|-----|----------|--------------------|
| `authMode` | guest / apple / google | Low — session mode |
| `accountUserIdentifier` | Provider user ID | Sensitive ID — also in Keychain; candidate to drop from UD later |
| `googleEmail` | Google email | Sensitive — consider Keychain later |
| `savedWorkouts` / `savedWorkoutsDeleted` | Workout JSON | Sensitive training data — UD (not migrated this task) |
| `weightHistory` | Weight history JSON | Sensitive |
| `workoutWeeklyCompletions` | Weekly completion JSON | Sensitive |
| `workoutPerformanceLogs` | Performance logs JSON | Sensitive |
| `activeWorkoutSession` | In-progress session JSON | Sensitive |
| `customExercises` | Custom exercise JSON | User content |
| `exerciseProgression*` / `progression*` / `globalExerciseProgress` | Progression JSON | Sensitive |
| `userSettings` | Preferences JSON | Includes equipment increments |
| `gymEquipmentProfiles.v1` / `activeId` | Gym profiles | Device-shared settings |
| `trenira.activeDataOwnerId` / `detachedAccountOwnerId` | Owner pointers | Isolation metadata |
| `trenira.dataTombstones` | Soft-delete markers | Sync metadata |
| `trenira.didShowFirstWorkoutBackupHint` | Bool hint | Low |
| `trenira.migrationDone.*` | Migration flags | Low |
| `testingTimeSimulatedDaysOffset` | DEBUG time offset | Dev only |
| `trenira.migrationDone.weightIncrementRepair_v1.<owner>` | Bool | Repair flag for legacy +2.0 kg dumbbell progression bug |
| `trenira.hasCompletedOnboarding` | First-launch intro completion | Low — not personal data; cleared on erase-all |
| `trenira.consultationRequestDraft.v1` | Consultation form draft | Sensitive PII — device-only; never logged |

Payloads are never logged in production.

## 4. Keychain accessibility

**Changed from:** `kSecAttrAccessibleAfterFirstUnlock`  
**Changed to:** `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`

Stores:

- `SecureAccountIdentityStore` (Apple/Google provider user IDs only — not OAuth tokens)
- `GuestIdentityStore` (guest UUID)

**Migration:** On successful read, values are deleted and rewritten with the new
accessibility class. Existing identities are preserved; a new guest/account ID is never
generated when an old value can still be read.

`ThisDeviceOnly` prevents iCloud Keychain sync of these items.

## 5. Logout behaviour

- Confirmation: “Log out?” / Cancel / Log Out
- Ends Trenira Apple/Google session (including `GIDSignIn.signOut()`)
- Clears auth UserDefaults + Keychain provider IDs
- **Does not** erase workouts, history, progression, settings, or vault files
- Vaults the account snapshot via `prepareForSignOut`
- After logout → Continue as Guest starts a **clean guest workspace** so another person
  choosing Guest cannot browse the previous account’s live records; the prior account
  vault remains for same-identity re-login
- A **different** Apple/Google identity swaps to that account’s vault (or empty), ending
  any active session and clearing missing progression/settings blobs

## 6. Erase All Local Data

Replaces “Delete Account” wording. Trenira does not delete Apple/Google accounts.

**UI:** `EraseLocalDataView`  
**Service:** `LocalDataErasureService`

Flow: explanation → first confirm (Continue) → type `DELETE` → Erase Data.

Erases vaults, mirrors, DEBUG backups, all listed UserDefaults user-content keys,
Keychain guest + provider IDs, then signs out to the welcome screen.

**Intentionally excluded:** bundled exercise catalogue, StoreKit entitlements/config,
Google/Apple SDK configuration, app binaries.

Consultation drafts (`trenira.consultationRequestDraft.v1` in UserDefaults) are included in the
UserDefaults wipe list. Founder Consultation is **not** a StoreKit entitlement and
does not unlock app features. Beta requests are prepared via `MFMailComposeViewController`
to `AppConfiguration.consultationEmail` (currently `trenira@trenira.info` for beta), or a copy/mailto fallback.
The app never silently transmits form data and only shows “sent” after Mail reports `.sent`.
Drafts are cleared after a successful send, manual clear, or erase-all — retained after cancel/failure/copy.

## 7. Logging

- Apple user IDs are not logged (even with `.private`)
- Workout ID/name prints remain `#if DEBUG` only
- Erasure/auth diagnostics use `Logger` with non-sensitive stage labels
- Consultation form fields (name, email, goals, notes) are never printed or logged

## 8. Manual TestFlight checklist

See the implementation report / Developer self-tests:

- `UserDataMigrationSelfTests`
- `LocalDataProtectionSelfTests`
- `ConsultationSelfTests`
