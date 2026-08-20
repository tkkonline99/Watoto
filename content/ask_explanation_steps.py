"""Give the why/what/where/which steps options that answer what they ask.

Why this exists
---------------
`choicePlanFor` answers "which of these things is it" by staging a lexicon
noun and its look-alikes. A directive asking for a reason, a place or a
consequence has no such answer, so the scan reached into the question and
staged a word out of it:

  * "Tap what lifts the water and drives the whole cycle" offered
    autumn / rain / **water** and scored `water`. The feedback reads "The sun."
  * "Tap where the big hand goes" offered eye / ear / **hand** — body parts —
    for a question whose answer is "on the 4".
  * "Tap the person who helps when you feel scared" offered scared /
    frustrated / angry: three emotions, where the question asks for a person.

A sweep of both planner paths over all 684 items found 45 such steps. The
planner now refuses them (see `_asksForExplanation` in content_lexicon.dart),
which dropped 43 of them to a plain tap with no comprehension check. This
script gives those 43 the options they should always have had.

Every answer is taken from the step's own `feedback`. Distractors are the
misconception the step exists to correct, or a claim an earlier step in the
same lesson makes — never invented noise.

**The Swahili and French are mine and have not been reviewed by a native
speaker**, in common with the rest of the app's non-English copy.

English by design
-----------------
Three steps teach English itself — identifying a verb, and which English
words take a capital. Translating their options destroys the exercise:
`sings` is only the verb in "The bird sings" in English, and `Tanzania`
versus `town` is a question about English orthography. Those options stay
English and their keys are registered in `content/i18n/english_by_design.json`
so `check_i18n.py` counts them as done rather than as a translation backlog.
That file's own readme is right that this is a workaround rather than a
curriculum answer; see docs/CONTENT_WORKLIST.md.

Answers sit off slot 0 wherever the choice allows; step_coverage_test caps
any one slot at 70% of all comprehension checks.

Idempotent: re-running makes no further change.

    python content/ask_explanation_steps.py            # from the repo root
    python content/ask_explanation_steps.py --check    # verify, exit 1 on drift
"""
from __future__ import annotations

import argparse
import json
import sys

from authoring import I18N_DIRS, LANGS, LIBRARIES, ROOT

# Longest an option may be before it stops being tappable on a phone.
# step_coverage_test.dart enforces the same bound.
MAX_OPTION = 22

# Only the content/ copy carries this register; it is a authoring-side record,
# not something the app bundles.
ENGLISH_BY_DESIGN = ROOT / "content/i18n/english_by_design.json"

# An option in all three languages, in LANGS order (en, sw, fr).
Option = tuple[str, str, str]


def en_only(*words: str) -> list[tuple[str, None, None]]:
    """Options whose English *is* the thing being taught."""
    return [(w, None, None) for w in words]


# The comma-placement steps ask the same question about two different
# sentences, so they share one set of positions.
COMMA_PLACE: list[Option] = [
    ("After the name", "Baada ya jina", "Après le nom"),
    ("Inside the quotes", "Ndani ya alama za nukuu", "Dans les guillemets"),
    ("At the very end", "Mwishoni kabisa", "Tout à la fin"),
]

# item id -> step index -> (options, answer index, english-by-design reason)
#
# The answer is stated in each step's feedback; it is quoted in the comment so
# a reviewer can check the pairing without opening the library.
STAGED: dict[str, dict[int, tuple[list, int, str | None]]] = {
    # "Someone always comes. You are not alone."
    "s03.emotions.lesson.02": {
        2: ([
            ("Nobody", "Hakuna mtu", "Personne"),
            ("A grown-up you trust", "Mtu mzima unayemwamini",
             "Un adulte de confiance"),
        ], 1, None),
    },
    # "'sings'. That is the verb." The three words of the sentence.
    "s07.writing.lesson.01": {
        6: (en_only("bird", "sings", "the"), 1,
            "English parts of speech: identifying the verb"),
    },
    # "What to do when the answer is no. Without it, nothing happens."
    "s08.tech.lesson.03": {
        5: ([
            ("It repeats the rule", "Hurudia sheria", "Elle répète la règle"),
            ("What happens if no", "Kinachotokea ikiwa hapana",
             "Ce qui se passe si non"),
            ("It stops everything", "Husimamisha yote", "Elle arrête tout"),
        ], 1, None),
    },
    # "On the 4. Twenty minutes is four jumps of five."
    "s08.math.lesson.06": {
        6: ([
            ("On the 20", "Kwenye 20", "Sur le 20"),
            ("On the 4", "Kwenye 4", "Sur le 4"),
            ("On the 3", "Kwenye 3", "Sur le 3"),
        ], 1, None),
    },
    # "It would overheat. The fur that saves it in one place kills it in
    # another." The distractor is the same fur read as always helpful.
    "s08.science.lesson.02": {
        5: ([
            ("It would grow more fur", "Ingeota manyoya zaidi",
             "Il aurait plus de poils"),
            ("It would overheat", "Ingepata joto kupita kiasi",
             "Il aurait trop chaud"),
            ("It would feel colder", "Ingehisi baridi zaidi",
             "Il aurait plus froid"),
        ], 1, None),
    },
    "s08.science.lesson.03": {
        # "Grass, by far. Each level needs a much bigger level under it."
        3: ([
            ("Rabbits", "Sungura", "Les lapins"),
            ("Grass plants", "Mimea ya nyasi", "Les brins d'herbe"),
        ], 1, None),
        # "It grows thick and wild. Chains work downwards as well as up."
        6: ([
            ("It dies back", "Hunyauka", "Elle dépérit"),
            ("It grows thick", "Hukua kwa wingi", "Elle pousse dru"),
            ("Nothing changes", "Hakuna mabadiliko", "Rien ne change"),
        ], 1, None),
    },
    # "Heat, twice. Solid to liquid, then liquid to gas."
    "s08.science.lesson.04": {
        6: ([
            ("Cold", "Baridi", "Du froid"),
            ("Heat", "Joto", "De la chaleur"),
            ("More ice", "Barafu zaidi", "Plus de glace"),
        ], 1, None),
    },
    "s08.science.lesson.05": {
        # "The sun. Without it water would never rise at all."
        4: ([
            ("The wind", "Upepo", "Le vent"),
            ("The sun", "Jua", "Le soleil"),
            ("The rain", "Mvua", "La pluie"),
        ], 1, None),
        # "Water that has cooled back into tiny drops. Not steam, and not
        # smoke." Both distractors are the two the feedback rules out.
        5: ([
            ("Steam", "Mvuke", "De la vapeur"),
            ("Tiny water drops", "Matone madogo ya maji",
             "De fines gouttes d'eau"),
            ("Smoke", "Moshi", "De la fumée"),
        ], 1, None),
    },
    # "It does. Magnetism passes through things that are not magnetic."
    "s08.science.lesson.06": {
        5: ([
            ("Yes, it still works", "Ndiyo, bado hufanya kazi",
             "Oui, ça marche encore"),
            ("No, paper blocks it", "Hapana, karatasi huzuia",
             "Non, le papier bloque"),
        ], 0, None),
    },
    # "East. And west is on your left. Turning changes it all."
    "s08.social.lesson.02": {
        4: ([
            ("West", "Magharibi", "L'ouest"),
            ("East", "Mashariki", "L'est"),
            ("South", "Kusini", "Le sud"),
        ], 1, None),
    },
    # "Water to drink, soil to farm, and a road that moves boats for free."
    "s08.social.lesson.04": {
        6: ([
            ("Rivers look pretty", "Mito ni mizuri", "Les fleuves sont beaux"),
            ("Water, soil and roads", "Maji, udongo na njia",
             "Eau, terre et transport"),
            ("Rivers stop floods", "Mito huzuia mafuriko",
             "Ils stoppent les crues"),
        ], 1, None),
    },
    # "River. It is only a capital if it is the name of one, like the Nile."
    "s08.writing.lesson.02": {
        4: (en_only("monday", "river", "october", "spain"), 1,
            "English capitalisation: proper nouns"),
    },
    "s08.writing.lesson.03": {
        # "After bread and after milk. The last item joins with 'and'."
        3: ([
            ("After every word", "Baada ya kila neno", "Après chaque mot"),
            ("After bread and milk", "Baada ya mkate na maziwa",
             "Après pain et lait"),
            ("Only after rice", "Baada ya wali tu", "Seulement après riz"),
        ], 1, None),
        # "One. Three items, two gaps, and the last gap gets 'and' instead."
        4: ([
            ("Two", "Mbili", "Deux"),
            ("One", "Moja", "Une"),
            ("Three", "Tatu", "Trois"),
        ], 1, None),
        # "Everything. 'Let's eat, Grandma' is an invitation, not a plan."
        5: ([
            ("Nothing at all", "Hakuna kitu", "Rien du tout"),
            ("Everything", "Kila kitu", "Tout"),
            ("Only the sound", "Sauti tu", "Seulement le son"),
        ], 1, None),
    },
    # "Three adjectives all saying one thing. One strong word beats three
    # weak ones."
    "s08.writing.lesson.05": {
        5: ([
            ("Too few words", "Maneno machache mno", "Trop peu de mots"),
            ("Three words, one idea", "Maneno matatu, wazo moja",
             "Trois mots, une idée"),
            ("The dog is missing", "Mbwa hayupo", "Le chien manque"),
        ], 1, None),
    },
    # "Beautiful cannot be measured. Conditions need facts, not feelings."
    "s09.coding.lesson.05": {
        5: ([
            ("It is too long", "Ni sentensi ndefu", "La phrase est longue"),
            ("Beauty is not a fact", "Uzuri si uhakika",
             "Beauté n'est pas un fait"),
            ("The sky moves", "Anga hubadilika", "Le ciel bouge"),
        ], 1, None),
    },
    "s09.science.lesson.01": {
        # "Pulls it, without touching. Magnetism is a force that reaches
        # across a gap."
        4: ([
            ("Pushes it away", "Huisukuma mbali", "Il le repousse"),
            ("Pulls it without touch", "Huivuta bila kugusa",
             "Il l'attire sans toucher"),
            ("Nothing at all", "Hakuna kitu", "Rien du tout"),
        ], 1, None),
        # "Ice is smooth, so friction is small. Same push, much more
        # movement."
        6: ([
            ("Carpet grips more", "Zulia hushikilia zaidi",
             "Le tapis accroche plus"),
            ("Ice, less friction", "Barafu, msuguano mdogo",
             "La glace, moins de frottement"),
            ("Both are the same", "Vyote ni sawa", "C'est pareil"),
        ], 1, None),
    },
    # "Cold. Every adaptation answers a problem the habitat sets."
    "s09.science.lesson.02": {
        3: ([
            ("Sand", "Mchanga", "Le sable"),
            ("Cold", "Baridi", "Le froid"),
            ("Rain", "Mvua", "La pluie"),
        ], 1, None),
    },
    # "More grass grows. Every change travels both up and down the web."
    "s09.science.lesson.03": {
        5: ([
            ("Less grass grows", "Nyasi hupungua", "Moins d'herbe pousse"),
            ("More grass grows", "Nyasi huongezeka", "Plus d'herbe pousse"),
            ("Nothing changes", "Hakuna mabadiliko", "Rien ne change"),
        ], 1, None),
    },
    "s09.science.lesson.04": {
        # "How the animal moved, and how fast. Bones show shape; tracks show
        # life." The distractors are what a bone does tell you.
        3: ([
            ("Its colour", "Rangi yake", "Sa couleur"),
            ("How it moved", "Jinsi alivyotembea", "Comment il bougeait"),
            ("How old it was", "Umri wake", "Son âge"),
        ], 1, None),
        # "Nothing hard is left to be replaced by stone. Bones and shells
        # last."
        5: ([
            ("They lived in water", "Waliishi majini",
             "Ils vivaient dans l'eau"),
            ("No hard parts last", "Hakuna sehemu ngumu",
             "Rien de dur ne reste"),
            ("They were too small", "Walikuwa wadogo mno",
             "Ils étaient trop petits"),
        ], 1, None),
    },
    # "Its orbit is far bigger, so one lap round the Sun takes far longer."
    "s09.science.lesson.06": {
        5: ([
            ("It spins slowly", "Huzunguka polepole", "Il tourne lentement"),
            ("Its orbit is bigger", "Njia yake ni ndefu",
             "Son orbite est plus grande"),
            ("It is colder there", "Ni baridi zaidi", "Il y fait plus froid"),
        ], 1, None),
    },
    "s09.social.lesson.02": {
        # "A star is the capital city."
        0: ([
            ("A big city park", "Bustani ya jiji", "Un parc urbain"),
            ("The capital city", "Mji mkuu", "La capitale"),
            ("A mountain", "Mlima", "Une montagne"),
        ], 1, None),
        # "It tells you which way is north, so the map matches the ground."
        6: ([
            ("It shows distance", "Huonyesha umbali", "Il montre la distance"),
            ("It shows direction", "Huonyesha mwelekeo",
             "Il montre la direction"),
            ("It names the towns", "Hutaja miji", "Il nomme les villes"),
        ], 1, None),
    },
    "s09.social.lesson.04": {
        # "It takes three times as long. Small regular spending is the slow
        # leak."
        5: ([
            ("It finishes sooner", "Itaisha mapema", "Ça finit plus tôt"),
            ("It takes 3x as long", "Itachukua mara 3 zaidi",
             "Ça prend 3 fois plus"),
            ("Nothing changes", "Hakuna mabadiliko", "Rien ne change"),
        ], 1, None),
        # "The fare. Needs before wants is what makes a budget hold up."
        6: ([
            ("The comic", "Katuni", "La BD"),
            ("The bus fare", "Nauli ya basi", "Le ticket de bus"),
        ], 1, None),
    },
    "s09.social.lesson.06": {
        # "Rural. Space is the thing there is most of."
        3: ([
            ("City centre", "Katikati ya jiji", "Le centre-ville"),
            ("Rural area", "Eneo la vijijini", "La campagne"),
            ("Suburb", "Kitongoji", "La banlieue"),
        ], 1, None),
        # "Things are further apart and buses are rarer. Distance decides."
        5: ([
            ("Cars are cheaper", "Magari ni rahisi", "Les autos coûtent moins"),
            ("Things are further", "Vitu viko mbali zaidi",
             "Tout est plus loin"),
            ("More people live there", "Watu ni wengi zaidi",
             "Il y a plus d'habitants"),
        ], 1, None),
    },
    "s09.writing.lesson.03": {
        # "Inside the quotes, before the closing mark: \"Hello,\" said Ana."
        3: (COMMA_PLACE, 1, None),
        # "Said. Thoughts are not spoken, so they take no marks."
        4: ([
            ("What Ana thought", "Alichofikiri Ana", "Ce qu'Ana a pensé"),
            ("What Ana said", "Alichosema Ana", "Ce qu'Ana a dit"),
        ], 1, None),
    },
    # "Tuesday and Tanzania. The other two name kinds, not particular ones."
    # Narrowed to the one pair a single choice can express.
    "s09.writing.lesson.04": {
        4: (en_only("town", "Tanzania"), 1,
            "English capitalisation: proper nouns"),
    },
    # "Prints them exactly, spaces and all. It never tidies them up for you."
    "s10.coding.lesson.01": {
        5: ([
            ("Tidies the spaces", "Hurekebisha nafasi",
             "Il corrige les espaces"),
            ("Prints them exactly", "Huchapisha kama zilivyo",
             "Il les affiche tels quels"),
            ("Ignores them", "Huzipuuza", "Il les ignore"),
        ], 1, None),
    },
    # "Quotes mean the letters themselves; no quotes means look inside the
    # box."
    "s10.coding.lesson.02": {
        6: ([
            ("It is a mistake", "Ni kosa", "C'est une erreur"),
            ("It is a variable", "Ni kisanduku cha data", "C'est une variable"),
            ("Quotes are optional", "Alama si lazima",
             "Guillemets optionnels"),
        ], 1, None),
    },
    # "Reports it and stops. It cannot guess what you meant, and will not try."
    "s10.coding.lesson.05": {
        4: ([
            ("Guesses what you meant", "Hubahatisha ulichomaanisha",
             "Il devine votre intention"),
            ("Reports it and stops", "Huripoti na kusimama",
             "Il signale et s'arrête"),
            ("Skips that line", "Huruka mstari huo", "Il saute la ligne"),
        ], 1, None),
    },
    # "Longitude is worked out from time differences. A slow clock is a wrong
    # place."
    "s10.social.lesson.01": {
        6: ([
            ("To time their meals", "Kupanga milo yao",
             "Pour l'heure des repas"),
            ("Longitude uses time", "Longitudo hutumia saa",
             "La longitude vient du temps"),
            ("To follow the stars", "Kufuata nyota", "Pour suivre les étoiles"),
        ], 1, None),
    },
    # "It defines the symbols. Without it a map is a picture you cannot read."
    "s10.social.lesson.04": {
        6: ([
            ("It shows the scale", "Huonyesha kipimo", "Il donne l'échelle"),
            ("It explains symbols", "Hufafanua alama",
             "Il explique les symboles"),
            ("It names the maker", "Hutaja mtengenezaji", "Il nomme l'auteur"),
        ], 1, None),
    },
    "s10.writing.lesson.04": {
        # "Inside the quotes: \"Let's go,\" said Maria."
        4: (COMMA_PLACE, 1, None),
        # "The spoken words and their punctuation inside; who said it,
        # outside."
        5: ([
            ("The speaker's name", "Jina la msemaji", "Le nom du locuteur"),
            ("The spoken words", "Maneno yaliyosemwa", "Les mots prononcés"),
            ("The whole sentence", "Sentensi nzima", "Toute la phrase"),
        ], 1, None),
    },
    # "The reason. There is no point spelling a sentence you are about to cut."
    "s10.writing.lesson.06": {
        4: ([
            ("Fixing the spelling", "Kurekebisha tahajia",
             "Corriger l'orthographe"),
            ("Adding the reason", "Kuongeza sababu", "Ajouter la raison"),
        ], 1, None),
    },
}


def check_spec() -> None:
    """Fail loudly on a spec that the player or the tests would reject."""
    for item_id, steps in STAGED.items():
        for index, (options, answer, english) in steps.items():
            where = f"{item_id} step{index}"
            english_words = [o[0] for o in options]
            if len(options) < 2:
                sys.exit(f"{where}: needs at least two options")
            if len(set(e.lower() for e in english_words)) != len(options):
                sys.exit(f"{where}: duplicate options")
            if not 0 <= answer < len(options):
                sys.exit(f"{where}: answer index {answer} out of range")
            for option in options:
                if not option[0].strip():
                    sys.exit(f"{where}: blank option")
                if len(option[0]) > MAX_OPTION:
                    sys.exit(f"{where}: option '{option[0]}' is too long")
                if english is None:
                    # lesson_depth_test requires sw/fr to differ from en, and
                    # an untranslated option puts English in front of a
                    # Swahili child — the half of the bug this set fixes.
                    if option[1] in (None, option[0]) or \
                            option[2] in (None, option[0]):
                        sys.exit(f"{where}: '{option[0]}' is not translated "
                                 f"and is not marked english-by-design")
                elif option[1] is not None or option[2] is not None:
                    sys.exit(f"{where}: '{option[0]}' is marked "
                             f"english-by-design but carries a translation")


def stage(library: dict) -> tuple[int, dict[str, dict[str, str]],
                                  dict[str, str]]:
    """Apply STAGED; return (steps changed, i18n wanted, english-by-design)."""
    by_id = {item["id"]: item for item in library["content"]}
    wanted: dict[str, dict[str, str]] = {lang: {} for lang in LANGS}
    english_keys: dict[str, str] = {}
    changed = 0

    for item_id, steps in STAGED.items():
        item = by_id.get(item_id)
        if item is None:
            sys.exit(f"{item_id}: not in the library")
        for index, (options, answer, english) in steps.items():
            if index >= len(item["steps"]):
                sys.exit(f"{item_id}: has no step{index}")
            step = item["steps"][index]
            english_words = [o[0] for o in options]
            before = (
                step.get("mechanic"),
                step.get("choices"),
                step.get("choiceIndex"),
            )
            step["mechanic"] = "multiChoice"
            step["choices"] = list(english_words)
            step["choiceIndex"] = answer
            if before != ("multiChoice", list(english_words), answer):
                changed += 1
            for position, option in enumerate(options):
                key = f"{item_id}.steps.{index}.choices.{position}"
                wanted["en"][key] = option[0]
                if english is not None:
                    # No sw/fr entry: the overlay falls back to the library
                    # English, which is the point.
                    english_keys[key] = english
                    continue
                wanted["sw"][key] = option[1]
                wanted["fr"][key] = option[2]

    return changed, wanted, english_keys


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    check_spec()
    library = json.loads(LIBRARIES[0].read_text(encoding="utf-8"))
    changed, wanted, english_keys = stage(library)

    missing = 0
    for directory in I18N_DIRS:
        for lang in LANGS:
            path = directory / f"{lang}.json"
            if not path.exists():
                continue
            overlay = json.loads(path.read_text(encoding="utf-8"))
            missing += sum(
                1 for k, v in wanted[lang].items() if overlay.get(k) != v
            )

    by_design = json.loads(ENGLISH_BY_DESIGN.read_text(encoding="utf-8"))
    unregistered = sum(
        1 for k, v in english_keys.items() if by_design["keys"].get(k) != v
    )

    if args.check:
        if changed or missing or unregistered:
            print(f"drift: {changed} step(s) unstaged, "
                  f"{missing} missing translation(s), "
                  f"{unregistered} unregistered english-by-design key(s)")
            return 1
        print("ok: every explanation step offers what it asks")
        return 0

    for path in LIBRARIES:
        path.write_text(
            json.dumps(library, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
    for directory in I18N_DIRS:
        for lang in LANGS:
            path = directory / f"{lang}.json"
            if not path.exists():
                continue
            overlay = json.loads(path.read_text(encoding="utf-8"))
            overlay.update(wanted[lang])
            path.write_text(
                json.dumps(dict(sorted(overlay.items())), indent=2,
                           ensure_ascii=False) + "\n",
                encoding="utf-8",
            )
    by_design["keys"].update(english_keys)
    by_design["keys"] = dict(sorted(by_design["keys"].items()))
    ENGLISH_BY_DESIGN.write_text(
        json.dumps(by_design, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    print(f"{changed} step(s) staged; {missing} translation(s) written; "
          f"{unregistered} english-by-design key(s) registered")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
