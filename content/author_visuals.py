"""Give every rendered part a declared `visual`.

Why this exists
---------------
`docs/26-question-screen-system.md` requires every step, question and story
page to declare what fills its stage, so the player stops guessing a glyph out
of the narration text. That is 3,556 parts across 684 items — 2,230 steps, 732
questions, 594 pages — which is why it is a script and not an authoring pass.

What it will not do
-------------------
Invent a picture it cannot justify. Where nothing in the content says what the
stage should show, the part gets a `slot`: a framed brief that ships as a
striped placeholder. That is the honest outcome, and it is the whole point —
an unmade picture should look unmade rather than quietly resolve to a tin of
food. `--report` counts them, so the art backlog is a query.

Resolution order
----------------
1. a story page's own `illustration`                    -> slot (real art)
2. a step whose conventional PNG is already bundled     -> slot (real art)
3. a part whose skill and fields describe a structure   -> scene
4. a concrete noun in the part's own text, registered
   for this item's skills                               -> token
5. anything else                                        -> slot (brief only)

Rule 4 is deliberately tighter than the token registry alone. The registry asks
"has this glyph ever legitimately illustrated this skill"; this asks "does
*this* sentence name the thing". Both must hold.

Alt text
--------
`alt` is the screen-reader label and the art brief at once, so it has to be a
real description. Sources, in order: the brief already written for that step in
`production/images/image_manifest.csv`, then the part's own authored text with
the instruction stripped ("Tap the dark sky." -> "The dark sky"), which is the
same transform the existing briefs were written to.

Idempotent: re-running makes no further change.

    python content/author_visuals.py            # from the repo root
    python content/author_visuals.py --check    # verify only, exit 1 on drift
    python content/author_visuals.py --report   # mode/source breakdown
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from collections import Counter

from authoring import LIBRARIES, ROOT
from build_visual_tokens import token_allows

TOKENS_PATH = ROOT / "content/visual_tokens.json"
MANIFEST = ROOT / "content/production/images/image_manifest.csv"
IMAGE_ROOT = ROOT / "apps/mobile/assets/images"

# Scene builder ids. Kept in step with validate_content.py's SCENES and the
# widget builders in core/widgets/stages/ — a ref in one and not the others is
# a validation error, which is what stops a scene shipping with no builder.
SCENES = {
    "counting.array", "counting.tens-and-units", "fraction.bars",
    "shape.loose-objects", "glyph.trace", "audio.waveform",
    "colour.field", "sentence.card",
}

# Leading instruction verbs. Stripping these turns narration into a description
# of what the picture shows, which is what an art brief and a screen-reader
# label both want.
_IMPERATIVES = (
    "tap on", "tap", "touch", "point to", "point at", "look at", "look",
    "find", "say", "count the", "count", "show me", "show", "press",
    "drag", "trace", "clap", "watch", "listen to", "listen", "put",
    "choose", "pick", "read", "write", "draw", "build", "sort", "match",
    "circle", "colour", "color", "name", "tell me", "tell", "add",
)
_IMPERATIVE_RE = re.compile(
    rf"^(?:{'|'.join(re.escape(v) for v in _IMPERATIVES)})\b[,:]?\s*",
    re.I,
)


def slugify(item: dict) -> str:
    return re.sub(r"[^a-z0-9]+", "_",
                  re.sub(r"^s\d\d\.", "", item["id"]).lower())


def step_ref(item: dict, index: int) -> str:
    """The path stepArtAsset() in content_art.dart already looks for."""
    return f"img/s{item['stage']:02d}/step_{slugify(item)}_{index}.png"


def question_ref(item: dict, index: int) -> str:
    return f"img/s{item['stage']:02d}/q_{slugify(item)}_{index}.png"


# ------------------------------------------------------------------ alt text

def sentences(text: str) -> list[str]:
    return [s.strip() for s in re.split(r"(?<=[.!?])\s+", text.strip()) if s.strip()]


def describe(text: str, item: dict) -> str:
    """Turn authored text into a description of the picture it implies."""
    parts = sentences(text)
    if not parts:
        return f"Illustration for {item['title']}"

    # Prefer the first sentence that says something about the world rather than
    # telling the child what to do with the screen.
    best = None
    for s in parts:
        stripped = _IMPERATIVE_RE.sub("", s)
        if stripped is not s and len(stripped.split()) < 3:
            continue  # "Tap it." leaves nothing to draw
        best = stripped or s
        break
    if best is None:
        best = _IMPERATIVE_RE.sub("", parts[0]) or parts[0]

    best = best.rstrip(" .").strip()
    best = re.sub(r"\s+", " ", best)
    if best:
        best = best[0].upper() + best[1:]
    return floor(best, item)


def floor(alt: str, item: dict) -> str:
    """Hold the validator's 4-word minimum without inventing detail.

    Some steps really do say one word — "Softly", "Ma-ma" — and the briefs
    already written for them are that word. Padding with filler would satisfy
    the counter and defeat its purpose, so the lesson name is what gets added:
    it is true, it is useful to an illustrator, and it is useful read aloud.
    """
    alt = alt.strip()
    if not alt:
        return f"Illustration for {item['title']}"
    if len(alt.split()) >= 4:
        return alt
    return f"{alt}, from the {item.get('type', 'lesson')} '{item['title']}'"


def load_manifest_briefs() -> dict[str, str]:
    """part key -> the descriptive half of an already-written art brief."""
    if not MANIFEST.exists():
        return {}
    out: dict[str, str] = {}
    with MANIFEST.open(encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            brief = (row.get("art_brief") or "").strip()
            if not brief:
                continue
            # Briefs are "<style boilerplate>. Scene: <the actual subject>."
            scene = brief.split("Scene:", 1)[-1].strip() if "Scene:" in brief else brief
            scene = scene.rstrip(" .")
            for key in (row.get("used_by") or "").split(";"):
                key = key.strip()
                if key and scene:
                    out[key] = scene
    return out


# -------------------------------------------------------------------- scenes

# A scene is proposed by the item's skill and confirmed by the part's own
# words. The skill alone is not enough: "Tap fast, then slow" sits in a
# First Numbers lesson and is not about quantity, and "How does Little Duck's
# story end?" sits in a Tracing & Stories item and has no glyph to trace. A
# rule that fired on skill alone would put a counting array on both, which is
# the lexicon's mistake wearing a different hat.
_CONFIRM = {
    "counting.array": re.compile(
        r"\bhow many\b|\bcount\b|\bcounting\b|\barray\b|\brows?\b|\d"),
    "counting.tens-and-units": re.compile(
        r"\btens?\b|\bones\b|\bhundreds?\b|place value|column|regroup|"
        r"\bborrow|\bcarry|\d\d"),
    "fraction.bars": re.compile(
        r"\bhalf\b|\bhalves\b|\bquarter|\bthird|\bfraction|\d\s*/\s*\d|"
        r"\btenths?\b|\bhundredths?\b|\bdecimal|\bequal parts?\b"),
    "shape.loose-objects": re.compile(
        r"\bshapes?\b|\bcircle|\bsquare|\btriangle|\brectangle|\bsort\b|"
        r"\bgroup\b|\bmatch\b|\bsame\b|\bdifferent\b|\bbelongs?\b"),
    "glyph.trace": re.compile(
        r"\btrace\b|\btracing\b|\bwrite\b|\bwriting\b|\bletters?\b|"
        r"\bstroke|\bpencil|\bline\b|\bcurve\b|\bshape of\b"),
    "audio.waveform": re.compile(
        r"\blisten|\bsounds?\b|\bhear\b|\bclap\b|\bsyllab|\brhyme|\bsong\b|"
        r"\bsing\b|\bmusic\b|\bbeat\b|\bloud\b|\bquiet\b|\bnoise\b"),
    "colour.field": re.compile(
        r"\bcolou?rs?\b|\bred\b|\bblue\b|\byellow\b|\bgreen\b|\borange\b|"
        r"\bpurple\b|\bpink\b|\bblack\b|\bwhite\b|\bbrown\b"),
    "sentence.card": re.compile(
        r"\bsentence|\bcapital|\bfull stop\b|\bperiod\b|\bpunctuat|\bverbs?\b|"
        r"\bnouns?\b|\badjectives?\b|\bpast\b|\bpresent\b|\bfuture\b|"
        r"\bcomma\b|\bword order\b|\bquestion mark\b"),
}

# skill -> the scene it proposes, most specific skill first.
_PROPOSE: list[tuple[frozenset[str], str]] = [
    (frozenset({"math.fractions", "math.decimals"}), "fraction.bars"),
    (frozenset({"math.place-value"}), "counting.tens-and-units"),
    (frozenset({"math.shapes", "sorting"}), "shape.loose-objects"),
    (frozenset({"colors"}), "colour.field"),
    (frozenset({"tracing", "reading.handwriting"}), "glyph.trace"),
    (frozenset({"phono", "music"}), "audio.waveform"),
    (frozenset({"reading.mechanics", "writing.mechanics",
                "writing.grammar"}), "sentence.card"),
    (frozenset({"math.counting", "counting", "numbers",
                "math.multiplication-division"}), "counting.array"),
]


def scene_for(item: dict, part: dict, kind: str) -> str | None:
    """A registered scene id when the part is about structure, else None."""
    skills = set(item.get("skills") or [])
    text = " ".join(filter(None, [
        part.get("narration", ""), part.get("prompt") or "",
    ])).lower()

    # Explicit array/counting fields beat every heuristic: the content already
    # said how many and in what shape, so there is nothing left to confirm.
    if kind == "step":
        if (part.get("rows") and part.get("cols")) or part.get("count") \
                or part.get("mechanic") in ("buildArray", "count"):
            return "counting.array"

    for owned, scene in _PROPOSE:
        if owned & skills and _CONFIRM[scene].search(text):
            return scene
    # A shape or colour word carries its own structure wherever it appears.
    for scene in ("colour.field", "shape.loose-objects"):
        if "colors" in skills and _CONFIRM[scene].search(text):
            return scene
    return None


# -------------------------------------------------------------------- tokens

def token_for(text: str, item: dict, tokens: dict) -> str | None:
    """A token, only where the text names exactly one picturable thing.

    §26.3 allows a token when "the concept is a single nameable object", and
    that word *single* is doing real work. Matching the first registered noun
    in the sentence is precisely the mistake the lexicon ladder makes: "Put a
    lid on a pan of hot water and watch where the drops form" names a lid, and
    a lid is a legal token for science.matter because the word genuinely occurs
    there — so first-match hands a condensation step a tin of food, which is
    the exact failure docs/26 was written about.

    A sentence naming several different things has no single object to stand
    for it, so it gets a slot and a brief instead. Counting *glyphs* rather
    than words keeps synonyms together: "a puddle... where did the water go"
    names two words for one picture, and that still resolves.
    """
    claimed = (item.get("skills") or [None])[-1]
    subject = item.get("subject")
    low = text.lower()
    by_glyph: dict[str, str] = {}
    for name, tok in tokens.items():
        if not token_allows(tok["for"], claimed, subject):
            continue
        word = name.replace(".", " ")
        if not re.search(rf"(?<![a-z]){re.escape(word)}(?![a-z])", low):
            continue
        # Keep the longest spelling for a glyph: "apples" over "apple".
        glyph = tok["glyph"]
        if glyph not in by_glyph or len(name) > len(by_glyph[glyph]):
            by_glyph[glyph] = name
    if len(by_glyph) != 1:
        return None
    return next(iter(by_glyph.values()))


# ------------------------------------------------------------------ resolve

def resolve(item, part, kind, index, tokens, briefs, on_disk):
    key = f"{item['id']}.{ {'step':'steps','question':'questions','page':'pages'}[kind] }.{index}"
    body = part.get("narration") or part.get("prompt") or ""
    written = briefs.get(key)
    alt = floor(written, item) if written else describe(body, item)

    if kind == "page":
        ref = part.get("illustration")
        if ref:
            return {"mode": "slot", "ref": ref, "alt": alt}, "page-art"

    if kind == "step":
        ref = step_ref(item, index)
        if ref in on_disk:
            return {"mode": "slot", "ref": ref, "alt": alt}, "drawn"

    scene = scene_for(item, part, kind)
    if scene:
        return {"mode": "scene", "ref": scene, "alt": alt}, "scene"

    token = token_for(body, item, tokens)
    if token:
        return {"mode": "token", "ref": token, "alt": alt}, "token"

    ref = step_ref(item, index) if kind == "step" else question_ref(item, index)
    return {"mode": "slot", "ref": ref, "alt": alt}, "brief"


def apply(lib, tokens, briefs, on_disk, stats):
    changed = 0
    for item in lib["content"]:
        for kind, field in (("step", "steps"), ("question", "questions"),
                            ("page", "pages")):
            for i, part in enumerate(item.get(field, [])):
                visual, source = resolve(item, part, kind, i,
                                         tokens, briefs, on_disk)
                stats[f"{visual['mode']}:{source}"] += 1
                if part.get("visual") != visual:
                    part["visual"] = visual
                    changed += 1
    return changed


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--report", action="store_true")
    args = ap.parse_args()

    tokens = json.loads(TOKENS_PATH.read_text(encoding="utf-8"))["tokens"]
    briefs = load_manifest_briefs()
    on_disk = {
        str(p.relative_to(IMAGE_ROOT)).replace("\\", "/")
        for p in IMAGE_ROOT.rglob("*.png")
    }

    total_changed = 0
    stats: Counter = Counter()
    for path in LIBRARIES:
        stats = Counter()
        lib = json.loads(path.read_text(encoding="utf-8"))
        changed = apply(lib, tokens, briefs, on_disk, stats)
        total_changed += changed
        if changed and not args.check:
            path.write_text(json.dumps(lib, indent=2, ensure_ascii=False) + "\n",
                            encoding="utf-8")

    if args.report:
        total = sum(stats.values())
        print(f"{total} rendered parts\n")
        for key, n in sorted(stats.items()):
            mode, source = key.split(":")
            print(f"  {n:5}  {mode:6} via {source}")
        drawn = stats["slot:page-art"] + stats["slot:drawn"]
        print(f"\n{drawn} parts point at art that is already drawn.")
        print(f"{stats['slot:brief']} carry a brief only and will render as "
              f"the striped placeholder.")

    if args.check:
        if total_changed:
            print(f"drift: {total_changed} part(s) would change", file=sys.stderr)
            return 1
        print("visuals up to date")
        return 0

    print(f"updated {total_changed} part(s) across {len(LIBRARIES)} librar(ies)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
