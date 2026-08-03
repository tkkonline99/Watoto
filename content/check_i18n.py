#!/usr/bin/env python3
"""
Report translation coverage for each locale against the English catalog.
Run after extract_strings.py + build_locale.py.

    python check_i18n.py
    python check_i18n.py --missing fr   # list untranslated keys for one locale

Exit 0 always (coverage report, not a gate) unless a locale has keys that do
NOT exist in English (a sign of stale/typo'd keys), which exits 1.
"""
import json, sys
from pathlib import Path

I18N = "i18n"
LOCALES = ["fr", "sw"]

# What the app actually bundles. These once ran 340 keys ahead of the source
# catalog here, because translations were pasted straight into the app tree —
# so this script reported a backlog that had in fact already been done, and
# anything regenerated from content/ would have thrown the work away.
SHIPPED = Path(__file__).resolve().parent.parent / "apps" / "mobile" / "assets" / "i18n"

def load(p):
    return json.load(open(p, encoding="utf-8"))

def english_by_design():
    """Keys that stay English on purpose — see i18n/english_by_design.json."""
    try:
        return set(load(f"{I18N}/english_by_design.json")["keys"])
    except FileNotFoundError:
        return set()

def main():
    en = load(f"{I18N}/en.json")
    en_keys = set(en)
    locked = english_by_design() & en_keys
    if locked:
        print(f"{len(locked)} keys are English by design (phonics, idioms) and are "
              f"not counted as pending.")
    en_keys -= locked
    print(f"English catalog: {len(en_keys)} strings needing translation "
          f"(source of truth)\n")

    bad = False
    for code in LOCALES:
        try:
            loc = load(f"{I18N}/{code}.json")
        except FileNotFoundError:
            print(f"{code}: bundle not found")
            continue
        keys = set(loc)
        translated = keys & en_keys
        missing = en_keys - keys
        orphan = keys - en_keys
        pct = round(100 * len(translated) / len(en_keys))
        print(f"{code}: {len(translated)}/{len(en_keys)} translated ({pct}%)  |  {len(missing)} pending")
        # per-stage breakdown
        for s in range(1, 11):
            sid = f"s{s:02d}."
            st_en = {k for k in en_keys if k.startswith(sid)}
            st_done = len(st_en & keys)
            if st_en:
                mark = "done" if st_done == len(st_en) else f"{st_done}/{len(st_en)}"
                print(f"     stage {s:>2}: {mark}")
        if orphan:
            bad = True
            print(f"   !! {len(orphan)} orphan keys not in English: {sorted(orphan)[:5]}")
        print()

    # ---- source catalog vs what the app bundles ----
    for code in ["en"] + LOCALES:
        shipped = SHIPPED / f"{code}.json"
        if not shipped.exists():
            continue
        here, there = load(f"{I18N}/{code}.json"), load(shipped)
        if here == there:
            continue
        bad = True
        only_here = sorted(set(here) - set(there))
        only_there = sorted(set(there) - set(here))
        changed = [k for k in set(here) & set(there) if here[k] != there[k]]
        print(f"   !! {code}.json differs from {shipped}")
        print(f"      {len(only_here)} only in content/, {len(only_there)} only in the app "
              f"bundle, {len(changed)} with different text")
        for k in (only_here[:3] + only_there[:3] + changed[:3]):
            print(f"        {k}")
        print("      the app ships its copy — reconcile before releasing")

    if "--missing" in sys.argv:
        code = sys.argv[sys.argv.index("--missing") + 1]
        loc = load(f"{I18N}/{code}.json")
        miss = sorted(set(en) - set(loc))
        print(f"--- {len(miss)} keys still needing {code} ---")
        for k in miss:
            print(f"  {k}")

    sys.exit(1 if bad else 0)

if __name__ == "__main__":
    main()
