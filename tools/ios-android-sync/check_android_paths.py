#!/usr/bin/env python3
"""Reject Android paths that are outside the classifier's approved list.

The plan JSON is the classifier output. Paths are newline-separated on stdin.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path


def allowed_paths(plan: dict) -> list[str]:
    proposed = set(plan.get("propose") or [])
    paths = []
    for feature in plan.get("features") or []:
        if feature.get("id") in proposed and feature.get("action") == "propose":
            paths.extend(feature.get("android_paths") or [])
    return paths


def unexpected(changed: list[str], plan: dict) -> list[str]:
    allowed = allowed_paths(plan)
    rejected = []
    for path in changed:
        normalized = path.strip().lstrip("./")
        if not normalized:
            continue
        if any(
            normalized == item or (item.endswith("/") and normalized.startswith(item))
            for item in allowed
        ):
            continue
        rejected.append(normalized)
    return rejected


def self_test() -> int:
    plan = {
        "propose": ["explore"],
        "features": [
            {
                "id": "explore",
                "action": "propose",
                "android_paths": ["app/src/main/java/com/example/trenira/ui/movement/LibraryScreens.kt"],
            }
        ],
    }
    ok = unexpected(["app/src/main/java/com/example/trenira/ui/movement/LibraryScreens.kt"], plan) == []
    blocked = unexpected(["app/src/main/java/com/example/trenira/community/CommunityFeature.kt"], plan)
    if not ok or blocked != ["app/src/main/java/com/example/trenira/community/CommunityFeature.kt"]:
        return 1
    print("check_android_paths self-test passed")
    return 0


def main() -> int:
    if "--self-test" in sys.argv:
        return self_test()
    plan = json.loads(Path(sys.argv[1]).read_text())
    changed = sys.stdin.read().splitlines()
    rejected = unexpected(changed, plan)
    print(json.dumps({"rejected": rejected}, indent=2))
    return 1 if rejected else 0


if __name__ == "__main__":
    raise SystemExit(main())
