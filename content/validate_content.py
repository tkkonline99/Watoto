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

# docs/26 §26.7: `emoji` is the deprecated free-text glyph field. It warns for
# one release and fails after, which is what this flag is for. Nothing in the
# library uses it today — the field only ever existed on the legacy
# lesson_player model — so this is a guard against it coming back.
STRICT_VISUALS = "--strict-visuals" in sys.argv

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

# ---- the visual contract (docs/26-question-screen-system.md) ----

VISUAL_MODES = {"token", "scene", "slot"}

# Registered scene builders. A scene ref must name one of these; the Flutter
# side maps the same ids to widgets in core/widgets/stages/. Keep in step with
# author_visuals.py's SCENES — a ref in one and not the other is how a scene
# ships with no builder behind it.
SCENES = {
    "counting.array", "counting.tens-and-units", "arithmetic.number-sentence",
    "fraction.bars", "shape.loose-objects", "glyph.trace", "audio.waveform",
    "colour.field", "sentence.card",
}

def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)

def load_tokens():
    p = Path(__file__).resolve().parent / "visual_tokens.json"
    if not p.exists():
        return None
    return load(p)["tokens"]

def token_allows(allowed, claimed, subject):
    """Is a token registered for [allowed] legal on this item?

    Hierarchical, not set intersection: a `for` entry matches the item's most
    specific skill or any ancestor of it, so `science` covers `science.matter`
    while `science.matter` covers only itself.

    Intersection is what let a cow onto a states-of-matter step. The item
    claimed both `science` and `science.matter`; the cow was legal for
    `science` because the word occurs in a life-cycles lesson; the sets met and
    the wrong picture passed. Mirrored in build_visual_tokens.token_allows.
    """
    for entry in allowed:
        if entry == subject:
            return True
        if claimed and (entry == claimed or claimed.startswith(entry + ".")):
            return True
    return False

ILLUSTRATOR_NOTE = re.compile(r"\bdo\s+not\s+depict\b", re.IGNORECASE)


def check_visual(cid, where, visual, skills, subject, tokens,
                 errors, warnings, assets, rendered, slots, *, is_page):
    """Grade one visual object. `where` is e.g. "step 2" or "question 0"."""
    if visual is None:
        errors.append(f"{cid}: {where} has no 'visual' — every rendered part "
                      f"declares one (docs/26 §26.3)")
        return

    mode = visual.get("mode")
    ref = visual.get("ref")
    alt = (visual.get("alt") or "").strip()

    if mode not in VISUAL_MODES:
        errors.append(f"{cid}: {where} visual.mode '{mode}' not in {sorted(VISUAL_MODES)}")
    if not ref:
        errors.append(f"{cid}: {where} visual has no 'ref'")
    if len(alt.split()) < 4:
        errors.append(f"{cid}: {where} visual.alt must be a real description "
                      f"(>=4 words) — it is the screen-reader label and the art brief")
    # An art brief may carry a direction to whoever draws the picture, and on a
    # question step that direction states the answer: "DO NOT depict the answer
    # (Four)". `alt` is announced to a screen reader and printed inside the
    # striped placeholder, so 191 parts read that out and named the answer
    # while doing it. `author_visuals.strip_illustrator_note` keeps it in the
    # manifest and out of here; this is what makes it stay out.
    if ILLUSTRATOR_NOTE.search(alt):
        errors.append(f"{cid}: {where} visual.alt carries an instruction meant "
                      f"for the illustrator, and it names the answer — a screen "
                      f"reader reads this to the child: {alt!r}")

    if mode == "token" and ref:
        if tokens is None:
            warnings.append(f"{cid}: {where} token '{ref}' unchecked — visual_tokens.json not found")
        elif ref not in tokens:
            errors.append(f"{cid}: {where} token '{ref}' is not in visual_tokens.json — "
                          f"free-text glyphs are not allowed")
        else:
            allowed = tokens[ref].get("for", [])
            claimed = (skills or [None])[-1]
            if not token_allows(allowed, claimed, subject):
                errors.append(
                    f"{cid}: {where} token '{ref}' is registered for {sorted(allowed)} "
                    f"but this item teaches '{claimed}' — wrong picture for the question"
                )

    if mode == "scene" and ref and ref not in SCENES:
        errors.append(f"{cid}: {where} scene '{ref}' has no builder — add it to "
                      f"SCENES and core/widgets/stages/, or use a slot")

    # Slots feed the art manifest either way, but they are graded in two very
    # different ways and conflating them would bury the real failures.
    #
    # A story page's slot is art that has been drawn and is expected on disk;
    # a missing file there is a hole on the screen, and stays an error (that
    # is the guard the 98 undrawn quiz-option PNGs earned).
    #
    # A step or question slot is usually a *brief* — §26.3 says an unfinished
    # asset ships as the striped placeholder carrying its text, so a missing
    # file is the backlog working as designed, not a defect. 1,573 parts are
    # in exactly that state today.
    if mode == "slot" and ref:
        assets.append(("image", ref, alt, cid))
        (rendered if is_page else slots).add(ref)

def check_legacy_emoji(cid, where, node, errors, warnings):
    """'emoji' is the deprecated free-text field (docs/26 §26.7)."""
    if "emoji" in node:
        msg = (f"{cid}: {where} still uses 'emoji' — migrate to "
               f"visual{{mode,ref,alt}} (docs/26 §26.7)")
        (errors if STRICT_VISUALS else warnings).append(msg)

def main():
    lib = load(PATH)
    stages = {s["stage"]: set(s["subjects"]) for s in lib["curriculum"]["stages"]}
    content = lib["content"]
    errors, warnings, ids, assets = [], [], set(), []
    rendered = set()  # refs the player actually draws, not just pipeline metadata
    slots = set()     # declared briefs — placeholder until someone draws them
    visual_modes = Counter()
    tokens = load_tokens()

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
        skills, subject = c.get("skills", []), c.get("subject")

        def visual(where, node, is_page=False):
            check_legacy_emoji(cid, where, node, errors, warnings)
            check_visual(cid, where, node.get("visual"), skills, subject,
                         tokens, errors, warnings, assets, rendered, slots,
                         is_page=is_page)
            if isinstance(node.get("visual"), dict):
                visual_modes[node["visual"].get("mode")] += 1

        if t == "lesson":
            if not c.get("steps"):
                errors.append(f"{cid}: lesson has no steps")
            for i, st in enumerate(c.get("steps", [])):
                for k in ("narration", "action", "feedback"):
                    if k not in st:
                        errors.append(f"{cid}: step {i} missing '{k}'")
                visual(f"step {i}", st)
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
                visual(f"question {i}", qq)
        elif t == "story":
            if not c.get("pages"):
                errors.append(f"{cid}: story has no pages")
            for i, pg in enumerate(c.get("pages", [])):
                if "narration" not in pg or "illustration" not in pg:
                    errors.append(f"{cid}: page {i} missing narration/illustration")
                visual(f"page {i}", pg, is_page=True)

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
        # pages[].illustration is no longer collected here: a page's `visual`
        # carries the same ref and check_visual already recorded it, with a
        # better description (the alt text rather than a truncated narration).
        # Appending both would double-count every story page.

    # ---- do the referenced files exist? ----
    #
    # 98 quiz-option images once shipped pointing at PNGs nobody had drawn,
    # because this validator only ever looked at `assets[]` and quiz options
    # live somewhere else. A ref the player renders must resolve to a file.
    # Audio is graded softer: the app plays bundled SFX and never loads these
    # refs, so a missing file is a production backlog item (tracked in
    # content/production/audio/audio_sfx_manifest.csv), not a broken screen.
    if ASSET_ROOT.is_dir():
        awaiting_art = set()
        for atype, ref, _desc, cid in assets:
            if atype == "haptic" or asset_path(atype, ref).exists():
                continue
            if atype == "image" and ref in rendered:
                errors.append(f"{cid}: renders {ref} but no such file — regenerate with "
                              f"apps/mobile/tool/generate_art_batch.py")
            elif atype == "image" and ref in slots:
                # By design: the player draws the striped placeholder and shows
                # the brief. Counted rather than listed — there are over a
                # thousand, and printing them all would drown the real problems.
                awaiting_art.add(ref)
            elif atype == "image":
                warnings.append(f"{cid}: {ref} declared in assets[] has no file")
            elif atype == "audio":
                warnings.append(f"{cid}: {ref} has no file (see audio_sfx_manifest.csv)")
        if awaiting_art:
            warnings.append(
                f"{len(awaiting_art)} slot visual(s) have no art yet and will render "
                f"as the striped placeholder — run with --assets for the briefs"
            )
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
    print(f"  visuals declared : {sum(visual_modes.values())} {dict(sorted(visual_modes.items()))}")

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
