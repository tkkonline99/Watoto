"""Build `content/visual_tokens.json` — the vocabulary of legal glyphs.

Why this exists
---------------
`docs/26-question-screen-system.md` §26.3 allows a `token` visual only when the
concept is "a single nameable object", and only when the glyph is registered
against the item's skill. This builds that registry.

Where the glyphs come from
--------------------------
`apps/mobile/lib/features/library/content_lexicon.dart`. Two reasons, both
practical: it is already a reviewed word→glyph vocabulary drawn from an
analysis of the whole library, and — more importantly — it is the set of glyphs
the app is known to render. A registry invented here could name a glyph that
renders as tofu on a Windows build, which is exactly the class of bug the flag
emoji hit on the language screen.

The Dart map is parsed rather than duplicated, so the two cannot drift. The
parse asserts a floor on the entry count: a format change that quietly matched
nothing would otherwise empty the registry and silently disable the gate.

What `for` means, and what the gate can actually catch
------------------------------------------------------
A token's `for` array is the set of skills in whose items that word actually
appears in authored text. So the registry states: *this glyph has legitimately
illustrated these kinds of question.*

That catches the fault docs/26 describes. A tin of food never appears in the
text of a states-of-matter item, so 🥫 is not registered for `science.matter`
and lands as an error. It does **not** catch a glyph used on an item where its
word appears only in passing — the tighter net for that is `author_visuals.py`,
which assigns a token only when the word appears in the rendered part's *own*
narration, not merely somewhere in the item.

Two categories are excluded from tokens on the spec's own terms:

  * `concept` — "letter", "clap", "sound". These are marked `choice: false` in
    the lexicon precisely because they are not nameable objects. §26.3 says a
    token is for a single nameable object, so they are not eligible.
  * `digit` — a numeral is a quantity, and §26.3 says to prefer a scene
    whenever the question is about quantity. Digits route to `counting.array`
    and friends in author_visuals.py instead.

Idempotent: re-running produces the same file.

    python content/build_visual_tokens.py            # from the repo root
    python content/build_visual_tokens.py --check    # verify only, exit 1 on drift
    python content/build_visual_tokens.py --report   # show the broadest tokens
"""
from __future__ import annotations

import argparse
import json
import re
import sys

from authoring import LIBRARIES, ROOT

LEXICON_DART = ROOT / "apps/mobile/lib/features/library/content_lexicon.dart"
OUT = ROOT / "content/visual_tokens.json"

# A parse that matched fewer than this many entries means the Dart format moved
# and the regex is now lying. Fail loudly rather than emit a hollow registry.
MIN_LEXICON_ENTRIES = 300

# Categories that cannot be tokens — see the module docstring.
EXCLUDED_CATEGORIES = {"concept", "digit"}

_ENTRY_RE = re.compile(
    r"'(?P<word>[a-z][a-z' -]*)':\s*LexEntry\(\s*'(?P<glyph>[^']+)'\s*,"
    r"\s*_(?P<category>\w+)"
)


def load_lexicon() -> dict[str, tuple[str, str]]:
    """word -> (glyph, category), parsed from the Dart source."""
    src = LEXICON_DART.read_text(encoding="utf-8")
    m = re.search(r"const Map<String, LexEntry> lexicon = \{(.*?)\n\};", src, re.S)
    if not m:
        sys.exit(f"could not find the lexicon map in {LEXICON_DART}")
    out: dict[str, tuple[str, str]] = {}
    for hit in _ENTRY_RE.finditer(m.group(1)):
        out[hit["word"]] = (hit["glyph"], hit["category"])
    if len(out) < MIN_LEXICON_ENTRIES:
        sys.exit(
            f"parsed only {len(out)} lexicon entries from {LEXICON_DART.name} "
            f"(expected >= {MIN_LEXICON_ENTRIES}); the Dart format has moved "
            f"and this regex needs updating"
        )
    return out


def item_text(item: dict) -> str:
    """Every authored English string in an item, lowercased."""
    parts: list[str] = [item.get("title", ""), item.get("objective", "")]
    for step in item.get("steps", []):
        parts += [step.get("narration", ""), step.get("prompt") or "",
                  step.get("feedback", "")]
        parts += [str(c) for c in step.get("choices", [])]
    for q in item.get("questions", []):
        parts += [q.get("prompt", ""), q.get("correctFeedback", ""),
                  q.get("retryFeedback", "")]
        parts += [o.get("label", "") for o in q.get("options", [])]
    for page in item.get("pages", []):
        parts.append(page.get("narration", ""))
    return " ".join(parts).lower()


def word_in(text: str, word: str) -> bool:
    """Whole-word match, so 'ant' does not fire inside 'want'."""
    return re.search(rf"(?<![a-z]){re.escape(word)}(?![a-z])", text) is not None


def build(lexicon: dict[str, tuple[str, str]], items: list[dict]) -> dict:
    texts = [(item_text(i), i.get("skills") or []) for i in items]
    tokens: dict[str, dict] = {}
    for word, (glyph, category) in sorted(lexicon.items()):
        if category in EXCLUDED_CATEGORIES:
            continue
        skills: set[str] = set()
        for text, item_skills in texts:
            if word_in(text, word):
                skills.update(item_skills)
        if not skills:
            continue  # never used in authored text; not a legal token anywhere
        tokens[word.replace(" ", ".").replace("'", "")] = {
            "glyph": glyph,
            "category": category,
            "for": sorted(skills),
        }
    return {
        "_meta": {
            "version": "1.0",
            "note": (
                "Vetted glyphs. A token is legal only for the skills listed in "
                "its 'for' array. Generated by content/build_visual_tokens.py "
                "from content_lexicon.dart; do not hand-edit."
            ),
            "tokens": len(tokens),
        },
        "tokens": tokens,
    }


def report(registry: dict) -> None:
    tokens = registry["tokens"]
    widths = sorted(((len(t["for"]), name) for name, t in tokens.items()),
                    reverse=True)
    print(f"{len(tokens)} tokens\n")
    print("broadest 'for' lists — the ones worth a human eye:")
    for n, name in widths[:15]:
        print(f"  {n:3} skills  {name}")
    narrow = [name for n, name in widths if n == 1]
    print(f"\n{len(narrow)} tokens are legal for exactly one skill "
          f"(the tightest gate).")
    from collections import Counter
    cats = Counter(t["category"] for t in tokens.values())
    print("\nby category:")
    for cat, n in sorted(cats.items()):
        print(f"  {n:4}  {cat}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true",
                    help="verify only; exit 1 if the registry would change")
    ap.add_argument("--report", action="store_true")
    args = ap.parse_args()

    lexicon = load_lexicon()
    lib = json.loads(LIBRARIES[0].read_text(encoding="utf-8"))
    registry = build(lexicon, lib["content"])
    rendered = json.dumps(registry, indent=2, ensure_ascii=False) + "\n"

    if args.report:
        report(registry)

    current = OUT.read_text(encoding="utf-8") if OUT.exists() else None
    if args.check:
        if current != rendered:
            print("drift: visual_tokens.json is out of date", file=sys.stderr)
            return 1
        print("visual_tokens.json up to date")
        return 0

    if current != rendered:
        OUT.write_text(rendered, encoding="utf-8")
        print(f"wrote {OUT.relative_to(ROOT)} ({len(registry['tokens'])} tokens)")
    else:
        print("visual_tokens.json unchanged")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
