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

I18N = "i18n"
LOCALES = ["fr", "sw"]

def load(p):
    return json.load(open(p, encoding="utf-8"))

def main():
    en = load(f"{I18N}/en.json")
    en_keys = set(en)
    print(f"English catalog: {len(en_keys)} strings (source of truth)\n")

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
