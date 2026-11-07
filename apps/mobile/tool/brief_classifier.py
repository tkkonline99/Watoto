"""Decide what a picture should show, from the brief that describes it.

The classifier this replaces was a cascade of `if "star" in text`. Substring
matching on English prose is a trap, and it had fallen into most of it:

    "start at the bigger number"      -> star   (night sky)
    "Is an apple a fruit or a grain?" -> rain   (rain cloud)
    "anything that reveals it"        -> hat    (a red hat)
    "Flat pastel cartoon, 512x512"    -> car    (a car; documented in
                                                 generate_art_batch.scene_of)

`that` and `what` contain `hat`, which is the expensive one: they are two of
the commonest words in English, so a great many briefs drew a hat. The old
code also matched against the *filename* as well as the brief, so
`step_reading_lesson_03_7` contributed "read" and drew a book whatever the
brief said.

Three changes fix the category rather than the instances:

1. **Words, not substrings.** The brief is tokenized and terms match whole
   words (with naive plural folding, so "bubbles" matches "bubble"). A term
   that genuinely wants a prefix says so: `phon*` covers phonics and phoneme.
2. **Scored, not first-wins.** Every motif scores against the brief and the
   best one wins, so a brief that says "tree" twice and "bird" once draws the
   tree. The old cascade returned whichever rule happened to be written first.
3. **It can say no.** Below a confidence floor, or when two motifs tie, the
   answer is `None` and the caller leaves the slot undrawn.

Point 3 is the reason this exists. A wrong picture is worse than no picture:
the striped placeholder says "not drawn yet" and prints a true description of
the part, while a rain cloud over "is an apple a fruit or a grain?" tells a
child looking for a clue something false. Abstaining is a correct answer, and
the old classifier had no way to give it.

Self-test:  python tool/test_brief_classifier.py
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field

WORD_RE = re.compile(r"[a-z0-9]+")

# Words that carry no picture and would otherwise pull weight around.
STOP = frozenset("""
a an the and or but if then than that this these those it its is are was were
be been being to of in on at by for with from as into over under up down out
off again more most some any each every all both few other own same so no not
you your yours we our us they them their he she his her i me my mine one two
do does did doing done have has had having will would can could shall should
may might must here there when where why how what which who whom whose
""".split())


def words(text: str) -> list[str]:
    """The brief's words, lowercased, with stopwords dropped."""
    return [w for w in WORD_RE.findall((text or "").lower()) if w not in STOP]


def _fold(word: str) -> set[str]:
    """A word and its naive singular, so "bubbles" can match "bubble"."""
    forms = {word}
    if len(word) > 3:
        if word.endswith("ies"):
            forms.add(word[:-3] + "y")
        if word.endswith("es"):
            forms.add(word[:-2])
        if word.endswith("s"):
            forms.add(word[:-1])
    return forms


@dataclass(frozen=True)
class Motif:
    """One thing the renderer knows how to draw."""

    key: str
    terms: tuple[str, ...]
    # What kind of thing this is. Two close scores mean something quite
    # different depending on this: "the bird and the fish" names two creatures
    # and drawing either is a coin toss, while "rain falls on the roof" names
    # weather and a building, which are not competing to be the subject — the
    # stronger one simply is it. Comparing scores alone cannot tell those
    # apart, because both look like a near-tie.
    category: str = "object"
    # Terms that veto this motif however well it otherwise scored.
    blocks: tuple[str, ...] = ()
    # Multiplier for motifs specific enough to trust on a single word
    # ("bubble"), against ones that are not ("shape").
    weight: float = 1.0
    notes: str = ""


# ---------------------------------------------------------------- the motifs
#
# Ordered for reading only; scoring makes order irrelevant. Terms are words an
# author actually writes in a brief, not a thesaurus: a term that never
# appears costs nothing, and a term that appears in the wrong context costs a
# wrong picture.

MOTIFS: tuple[Motif, ...] = (
    Motif("body", ("head", "shoulder", "knee", "toe", "whole body",
                   "head shoulders", "tummy", "elbow", "ankle", "stretch*",
                   "nose", "ear*", "eye*", "foot", "feet", "jump", "stomp*",
                   "hop", "waddle"),
          category="body", weight=1.35, notes="head, shoulders, knees and toes"),
    Motif("hands", ("clap", "hand", "wave", "waving", "palm", "finger",
                    "high five", "fist"),
          category="body", weight=1.25),
    Motif("music", ("music", "song", "sing", "rhythm", "melody", "tune",
                    "drum", "maraca", "shaker", "rattle", "boom", "lullaby",
                    "instrument*", "loud*", "whisper"),
          category="abstract", weight=1.25),
    Motif("face", ("face", "smile", "smiling", "baby", "caregiver", "mama",
                   "dada", "ma ma", "da da", "ba ba", "babble", "grown up",
                   "person", "people", "family", "hug", "kiss", "yawn",
                   "sneeze", "peekaboo", "mouth", "cheek", "chin"),
          category="body", weight=1.15),
    Motif("bear", ("bear", "teddy"), category="creature", weight=1.5),
    Motif("bunny", ("bunny", "rabbit", "hare"), category="creature", weight=1.5),
    Motif("bird", ("bird", "hen", "chick", "duck", "duckling", "owl", "nest",
                   "wing", "feather", "quack", "chirp", "tweet"),
          category="creature", weight=1.4),
    Motif("fish", ("fish", "fin", "gill"), category="creature", weight=1.5),
    Motif("animal", ("animal", "cow", "moo", "cat", "kitten", "meow", "dog",
                     "puppy", "woof", "bark", "lion", "roar", "elephant",
                     "giraffe", "koala", "farm", "goat", "sheep", "baa",
                     "horse", "monkey", "zebra", "turtle", "tortoise", "pig"),
          category="creature", weight=1.25),
    Motif("night", ("star", "twinkle", "night", "moonlight", "constellation",
                    "dark sky", "night sky", "planet", "solar system", "orbit"),
          # "night sky" / "dark sky" is the motif; a lone "sky" is daytime more
          # often than not, so it belongs to `cloud` instead.
          category="sky", weight=1.3),
    Motif("sun", ("sun", "sunrise", "sunset", "daylight", "sunshine", "sunny"),
          category="sky", weight=1.3),
    Motif("moon", ("moon", "crescent"), category="sky", weight=1.4),
    Motif("rain", ("rain", "raindrop", "storm", "puddle", "umbrella",
                   "thunder", "lightning"),
          category="sky", weight=1.3, notes="the grain/rain collision lived here"),
    Motif("cloud", ("cloud", "sky", "weather"), category="sky", weight=1.0),
    Motif("tree", ("tree", "leaf", "forest", "branch", "trunk", "wood"),
          category="nature", weight=1.3),
    Motif("flower", ("flower", "garden", "petal", "bloom", "rose", "daisy"),
          category="nature", weight=1.3),
    Motif("bubble", ("bubble", "foam", "soap"), weight=1.5),
    Motif("ball", ("ball", "balloon", "bounce", "roll the ball"), weight=1.3),
    Motif("bell", ("bell", "chime", "ringing"), weight=1.25),
    Motif("cup", ("cup", "mug", "spoon", "fork", "bowl", "pot", "pan"),
          weight=1.3),
    Motif("hat", ("hat", "cap", "helmet", "coat", "jacket", "shirt", "pajama"),
          weight=1.4, notes="the that/what collision lived here"),
    Motif("door", ("door", "gate", "doorway", "knock", "window", "key", "lock"),
          weight=1.3),
    Motif("box", ("box", "crate", "parcel", "bin", "bucket",
                  "pocket", "bag", "container"),
          weight=1.2),
    Motif("vehicle", ("car", "train", "bus", "truck", "bicycle", "wheel",
                      "boat", "ship", "airplane", "plane", "tractor", "road",
                      "tunnel"),
          weight=1.3),
    Motif("house", ("house", "home", "coop", "roof", "hut", "room", "kitchen",
                    "bedroom"),
          weight=1.2),
    Motif("book", ("book", "letter", "word", "read", "story", "page",
                   "phon*", "rhyme", "syllable", "spell", "alphabet",
                   "going to z"),
          weight=1.0),
    Motif("apple", ("apple", "fruit", "banana", "mango", "orange", "berry",
                    "carrot", "corn", "tomato"),
          weight=1.3),
    Motif("cloth", ("cloth", "blanket", "towel", "fabric", "pillow", "bed",
                    "quilt", "mat"),
          weight=1.3),
    Motif("shoe", ("shoe", "boot", "sandal", "sock", "lace"), weight=1.3),
    Motif("lamp", ("lamp", "light", "glow", "torch", "candle", "flashlight",
                   "lantern", "dim"),
          weight=1.15),
    Motif("colors", ("color", "colour", "swirl", "gradient", "spiral",
                     "rainbow"),
          category="abstract", weight=1.1),
    Motif("water", ("water", "bath", "splash", "pond", "river", "lake",
                    "wash", "sea", "ocean", "stream", "wave in the sea",
                    "drop", "droplet"),
          category="nature", weight=1.2),
    Motif("heart", ("heart", "love", "kindness", "caring"),
          category="abstract", weight=1.0),
    Motif("map", ("map", "world", "earth", "globe", "country", "continent",
                  "atlas"),
          category="abstract", weight=1.25),
    Motif("shapes", ("shape", "circle", "square", "triangle", "pattern",
                     "rectangle", "oval", "diamond", "hexagon", "cube",
                     "odd one out", "comes next"),
          category="abstract", weight=1.05),
    Motif("number", ("number", "count", "how many", "add", "plus", "minus",
                     "subtract", "sum", "total", "digit", "three", "four",
                     "five", "six", "seven", "eight", "nine", "ten",
                     "just one", "side with many"),
          category="abstract", weight=1.05),
    Motif("robot", ("robot", "code", "coding", "program*", "python",
                    "algorithm*", "loop*", "repeat", "sequence",
                    "variable*", "function*", "debug*", "bug", "if else",
                    "scratch", "instruction*", "step in order",
                    "steps in order"),
          category="tech", weight=1.2),
    Motif("tablet", ("tablet", "device", "screen", "button", "online",
                     "password*", "internet", "digital", "message", "photo",
                     "camera", "app", "swipe", "shake", "quiet button"),
          category="tech", weight=1.18),
    Motif("circuit", ("circuit*", "electric*", "battery", "bulb", "wire",
                      "switch", "energy", "shadow"),
          category="science", weight=1.25),
    Motif("magnet", ("magnet*", "attract*", "repel*", "pole", "iron", "metal",
                     "force", "push", "pull", "lever", "pulley", "ramp",
                     "wheel and axle", "simple machine*", "gravity",
                     "friction"),
          category="science", weight=1.25),
    Motif("butterfly", ("butterfly", "caterpillar", "chrysalis", "cocoon",
                        "metamorphosis", "life cycle", "lifecycle", "frog",
                        "tadpole", "insect", "bee", "hive", "pollinat*",
                        "honey"),
          category="creature", weight=1.45),
    Motif("plant", ("plant*", "seed*", "sprout*", "root*", "stem", "soil",
                    "bush", "grass", "desert", "cactus", "camel",
                    "habitat*", "ecosystem*", "food chain", "living thing*",
                    "photosynthesis"),
          category="nature", weight=1.25),
    Motif("weather", ("season*", "summer", "winter", "autumn",
                      "spring", "wind", "windy", "breeze", "snow*", "cold",
                      "hot", "warm", "freeze", "freezer", "ice", "melt*",
                      "solid", "liquid", "gas", "matter", "evaporat*",
                      "condens*", "steam", "boil*"),
          category="weather_state", weight=1.2),
    Motif("science", ("scien*", "experiment*", "hypothes*", "observ*",
                      "predict*", "microscope", "magnifying",
                      "fossil*", "volcano*", "rock", "stone", "sink or float",
                      "float or sink", "sink", "heavy", "lightweight"),
          category="science", weight=1.18),
    Motif("community", ("citizen*", "law*", "govern*", "vote",
                        "ballot", "fair*", "responsibil*",
                        "respect", "community", "helper*", "firefighter",
                        "teacher", "doctor", "hospital", "school", "town",
                        "police", "farmer", "leader*", "mayor",
                        "rights and", "rule is for"),
          category="social", weight=1.2),
    Motif("market", ("goods", "service*", "money", "coin*",
                     "buy", "sell", "save", "saving", "spend*", "price",
                     "cost", "shop*", "market", "producer*", "consumer*",
                     "trade", "job*", "needs and wants", "need or a want"),
          category="social", weight=1.2),
    Motif("history", ("history", "timeline*", "ancient", "egypt", "mali",
                      "empire", "long ago", "then and now",
                      "chronolog*", "artifact*", "tradition*",
                      "celebrat*", "culture*", "hieroglyph*", "quill",
                      "ancestor*"),
          category="social", weight=1.25),
    Motif("compass", ("north", "south", "east", "west", "direction*",
                      "compass", "latitude", "longitude", "equator",
                      "hemisphere", "island", "peninsula", "mountain",
                      "valley", "plain", "landform*"),
          category="social", weight=1.25),
    Motif("writing", ("write", "writing", "pen", "pencil", "crayon",
                      "paragraph*", "essay*", "opinion", "persuad*",
                      "inform", "entertain", "purpose", "revis*", "edit*",
                      "draft", "quotation*", "comma*", "apostrophe",
                      "contraction*", "capital*", "plural*", "verb*", "noun*",
                      "adjective*", "tense*", "transition*", "first next",
                      "question mark", "full stop", "period", "statement",
                      "punctuation", "grammar", "trace", "tracing", "zigzag*",
                      "dot", "straight line", "wiggly line", "curved line"),
          category="literacy", weight=1.18),
    Motif("reading", ("main idea", "summar*", "detail*", "infer*", "theme",
                      "retell*", "character*", "setting", "plot", "beginning",
                      "middle", "ending", "passage", "author*", "fact",
                      "prefix*", "suffix*", "compound", "vowel*",
                      "consonant*", "digraph*", "blend*", "sight word*",
                      "starts with", "b i g", "c a t", "h o t", "m a p"),
          category="literacy", weight=1.18),
    Motif("math", ("compare", "fewer", "equal", "sort*", "order*", "size",
                   "taller", "shorter", "longer", "bigger", "smaller",
                   "big and small", "tall and short", "measure*",
                   "length", "area", "perimeter", "fraction*", "half",
                   "quarter", "third", "decimal*", "tenth*", "hundredth*",
                   "multiply", "divide", "take away", "bond*", "pair*",
                   "number line", "rounding", "place value"),
          category="math", weight=1.15),
    Motif("clock", ("clock", "hour*", "minute*", "o clock",
                    "schedule", "morning", "bedtime", "routine*",
                    "goodnight"),
          category="math", weight=1.25),
    Motif("chart", ("graph", "bar graph", "chart", "data", "tally", "survey",
                    "most votes", "shortest bar", "table"),
          category="math", weight=1.28),
    Motif("palette", ("art*", "paint*", "brush", "mix*", "red", "blue",
                      "yellow", "green", "purple", "pink", "black", "white",
                      "bright*", "stripe*", "spot*", "fuzzy", "bumpy",
                      "smooth", "soft", "rough", "texture*", "crinkle",
                      "patch", "pretend"),
          category="arts", weight=1.15),
    Motif("emotion", ("feel*", "feeling*", "emotion*", "happy", "sad",
                      "angry", "cross", "worried", "scared", "scary",
                      "excited", "calm", "breath*", "share", "sharing",
                      "friend*", "please", "thank", "sorry", "proud",
                      "birthday", "turn taking", "take turns"),
          category="emotion", weight=1.18),
    Motif("health", ("health*", "food*", "snack*", "plate", "bread", "milk",
                     "vegetable*", "grain*", "eat*", "hygiene", "clean",
                     "dirt", "germ*", "tooth", "teeth", "sleep", "rest",
                     "exercise"),
          category="health", weight=1.15),
)

# A motif must clear this to be drawn at all. One ordinary term hitting once
# scores its weight, so the floor sits just under the weakest single-term
# motif: a lone confident word ("bubble", 1.5) is enough, a lone vague one
# scored below 1.0 is not.
MIN_SCORE = 1.0

# How far ahead the winner must be *of a rival of its own kind*. Two creatures
# within 15% of each other means the brief names two animals and picking one is
# a coin toss. Against a rival of a different kind there is no such contest:
# "rain falls on the roof" scores rain 1.3 and house 1.2, and rain is the
# subject — weather and a building are not competing to be the picture.
MIN_RATIO = 1.15


@dataclass
class Verdict:
    """What the classifier decided, and how sure it was."""

    motif: str | None
    score: float = 0.0
    margin: float = 0.0
    runner_up: str | None = None
    matched: tuple[str, ...] = field(default_factory=tuple)

    @property
    def confident(self) -> bool:
        return self.motif is not None


# What each repeat of a term adds, relative to the first. Saying a word twice
# is a real signal about what the picture is of — "the fish swims, another fish
# joins it, and one bird watching" is a picture of fish — but a brief is a
# sentence or two, so repetition has to count for less than a fresh term or a
# single chatty noun would run away with it.
REPEAT_BONUS = 0.5


def _score(motif: Motif, counts: dict[str, int], joined: str) -> tuple[float, list[str]]:
    total = 0.0
    hits: list[str] = []

    def add(term: str, n: int, multiplier: float = 1.0) -> None:
        nonlocal total
        total += motif.weight * multiplier * (1 + REPEAT_BONUS * (n - 1))
        hits.append(term)

    for term in motif.terms:
        if term.endswith("*"):
            stem = term[:-1]
            n = sum(c for f, c in counts.items() if f.startswith(stem))
            if n:
                add(term, n)
        elif " " in term:
            n = joined.count(f" {term} ")
            if n:
                # A phrase is worth more than a word: far less likely to be a
                # coincidence.
                add(term, n, multiplier=1.6)
        elif counts.get(term):
            add(term, counts[term])
    return total, hits


def classify(brief: str, subject: str = "") -> Verdict:
    """Which motif the brief asks for, or an abstention.

    [subject] is the item's subject line. It is deliberately *not* mixed into
    the brief text — mixing in the filename is how the old classifier drew a
    book for every reading lesson — but it may break a tie, which is all it is
    trusted for.
    """
    ws = words(brief)
    if not ws:
        return Verdict(None)
    # Counted, not just seen: how often a word appears is most of what tells
    # the subject of the brief from its scenery.
    counts: dict[str, int] = {}
    for w in ws:
        for form in _fold(w):
            counts[form] = counts.get(form, 0) + 1
    # Phrase terms may contain stopwords ("how many", "starts with", "then and
    # now"), so match them against the full tokenized brief with word boundary
    # spaces on each side.
    raw_words = WORD_RE.findall((brief or "").lower())
    joined = f" {' '.join(raw_words)} "

    scored: list[tuple[float, Motif, list[str]]] = []
    for motif in MOTIFS:
        if any(counts.get(b) for b in motif.blocks):
            continue
        total, hits = _score(motif, counts, joined)
        if total > 0:
            scored.append((total, motif, hits))

    if not scored:
        return Verdict(None)

    scored.sort(key=lambda row: (-row[0], row[1].key))
    best_score, best, hits = scored[0]

    # The only rival that can force an abstention is one of the same kind.
    rival = next(
        ((s, m) for s, m in ((s, m) for s, m, _ in scored[1:])
         if m.category == best.category),
        None,
    )
    runner_up = scored[1][1].key if len(scored) > 1 else None
    margin = best_score - (rival[0] if rival else 0.0)

    if best_score < MIN_SCORE:
        return Verdict(None, best_score, margin, runner_up, tuple(hits))

    if rival is not None and best_score < rival[0] * MIN_RATIO:
        # Two of a kind, too close to call. The subject line is the one extra
        # signal worth consulting, and only here: a Mathematics item naming a
        # maths motif is a real tiebreak, whereas mixing the subject into the
        # brief text is how the old classifier came to draw a book for every
        # reading lesson.
        subject_words = set(words(subject)) if subject else set()
        broken = None
        if subject_words:
            for s_i, m_i, h_i in scored:
                if m_i.category == best.category and subject_words & set(m_i.terms):
                    broken = (s_i, m_i, h_i)
                    break
        if broken is None:
            return Verdict(None, best_score, margin, runner_up, tuple(hits))
        best_score, best, hits = broken

    return Verdict(best.key, best_score, margin, runner_up, tuple(hits))


def classify_key(brief: str, subject: str = "") -> str | None:
    """Just the motif, for callers that do not care how close it was."""
    return classify(brief, subject).motif
