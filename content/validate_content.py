#!/usr/bin/env python3
"""
Watoto content validator + asset-manifest exporter.

Usage:
    python validate_content.py                 # validate the library, report errors
    python validate_content.py --assets        # also print the full asset manifest
    python validate_content.py path/to.json    # validate a specific file

Exit code 0 = clean, 1 = problems found. Wire this into CI so no malformed
or non-compliant content item can ever ship to a child.
"""
import json, re, sys
from collections import Counter
from pathlib import Path

PATH = next((a for a in sys.argv[1:] if not a.startswith("--")), "watoto_content_library.json")
SHOW_ASSETS = "--assets" in sys.argv

REPO = Path(__file__).resolve().parent.parent

# Where an asset `ref` resolves from. Images are relative to assets/images
# ("img/s01/ball.png"); audio is relative to assets ("audio/s01/chime.mp3").
ASSET_ROOT = REPO / "apps" / "mobile" / "assets"

def asset_path(atype, ref):
    return ASSET_ROOT / ("images/" + ref if atype == "image" else ref)

# content/watoto_content_library.json is a mirror of the file the app ships.
# CI validates this copy, so if the two drift the validator starts grading a
# library no child will ever play.
SHIPPED = ASSET_ROOT / "content" / "watoto_content_library.json"

TYPES = {"lesson", "quiz", "story"}
ID_RE = re.compile(r"^s\d{2}\.[a-z0-9\-]+\.(lesson|quiz|story)\.\d{2}$")

def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)

def main():
    lib = load(PATH)
    stages = {s["stage"]: set(s["subjects"]) for s in lib["curriculum"]["stages"]}
    content = lib["content"]
    errors, warnings, ids, assets = [], [], set(), []
    rendered = set()  # refs the player actually draws, not just pipeline metadata

    for c in content:
        cid = c.get("id", "<no id>")

        # ---- identity ----
        if not ID_RE.match(cid):
            errors.append(f"{cid}: id does not match pattern sNN.slug.type.NN")
        if cid in ids:
            errors.append(f"{cid}: duplicate id")
        ids.add(cid)

        # ---- required fields ----
        for field in ("stage", "subject", "type", "title", "objective",
                      "designTier", "reading", "timed", "interaction"):
            if field not in c:
                errors.append(f"{cid}: missing required field '{field}'")

        # ---- enums / ranges ----
        if c.get("type") not in TYPES:
            errors.append(f"{cid}: type '{c.get('type')}' not in {sorted(TYPES)}")
        if c.get("stage") not in stages:
            errors.append(f"{cid}: stage {c.get('stage')} is out of range 1-10")
        elif c.get("subject") not in stages[c["stage"]]:
            errors.append(f"{cid}: subject '{c.get('subject')}' is not in stage {c['stage']} curriculum")

        # ---- design rules ----
        if c.get("timed") is not False:
            errors.append(f"{cid}: 'timed' must be false (no time pressure on any item)")
        if not isinstance(c.get("reading"), bool):
            errors.append(f"{cid}: 'reading' must be a boolean")
        if c.get("stage") in (1, 2, 3, 4) and c.get("reading") is True:
            warnings.append(f"{cid}: reading=true below stage 5 (design tip: zero/one-word text for 0-4)")

        # ---- body by type ----
        t = c.get("type")
        if t == "lesson":
            if not c.get("steps"):
                errors.append(f"{cid}: lesson has no steps")
            for i, st in enumerate(c.get("steps", [])):
                for k in ("narration", "action", "feedback"):
                    if k not in st:
                        errors.append(f"{cid}: step {i} missing '{k}'")
        elif t == "quiz":
            if not c.get("questions"):
                errors.append(f"{cid}: quiz has no questions")
            for i, qq in enumerate(c.get("questions", [])):
                opts = qq.get("options", [])
                if len(opts) < 2:
                    errors.append(f"{cid}: question {i} needs >=2 options")
                ans = qq.get("answer")
                if not isinstance(ans, int) or not (0 <= ans < len(opts)):
                    errors.append(f"{cid}: question {i} answer index out of range")
                if not qq.get("correctFeedback") or not qq.get("retryFeedback"):
                    errors.append(f"{cid}: question {i} must have correct+retry feedback (retry-friendly, never punitive)")
        elif t == "story":
            if not c.get("pages"):
                errors.append(f"{cid}: story has no pages")
            for i, pg in enumerate(c.get("pages", [])):
                if "narration" not in pg or "illustration" not in pg:
                    errors.append(f"{cid}: page {i} missing narration/illustration")

        # ---- collect assets ----
        #
        # Three places carry a media ref, and they are not equally important.
        # `assets[]` is pipeline metadata — LibraryItem does not even parse it,
        # so a bad ref there costs a child nothing today. `options[].asset` and
        # `pages[].illustration` are what the player actually renders; a ref
        # with no file behind it is a hole on the screen. Collect all three,
        # remember which are rendered, and grade them differently below.
        for a in c.get("assets", []):
            if a.get("type") not in {"image", "audio", "haptic"} or not a.get("ref"):
                errors.append(f"{cid}: bad asset entry {a}")
            else:
                assets.append((a["type"], a["ref"], a.get("desc", ""), cid))
        for i, qq in enumerate(c.get("questions", [])):
            for o in qq.get("options", []):
                if o.get("asset"):
                    assets.append(("image", o["asset"], o.get("label", ""), cid))
                    rendered.add(o["asset"])
        for i, pg in enumerate(c.get("pages", [])):
            if pg.get("illustration"):
                assets.append(("image", pg["illustration"], pg.get("narration", "")[:60], cid))
                rendered.add(pg["illustration"])

    # ---- do the referenced files exist? ----
    #
    # 98 quiz-option images once shipped pointing at PNGs nobody had drawn,
    # because this validator only ever looked at `assets[]` and quiz options
    # live somewhere else. A ref the player renders must resolve to a file.
    # Audio is graded softer: the app plays bundled SFX and never loads these
    # refs, so a missing file is a production backlog item (tracked in
    # content/production/audio/audio_sfx_manifest.csv), not a broken screen.
    if ASSET_ROOT.is_dir():
        for atype, ref, _desc, cid in assets:
            if atype == "haptic" or asset_path(atype, ref).exists():
                continue
            if atype == "image" and ref in rendered:
                errors.append(f"{cid}: renders {ref} but no such file — regenerate with "
                              f"apps/mobile/tool/generate_art_batch.py")
            elif atype == "image":
                warnings.append(f"{cid}: {ref} declared in assets[] has no file")
            elif atype == "audio":
                warnings.append(f"{cid}: {ref} has no file (see audio_sfx_manifest.csv)")
    else:
        warnings.append(f"asset root {ASSET_ROOT} not found — skipped file checks")

    # ---- is this the library the app actually ships? ----
    if SHIPPED.exists() and Path(PATH).resolve() != SHIPPED:
        if load(SHIPPED) != lib:
            errors.append(
                f"{PATH} and {SHIPPED} have diverged — CI validates this copy but the "
                f"app bundles the other one. Copy the file across before committing."
            )

    # ---- report ----
    by_type = Counter(c.get("type") for c in content)
    by_stage = Counter(c.get("stage") for c in content)
    print(f"Validated {len(content)} items from {PATH}")
    print(f"  by type : {dict(by_type)}")
    print(f"  by stage: {dict(sorted(by_stage.items()))}")
    print(f"  assets referenced: {len(assets)} ({len({r for _,r,_,_ in assets})} unique)")

    if SHOW_ASSETS:
        print("\n--- ASSET MANIFEST (hand to art & audio teams) ---")
        seen = set()
        for atype, ref, desc, cid in sorted(assets):
            if ref in seen:
                continue
            seen.add(ref)
            print(f"  [{atype:6}] {ref:40} {desc}")

    if warnings:
        print(f"\n{len(warnings)} warning(s):")
        for w in warnings:
            print("  ! " + w)

    if errors:
        print(f"\nFAILED — {len(errors)} error(s):")
        for e in errors:
            print("  x " + e)
        sys.exit(1)
    print("\nOK — content is schema-valid and design-rule compliant.")
    sys.exit(0)

if __name__ == "__main__":
    main()
