# Exercise Demonstrations (real-human loops)

trenira shows a **silent, looping real-human** demonstration on Exercise Details
only when a licensed clip exists for that stable exercise ID.

If no approved clip is present, the visual is omitted. Accuracy over completeness.
Stylized / procedural stand-ins are not shown in the product UI.

## Naming

```
Resources/Demonstrations/demo-<exercise-id>.mp4
```

Examples:

| Exercise | File |
|----------|------|
| Dumbbell Overhead Press | `demo-dumbbell-shoulder-press.mp4` |
| Barbell Overhead Press | `demo-overhead-press.mp4` |
| Machine Shoulder Press | `demo-machine-shoulder-press.mp4` |
| Dumbbell Skull Crusher | `demo-dumbbell-skull-crusher.mp4` |

Never reuse one clip across equipment variations.

## Visual standards

- Real human demonstrator (prefer a consistent model set)
- Neutral workout clothing (black / charcoal / grey), no brand logos
- Plain studio background
- Consistent lighting and framing
- Static camera (no zoom, pan, or cuts)
- Silent, ~3–6 seconds, seamless loop
- No watermarks, text overlays, music, or motivational effects

## Licensing

Only add clips trenira has permission or a license to use.
Do not copy videos from other fitness apps, websites, or social accounts.

## Playback

- Autoplays when Exercise Details opens
- Loops silently
- Tap to pause / resume
- Lazy-loaded (not at app launch)
- Recently viewed clips are lightly cached in memory
- Never autoplays during an active workout

## Inventory

```swift
ExerciseDemonstrationCatalog.missingBundledVideoAssets()
```

See also `AUDIT.md` for internal tracking.
