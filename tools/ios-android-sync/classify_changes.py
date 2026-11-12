#!/usr/bin/env python3
"""Classify iOS paths into Android sync features.

Reads newline-separated paths on stdin, or the paths listed in --files.
Prints JSON. Does not call a network service, an agent, or git push.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
MAP_PATH = ROOT / "feature-map.json"


def load_map() -> dict:
    return json.loads(MAP_PATH.read_text())


def classify(paths: list[str], feature_map: dict) -> dict:
    matched: dict[str, dict] = {}
    unmapped: list[str] = []
    for path in paths:
        normalized = path.strip()
        if not normalized:
            continue
        hits = []
        for feature in feature_map["features"]:
            if any(normalized.startswith(prefix) or prefix.startswith(normalized) for prefix in feature["ios_paths"]):
                hits.append(feature["id"])
                bucket = matched.setdefault(
                    feature["id"],
                    {
                        "id": feature["id"],
                        "action": feature["action"],
                        "summary": feature["summary"],
                        "files": [],
                        "android_paths": feature["android_paths"],
                        "android_tests": feature["android_tests"],
                    },
                )
                bucket["files"].append(normalized)
        if not hits:
            unmapped.append(normalized)
    features = list(matched.values())
    propose = [item["id"] for item in features if item["action"] == "propose"]
    return {
        "version": feature_map["version"],
        "propose": propose,
        "human_review": [item["id"] for item in features if item["action"] == "human-review"],
        "ignored": [item["id"] for item in features if item["action"] == "ignore"],
        "features": features,
        "unmapped": unmapped,
        "needs_agent": bool(propose),
    }


def self_test() -> int:
    feature_map = load_map()
    sample = classify(
        [
            "ios/IronHer/Models/MovementCatalog.swift",
            "ios/IronHer/Views/YourCirclePreview.swift",
            "ios/IronHer/Views/Workouts/ActiveWorkoutView.swift",
            "README.md",
        ],
        feature_map,
    )
    expected_propose = "movement-catalog" in sample["propose"]
    expected_review = "community-preview" in sample["human_review"]
    expected_ignore = "strength-legacy" in sample["ignored"]
    expected_unmapped = "README.md" in sample["unmapped"]
    ok = expected_propose and expected_review and expected_ignore and expected_unmapped
    if not ok:
        print(json.dumps(sample, indent=2))
        return 1
    print("classify_changes self-test passed")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--files", type=Path, help="File containing newline-separated paths")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    if args.files:
        raw = args.files.read_text().splitlines()
    else:
        raw = sys.stdin.read().splitlines()
    print(json.dumps(classify(raw, load_map()), indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
