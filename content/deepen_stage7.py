"""Author ten stage-7 (ages 6–7) lessons to full depth, in EN/SW/FR.

Why this exists
---------------
The library is 565 items wide and about two steps deep: 342 lessons share 747
steps, and 539 of those steps are a bare `tap`. A "lesson" was a picture, a
sentence and a poke — fifteen seconds. Breadth was proven; depth was not.

This script rewrites ten lessons across math, reading, writing, science and
health into 8–10 step teaching arcs: hook → worked example broken into its
parts → guided practice → independent practice → transfer → close. It is the
depth pilot. If the shape works with real children, the same treatment scales
to the rest of the library.

Two things it does deliberately:

1. **Every step declares its `mechanic`.** The player can infer a mechanic from
   the step text (`planStep` in step_play.dart), but the heuristics read English
   — "how many", "trace", "rows of". A Swahili or French child hits the same
   step with translated narration and the heuristics miss, so the step silently
   degrades to a tap. Authored mechanics make the three languages play the same
   lesson.

2. **It writes the i18n overlay for all three languages, English included.**
   `LocalizedItem._t` prefers the overlay over the text embedded in the library,
   so a stale `en` key would keep showing the old two-step script forever.

Idempotent: re-running replaces the same ten lessons and their keys.

    python content/deepen_stage7.py            # from the repo root
    python content/deepen_stage7.py --check    # verify only, exit 1 on drift
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# The app reads assets/; content/ is the authoring copy. They had already
# drifted (assets/ carried 133 authored mechanics that content/ never got), so
# both are written from the same in-memory object here rather than edited twice.
LIBRARIES = [
    ROOT / "apps/mobile/assets/content/watoto_content_library.json",
    ROOT / "content/watoto_content_library.json",
]
I18N_DIRS = [ROOT / "apps/mobile/assets/i18n", ROOT / "content/i18n"]

# Steps a deepened lesson must have before it counts as deep. Ten is the ceiling
# a 6-year-old will sit through in one go; eight is the floor for a worked
# example plus practice.
MIN_STEPS = 8


def s(mechanic, en, sw, fr, *, action="tap", **extra):
    """One authored step. `en`/`sw`/`fr` are (narration, feedback) pairs.

    `prompt` and `choices` are passed as dicts keyed by language when the step
    asks a question; `answer`, `choiceIndex`, `count`, `rows`, `cols` are
    language-neutral and live at the top level.
    """
    return {"mechanic": mechanic, "action": action, "en": en, "sw": sw, "fr": fr, **extra}


# --------------------------------------------------------------------------
# The lessons.
# --------------------------------------------------------------------------
LESSONS: dict[str, list[dict]] = {}

LESSONS["s07.math.lesson.02"] = [
    s(
        "explain",
        ("Big sums can be easy. Watch this one: 8 + 7.",
         "Let's find a trick."),
        ("Hesabu kubwa zinaweza kuwa rahisi. Tazama hii: 8 + 7.",
         "Tutafute njia rahisi."),
        ("Les grandes additions peuvent être faciles. Regarde : 8 + 7.",
         "Cherchons une astuce."),
    ),
    s(
        "explain",
        ("Ten is our friend. It is easy to add to ten.",
         "So let's make a ten first."),
        ("Kumi ni rafiki yetu. Ni rahisi kujumlisha na kumi.",
         "Kwa hiyo tutengeneze kumi kwanza."),
        ("Dix est notre ami. C'est facile d'ajouter à dix.",
         "Alors faisons d'abord un dix."),
    ),
    s(
        "multiChoice",
        ("Eight is nearly ten. How much more does it need? 8 + ? = 10.",
         "Yes! 8 + 2 = 10."),
        ("Nane iko karibu na kumi. Inahitaji kiasi gani zaidi? 8 + ? = 10.",
         "Ndiyo! 8 + 2 = 10."),
        ("Huit est presque dix. Combien lui faut-il en plus ? 8 + ? = 10.",
         "Oui ! 8 + 2 = 10."),
        prompt={"en": "8 + ? = 10", "sw": "8 + ? = 10", "fr": "8 + ? = 10"},
        choices={"en": ["1", "2", "3"], "sw": ["1", "2", "3"], "fr": ["1", "2", "3"]},
        choiceIndex=1,
    ),
    s(
        "explain",
        ("We borrowed that 2 from the 7. Now take it away: 7 - 2.",
         "Let's see how much is left."),
        ("Tumechukua 2 hiyo kutoka kwa 7. Sasa itoe: 7 - 2.",
         "Tuone kiasi gani kimebaki."),
        ("Nous avons pris ce 2 dans le 7. Enlève-le : 7 - 2.",
         "Voyons ce qui reste."),
    ),
    s(
        "numberAnswer",
        ("7 - 2. Seven, give away two.",
         "5 is left."),
        ("7 - 2. Saba, toa mbili.",
         "Zimebaki 5."),
        ("7 - 2. Sept, enlève deux.",
         "Il reste 5."),
        prompt={"en": "7 − 2 = ?", "sw": "7 − 2 = ?", "fr": "7 − 2 = ?"},
        answer=5,
    ),
    s(
        "multiChoice",
        ("Now the hard sum has become an easy one: 10 + 5.",
         "10 and 5 is 15!"),
        ("Sasa hesabu ngumu imekuwa rahisi: 10 + 5.",
         "10 na 5 ni 15!"),
        ("Maintenant l'addition difficile est devenue facile : 10 + 5.",
         "10 et 5 font 15 !"),
        prompt={"en": "10 + 5 = ?", "sw": "10 + 5 = ?", "fr": "10 + 5 = ?"},
        choices={"en": ["12", "15", "50"], "sw": ["12", "15", "50"], "fr": ["12", "15", "50"]},
        choiceIndex=1,
    ),
    s(
        "explain",
        ("So 8 + 7 = 15. Making ten turned a hard sum into an easy one.",
         "That trick works every time."),
        ("Kwa hiyo 8 + 7 = 15. Kutengeneza kumi kumefanya hesabu ngumu kuwa rahisi.",
         "Njia hiyo hufanya kazi kila mara."),
        ("Donc 8 + 7 = 15. Faire dix a rendu l'addition facile.",
         "Cette astuce marche à chaque fois."),
    ),
    s(
        "multiChoice",
        ("Your turn. We want to add 9 + 6.",
         "Right — 9 needs just 1 more."),
        ("Zamu yako. Tunataka kujumlisha 9 + 6.",
         "Sawa — 9 inahitaji 1 tu zaidi."),
        ("À ton tour. Nous voulons calculer 9 + 6.",
         "C'est ça — 9 a besoin de 1 de plus."),
        prompt={
            "en": "What does 9 need to make ten?",
            "sw": "9 inahitaji nini ili ifike kumi?",
            "fr": "De combien 9 a-t-il besoin pour faire dix ?",
        },
        choices={"en": ["1", "2", "6"], "sw": ["1", "2", "6"], "fr": ["1", "2", "6"]},
        choiceIndex=0,
    ),
    s(
        "numberAnswer",
        ("Take 1 from the 6 to make ten, then add what is left.",
         "10 and 5 is 15. You did it the clever way!"),
        ("Chukua 1 kutoka kwa 6 ili ufike kumi, kisha jumlisha kilichobaki.",
         "10 na 5 ni 15. Umefanya kwa njia ya werevu!"),
        ("Prends 1 dans le 6 pour faire dix, puis ajoute ce qui reste.",
         "10 et 5 font 15. Tu l'as fait intelligemment !"),
        prompt={"en": "9 + 6 = ?", "sw": "9 + 6 = ?", "fr": "9 + 6 = ?"},
        answer=15,
    ),
    s(
        "numberAnswer",
        ("Last one, all by yourself: 7 + 5.",
         "12! Making ten works every single time."),
        ("Ya mwisho, wewe mwenyewe: 7 + 5.",
         "12! Kutengeneza kumi hufanya kazi kila wakati."),
        ("La dernière, tout seul : 7 + 5.",
         "12 ! Faire dix marche à tous les coups."),
        prompt={"en": "7 + 5 = ?", "sw": "7 + 5 = ?", "fr": "7 + 5 = ?"},
        answer=12,
    ),
]

LESSONS["s07.math.lesson.03"] = [
    s(
        "explain",
        ("Taking away can use the same ten trick. Try 15 − 7.",
         "Watch how we do it."),
        ("Kutoa kunaweza kutumia njia ile ile ya kumi. Jaribu 15 − 7.",
         "Tazama jinsi tunavyofanya."),
        ("Soustraire peut utiliser la même astuce du dix. Essaie 15 − 7.",
         "Regarde comment on fait."),
    ),
    s(
        "explain",
        ("Instead of taking all 7 at once, we step down to ten first.",
         "Ten is an easy place to stand."),
        ("Badala ya kutoa 7 zote mara moja, tunashuka hadi kumi kwanza.",
         "Kumi ni mahali rahisi pa kusimama."),
        ("Au lieu d'enlever les 7 d'un coup, on descend d'abord à dix.",
         "Dix est un endroit facile."),
    ),
    s(
        "multiChoice",
        ("How far is 15 from 10?",
         "Yes — 5 steps down."),
        ("15 iko mbali kiasi gani na 10?",
         "Ndiyo — hatua 5 chini."),
        ("À quelle distance 15 est-il de 10 ?",
         "Oui — 5 pas vers le bas."),
        prompt={"en": "15 − ? = 10", "sw": "15 − ? = 10", "fr": "15 − ? = 10"},
        choices={"en": ["4", "5", "7"], "sw": ["4", "5", "7"], "fr": ["4", "5", "7"]},
        choiceIndex=1,
    ),
    s(
        "explain",
        ("We have taken 5 of the 7 away. Two more still to go.",
         "7 is 5 and 2."),
        ("Tumetoa 5 kati ya 7. Zimebaki 2 zaidi.",
         "7 ni 5 na 2."),
        ("Nous avons enlevé 5 des 7. Il en reste 2 à enlever.",
         "7 c'est 5 et 2."),
    ),
    s(
        "numberAnswer",
        ("Take the last 2 from our ten.",
         "8! And 15 − 7 = 8."),
        ("Toa 2 za mwisho kutoka kwa kumi yetu.",
         "8! Na 15 − 7 = 8."),
        ("Enlève les 2 derniers de notre dix.",
         "8 ! Et 15 − 7 = 8."),
        prompt={"en": "10 − 2 = ?", "sw": "10 − 2 = ?", "fr": "10 − 2 = ?"},
        answer=8,
    ),
    s(
        "explain",
        ("Down to ten, then down again. That is the whole trick.",
         "Now you try some."),
        ("Shuka hadi kumi, kisha shuka tena. Hiyo ndiyo njia yote.",
         "Sasa jaribu wewe."),
        ("Descendre à dix, puis descendre encore. C'est toute l'astuce.",
         "Maintenant essaie."),
    ),
    s(
        "multiChoice",
        ("This one lands on ten in a single step.",
         "16 − 6 = 10. Straight to ten!"),
        ("Hii inafika kumi kwa hatua moja.",
         "16 − 6 = 10. Moja kwa moja hadi kumi!"),
        ("Celle-ci arrive à dix en un seul pas.",
         "16 − 6 = 10. Direct à dix !"),
        prompt={"en": "16 − 6 = ?", "sw": "16 − 6 = ?", "fr": "16 − 6 = ?"},
        choices={"en": ["9", "10", "12"], "sw": ["9", "10", "12"], "fr": ["9", "10", "12"]},
        choiceIndex=1,
    ),
    s(
        "numberAnswer",
        ("14 − 5. Step down to ten, then take what is left.",
         "9! Four to reach ten, then one more."),
        ("14 − 5. Shuka hadi kumi, kisha toa kilichobaki.",
         "9! Nne kufika kumi, kisha moja zaidi."),
        ("14 − 5. Descends à dix, puis enlève le reste.",
         "9 ! Quatre pour atteindre dix, puis un de plus."),
        prompt={"en": "14 − 5 = ?", "sw": "14 − 5 = ?", "fr": "14 − 5 = ?"},
        answer=9,
    ),
    s(
        "numberAnswer",
        ("One more on your own: 13 − 4.",
         "9! You are subtracting like a mathematician."),
        ("Moja zaidi peke yako: 13 − 4.",
         "9! Unatoa kama mwanahisabati."),
        ("Encore une tout seul : 13 − 4.",
         "9 ! Tu soustrais comme un mathématicien."),
        prompt={"en": "13 − 4 = ?", "sw": "13 − 4 = ?", "fr": "13 − 4 = ?"},
        answer=9,
    ),
]

LESSONS["s07.math.lesson.04"] = [
    s(
        "explain",
        ("Big numbers are made of tens and ones. Look at 47.",
         "Two digits, two jobs."),
        ("Namba kubwa zimeundwa na makumi na mamoja. Angalia 47.",
         "Tarakimu mbili, kazi mbili."),
        ("Les grands nombres sont faits de dizaines et d'unités. Regarde 47.",
         "Deux chiffres, deux rôles."),
    ),
    s(
        "explain",
        ("The 4 is not really four. It means four bundles of ten: 40.",
         "Where a digit stands changes what it is worth."),
        ("4 si nne hasa. Inamaanisha mafungu manne ya kumi: 40.",
         "Mahali tarakimu inaposimama hubadilisha thamani yake."),
        ("Le 4 n'est pas vraiment quatre. Il veut dire quatre paquets de dix : 40.",
         "La place d'un chiffre change sa valeur."),
    ),
    s(
        "multiChoice",
        ("Count the bundles of ten in 47.",
         "Four tens — that is 40."),
        ("Hesabu mafungu ya kumi katika 47.",
         "Makumi manne — hiyo ni 40."),
        ("Compte les paquets de dix dans 47.",
         "Quatre dizaines — cela fait 40."),
        prompt={
            "en": "How many tens are in 47?",
            "sw": "Kuna makumi mangapi katika 47?",
            "fr": "Combien de dizaines y a-t-il dans 47 ?",
        },
        choices={"en": ["4", "7", "40"], "sw": ["4", "7", "40"], "fr": ["4", "7", "40"]},
        choiceIndex=0,
    ),
    s(
        "numberAnswer",
        ("The loose ones are the leftovers that could not make a bundle.",
         "7 ones. So 47 is 40 and 7."),
        ("Mamoja yaliyobaki ni yale yasiyoweza kufanya fungu.",
         "Mamoja 7. Kwa hiyo 47 ni 40 na 7."),
        ("Les unités sont ce qui reste et ne fait pas un paquet.",
         "7 unités. Donc 47 c'est 40 et 7."),
        prompt={
            "en": "How many ones are in 47?",
            "sw": "Kuna mamoja mangapi katika 47?",
            "fr": "Combien d'unités y a-t-il dans 47 ?",
        },
        answer=7,
    ),
    s(
        "explain",
        ("Say it out loud: forty… seven. The number tells you its own parts.",
         "Every two-digit number works this way."),
        ("Sema kwa sauti: arobaini… saba. Namba yenyewe inakuambia sehemu zake.",
         "Kila namba ya tarakimu mbili hufanya hivi."),
        ("Dis-le à voix haute : quarante… sept. Le nombre annonce ses parties.",
         "Tous les nombres à deux chiffres marchent ainsi."),
    ),
    s(
        "multiChoice",
        ("Now backwards: build the number from its parts.",
         "6 tens and 2 ones is 62."),
        ("Sasa kinyume: unda namba kutoka sehemu zake.",
         "Makumi 6 na mamoja 2 ni 62."),
        ("Maintenant à l'envers : construis le nombre à partir de ses parties.",
         "6 dizaines et 2 unités font 62."),
        prompt={
            "en": "Which number has 6 tens and 2 ones?",
            "sw": "Ni namba ipi yenye makumi 6 na mamoja 2?",
            "fr": "Quel nombre a 6 dizaines et 2 unités ?",
        },
        choices={"en": ["26", "62", "620"], "sw": ["26", "62", "620"], "fr": ["26", "62", "620"]},
        choiceIndex=1,
    ),
    s(
        "numberAnswer",
        ("Careful with this one — there are no loose ones at all.",
         "80. A zero holds the ones place open."),
        ("Kuwa makini na hii — hakuna mamoja yaliyobaki kabisa.",
         "80. Sifuri inashikilia nafasi ya mamoja."),
        ("Attention à celui-ci — il n'y a aucune unité.",
         "80. Le zéro garde la place des unités."),
        prompt={
            "en": "8 tens and 0 ones = ?",
            "sw": "Makumi 8 na mamoja 0 = ?",
            "fr": "8 dizaines et 0 unité = ?",
        },
        answer=80,
    ),
    s(
        "multiChoice",
        ("Tens are worth more than ones, so look at the tens first.",
         "85 has 8 tens; 58 has only 5."),
        ("Makumi yana thamani zaidi ya mamoja, kwa hiyo angalia makumi kwanza.",
         "85 ina makumi 8; 58 ina 5 tu."),
        ("Les dizaines valent plus que les unités, alors regarde-les d'abord.",
         "85 a 8 dizaines ; 58 n'en a que 5."),
        prompt={
            "en": "Which is bigger, 58 or 85?",
            "sw": "Ipi ni kubwa, 58 au 85?",
            "fr": "Lequel est plus grand, 58 ou 85 ?",
        },
        choices={"en": ["58", "85"], "sw": ["58", "85"], "fr": ["58", "85"]},
        choiceIndex=1,
    ),
    s(
        "numberAnswer",
        ("Last one: build 5 tens and 9 ones.",
         "59! You can read any number now."),
        ("Ya mwisho: unda makumi 5 na mamoja 9.",
         "59! Sasa unaweza kusoma namba yoyote."),
        ("La dernière : construis 5 dizaines et 9 unités.",
         "59 ! Tu peux lire n'importe quel nombre maintenant."),
        prompt={
            "en": "5 tens and 9 ones = ?",
            "sw": "Makumi 5 na mamoja 9 = ?",
            "fr": "5 dizaines et 9 unités = ?",
        },
        answer=59,
    ),
]

LESSONS["s07.math.lesson.06"] = [
    s(
        "explain",
        ("Coins are small, but each one is worth a different amount.",
         "Size does not tell you the value — the number does."),
        ("Sarafu ni ndogo, lakini kila moja ina thamani tofauti.",
         "Ukubwa hauonyeshi thamani — namba ndiyo inayoonyesha."),
        ("Les pièces sont petites, mais chacune a une valeur différente.",
         "La taille ne dit pas la valeur — le chiffre si."),
    ),
    s(
        "multiChoice",
        ("Read the number on each coin.",
         "10 is worth more than 5, even if the coin looks smaller."),
        ("Soma namba iliyo kwenye kila sarafu.",
         "10 ina thamani zaidi ya 5, hata kama sarafu inaonekana ndogo."),
        ("Lis le nombre sur chaque pièce.",
         "10 vaut plus que 5, même si la pièce paraît plus petite."),
        prompt={
            "en": "Which is worth more, a 5 or a 10?",
            "sw": "Ipi ina thamani zaidi, 5 au 10?",
            "fr": "Laquelle vaut plus, une 5 ou une 10 ?",
        },
        choices={"en": ["5", "10"], "sw": ["5", "10"], "fr": ["5", "10"]},
        choiceIndex=1,
    ),
    s(
        "count",
        ("Tap each coin in the pile to count them.",
         "Three coins — but we still do not know how much money that is."),
        ("Gusa kila sarafu kwenye rundo ili uzihesabu.",
         "Sarafu tatu — lakini bado hatujui ni pesa kiasi gani."),
        ("Touche chaque pièce du tas pour les compter.",
         "Trois pièces — mais on ne sait pas encore combien d'argent."),
        count=3,
    ),
    s(
        "explain",
        ("Counting coins is not the same as counting money.",
         "To find the money, add the values."),
        ("Kuhesabu sarafu si sawa na kuhesabu pesa.",
         "Ili kupata pesa, jumlisha thamani zake."),
        ("Compter les pièces n'est pas compter l'argent.",
         "Pour trouver l'argent, additionne les valeurs."),
    ),
    s(
        "numberAnswer",
        ("Two coins marked 5.",
         "10! Two fives make a ten."),
        ("Sarafu mbili zenye alama ya 5.",
         "10! Tano mbili hufanya kumi."),
        ("Deux pièces marquées 5.",
         "10 ! Deux cinq font dix."),
        prompt={"en": "5 + 5 = ?", "sw": "5 + 5 = ?", "fr": "5 + 5 = ?"},
        answer=10,
    ),
    s(
        "numberAnswer",
        ("Now a 10, a 5 and a 1 together.",
         "16. Add the big ones first — it is easier."),
        ("Sasa 10, 5 na 1 pamoja.",
         "16. Jumlisha kubwa kwanza — ni rahisi zaidi."),
        ("Maintenant une 10, une 5 et une 1 ensemble.",
         "16. Additionne les grandes d'abord — c'est plus facile."),
        prompt={"en": "10 + 5 + 1 = ?", "sw": "10 + 5 + 1 = ?", "fr": "10 + 5 + 1 = ?"},
        answer=16,
    ),
    s(
        "multiChoice",
        ("You have 20. The mango costs 15.",
         "Yes — 20 is more than 15, so you can buy it."),
        ("Una 20. Embe linagharimu 15.",
         "Ndiyo — 20 ni zaidi ya 15, kwa hiyo unaweza kulinunua."),
        ("Tu as 20. La mangue coûte 15.",
         "Oui — 20 est plus que 15, tu peux l'acheter."),
        prompt={
            "en": "Do you have enough to buy the mango?",
            "sw": "Una pesa za kutosha kununua embe?",
            "fr": "As-tu assez pour acheter la mangue ?",
        },
        choices={"en": ["Yes", "No"], "sw": ["Ndiyo", "Hapana"], "fr": ["Oui", "Non"]},
        choiceIndex=0,
    ),
    s(
        "numberAnswer",
        ("The seller gives back what is left over. That is your change.",
         "5 back. Now you know how to check your change."),
        ("Muuzaji anarudisha kilichobaki. Hiyo ndiyo chenji yako.",
         "Unarudishiwa 5. Sasa unajua kuangalia chenji yako."),
        ("Le vendeur rend ce qui reste. C'est ta monnaie.",
         "5 rendus. Tu sais vérifier ta monnaie maintenant."),
        prompt={"en": "20 − 15 = ?", "sw": "20 − 15 = ?", "fr": "20 − 15 = ?"},
        answer=5,
    ),
    s(
        "multiChoice",
        ("Sometimes different coins make the same amount.",
         "10 + 1 makes 11. 5 + 5 only makes 10."),
        ("Wakati mwingine sarafu tofauti hufanya kiasi kile kile.",
         "10 + 1 hufanya 11. 5 + 5 hufanya 10 tu."),
        ("Parfois des pièces différentes font le même montant.",
         "10 + 1 font 11. 5 + 5 ne font que 10."),
        prompt={
            "en": "Which coins make 11?",
            "sw": "Ni sarafu zipi zinazofanya 11?",
            "fr": "Quelles pièces font 11 ?",
        },
        choices={"en": ["10 + 1", "5 + 5"], "sw": ["10 + 1", "5 + 5"], "fr": ["10 + 1", "5 + 5"]},
        choiceIndex=0,
    ),
]

LESSONS["s07.reading.lesson.01"] = [
    s(
        "explain",
        ("Read this word slowly: cap. /c/ /a/ /p/.",
         "Short and quick — the a says /a/."),
        ("Soma neno hili polepole: cap. /c/ /a/ /p/.",
         "Fupi na haraka — a inasema /a/."),
        ("Lis ce mot lentement : cap. /c/ /a/ /p/.",
         "Court et rapide — le a dit /a/."),
    ),
    s(
        "explain",
        ("Now watch. We add one letter at the end: cape.",
         "The word changed, and so did the middle sound."),
        ("Sasa tazama. Tunaongeza herufi moja mwishoni: cape.",
         "Neno limebadilika, na sauti ya katikati pia."),
        ("Regarde. On ajoute une lettre à la fin : cape.",
         "Le mot a changé, et le son du milieu aussi."),
    ),
    s(
        "multiChoice",
        ("Read it again: cape. The new e is silent — you never say it out loud.",
         "cape. The e is there but stays quiet."),
        ("Soma tena: cape. e mpya haisemwi — huwa husemi kwa sauti.",
         "cape. e ipo lakini inakaa kimya."),
        ("Lis encore : cape. Le nouveau e est muet — on ne le prononce jamais.",
         "cape. Le e est là mais reste silencieux."),
        prompt={
            "en": "cap + e makes which word?",
            "sw": "cap + e hufanya neno lipi?",
            "fr": "cap + e donne quel mot ?",
        },
        choices={"en": ["cape", "capp", "caper"], "sw": ["cape", "capp", "caper"],
                 "fr": ["cape", "capp", "caper"]},
        choiceIndex=0,
    ),
    s(
        "explain",
        ("Here is the magic: silent e makes the vowel read its own name. A says 'ay'.",
         "cap becomes cape. hop becomes hope."),
        ("Hii ndiyo ajabu: e isiyosemwa hufanya vokali isome jina lake. A inasema 'ei'.",
         "cap inakuwa cape. hop inakuwa hope."),
        ("Voici la magie : le e muet fait lire son nom à la voyelle. A dit « eï ».",
         "cap devient cape. hop devient hope."),
    ),
    s(
        "multiChoice",
        ("Look for the quiet e at the end of the word.",
         "hope has it. hop and hopping do not."),
        ("Tafuta e ya kimya mwishoni mwa neno.",
         "hope inayo. hop na hopping hazina."),
        ("Cherche le e silencieux à la fin du mot.",
         "hope l'a. hop et hopping non."),
        prompt={
            "en": "Which word has a silent e?",
            "sw": "Neno lipi lina e isiyosemwa?",
            "fr": "Quel mot a un e muet ?",
        },
        choices={"en": ["hop", "hope", "hopping"], "sw": ["hop", "hope", "hopping"],
                 "fr": ["hop", "hope", "hopping"]},
        choiceIndex=1,
    ),
    s(
        "explain",
        ("There is a second way vowels help each other. Two vowels together, one sound: rain.",
         "That is called a vowel team."),
        ("Kuna njia ya pili vokali kusaidiana. Vokali mbili pamoja, sauti moja: rain.",
         "Hiyo inaitwa timu ya vokali."),
        ("Il y a une deuxième façon : deux voyelles ensemble, un seul son : rain.",
         "Cela s'appelle une équipe de voyelles."),
    ),
    s(
        "multiChoice",
        ("Find the two letters doing the work in rain.",
         "a and i together say /ay/."),
        ("Tafuta herufi mbili zinazofanya kazi katika rain.",
         "a na i pamoja zinasema /ei/."),
        ("Trouve les deux lettres qui travaillent dans rain.",
         "a et i ensemble disent /eï/."),
        prompt={
            "en": "In 'rain', which letters work together?",
            "sw": "Katika 'rain', herufi zipi zinashirikiana?",
            "fr": "Dans « rain », quelles lettres travaillent ensemble ?",
        },
        choices={"en": ["r and n", "a and i", "i and n"], "sw": ["r na n", "a na i", "i na n"],
                 "fr": ["r et n", "a et i", "i et n"]},
        choiceIndex=1,
    ),
    s(
        "multiChoice",
        ("Listen for that same /ay/ sound in another word.",
         "train! Same team, same sound."),
        ("Sikiliza sauti ile ile ya /ei/ katika neno lingine.",
         "train! Timu ile ile, sauti ile ile."),
        ("Écoute le même son /eï/ dans un autre mot.",
         "train ! Même équipe, même son."),
        prompt={
            "en": "Which word has the same sound as rain?",
            "sw": "Neno lipi lina sauti sawa na rain?",
            "fr": "Quel mot a le même son que rain ?",
        },
        choices={"en": ["train", "ran", "run"], "sw": ["train", "ran", "run"],
                 "fr": ["train", "ran", "run"]},
        choiceIndex=0,
    ),
    s(
        "explain",
        ("Once you spot a team you can read a whole family: rain, pain, mail, tail.",
         "Four new words from one pattern."),
        ("Ukiona timu unaweza kusoma familia nzima: rain, pain, mail, tail.",
         "Maneno manne mapya kutoka mtindo mmoja."),
        ("Dès que tu vois une équipe, tu lis toute une famille : rain, pain, mail, tail.",
         "Quatre mots nouveaux avec un seul motif."),
    ),
    s(
        "multiChoice",
        ("Read this sentence: 'The tail is long.'",
         "tail — a and i again. You are reading with patterns now."),
        ("Soma sentensi hii: 'The tail is long.'",
         "tail — a na i tena. Sasa unasoma kwa mitindo."),
        ("Lis cette phrase : « The tail is long. »",
         "tail — encore a et i. Tu lis avec des motifs maintenant."),
        prompt={
            "en": "Which word has a vowel team?",
            "sw": "Neno lipi lina timu ya vokali?",
            "fr": "Quel mot a une équipe de voyelles ?",
        },
        choices={"en": ["The", "tail", "long"], "sw": ["The", "tail", "long"],
                 "fr": ["The", "tail", "long"]},
        choiceIndex=1,
    ),
]

LESSONS["s07.reading.lesson.03"] = [
    s(
        "explain",
        ("Sometimes two letters stand side by side and you hear both. Listen: bl in black.",
         "/b/ and /l/, close together but both there."),
        ("Wakati mwingine herufi mbili husimama pamoja na unasikia zote. Sikiliza: bl katika black.",
         "/b/ na /l/, karibu pamoja lakini zote zipo."),
        ("Parfois deux lettres se suivent et on entend les deux. Écoute : bl dans black.",
         "/b/ et /l/, tout près mais toutes les deux là."),
    ),
    s(
        "multiChoice",
        ("Say black slowly and listen to the very start.",
         "bl — that is a blend."),
        ("Sema black polepole na sikiliza mwanzo kabisa.",
         "bl — huo ni mchanganyiko."),
        ("Dis black lentement et écoute le tout début.",
         "bl — c'est un mélange."),
        prompt={
            "en": "Which blend starts 'black'?",
            "sw": "Mchanganyiko upi unaanza 'black'?",
            "fr": "Quel mélange commence « black » ?",
        },
        choices={"en": ["bl", "ck", "la"], "sw": ["bl", "ck", "la"], "fr": ["bl", "ck", "la"]},
        choiceIndex=0,
    ),
    s(
        "numberAnswer",
        ("A blend is two sounds, not one new sound.",
         "2 sounds. You can hear them both if you go slowly."),
        ("Mchanganyiko ni sauti mbili, si sauti mpya moja.",
         "Sauti 2. Unaweza kuzisikia zote ukienda polepole."),
        ("Un mélange, c'est deux sons, pas un son nouveau.",
         "2 sons. Tu les entends tous les deux en allant lentement."),
        prompt={
            "en": "How many sounds do you hear in 'bl'?",
            "sw": "Unasikia sauti ngapi katika 'bl'?",
            "fr": "Combien de sons entends-tu dans « bl » ?",
        },
        answer=2,
    ),
    s(
        "explain",
        ("Blends come in families too: st in stop, star, stand.",
         "Learn one blend, unlock many words."),
        ("Michanganyiko pia ina familia: st katika stop, star, stand.",
         "Jifunze mchanganyiko mmoja, fungua maneno mengi."),
        ("Les mélanges ont aussi des familles : st dans stop, star, stand.",
         "Apprends un mélange, ouvre beaucoup de mots."),
    ),
    s(
        "multiChoice",
        ("Which of these begins with that st sound?",
         "star. sun starts with just /s/."),
        ("Ni lipi kati ya haya linaanza na sauti hiyo ya st?",
         "star. sun linaanza na /s/ tu."),
        ("Lequel commence par ce son st ?",
         "star. sun commence par juste /s/."),
        prompt={
            "en": "Which word starts with 'st'?",
            "sw": "Neno lipi linaanza na 'st'?",
            "fr": "Quel mot commence par « st » ?",
        },
        choices={"en": ["sun", "star", "tap"], "sw": ["sun", "star", "tap"],
                 "fr": ["sun", "star", "tap"]},
        choiceIndex=1,
    ),
    s(
        "explain",
        ("Blends can hide at the end of a word too. Listen to the end of hand: /n/ /d/.",
         "nd — both sounds, right at the finish."),
        ("Michanganyiko inaweza kujificha mwishoni mwa neno pia. Sikiliza mwisho wa hand: /n/ /d/.",
         "nd — sauti zote mbili, mwishoni kabisa."),
        ("Les mélanges se cachent aussi à la fin. Écoute la fin de hand : /n/ /d/.",
         "nd — les deux sons, tout à la fin."),
    ),
    s(
        "multiChoice",
        ("Say each one and listen to the last part.",
         "sand ends with nd."),
        ("Sema kila moja na sikiliza sehemu ya mwisho.",
         "sand linaishia na nd."),
        ("Dis chacun et écoute la fin.",
         "sand finit par nd."),
        prompt={
            "en": "Which word ends with 'nd'?",
            "sw": "Neno lipi linaishia na 'nd'?",
            "fr": "Quel mot finit par « nd » ?",
        },
        choices={"en": ["sat", "sand", "san"], "sw": ["sat", "sand", "san"],
                 "fr": ["sat", "sand", "san"]},
        choiceIndex=1,
    ),
    s(
        "multiChoice",
        ("Here is a new word to sound out: frog.",
         "fr at the front. /f/ then /r/."),
        ("Hili ni neno jipya la kutamka: frog.",
         "fr mbele. /f/ kisha /r/."),
        ("Voici un mot nouveau à décoder : frog.",
         "fr au début. /f/ puis /r/."),
        prompt={
            "en": "Which blend do you see in 'frog'?",
            "sw": "Mchanganyiko upi unauona katika 'frog'?",
            "fr": "Quel mélange vois-tu dans « frog » ?",
        },
        choices={"en": ["fr", "og", "ro"], "sw": ["fr", "og", "ro"], "fr": ["fr", "og", "ro"]},
        choiceIndex=0,
    ),
    s(
        "explain",
        ("bl, st, nd, fr — you can now sound out words you have never seen before.",
         "That is what blends are for."),
        ("bl, st, nd, fr — sasa unaweza kutamka maneno ambayo hujawahi kuyaona.",
         "Hiyo ndiyo kazi ya michanganyiko."),
        ("bl, st, nd, fr — tu peux décoder des mots jamais vus.",
         "C'est à ça que servent les mélanges."),
    ),
]

LESSONS["s07.reading.lesson.06"] = [
    s(
        "explain",
        ("Listen to this little story. 'Bees live together in a hive.'",
         "One sentence so far. Keep listening."),
        ("Sikiliza hadithi hii ndogo. 'Nyuki wanaishi pamoja katika mzinga.'",
         "Sentensi moja hadi sasa. Endelea kusikiliza."),
        ("Écoute cette petite histoire. « Les abeilles vivent ensemble dans une ruche. »",
         "Une phrase pour l'instant. Continue d'écouter."),
    ),
    s(
        "explain",
        ("'Some bees find flowers. Some bees make honey. Some keep the hive clean.'",
         "Three more sentences. Notice what they are all about."),
        ("'Nyuki wengine hutafuta maua. Wengine hutengeneza asali. Wengine husafisha mzinga.'",
         "Sentensi tatu zaidi. Angalia zote zinahusu nini."),
        ("« Certaines abeilles cherchent des fleurs. D'autres font du miel. D'autres nettoient la ruche. »",
         "Trois phrases de plus. Remarque de quoi elles parlent."),
    ),
    s(
        "multiChoice",
        ("Before we think about the whole story, check one thing you heard.",
         "Honey. That is a detail — one fact from one sentence."),
        ("Kabla ya kufikiria hadithi nzima, angalia kitu kimoja ulichosikia.",
         "Asali. Hayo ni maelezo — ukweli mmoja kutoka sentensi moja."),
        ("Avant de penser à toute l'histoire, vérifie une chose entendue.",
         "Du miel. C'est un détail — un fait d'une seule phrase."),
        prompt={
            "en": "What do some bees make?",
            "sw": "Nyuki wengine hutengeneza nini?",
            "fr": "Que fabriquent certaines abeilles ?",
        },
        choices={
            "en": ["Honey", "Bread", "Shoes"],
            "sw": ["Asali", "Mkate", "Viatu"],
            "fr": ["Du miel", "Du pain", "Des chaussures"],
        },
        choiceIndex=0,
    ),
    s(
        "multiChoice",
        ("Now the whole story. Every sentence talked about bees doing a job.",
         "Yes — it is mostly about bees working together."),
        ("Kila sentensi imezungumzia nyuki wakifanya kazi.",
         "Ndiyo — inahusu zaidi nyuki wanaofanya kazi pamoja."),
        ("Chaque phrase parlait d'abeilles qui font un travail.",
         "Oui — cela parle surtout des abeilles qui travaillent ensemble."),
        prompt={
            "en": "What is this story mostly about?",
            "sw": "Hadithi hii inahusu zaidi nini?",
            "fr": "De quoi parle surtout cette histoire ?",
        },
        choices={
            "en": ["How bees work together", "How to bake a cake", "One bee's name"],
            "sw": ["Jinsi nyuki wanavyofanya kazi pamoja", "Jinsi ya kuoka keki",
                   "Jina la nyuki mmoja"],
            "fr": ["Comment les abeilles travaillent ensemble", "Comment faire un gâteau",
                   "Le nom d'une abeille"],
        },
        choiceIndex=0,
    ),
    s(
        "explain",
        ("That is the main idea: what most of the sentences are about.",
         "It is the whole story in a few words."),
        ("Hilo ndilo wazo kuu: sentensi nyingi zinahusu nini.",
         "Ni hadithi yote kwa maneno machache."),
        ("C'est l'idée principale : ce dont parlent la plupart des phrases.",
         "C'est toute l'histoire en quelques mots."),
    ),
    s(
        "multiChoice",
        ("The other sentences are details. They fill in the picture.",
         "'Some bees make honey' is one small detail, not the whole idea."),
        ("Sentensi nyingine ni maelezo. Zinakamilisha picha.",
         "'Wengine hutengeneza asali' ni maelezo madogo, si wazo lote."),
        ("Les autres phrases sont des détails. Elles complètent l'image.",
         "« D'autres font du miel » est un petit détail, pas l'idée entière."),
        prompt={
            "en": "Which one is a detail, not the main idea?",
            "sw": "Ni ipi ni maelezo, si wazo kuu?",
            "fr": "Laquelle est un détail, pas l'idée principale ?",
        },
        choices={
            "en": ["Bees work together", "Some bees make honey"],
            "sw": ["Nyuki wanafanya kazi pamoja", "Wengine hutengeneza asali"],
            "fr": ["Les abeilles travaillent ensemble", "D'autres font du miel"],
        },
        choiceIndex=1,
    ),
    s(
        "explain",
        ("A good title is the main idea, made short.",
         "Titles are a clue to what a story is about."),
        ("Kichwa kizuri ni wazo kuu, kikifanywa kifupi.",
         "Vichwa ni kidokezo cha hadithi inahusu nini."),
        ("Un bon titre, c'est l'idée principale en plus court.",
         "Les titres indiquent de quoi parle une histoire."),
    ),
    s(
        "multiChoice",
        ("Pick the title that fits our bee story.",
         "'Busy Bees' — short, and it says the main idea."),
        ("Chagua kichwa kinachofaa hadithi yetu ya nyuki.",
         "'Nyuki Wenye Shughuli' — kifupi, na kinasema wazo kuu."),
        ("Choisis le titre qui va à notre histoire d'abeilles.",
         "« Abeilles occupées » — court, et il dit l'idée principale."),
        prompt={
            "en": "Which title fits best?",
            "sw": "Kichwa kipi kinafaa zaidi?",
            "fr": "Quel titre convient le mieux ?",
        },
        choices={
            "en": ["Busy Bees", "My Red Bike"],
            "sw": ["Nyuki Wenye Shughuli", "Baiskeli Yangu Nyekundu"],
            "fr": ["Abeilles occupées", "Mon vélo rouge"],
        },
        choiceIndex=0,
    ),
    s(
        "explain",
        ("Now a brand new story. 'Rain fills the river. Plants drink. Animals come to the water.'",
         "Ask yourself: what are all three about?"),
        ("Sasa hadithi mpya kabisa. 'Mvua inajaza mto. Mimea inanywa. Wanyama wanakuja kwa maji.'",
         "Jiulize: zote tatu zinahusu nini?"),
        ("Maintenant une histoire toute neuve. « La pluie remplit la rivière. Les plantes boivent. "
         "Les animaux viennent à l'eau. »",
         "Demande-toi : de quoi parlent les trois ?"),
    ),
    s(
        "multiChoice",
        ("Find the idea that holds all three sentences together.",
         "Rain helps life grow. You found a main idea on your own!"),
        ("Tafuta wazo linaloshikilia sentensi zote tatu.",
         "Mvua husaidia uhai. Umepata wazo kuu mwenyewe!"),
        ("Trouve l'idée qui relie les trois phrases.",
         "La pluie aide la vie. Tu as trouvé l'idée principale seul !"),
        prompt={
            "en": "What is the main idea?",
            "sw": "Wazo kuu ni lipi?",
            "fr": "Quelle est l'idée principale ?",
        },
        choices={
            "en": ["Rain helps life grow", "Rivers are cold", "Animals can run"],
            "sw": ["Mvua husaidia uhai", "Mito ni baridi", "Wanyama hukimbia"],
            "fr": ["La pluie aide la vie", "Rivières froides", "Animaux qui courent"],
        },
        choiceIndex=0,
    ),
]

LESSONS["s07.writing.lesson.03"] = [
    s(
        "explain",
        ("Some words are things. Some words are doings. A doing word is a verb.",
         "run, jump, eat — all verbs."),
        ("Maneno mengine ni vitu. Mengine ni matendo. Neno la tendo ni kitenzi.",
         "kimbia, ruka, kula — vyote vitenzi."),
        ("Certains mots sont des choses. D'autres sont des actions. Un mot d'action est un verbe.",
         "courir, sauter, manger — tous des verbes."),
    ),
    s(
        "multiChoice",
        ("One of these you can do. The other you sit on.",
         "jump is the action. A chair is a thing."),
        ("Moja unaweza kufanya. Nyingine unakalia.",
         "ruka ni tendo. Kiti ni kitu."),
        ("L'un se fait. L'autre, on s'assoit dessus.",
         "sauter est l'action. Une chaise est une chose."),
        prompt={
            "en": "Which word is an action?",
            "sw": "Neno lipi ni tendo?",
            "fr": "Quel mot est une action ?",
        },
        choices={"en": ["chair", "jump"], "sw": ["kiti", "ruka"], "fr": ["chaise", "sauter"]},
        choiceIndex=1,
    ),
    s(
        "explain",
        ("Every sentence needs a verb, or nothing happens in it.",
         "'The girl runs.' Without runs, the girl just stands there."),
        ("Kila sentensi inahitaji kitenzi, vinginevyo hakuna kinachotokea.",
         "'Msichana anakimbia.' Bila anakimbia, msichana anasimama tu."),
        ("Chaque phrase a besoin d'un verbe, sinon rien ne se passe.",
         "« La fille court. » Sans court, la fille reste immobile."),
    ),
    s(
        "multiChoice",
        ("Find the doing word in this sentence: 'The dog barks.'",
         "barks. That is what the dog does."),
        ("Tafuta neno la tendo katika sentensi hii: 'Mbwa anabweka.'",
         "anabweka. Hicho ndicho mbwa anafanya."),
        ("Trouve le mot d'action : « Le chien aboie. »",
         "aboie. C'est ce que fait le chien."),
        prompt={
            "en": "Which word is the verb?",
            "sw": "Neno lipi ni kitenzi?",
            "fr": "Quel mot est le verbe ?",
        },
        choices={"en": ["dog", "barks"], "sw": ["mbwa", "anabweka"], "fr": ["chien", "aboie"]},
        choiceIndex=1,
    ),
    s(
        "explain",
        ("Verbs are not always loud or fast. Quiet things are verbs too: think, sleep, wait.",
         "If it is something you do, it is a verb."),
        ("Vitenzi si lazima viwe na sauti au haraka. Vitu tulivu pia ni vitenzi: fikiri, lala, subiri.",
         "Ikiwa ni kitu unachofanya, ni kitenzi."),
        ("Les verbes ne sont pas toujours bruyants. Les choses calmes aussi : penser, dormir, attendre.",
         "Si c'est quelque chose que tu fais, c'est un verbe."),
    ),
    s(
        "multiChoice",
        ("You lie still when you do this one — but you are still doing it.",
         "Yes, sleep is a verb."),
        ("Unalala tuli unapofanya hili — lakini bado unalifanya.",
         "Ndiyo, lala ni kitenzi."),
        ("On ne bouge pas en le faisant — mais on le fait quand même.",
         "Oui, dormir est un verbe."),
        prompt={
            "en": "Is 'sleep' a verb?",
            "sw": "Je, 'lala' ni kitenzi?",
            "fr": "Est-ce que « dormir » est un verbe ?",
        },
        choices={"en": ["Yes", "No"], "sw": ["Ndiyo", "Hapana"], "fr": ["Oui", "Non"]},
        choiceIndex=0,
    ),
    s(
        "multiChoice",
        ("Try a longer sentence: 'Amina reads a book.'",
         "reads. Amina is the person, book is the thing, reads is the doing."),
        ("Jaribu sentensi ndefu: 'Amina anasoma kitabu.'",
         "anasoma. Amina ni mtu, kitabu ni kitu, anasoma ni tendo."),
        ("Essaie une phrase plus longue : « Amina lit un livre. »",
         "lit. Amina est la personne, livre la chose, lit l'action."),
        prompt={
            "en": "Pick the verb.",
            "sw": "Chagua kitenzi.",
            "fr": "Choisis le verbe.",
        },
        choices={"en": ["Amina", "reads", "book"], "sw": ["Amina", "anasoma", "kitabu"],
                 "fr": ["Amina", "lit", "livre"]},
        choiceIndex=1,
    ),
    s(
        "explain",
        ("Change the verb and you change what happens. 'The bird sings.' 'The bird flies.'",
         "Same bird, two different actions."),
        ("Badilisha kitenzi na unabadilisha kinachotokea. 'Ndege anaimba.' 'Ndege anaruka.'",
         "Ndege yule yule, matendo mawili tofauti."),
        ("Change le verbe et tu changes l'action. « L'oiseau chante. » « L'oiseau vole. »",
         "Même oiseau, deux actions différentes."),
    ),
    s(
        "multiChoice",
        ("Only one of these can finish the sentence 'The bird ___.'",
         "flies. Blue and table are not doings."),
        ("Moja tu kati ya haya linaweza kukamilisha 'Ndege ___.'",
         "anaruka. Bluu na meza si matendo."),
        ("Un seul peut finir « L'oiseau ___. »",
         "vole. Bleu et table ne sont pas des actions."),
        prompt={
            "en": "Which verb fits?",
            "sw": "Kitenzi kipi kinafaa?",
            "fr": "Quel verbe convient ?",
        },
        choices={"en": ["flies", "blue", "table"], "sw": ["anaruka", "bluu", "meza"],
                 "fr": ["vole", "bleu", "table"]},
        choiceIndex=0,
    ),
]

LESSONS["s07.science.lesson.02"] = [
    s(
        "explain",
        ("A butterfly does not start as a butterfly. It starts as a tiny egg on a leaf.",
         "Smaller than a seed."),
        ("Kipepeo hakianzi kama kipepeo. Kinaanza kama yai dogo kwenye jani.",
         "Dogo kuliko mbegu."),
        ("Un papillon ne commence pas papillon. Il commence en petit œuf sur une feuille.",
         "Plus petit qu'une graine."),
    ),
    s(
        "explain",
        ("Out of the egg comes a caterpillar. It eats and eats and grows.",
         "Eating is its whole job."),
        ("Kutoka kwenye yai hutoka kiwavi. Hukula na kukula na kukua.",
         "Kula ni kazi yake yote."),
        ("De l'œuf sort une chenille. Elle mange, mange et grandit.",
         "Manger est tout son travail."),
    ),
    s(
        "multiChoice",
        ("Put the first two stages in order in your head.",
         "Caterpillar comes right after the egg."),
        ("Weka hatua mbili za kwanza kwa mpangilio kichwani mwako.",
         "Kiwavi hufuata mara baada ya yai."),
        ("Mets les deux premières étapes en ordre dans ta tête.",
         "La chenille vient juste après l'œuf."),
        prompt={
            "en": "What comes right after the egg?",
            "sw": "Nini hufuata mara baada ya yai?",
            "fr": "Qu'est-ce qui vient juste après l'œuf ?",
        },
        choices={"en": ["Caterpillar", "Butterfly"], "sw": ["Kiwavi", "Kipepeo"],
                 "fr": ["Chenille", "Papillon"]},
        choiceIndex=0,
    ),
    s(
        "explain",
        ("Then the caterpillar makes a hard case around itself. That case is a chrysalis.",
         "From outside, nothing seems to happen."),
        ("Kisha kiwavi hujitengenezea kifuko kigumu. Kifuko hicho ni buu.",
         "Kwa nje, inaonekana hakuna kinachotokea."),
        ("Puis la chenille se fabrique une coque dure. Cette coque est une chrysalide.",
         "De l'extérieur, rien ne semble se passer."),
    ),
    s(
        "multiChoice",
        ("Inside the chrysalis it is very busy indeed.",
         "It is changing its whole body."),
        ("Ndani ya buu kuna shughuli nyingi sana.",
         "Kinabadilisha mwili wake wote."),
        ("À l'intérieur de la chrysalide, c'est très actif.",
         "Il change tout son corps."),
        prompt={
            "en": "What is happening inside the chrysalis?",
            "sw": "Nini kinatokea ndani ya buu?",
            "fr": "Que se passe-t-il dans la chrysalide ?",
        },
        choices={
            "en": ["It is changing shape", "It is only sleeping", "Nothing at all"],
            "sw": ["Kinabadilisha umbo", "Kinalala tu", "Hakuna kitu kabisa"],
            "fr": ["Il change de forme", "Il dort seulement", "Rien du tout"],
        },
        choiceIndex=0,
    ),
    s(
        "explain",
        ("The case opens and a butterfly climbs out with new wings.",
         "The same animal — a completely new shape."),
        ("Kifuko hufunguka na kipepeo hutoka na mabawa mapya.",
         "Mnyama yule yule — umbo jipya kabisa."),
        ("La coque s'ouvre et un papillon sort avec de nouvelles ailes.",
         "Le même animal — une forme toute neuve."),
    ),
    s(
        "drag",
        ("Now you put all four in order: egg, caterpillar, chrysalis, butterfly.",
         "Egg, caterpillar, chrysalis, butterfly!"),
        ("Sasa weka zote nne kwa mpangilio: yai, kiwavi, buu, kipepeo.",
         "Yai, kiwavi, buu, kipepeo!"),
        ("Maintenant mets les quatre en ordre : œuf, chenille, chrysalide, papillon.",
         "Œuf, chenille, chrysalide, papillon !"),
        action="drag-order",
    ),
    s(
        "numberAnswer",
        ("Count the stages we named.",
         "4 stages, always in the same order."),
        ("Hesabu hatua tulizotaja.",
         "Hatua 4, kila wakati kwa mpangilio ule ule."),
        ("Compte les étapes nommées.",
         "4 étapes, toujours dans le même ordre."),
        prompt={
            "en": "How many stages are there?",
            "sw": "Kuna hatua ngapi?",
            "fr": "Combien y a-t-il d'étapes ?",
        },
        answer=4,
    ),
    s(
        "multiChoice",
        ("Then the butterfly lays eggs, and it all begins again.",
         "A cycle — it goes round and round for ever."),
        ("Kisha kipepeo hutaga mayai, na yote huanza tena.",
         "Mzunguko — huzunguka na kuzunguka milele."),
        ("Puis le papillon pond des œufs, et tout recommence.",
         "Un cycle — il tourne encore et encore."),
        prompt={
            "en": "What do we call something that repeats like this?",
            "sw": "Tunaita nini kitu kinachojirudia hivi?",
            "fr": "Comment appelle-t-on ce qui se répète ainsi ?",
        },
        choices={"en": ["A life cycle", "A straight line"],
                 "sw": ["Mzunguko wa maisha", "Mstari ulionyooka"],
                 "fr": ["Un cycle de vie", "Une ligne droite"]},
        choiceIndex=0,
    ),
]

LESSONS["s07.health.lesson.02"] = [
    s(
        "explain",
        ("Germs are living things far too small to see. They can sit on your hands.",
         "Clean-looking hands can still carry them."),
        ("Vijidudu ni viumbe hai vidogo sana visivyoonekana. Vinaweza kukaa mikononi yako.",
         "Mikono inayoonekana safi inaweza kuwa navyo."),
        ("Les microbes sont des êtres vivants trop petits à voir. Ils se posent sur tes mains.",
         "Des mains qui paraissent propres peuvent en porter."),
    ),
    s(
        "multiChoice",
        ("Germs get inside you through your mouth, so one moment matters most.",
         "Before eating. That is when hands go near your mouth."),
        ("Vijidudu huingia mwilini kupitia mdomo, kwa hiyo wakati mmoja ni muhimu zaidi.",
         "Kabla ya kula. Ndio wakati mikono inakaribia mdomo wako."),
        ("Les microbes entrent par la bouche, alors un moment compte le plus.",
         "Avant de manger. C'est là que les mains vont vers la bouche."),
        prompt={
            "en": "When is it most important to wash?",
            "sw": "Ni lini muhimu zaidi kunawa?",
            "fr": "Quand est-il le plus important de se laver ?",
        },
        choices={
            "en": ["Before eating", "After sleeping", "Before running"],
            "sw": ["Kabla ya kula", "Baada ya kulala", "Kabla ya kukimbia"],
            "fr": ["Avant de manger", "Après avoir dormi", "Avant de courir"],
        },
        choiceIndex=0,
    ),
    s(
        "explain",
        ("Three steps: wet your hands, rub on soap, then scrub.",
         "The scrubbing is the part that works."),
        ("Hatua tatu: tia maji mikononi, paka sabuni, kisha sugua.",
         "Kusugua ni sehemu inayofanya kazi."),
        ("Trois étapes : mouille tes mains, mets du savon, puis frotte.",
         "C'est le frottage qui agit."),
    ),
    s(
        "count",
        ("Scrubbing takes longer than you think. Tap a bubble for each slow count.",
         "Five slow counts — keep going that long every time."),
        ("Kusugua huchukua muda zaidi kuliko unavyofikiri. Gusa kiputo kwa kila hesabu ya polepole.",
         "Hesabu tano za polepole — endelea muda huo kila wakati."),
        ("Frotter prend plus longtemps qu'on croit. Touche une bulle à chaque compte lent.",
         "Cinq comptes lents — fais-le aussi longtemps chaque fois."),
        count=5,
    ),
    s(
        "explain",
        ("Do not forget between your fingers, and under your nails.",
         "Germs hide in the places we rush past."),
        ("Usisahau katikati ya vidole, na chini ya kucha.",
         "Vijidudu hujificha mahali tunapoharakisha."),
        ("N'oublie pas entre les doigts et sous les ongles.",
         "Les microbes se cachent là où on va trop vite."),
    ),
    s(
        "multiChoice",
        ("Water alone only pushes germs about. Soap lifts them off.",
         "Soap and water together. That is the pair that cleans."),
        ("Maji peke yake yanasukuma vijidudu tu. Sabuni inaviondoa.",
         "Sabuni na maji pamoja. Hiyo ndiyo jozi inayosafisha."),
        ("L'eau seule déplace les microbes. Le savon les décolle.",
         "Le savon et l'eau ensemble. Voilà la paire qui nettoie."),
        prompt={
            "en": "What washes germs away best?",
            "sw": "Nini husafisha vijidudu vizuri zaidi?",
            "fr": "Qu'est-ce qui enlève le mieux les microbes ?",
        },
        choices={
            "en": ["Water alone", "Soap and water"],
            "sw": ["Maji peke yake", "Sabuni na maji"],
            "fr": ["L'eau seule", "Le savon et l'eau"],
        },
        choiceIndex=1,
    ),
    s(
        "multiChoice",
        ("You have been playing outside in the dirt. What now?",
         "Wash your hands — before you touch food or your face."),
        ("Umekuwa unacheza nje kwenye udongo. Sasa nini?",
         "Nawa mikono — kabla ya kugusa chakula au uso wako."),
        ("Tu as joué dehors dans la terre. Et maintenant ?",
         "Lave-toi les mains — avant de toucher la nourriture ou ton visage."),
        prompt={
            "en": "What should you do first?",
            "sw": "Unapaswa kufanya nini kwanza?",
            "fr": "Que dois-tu faire d'abord ?",
        },
        choices={
            "en": ["Wash your hands", "Eat a snack"],
            "sw": ["Nawa mikono", "Kula kitafunio"],
            "fr": ["Te laver les mains", "Manger un goûter"],
        },
        choiceIndex=0,
    ),
    s(
        "explain",
        ("Last step: dry with a clean cloth. Wet hands pick germs up again.",
         "Clean, scrubbed, dry."),
        ("Hatua ya mwisho: kausha kwa kitambaa safi. Mikono yenye maji inachukua vijidudu tena.",
         "Safi, imesuguliwa, kavu."),
        ("Dernière étape : sèche avec un linge propre. Les mains mouillées reprennent des microbes.",
         "Propres, frottées, sèches."),
    ),
    s(
        "multiChoice",
        ("You know the whole routine now.",
         "Wet, soap, scrub, rinse, dry. Every time."),
        ("Sasa unajua utaratibu wote.",
         "Maji, sabuni, sugua, suuza, kausha. Kila wakati."),
        ("Tu connais toute la routine.",
         "Mouiller, savonner, frotter, rincer, sécher. Chaque fois."),
        prompt={
            "en": "Which step actually removes the germs?",
            "sw": "Hatua ipi hasa huondoa vijidudu?",
            "fr": "Quelle étape enlève vraiment les microbes ?",
        },
        choices={
            "en": ["Scrubbing with soap", "Looking at your hands"],
            "sw": ["Kusugua na sabuni", "Kutazama mikono yako"],
            "fr": ["Frotter avec du savon", "Regarder tes mains"],
        },
        choiceIndex=0,
    ),
]


# --------------------------------------------------------------------------
# Applier.
# --------------------------------------------------------------------------
LANGS = ("en", "sw", "fr")


def build_step(a: dict, lang: str) -> dict:
    """The library carries English; overlays carry the rest."""
    narration, feedback = a[lang]
    step = {
        "narration": narration,
        "action": a["action"],
        "feedback": feedback,
        "mechanic": a["mechanic"],
    }
    if "prompt" in a:
        step["prompt"] = a["prompt"][lang]
    if "choices" in a:
        step["choices"] = list(a["choices"][lang])
        step["choiceIndex"] = a["choiceIndex"]
    for k in ("answer", "count", "rows", "cols"):
        if k in a:
            step[k] = a[k]
    return step


def i18n_keys(item_id: str, steps: list[dict], lang: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for i, a in enumerate(steps):
        narration, feedback = a[lang]
        out[f"{item_id}.steps.{i}.narration"] = narration
        out[f"{item_id}.steps.{i}.feedback"] = feedback
        if "prompt" in a:
            out[f"{item_id}.steps.{i}.prompt"] = a["prompt"][lang]
        if "choices" in a:
            for o, label in enumerate(a["choices"][lang]):
                out[f"{item_id}.steps.{i}.choices.{o}"] = label
    return out


def apply(check_only: bool) -> int:
    lib = json.loads(LIBRARIES[0].read_text(encoding="utf-8"))
    by_id = {x["id"]: x for x in lib["content"]}

    missing = [k for k in LESSONS if k not in by_id]
    if missing:
        print(f"unknown ids: {missing}", file=sys.stderr)
        return 1

    problems = []
    for item_id, authored in LESSONS.items():
        if len(authored) < MIN_STEPS:
            problems.append(f"{item_id}: only {len(authored)} steps (need {MIN_STEPS})")
        for i, a in enumerate(authored):
            if "choices" in a:
                lens = {len(a["choices"][l]) for l in LANGS}
                if len(lens) != 1:
                    problems.append(f"{item_id} step {i}: choice counts differ across languages")
                if not 0 <= a["choiceIndex"] < min(lens):
                    problems.append(f"{item_id} step {i}: choiceIndex out of range")
            for l in LANGS:
                if len(a[l]) != 2 or not all(a[l]):
                    problems.append(f"{item_id} step {i}: {l} needs (narration, feedback)")
    if problems:
        print("authoring problems:\n  " + "\n  ".join(problems), file=sys.stderr)
        return 1

    if check_only:
        for item_id, authored in LESSONS.items():
            live = by_id[item_id].get("steps") or []
            if len(live) != len(authored):
                print(
                    f"drift: {item_id} has {len(live)} steps in the library, "
                    f"{len(authored)} authored here — run without --check",
                    file=sys.stderr,
                )
                return 1
        print(f"{len(LESSONS)} lessons match the library.")
        return 0

    for item_id, authored in LESSONS.items():
        by_id[item_id]["steps"] = [build_step(a, "en") for a in authored]

    for path in LIBRARIES:
        path.write_text(
            json.dumps(lib, indent=1, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n"
        )

    for d in I18N_DIRS:
        for lang in LANGS:
            f = d / f"{lang}.json"
            data = json.loads(f.read_text(encoding="utf-8"))
            for item_id, authored in LESSONS.items():
                # Drop every old step key first: the deepened lesson has more
                # steps than before, and a leftover key from the two-step
                # version would win over the new text at runtime.
                for k in [k for k in data if k.startswith(f"{item_id}.steps.")]:
                    del data[k]
                data.update(i18n_keys(item_id, authored, lang))
            f.write_text(
                json.dumps(data, indent=1, ensure_ascii=False, sort_keys=True) + "\n",
                encoding="utf-8", newline="\n",
            )

    steps = sum(len(v) for v in LESSONS.values())
    print(f"deepened {len(LESSONS)} lessons to {steps} steps, in {', '.join(LANGS)}")
    return 0


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--check", action="store_true", help="verify only; exit 1 on drift")
    sys.exit(apply(p.parse_args().check))
