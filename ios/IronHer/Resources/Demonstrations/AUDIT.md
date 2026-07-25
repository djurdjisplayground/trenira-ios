# Exercise Demonstration Audit

## Product policy

User-facing demonstrations are **licensed real-human silent loops** only.

| State | Behavior |
|-------|----------|
| `demo-<id>.mp4` present | Autoplay loop on Exercise Details |
| Missing | Omit visual (no stylized stand-in, no wrong variation) |

Procedural silhouette code may remain in the repo for internal experiments, but it is **not** shown in the product UI.

## Adding clips

1. License or produce a clip that matches the exact exercise ID / equipment.
2. Place it at `Resources/Demonstrations/demo-<exercise-id>.mp4`.
3. Follow the style guide in `README.md`.
4. Rebuild — no catalog code change required for a new file of an existing ID.

## Runtime checks

```swift
// IDs still waiting on licensed video
ExerciseDemonstrationCatalog.missingBundledVideoAssets()

// Full quality / mapping report (includes procedural metadata for authoring)
ExerciseDemonstrationCatalog.auditReport()
```
