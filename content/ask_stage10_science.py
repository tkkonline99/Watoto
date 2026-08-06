"""Give the stage-10 science lessons questions a child can actually answer.

Why this exists
---------------
wire_circuit_steps.py fixed s10.science.lesson.01. An audit of the other five
found the same defect and a worse one.

**Fourteen steps asked a question with no options at all.** They were bare
`tap` steps, so the player showed the item's emoji and completing the step
meant touching it. "Tap what producers use to make their own energy" was
answered by tapping a picture of a food web. Nothing could be got wrong.

**Three steps were worse than empty: they marked a wrong answer correct.**
`choicePlanFor` stages look-alike objects for a directive like "Tap the drum",
which is right for naming a thing and wrong for asking why something happens.
It read the nouns in the sentence and staged them as the answer:

  * 02.5 "Tap **why** a year on Neptune is far longer" staged Earth as correct.
    The answer is that Neptune's orbit is enormous.
  * 03.5 "Tap what a rolling ball's motion energy **becomes**" staged the ball.
    The answer is heat.
  * 05.5 "Tap **where** the water went" staged a water droplet. The answer is
    that it went into the air.

A child who knew the right answer was marked wrong. That is the one failure a
quiz must never have, so those three are re-authored here with the rest.

Every option below comes from the step's own `feedback` — the same rule
comprehension_check.dart works to. Distractors are drawn from the lesson's own
material (the other energy forms, the other states of matter) rather than
invented.

`figures` names one picture per option, language-neutral, resolved by the
player: a circuit diagram if it names one, otherwise a lexicon emoji. Left
empty where the answer is a phrase no picture honestly depicts — a wrong
picture is worse than none.

Idempotent: re-running makes no further change.

    python content/ask_stage10_science.py            # from the repo root
    python content/ask_stage10_science.py --check    # verify only, exit 1 on drift
"""
from __future__ import annotations

import argparse
import json
import sys

from authoring import I18N_DIRS, LANGS, LIBRARIES

# Longest an option may be before it stops being tappable on a phone.
# step_coverage_test.dart enforces the same bound.
MAX_OPTION = 22


def T(en, sw, fr):
    return (en, sw, fr)


# Steps that only needed a tappable noun. "Tap to freeze" named no object, so
# the lexicon had nothing to stage and the step became a dead tap; naming the
# water keeps it the demonstration it was meant to be rather than turning a
# hands-on beat into another quiz.
NARRATION_ONLY = {
    "s10.science.lesson.05": {
        1: T(
            "Cooling freezes a liquid back to solid: water into ice. Tap the "
            "water to freeze it.",
            "Kupoa hugandisha kimiminika kuwa kigumu: maji kuwa barafu. Gusa "
            "maji ili yagande.",
            "Le froid gèle un liquide en solide : l'eau devient glace. Touche "
            "l'eau pour la geler.",
        ),
    },
}

# Steps that already asked a real question and only wanted pictures. Their
# options and translations are untouched.
#
# Only where every option is a concrete thing the lexicon already draws. The
# other pre-existing choice steps — "Shorter"/"Longer", "Hypothesis"/"Ask"/
# "Conclusion" — stay as words, because inventing a picture for a conclusion
# would say less than the word does.
FIGURES_ONLY = {
    "s10.science.lesson.03": {
        # Light / Sound / Motion
        2: ["lamp", "sound", "ball"],
    },
}

QUESTIONS = {
    "s10.science.lesson.02": {
        5: {
            "question": T(
                "Why is a year on Neptune far longer than a year on Earth?",
                "Kwa nini mwaka kwenye Neptune ni mrefu zaidi kuliko wa Dunia?",
                "Pourquoi une année sur Neptune est-elle bien plus longue que "
                "sur Terre ?",
            ),
            "choices": [
                (T("Its orbit is bigger.", "Mzingo wake ni mkubwa.",
                   "Son orbite est plus grande."), ""),
                (T("It spins slower.", "Inazunguka polepole.",
                   "Elle tourne plus lentement."), ""),
                (T("It is a gas giant.", "Ni jitu la gesi.",
                   "C'est une géante gazeuse."), ""),
            ],
            "answer": 0,
        },
        6: {
            "question": T(
                "Someone said the Sun goes round the Earth. What do we "
                "actually observe?",
                "Mtu alisema Jua huzunguka Dunia. Kwa kweli tunaona nini?",
                "Quelqu'un dit que le Soleil tourne autour de la Terre. "
                "Qu'observe-t-on vraiment ?",
            ),
            "choices": [
                (T("The Earth spins.", "Dunia inajizungusha.",
                   "La Terre tourne."), "earth"),
                (T("The Sun orbits us.", "Jua linatuzunguka.",
                   "Le Soleil nous tourne autour."), "sun"),
            ],
            "answer": 0,
        },
    },
    "s10.science.lesson.03": {
        4: {
            "question": T(
                "A guitar string vibrates. What kind of energy is it making?",
                "Uzi wa gitaa unatetemeka. Unatengeneza nishati ya aina gani?",
                "Une corde de guitare vibre. Quelle énergie produit-elle ?",
            ),
            "choices": [
                (T("Sound", "Sauti", "Le son"), "sound"),
                (T("Light", "Mwanga", "La lumière"), "lamp"),
                (T("Heat", "Joto", "La chaleur"), "fire"),
            ],
            "answer": 0,
        },
        5: {
            "question": T(
                "What does a rolling ball's motion energy become when it "
                "stops?",
                "Nishati ya mwendo ya mpira inakuwa nini unaposimama?",
                "Que devient l'énergie de mouvement d'une balle qui s'arrête ?",
            ),
            "choices": [
                (T("Heat", "Joto", "De la chaleur"), "fire"),
                (T("Light", "Mwanga", "De la lumière"), "lamp"),
                (T("Sound", "Sauti", "Du son"), "sound"),
            ],
            "answer": 0,
        },
        6: {
            "question": T(
                "Someone said a lamp creates light out of nothing. What is "
                "wrong?",
                "Mtu alisema taa hutengeneza mwanga kutoka hewani. Kosa ni "
                "lipi?",
                "Quelqu'un dit qu'une lampe crée la lumière à partir de rien. "
                "Où est l'erreur ?",
            ),
            "choices": [
                (T("It uses electricity.", "Inatumia umeme.",
                   "Elle utilise l'électricité."), ""),
                (T("Light needs no source.", "Mwanga hauhitaji chanzo.",
                   "La lumière n'a pas de source."), ""),
                (T("Lamps make new energy.", "Taa hutengeneza nishati mpya.",
                   "Les lampes créent l'énergie."), ""),
            ],
            "answer": 0,
        },
    },
    "s10.science.lesson.04": {
        4: {
            "question": T(
                "What do producers use to make their own energy?",
                "Wazalishaji hutumia nini kutengeneza nishati yao?",
                "Qu'utilisent les producteurs pour fabriquer leur énergie ?",
            ),
            "choices": [
                (T("Sunlight", "Mwanga wa jua", "La lumière du soleil"), "sun"),
                (T("Other plants", "Mimea mingine", "D'autres plantes"),
                 "plant"),
                (T("Small animals", "Wanyama wadogo", "De petits animaux"),
                 "frog"),
            ],
            "answer": 0,
        },
        5: {
            "question": T(
                "If all the grass disappeared, what happens to the "
                "grasshoppers?",
                "Nyasi zote zikitoweka, panzi watakuwaje?",
                "Si toute l'herbe disparaissait, qu'arriverait-il aux "
                "sauterelles ?",
            ),
            "choices": [
                (T("They have less food.", "Wana chakula kidogo.",
                   "Ils ont moins à manger."), ""),
                (T("They eat more grass.", "Wanakula nyasi zaidi.",
                   "Ils mangent plus d'herbe."), ""),
                (T("Nothing changes.", "Hakuna kinachobadilika.",
                   "Rien ne change."), ""),
            ],
            "answer": 0,
        },
        6: {
            "question": T(
                "Why does removing one animal affect species that never eat "
                "it?",
                "Kwa nini kuondoa mnyama mmoja huathiri wanyama wasiomla?",
                "Pourquoi retirer un animal touche-t-il des espèces qui ne le "
                "mangent jamais ?",
            ),
            "choices": [
                (T("They share a chain.", "Wanashiriki mnyororo.",
                   "Ils partagent une chaîne."), ""),
                (T("They eat it secretly.", "Wanamla kwa siri.",
                   "Ils le mangent en secret."), ""),
                (T("Nothing links them.", "Hakuna kinachowaunganisha.",
                   "Rien ne les relie."), ""),
            ],
            "answer": 0,
        },
    },
    "s10.science.lesson.05": {
        4: {
            "question": T(
                "What do you add to turn a solid into a liquid?",
                "Unaongeza nini ili kigumu kiwe kimiminika?",
                "Qu'ajoute-t-on pour transformer un solide en liquide ?",
            ),
            "choices": [
                (T("Heat", "Joto", "De la chaleur"), "fire"),
                (T("Cold", "Baridi", "Du froid"), "ice"),
                (T("Water", "Maji", "De l'eau"), "water"),
            ],
            "answer": 0,
        },
        5: {
            "question": T(
                "A puddle vanishes on a warm day. Where did the water go?",
                "Kidimbwi kinatoweka siku ya joto. Maji yalienda wapi?",
                "Une flaque disparaît par temps chaud. Où est passée l'eau ?",
            ),
            "choices": [
                (T("Into the air.", "Hewani.", "Dans l'air."), ""),
                (T("Into the ground.", "Ardhini.", "Dans le sol."), ""),
                (T("It vanished.", "Yalitoweka.", "Elle a disparu."), ""),
            ],
            "answer": 0,
        },
        6: {
            "question": T(
                "Someone said melted ice is a different substance. What is "
                "the mistake?",
                "Mtu alisema barafu iliyoyeyuka ni kitu tofauti. Kosa ni lipi?",
                "Quelqu'un dit que la glace fondue est une autre substance. "
                "Où est l'erreur ?",
            ),
            "choices": [
                (T("Same stuff, new state.", "Kitu kilekile, hali mpya.",
                   "Même matière, autre état."), ""),
                (T("Melting makes water.", "Kuyeyuka hutengeneza maji.",
                   "Fondre fabrique de l'eau."), ""),
                (T("Ice is not water.", "Barafu si maji.",
                   "La glace n'est pas de l'eau."), ""),
            ],
            "answer": 0,
        },
    },
    "s10.science.lesson.06": {
        4: {
            "question": T(
                "You test which paper plane flies furthest. What must stay "
                "the same?",
                "Unajaribu ndege ipi ya karatasi inaruka mbali zaidi. Nini "
                "kibaki sawa?",
                "Tu testes quel avion en papier vole le plus loin. Que "
                "faut-il garder pareil ?",
            ),
            "choices": [
                (T("The throw and paper.", "Rusha na karatasi.",
                   "Le lancer et le papier."), ""),
                (T("The fold of the plane.", "Mkunjo wa ndege.",
                   "Le pliage de l'avion."), ""),
                (T("Nothing at all.", "Hakuna kitu.", "Rien du tout."), ""),
            ],
            "answer": 0,
        },
        5: {
            "question": T(
                "Before you throw a single paper plane, what is a hypothesis?",
                "Kabla hujarusha ndege hata moja, dhana ni nini?",
                "Avant de lancer le moindre avion, qu'est-ce qu'une "
                "hypothèse ?",
            ),
            "choices": [
                (T("A prediction.", "Utabiri.", "Une prédiction."), ""),
                (T("A result.", "Matokeo.", "Un résultat."), ""),
                (T("A conclusion.", "Hitimisho.", "Une conclusion."), ""),
            ],
            "answer": 0,
        },
        6: {
            "question": T(
                "Your result disagrees with your hypothesis. What is the "
                "right response?",
                "Matokeo yako yanatofautiana na dhana yako. Jibu sahihi ni "
                "lipi?",
                "Ton résultat contredit ton hypothèse. Quelle est la bonne "
                "réaction ?",
            ),
            "choices": [
                (T("Record it and say so.", "Andika na useme.",
                   "Note-le et dis-le."), ""),
                (T("Change the result.", "Badilisha matokeo.",
                   "Change le résultat."), ""),
                (T("Try until it agrees.", "Jaribu hadi ikubali.",
                   "Essaie jusqu'à ce que ça colle."), ""),
            ],
            "answer": 0,
        },
    },
}


def check_spec() -> None:
    """Fail loudly on a spec that would ship a broken question."""
    for item_id, steps in QUESTIONS.items():
        for index, spec in steps.items():
            where = f"{item_id} step {index}"
            english = [c[0][0] for c in spec["choices"]]
            if len(english) < 2:
                raise SystemExit(f"{where}: needs at least two options")
            if len(set(e.lower() for e in english)) != len(english):
                raise SystemExit(f"{where}: duplicate options")
            for e in english:
                if len(e) > MAX_OPTION:
                    raise SystemExit(f"{where}: option too long: {e!r}")
            if not 0 <= spec["answer"] < len(english):
                raise SystemExit(f"{where}: answer index out of range")
            figures = [c[1] for c in spec["choices"]]
            if any(figures) and not all(figures):
                raise SystemExit(
                    f"{where}: some options have a picture and some do not"
                )


def stage(lib: dict) -> tuple[int, dict[str, dict[str, str]]]:
    """Author the questions. Returns (changed, overlay)."""
    changed = 0
    overlay: dict[str, dict[str, str]] = {lang: {} for lang in LANGS}
    by_id = {c["id"]: c for c in lib["content"]}

    for item_id, steps in NARRATION_ONLY.items():
        item = by_id[item_id]
        for index, text in steps.items():
            step = item["steps"][index]
            if step["narration"] != text[0]:
                changed += 1
            step["narration"] = text[0]
            for lang_index, lang in enumerate(LANGS):
                overlay[lang][f"{item_id}.steps.{index}.narration"] = \
                    text[lang_index]

    for item_id, steps in FIGURES_ONLY.items():
        item = by_id[item_id]
        for index, figures in steps.items():
            step = item["steps"][index]
            if len(figures) != len(step.get("choices", [])):
                raise SystemExit(
                    f"{item_id} step {index}: {len(figures)} pictures for "
                    f"{len(step.get('choices', []))} options"
                )
            if step.get("figures") != figures:
                changed += 1
            step["figures"] = figures

    for item_id, steps in QUESTIONS.items():
        item = by_id.get(item_id)
        if item is None:
            raise SystemExit(f"{item_id} is not in the library")
        for index, spec in steps.items():
            step = item["steps"][index]
            before = json.dumps(step, sort_keys=True)
            step["mechanic"] = "multiChoice"
            # The question is the narration, never a separate `prompt`: the
            # player prints both, so a prompt restating it asks twice.
            step["narration"] = spec["question"][0]
            step.pop("prompt", None)
            step["choices"] = [c[0][0] for c in spec["choices"]]
            step["figures"] = [c[1] for c in spec["choices"]]
            step["choiceIndex"] = spec["answer"]
            if before != json.dumps(step, sort_keys=True):
                changed += 1

            for lang_index, lang in enumerate(LANGS):
                base = f"{item_id}.steps.{index}"
                overlay[lang][f"{base}.narration"] = spec["question"][lang_index]
                for option_index, (text, _figure) in enumerate(spec["choices"]):
                    overlay[lang][f"{base}.choices.{option_index}"] = \
                        text[lang_index]
    return changed, overlay


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    check_spec()
    lib = json.loads(LIBRARIES[0].read_text(encoding="utf-8"))
    changed, wanted = stage(lib)

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

    if args.check:
        if changed or missing:
            print(f"drift: {changed} step(s) unstaged, "
                  f"{missing} missing translation(s)")
            return 1
        print("ok: every stage-10 science question is answerable")
        return 0

    for path in LIBRARIES:
        path.write_text(
            json.dumps(lib, indent=2, ensure_ascii=False) + "\n",
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

    print(f"{changed} step(s) staged; {missing} translation(s) written")
    return 0


if __name__ == "__main__":
    sys.exit(main())
