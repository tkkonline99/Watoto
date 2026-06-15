#!/usr/bin/env python3
"""
Extract every learner-facing string from the content library into a flat
localization catalog. Keys are dotted paths so the app can overlay a locale
bundle (fr/sw) on top of the structural content file at runtime.

    python extract_strings.py            # writes i18n/en.json
    python extract_strings.py --print    # also print key count

The English bundle is the SOURCE OF TRUTH for keys. Translators only ever
fill the same keys in fr.json / sw.json — never touch the content file.
"""
import json, os, sys

CONTENT = "watoto_content_library.json"
OUTDIR = "i18n"

# fields that are shown to a child or parent and therefore need translation
def extract(item):
    out = {}
    i = item["id"]
    out[f"{i}.title"] = item["title"]
    if item.get("parentNote"):
        out[f"{i}.parentNote"] = item["parentNote"]
    for n, st in enumerate(item.get("steps", [])):
        out[f"{i}.steps.{n}.narration"] = st["narration"]
        out[f"{i}.steps.{n}.feedback"] = st["feedback"]
    for n, q in enumerate(item.get("questions", [])):
        out[f"{i}.questions.{n}.prompt"] = q["prompt"]
        out[f"{i}.questions.{n}.correctFeedback"] = q["correctFeedback"]
        out[f"{i}.questions.{n}.retryFeedback"] = q["retryFeedback"]
        for m, op in enumerate(q.get("options", [])):
            out[f"{i}.questions.{n}.options.{m}.label"] = op["label"]
    for n, pg in enumerate(item.get("pages", [])):
        out[f"{i}.pages.{n}.narration"] = pg["narration"]
    return out

def main():
    lib = json.load(open(CONTENT, encoding="utf-8"))
    catalog = {}
    for item in lib["content"]:
        catalog.update(extract(item))
    catalog = dict(sorted(catalog.items()))
    os.makedirs(OUTDIR, exist_ok=True)
    with open(f"{OUTDIR}/en.json", "w", encoding="utf-8") as f:
        json.dump(catalog, f, indent=2, ensure_ascii=False)
    print(f"wrote {OUTDIR}/en.json — {len(catalog)} strings from {len(lib['content'])} items")
    if "--print" in sys.argv:
        for k in list(catalog)[:8]:
            print("  ", k, "=>", catalog[k])

if __name__ == "__main__":
    main()
