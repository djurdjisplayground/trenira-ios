# iOS to Android sync

The review workflow is `.github/workflows/ios-android-sync.yml`. It is manual-only. GitHub registers `workflow_dispatch` from the default branch, so the file must also exist on `main` before a run can be started. The run itself must select `cursor/replace-exercise-and-rest-timer`. `workflow.proposed.yml` is an older placeholder and is not the workflow to activate.

The iOS repository is `djurdjisplayground/trenira-ios`. The Android repository is the private `djurdjisplayground/trenira-android`. Nothing in this folder writes to the Android project when run locally.

## What is safe to run now

```bash
python3 tools/ios-android-sync/classify_changes.py --self-test
git diff-tree --no-commit-id --name-only -r HEAD | python3 tools/ios-android-sync/classify_changes.py
```

The classifier maps changed iOS paths to product features. `propose` means an Android pull request could later be opened. `human-review` and `ignore` must not be applied automatically. Unmapped files stay for a person.

`contracts/movement-rules.v1.json` records the shared identifiers and rules. Neither app loads it yet.

## What is still required before activation

1. Add `ANTHROPIC_API_KEY` to `djurdjisplayground/trenira-ios`.
2. Add a fine-grained `ANDROID_REPO_TOKEN` that can read and write only `trenira-android` contents and pull requests.
3. Push this manual workflow to `main` so GitHub can register it, and to `cursor/replace-exercise-and-rest-timer` so that branch's copy runs. Do not add a push trigger.

The installed workflow must open a draft pull request, never merge it, and never upload a release build. Android must not push commits back to iOS. Commits that contain `Sync-Source: trenira-android` are ignored.
