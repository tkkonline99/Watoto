"""Give every library item a `skills[]` taxonomy.

Why this exists
---------------
`docs/26-question-screen-system.md` gates a visual token on the skill it is
registered for: 🧊 is legal on a states-of-matter question and illegal on a
food-chain one. That gate needs something to match against, and no item in the
library had `skills[]` at all — so as the design shipped, every `token` visual
would have failed validation.

Two levels, coarse then fine:

    "skills": ["science", "science.matter"]

The **domain** is the topic segment already in every item id
(`s08.`**`science`**`.lesson.05`). It maps 1:1 onto `subject` — see the pairing
survey in VISUAL_SCHEMA.md — so it restates existing structure rather than
inventing a judgement.

The **fine skill** is classified from the item's title and objective. A title
that matches no rule yields the domain alone, which is the honest outcome: it
says "we know the subject, not the sub-skill" instead of guessing. That is the
same failure the whole design exists to stop, so this script must not commit it
either.

Rules are ordered and first-match-wins, so the specific ones sit above the
general ones. `Where Does Rain Come From?` is weather, not matter, even though
rain is water — which is why 'weather' is tested before 'made of'.

Idempotent: re-running makes no further change.

    python content/author_skills.py            # from the repo root
    python content/author_skills.py --check    # verify only, exit 1 on drift
    python content/author_skills.py --report   # print the resulting distribution
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter

from authoring import LIBRARIES

# Domains that are already one topic — 12 items each, a single coherent skill.
# They get the domain alone; splitting them further would be invention.
ATOMIC = {
    "cause", "lang", "motor", "object", "sensory", "animals", "body",
    "colors", "numbers", "music", "sorting", "counting", "emotions",
    "patterns", "phono", "vocab", "arts", "literacy", "semotional",
    "health", "tracing", "stories",
}

# `coding` and `tech` are the same material under different subject names —
# "Creativity & Coding", "Technology & Logic", "Logic & Coding" and
# "Digital Literacy & Coding" all author into one of the two domains — so they
# share a rule set rather than drifting apart.
COMPUTING: list[tuple[str, tuple[str, ...]]] = [
    ("variables", ("variable",)),
    ("debugging", ("debug", "bug", "fix a mistake", "took it literally")),
    ("loops", ("loop", "repeat")),
    ("logic", ("true or false", "condition", "decision", "puzzle",
               "if-else", "branch", "sort")),
    ("programs", ("python", "print(", "program", "run a")),
    ("algorithms", ("sequence", "step", "order", "instruction", "algorithm",
                    "command", "robot")),
    ("patterns", ("pattern", "comes next")),
    ("creative", ("pixel", "music", "note", "art", "draw", "picture")),
    ("digital-literacy", ("online", "website", "safe", "trust", "password",
                          "screen", "search", "source")),
    ("devices", ("tablet", "computer", "mouse", "keyboard", "device")),
]

# domain -> ordered (fine-skill, keywords). First match wins.
RULES: dict[str, list[tuple[str, tuple[str, ...]]]] = {
    "science": [
        ("life-cycles", ("life cycle", "egg to butterfly", "animal babies")),
        ("ecosystems", ("food chain", "food web", "habitat", "adaptation",
                        "lives in", "where do i live", "where it lives",
                        "a day in the pond", "chameleon")),
        ("earth-space", ("solar system", "planet", "moon", "sun, moon",
                         "day and night", "fossil", "erosion", "sky",
                         "shells on the mountain")),
        ("weather", ("weather", "season", "rain", "snow", "climate",
                     "puddle", "water cycle", "cloud")),
        ("energy", ("light", "shadow", "sound", "electric", "circuit",
                    "energy", "magnet")),
        ("forces", ("push", "pull", "force", "motion", "fast and slow",
                    "simple machine", "float", "sink", "snail and the cheetah")),
        ("matter", ("made of", "states of matter", "solid, liquid",
                    "changes of matter", "ice and water", "material")),
        ("plants", ("plant", "seed", "grow", "sprout")),
        ("animals", ("animal", "mammal, bird", "butterfly")),
        ("body", ("five senses", "parts of the body", "body and plants")),
        ("living-things", ("living", "non-living")),
        ("inquiry", ("think like a scientist", "fair test", "journal")),
    ],
    "math": [
        ("decimals", ("decimal", "tenths", "hundredths")),
        ("fractions", ("fraction", "sharing the pizza", "equivalent")),
        ("multiplication-division", ("multipl", "divis", "divide", "array",
                                     "times table", "skip count", "tiler")),
        ("place-value", ("tens and ones", "teen number", "place value",
                         "regroup", "round")),
        ("time", ("time to", "what time", "o'clock", "clock")),
        ("money", ("coin", "money", "market stall", "budget", "bake sale")),
        ("data", ("graph", "survey")),
        ("measurement", ("measure", "longer", "shorter", "area", "perimeter",
                         "cubes", "sort by size", "rug that did not fit")),
        ("shapes", ("shape", "2d and 3d")),
        ("patterns", ("pattern", "comes next")),
        ("arithmetic", ("add", "subtract", "take away", "plus", "number bond",
                        "sum", "five in the bed", "sharing ten mangoes")),
        ("comparison", ("more, less", "which is more", "bigger number",
                        "equal")),
        ("counting", ("count", "how many", "five stones", "ten-frame")),
    ],
    "reading": [
        ("sight-words", ("sight word",)),
        ("handwriting", ("write your letters", "form lowercase", "handwriting",
                         "by tracing")),
        ("phonics", ("blend", "digraph", "word family", "build the word",
                     "build a word", "vowel", "silent-e", "consonant",
                     "short and long", "long or short", "decodable",
                     "word i could not read", "word she guessed")),
        ("fluency", ("fluency", "read along")),
        ("vocabulary", ("compound", "prefix", "suffix", "context clue",
                        "word part", "idiom")),
        ("literary", ("simile", "metaphor", "character", "setting",
                      "story structure", "theme", "point of view",
                      "author", "two ways to tell")),
        ("text-features", ("text feature", "fact or opinion",
                           "advert", "beneath the words")),
        ("comprehension", ("main idea", "retell", "summar", "infer",
                           "read for meaning", "predict", "what was it about",
                           "read between", "who and what", "cause and effect",
                           "details")),
        ("mechanics", ("capital", "period", "end mark", "sentence")),
    ],
    "social": [
        ("government", ("rule", "law", "right", "responsibilit", "citizen",
                        "vote", "government", "branch", "leader", "flag",
                        "anthem", "who decides", "town meeting")),
        ("economics", ("goods", "services", "trade", "money", "saving",
                       "spending", "market", "producer", "consumer",
                       "needs", "wants", "need or want", "lemonade",
                       "economics", "where the bread comes from",
                       "salt road")),
        ("maps", ("map", "globe", "continent", "ocean", "direction",
                  "north", "landform", "latitude", "longitude",
                  "land and water", "where people live", "urban",
                  "longest journey")),
        ("history", ("long ago", "then and now", "then vs", "ancient",
                     "timeline", "history", "medieval", "empire")),
        ("culture", ("celebration", "people around the world")),
        ("citizenship", ("kind", "fair", "safety", "care for our earth",
                         "helping", "helps out", "being a good")),
        ("community", ("community", "helper", "neighbor", "neighbour",
                       "town", "who helps", "who teaches", "job",
                       "travel", "places in my", "trip to the market",
                       "who would you ask")),
        ("family", ("family", "families")),
    ],
    "writing": [
        ("mechanics", ("capital", "period", "end mark", "punctuat",
                       "apostrophe", "contraction", "comma", "quotation")),
        ("grammar", ("noun", "verb", "adjective", "plural", "tense",
                     "sentence")),
        # Before `transitions`: the combined quizzes name both, and essay
        # shape is the larger of the two skills they exercise.
        ("composition", ("paragraph", "essay", "narrative", "informative",
                         "persuasive", "argument", "speech",
                         "kinds of writing", "edit", "revise", "draft",
                         "letter", "story")),
        ("transitions", ("transition", "linking word")),
    ],
    "coding": COMPUTING,
    "tech": COMPUTING,
}

DOMAIN_RE = re.compile(r"^s\d\d\.([a-z0-9]+)\.")


def domain_of(item: dict) -> str | None:
    m = DOMAIN_RE.match(item.get("id", ""))
    return m.group(1) if m else None


def skills_for(item: dict) -> list[str]:
    """The skills[] an item should carry, coarse first."""
    domain = domain_of(item)
    if domain is None:
        return []
    if domain in ATOMIC:
        return [domain]
    haystack = f"{item.get('title', '')} {item.get('objective', '')}".lower()
    for fine, keywords in RULES.get(domain, ()):
        if any(k in haystack for k in keywords):
            return [domain, f"{domain}.{fine}"]
    return [domain]


def with_skills(item: dict, skills: list[str]) -> dict:
    """Rebuild [item] with `skills` sitting just after `type`.

    Rebuilt rather than assigned so the field lands in a readable place in the
    diff instead of at the end of a 40-key object.
    """
    out: dict = {}
    for key, value in item.items():
        if key == "skills":
            continue
        out[key] = value
        if key == "type":
            out["skills"] = skills
    if "skills" not in out:  # no `type` key — degrade rather than drop it
        out["skills"] = skills
    return out


def apply(lib: dict) -> tuple[dict, int]:
    changed = 0
    items = lib["content"]
    for i, item in enumerate(items):
        skills = skills_for(item)
        if item.get("skills") == skills:
            continue
        items[i] = with_skills(item, skills)
        changed += 1
    return lib, changed


def report(lib: dict) -> None:
    counts = Counter()
    coarse_only = []
    for item in lib["content"]:
        skills = item.get("skills") or []
        counts[skills[-1] if skills else "(none)"] += 1
        if len(skills) < 2:
            coarse_only.append(item["id"])
    print(f"{len(lib['content'])} items, {len(counts)} distinct leaf skills\n")
    for skill, n in sorted(counts.items()):
        print(f"{n:5}  {skill}")
    atomic_ids = {i["id"] for i in lib["content"]
                  if domain_of(i) in ATOMIC}
    unclassified = [i for i in coarse_only if i not in atomic_ids]
    print(f"\n{len(coarse_only)} items carry a domain only "
          f"({len(atomic_ids)} of them by design — single-topic domains).")
    if unclassified:
        print(f"{len(unclassified)} unclassified in a domain that has rules:")
        for cid in unclassified:
            print(f"    {cid}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true",
                    help="verify only; exit 1 if the library would change")
    ap.add_argument("--report", action="store_true",
                    help="print the resulting skill distribution")
    args = ap.parse_args()

    total_changed = 0
    for path in LIBRARIES:
        lib = json.loads(path.read_text(encoding="utf-8"))
        lib, changed = apply(lib)
        total_changed += changed
        if args.report and path is LIBRARIES[0]:
            report(lib)
        if changed and not args.check:
            path.write_text(json.dumps(lib, indent=2, ensure_ascii=False) + "\n",
                            encoding="utf-8")

    if args.check:
        if total_changed:
            print(f"drift: {total_changed} item(s) would change", file=sys.stderr)
            return 1
        print("skills up to date")
        return 0

    print(f"updated {total_changed} item(s) across {len(LIBRARIES)} librar(ies)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
