#!/usr/bin/env python3
"""Flag content strings that likely need per-locale reauthoring (pedagogy).

Looks for English-centric teaching patterns that often break FR/SW phonics
or idioms. Exit 0 always with a report; use --strict to fail CI on hits.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
LIB = ROOT / "watoto_content_library.json"

# Patterns that often need locale-specific rewrites.
PATTERNS = [
    (re.compile(r"\b(short|long)\s+[aeiou]\b", re.I), "english_vowel_phonics"),
    (re.compile(r"\b(th|sh|ch)\s+sound\b", re.I), "english_consonant_phonics"),
    (re.compile(r"\bquotation\b|\bquote\s+marks?\b", re.I), "english_punctuation"),
    (re.compile(r"\bidiom\b|\bsaying\b", re.I), "idiom"),
    (re.compile(r"\b(color|colour)\s+word\b", re.I), "spelling_variant"),
]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--strict", action="store_true")
    args = ap.parse_args()

    data = json.loads(LIB.read_text(encoding="utf-8"))
    content = data.get("content") or data
    if not isinstance(content, list):
        print("No content list", file=sys.stderr)
        return 1

    hits: list[str] = []
    for item in content:
        iid = item.get("id", "?")
        blobs: list[str] = []
        for k in ("title", "objective", "parentNote"):
            if item.get(k):
                blobs.append(str(item[k]))
        for step in item.get("steps") or []:
            for k in ("narration", "action", "feedback"):
                if step.get(k):
                    blobs.append(str(step[k]))
        for q in item.get("questions") or []:
            for k in ("prompt", "correctFeedback", "retryFeedback"):
                if q.get(k):
                    blobs.append(str(q[k]))
        text = "\n".join(blobs)
        for rx, label in PATTERNS:
            if rx.search(text):
                hits.append(f"{iid}\t{label}")

    print(f"locale_review candidates: {len(hits)}")
    for h in hits[:80]:
        print(h)
    if len(hits) > 80:
        print(f"... and {len(hits) - 80} more")

    if args.strict and hits:
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
