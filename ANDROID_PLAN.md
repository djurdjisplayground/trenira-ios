# trenira Android plan

This plan is an assessment of the current iOS app. It does not migrate or rewrite the SwiftUI project.

The live iOS app is a local-first movement companion. After the splash and sign-in, `RootView` shows companion questions only when no profile is resolved. The shell is `MainTabView`: Today, My Moments, and Explore. Profile opens Settings. Workout, Adapt, and Progress screens still compile for older strength data, and they are not on the tab bar.

## What can be shared or ported

These pieces are plain data and rules. They do not depend on SwiftUI. They can be ported as Kotlin, or described once and implemented twice. They cannot be compiled into an Android app as Swift source.

| iOS source | What to carry over | Android shape |
| --- | --- | --- |
| `MovementCatalog.swift` | Equipment, categories, energies, the activity list, and the hard equipment filter | Kotlin data classes plus a catalog file. Draft `withBabyNearby` entries stay marked `pendingProfessionalReview`. |
| `MovementCatalogRecommender` | Time upper bound, energy match, equipment match, floor exclusion, three distinct suggestions, empty result instead of a silent substitute | A pure function with the same tests. Dumbbells must not be filled with walking or dancing. |
| `MovementRecord`, `MovementRecordStore`, `MovementDiary` | Owner, activity date, exact seconds, idempotent upsert, week grouped by activity date | The same JSON fields. `actualDurationSeconds` stays optional so older records still decode. |
| `MovementSessionClock` | Foreground monotonic time. Background gaps are not counted. | Elapsed realtime while resumed, not wall-clock including background. |
| `CompanionProfile` and `CompanionProfileStore` | Optional equipment, floor preference, preferred kinds. Missing fields decode as empty. | Same optional JSON. Do not require a second onboarding gate. |
| `TodayCheckInStore`, `MovementFavoriteStore`, `PausedMovementDraft` | Last time, energy, and equipment. A paused moment can resume. | Same keys and behavior. |
| `DiaryReflection` and catalog safety copy | Weekly lines, the no-match line, and the postpartum note that refuses rehabilitation claims | Copy constants. Do not rewrite them into medical claims. |
| `MovementRecordKind.analyticsActivityType` | Closed tokens such as `walking`, `dancing`, `with_baby`, `guided` | Same allowlist. No free-text notes. |

Persistence keys to keep stable if an account backup is ever shared across platforms:

- `trenira.movementRecords.v1`
- `trenira.companionProfile.v1`
- `trenira.todayCheckIn.v1`
- `trenira.pausedMovement.v1`
- `trenira.movementFavorites.v1`
- `trenira.movementReminders.v1` (per owner, not part of the workout backup snapshot)
- `trenira.weekPlan.v1` (local only)

Do not port the strength-workout stack for the movement MVP: active workout logging, adaptation, exercise database, progression, calibration, StoreKit, or consultation. Leave PostHog until the iOS consent rule is copied exactly: missing consent means allowed, debug builds do not send unless a developer switch is on, and the property allowlist stays closed.

`Your circle` is a text preview behind `TreniraFeature.yourCirclePreviewEnabled = false`. Do not build chat, accounts, or a community backend in the MVP.

## Kotlin/Jetpack Compose or Flutter

**Recommendation: native Kotlin and Jetpack Compose.**

The iOS app is already native, and its valuable core is a set of Swift rules rather than a shared UI toolkit. Compose can follow the same screen structure: ivory canvas, serif titles, lavender cards, three tabs, and text-only equipment rows. A Flutter app would still rewrite every model, the recommender, and every screen, and it would add a second runtime beside the iOS binary. There is no existing Dart module and no shared backend that would make that cost pay off.

Compose fits this product for three practical reasons.

- The movement MVP is a small navigation graph, not a custom renderer. Compose Navigation can mirror Today, suggestions, the active moment, the diary, and Explore.
- Local JSON is the source of truth. DataStore or a single Room database of JSON-compatible records is enough. Flutter's plugin layer is unnecessary for that.
- Release builds need the same care as iOS about what is visible. A feature flag in Kotlin is a normal `BuildConfig` or constant. The community preview stays out of the beta graph.

Choose Flutter only if a later product decision requires one team to ship both clients from one UI codebase, and only after the catalog and diary rules are frozen as a written contract. That is not the situation of this repository.

## MVP screen order

1. Guest entry and a skippable four-step preference flow: enjoyed movement, equipment, floor constraint, reminders explained without asking permission yet.
2. Today: time, optional energy, one equipment choice, Find my movement, Log movement.
3. Three suggestions, or the no-match explanation. Something else stays available.
4. Detail, active moment with pause that excludes background time, and one save.
5. My Moments: list by activity date, edit, delete, and the weekly reflection lines.
6. Explore, including the draft With baby nearby filter.
7. Profile: reminders, privacy, and local data. No community tab.

Equipment on Today stays a single selection. Surprise me uses only equipment the profile marked available. With baby nearby is a category in Explore and a `with_baby` record kind. It is not a baby-lifting workout.

## Persistence

Use one local store on the device. Preferences DataStore can hold the profile, check-in, favorites, and reminder settings. Movement records can live in the same store as one JSON document for the MVP, matching `MovementRecordStore`, or in Room if the diary needs querying sooner. Either way, decode unknown fields without deleting old records, upsert by id, and group the week by `activityAt` when it exists, otherwise `completedAt`.

Reminders use `AlarmManager` or WorkManager only after the user turns them on in Profile. Logout cancels pending reminders and keeps the saved preference, matching iOS. Do not add a server, push provider, or chat database.

## Phases

| Phase | Scope | Estimate |
| --- | --- | --- |
| 0. Contract | Port the catalog, recommender, record, and diary rules. Reproduce the iOS self-test cases in Kotlin. | 1 week |
| 1. Today loop | Guest entry, preferences, Today, suggestions, detail, timer, save. | 2 weeks |
| 2. Diary | Retrospective log, edit, delete, weekly summary, paused resume. | 1 week |
| 3. Explore | Filters, favorites, and the five draft baby-nearby entries with the review label. | 1 week |
| 4. Profile | Reminders, privacy copy, local erasure of the movement keys. | 1 week |
| 5. Later | Sign-in, backup, analytics consent, and only then a community design. Not part of the MVP. | Separate decision |

Estimates assume one Android developer who can read the Swift rules and does not rebuild the unused workout product. The iOS app remains the reference for copy, filter behavior, and what must stay unreviewed until a professional content review.
