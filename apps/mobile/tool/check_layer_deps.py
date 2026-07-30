#!/usr/bin/env python3
"""Fail if domain or data/core layers import features (architecture guard)."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "lib"
IMPORT_RE = re.compile(r"""^\s*import\s+['"]([^'"]+)['"]""")

# Paths relative to lib/ that must not import features/*
FORBIDDEN_IMPORTERS = (
    "domain/",
    "core/network/",
    "core/offline/offline_store.dart",
)

# Allowed exception patterns (re-export barrels may mention features? no.)
FEATURE_IMPORT = re.compile(r"features/")


def main() -> int:
    violations: list[str] = []
    for path in ROOT.rglob("*.dart"):
        rel = path.relative_to(ROOT).as_posix()
        if not any(rel.startswith(p) or rel == p.rstrip("/") for p in FORBIDDEN_IMPORTERS):
            # also check pure domain and any file under domain/
            if not rel.startswith("domain/"):
                if not any(rel.startswith(p) for p in FORBIDDEN_IMPORTERS if p.endswith("/")):
                    if rel not in {p for p in FORBIDDEN_IMPORTERS if not p.endswith("/")}:
                        continue
        text = path.read_text(encoding="utf-8")
        for i, line in enumerate(text.splitlines(), 1):
            m = IMPORT_RE.match(line)
            if not m:
                continue
            uri = m.group(1)
            if FEATURE_IMPORT.search(uri):
                violations.append(f"{rel}:{i}: imports features → {uri}")

    # domain must not import flutter or features
    for path in (ROOT / "domain").rglob("*.dart"):
        rel = path.relative_to(ROOT).as_posix()
        for i, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            m = IMPORT_RE.match(line)
            if not m:
                continue
            uri = m.group(1)
            if uri.startswith("package:flutter") or "features/" in uri:
                violations.append(f"{rel}:{i}: domain forbidden import → {uri}")

    if violations:
        print("Layer dependency violations:")
        for v in violations:
            print(" ", v)
        return 1
    print("Layer dependency check OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
