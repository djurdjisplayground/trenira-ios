#!/usr/bin/env python3
"""Flag diffs that must not be applied to Android automatically.

Reads a unified diff on stdin. Prints JSON. Exit 0 always; callers inspect
the safety_review field. This does not call a network service.
"""

from __future__ import annotations

import json
import sys

# Matched case-insensitively against added and removed diff lines.
PATTERNS = (
    "postpartum",
    "pelvic",
    "rehabilitat",
    "baby",
    "clinician",
    "not a treatment",
    "safe after birth",
)


def review(diff: str) -> dict:
    hits = []
    for line in diff.splitlines():
        if not (line.startswith("+") or line.startswith("-")):
            continue
        if line.startswith("+++") or line.startswith("---"):
            continue
        lowered = line.lower()
        for pattern in PATTERNS:
            if pattern in lowered and pattern not in hits:
                hits.append(pattern)
    return {"safety_review": bool(hits), "patterns": hits}


def self_test() -> int:
    ordinary = review("+Text(\"A small library\")\n")
    sensitive = review("+Your baby stays in a safe place nearby.\n")
    ok = ordinary["safety_review"] is False and sensitive["safety_review"] is True and "baby" in sensitive["patterns"]
    if not ok:
        print(json.dumps({"ordinary": ordinary, "sensitive": sensitive}, indent=2))
        return 1
    print("safety_gate self-test passed")
    return 0


def main() -> int:
    if "--self-test" in sys.argv:
        return self_test()
    print(json.dumps(review(sys.stdin.read()), indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
