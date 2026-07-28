#!/usr/bin/env python3
"""Coverage report: items per stage × subject × type.

Usage:
  python coverage_report.py
  python coverage_report.py --json
"""
from __future__ import annotations

import argparse
import json
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent
LIBRARY = ROOT / "watoto_content_library.json"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    data = json.loads(LIBRARY.read_text(encoding="utf-8"))
    items = data.get("content") or data.get("items") or []
    by_stage: dict[int, dict[str, dict[str, int]]] = defaultdict(
        lambda: defaultdict(lambda: defaultdict(int))
    )
    thin: list[str] = []

    for it in items:
        stage = int(it.get("stage") or 0)
        subject = str(it.get("subject") or "?")
        typ = str(it.get("type") or "?")
        by_stage[stage][subject][typ] += 1

    report = {
        "total_items": len(items),
        "stages": {},
        "thin_cells": [],
    }

    for stage in sorted(by_stage.keys()):
        subjects = by_stage[stage]
        stage_total = sum(sum(t.values()) for t in subjects.values())
        report["stages"][str(stage)] = {
            "total": stage_total,
            "subjects": {
                s: dict(types) for s, types in sorted(subjects.items())
            },
        }
        for subject, types in subjects.items():
            n = sum(types.values())
            if n < 3:
                msg = f"stage {stage} / {subject}: only {n} item(s)"
                thin.append(msg)
                report["thin_cells"].append(msg)

    # Empty stages 1–10
    for s in range(1, 11):
        if str(s) not in report["stages"]:
            msg = f"stage {s}: no content"
            thin.append(msg)
            report["thin_cells"].append(msg)

    if args.json:
        print(json.dumps(report, indent=2))
    else:
        print(f"Watoto content coverage — {report['total_items']} items\n")
        for stage, body in report["stages"].items():
            print(f"Stage {stage}: {body['total']} items")
            for subj, types in body["subjects"].items():
                parts = ", ".join(f"{k}={v}" for k, v in sorted(types.items()))
                print(f"  - {subj}: {parts}")
            print()
        if thin:
            print("Thin / empty cells (authoring priority):")
            for m in thin:
                print(f"  ! {m}")
        else:
            print("No thin cells under threshold (<3 per stage×subject).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
