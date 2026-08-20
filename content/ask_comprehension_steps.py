"""Give the remaining question-shaped tap steps options that answer them.

Why this exists
---------------
`ask_explanation_steps.py` fixed the 43 steps whose options the planner was
scraping out of the question. The same sweep found **125 more** that ask a
question and were *already* plain taps — never staged, never mis-scored, and
never answerable either. "Tap why the Nile mattered more than anything else
in Egypt" showed a picture and a continue button.

They were not a regression, so they were not urgent; they were simply a gap
nobody had counted. This script closes it.

Six of the 125 are deliberately left alone, because they have no right
answer and are not meant to:

  * s01.lang.lesson.05 step2   "Point with me. Tap what you see."
  * s03.emotions.lesson.01 s3  "Tap the face that matches how you feel now."
                               ("Whatever you picked is allowed.")
  * s04.semotional.lesson.04 s4 "Has someone said sorry to you? Tap how it
                               felt."
  * s06.tech.lesson.02 step6   "Sort your own toys ... and tap when done."
  * s06.tech.lesson.04 step5   "Make your own pattern ... and tap when done."
  * s07.health.lesson.06 s2    "Tap the road when it is clear."

Turning any of those into a quiz would be worse than leaving it: the first
three invite a child to answer for themselves, and the last three are a
prompt to go and do something away from the screen.

Every answer here is taken from the step's own `feedback`. Distractors are
the misconception the step exists to correct, or a claim an earlier step in
the same lesson makes.

**The Swahili and French are mine and have not been reviewed by a native
speaker**, in common with the rest of the app's non-English copy.

Options whose English *is* the lesson — English irregular verbs, apostrophes,
capitalisation, prefixes — keep their English and are registered in
`content/i18n/english_by_design.json`, the same register `check_i18n.py` and
`question_i18n_test.dart` read.

Idempotent: re-running makes no further change.

    python content/ask_comprehension_steps.py            # from the repo root
    python content/ask_comprehension_steps.py --check    # verify only
"""
from __future__ import annotations

import argparse
import json
import sys

from authoring import I18N_DIRS, LANGS, LIBRARIES, ROOT

MAX_OPTION = 22
ENGLISH_BY_DESIGN = ROOT / "content/i18n/english_by_design.json"

Option = tuple[str, str, str]


def en_only(*words: str) -> list[tuple[str, None, None]]:
    """Options whose English *is* the thing being taught."""
    return [(w, None, None) for w in words]


# Reasons used more than once, so the register reads consistently.
_ORTHOGRAPHY = "English orthography: capitals and apostrophes"
_MORPHOLOGY = "English morphology: irregular verbs and prefixes"

# item id -> step index -> (options, answer index, english-by-design reason)
STAGED: dict[str, dict[int, tuple[list, int, str | None]]] = {
    # "'Red!' Patterns can be longer than two."
    "s03.patterns.lesson.05": {
        2: ([
            ("Blue", "Buluu", "Bleu"),
            ("Red", "Nyekundu", "Rouge"),
            ("Green", "Kijani", "Vert"),
        ], 1, None),
    },
    # "'Thank you!' Straight away."
    "s04.social.lesson.05": {
        2: ([
            ("Nothing", "Hakuna kitu", "Rien"),
            ("Thank you!", "Asante!", "Merci !"),
            ("Give it back", "Kirudishe", "Rends-le"),
        ], 1, None),
    },
    # "At the very end. Now it stops properly."
    "s06.reading.lesson.06": {
        4: ([
            ("At the start", "Mwanzoni", "Au début"),
            ("At the very end", "Mwishoni kabisa", "Tout à la fin"),
            ("After each word", "Baada ya kila neno", "Après chaque mot"),
        ], 1, None),
    },
    # "Liquid! Heat changed its state."
    "s06.science.lesson.01": {
        6: ([
            ("A gas", "Gesi", "Un gaz"),
            ("A liquid", "Kimiminika", "Un liquide"),
            ("A solid", "Kigumu", "Un solide"),
        ], 1, None),
    },
    # "Water! The river is its home and its drink."
    "s06.science.lesson.02": {
        5: ([
            ("Sand", "Mchanga", "Du sable"),
            ("Water", "Maji", "De l'eau"),
            ("Sunlight", "Mwanga wa jua", "Du soleil"),
        ], 1, None),
    },
    "s06.tech.lesson.04": {
        # "'Red!' You see the pattern."
        0: ([
            ("Blue", "Buluu", "Bleu"),
            ("Red", "Nyekundu", "Rouge"),
            ("Green", "Kijani", "Vert"),
        ], 1, None),
        # "Circle! Two things, taking turns."
        2: ([
            ("Square", "Mraba", "Un carré"),
            ("Circle", "Duara", "Un cercle"),
            ("Triangle", "Pembetatu", "Un triangle"),
        ], 1, None),
        # "Drum! Patterns work in sound too."
        4: ([
            ("Bell", "Kengele", "La cloche"),
            ("Drum", "Ngoma", "Le tambour"),
            ("Whistle", "Filimbi", "Le sifflet"),
        ], 1, None),
    },
    "s07.reading.lesson.04": {
        # "The book. That is the what."
        4: ([
            ("The girl", "Msichana", "La fille"),
            ("The book", "Kitabu", "Le livre"),
            ("Reading", "Kusoma", "La lecture"),
        ], 1, None),
        # "The river. Sentences can answer where, too."
        5: ([
            ("The dog", "Mbwa", "Le chien"),
            ("The river", "Mto", "La rivière"),
            ("Running", "Kukimbia", "La course"),
        ], 1, None),
    },
    # "Nowhere! Go far enough and you come back round."
    "s07.social.lesson.02": {
        5: ([
            ("At the North Pole", "Kwenye Ncha ya Kaskazini", "Au pôle Nord"),
            ("Nowhere", "Hakuna mwisho", "Nulle part"),
            ("At the equator", "Kwenye ikweta", "À l'équateur"),
        ], 1, None),
    },
    "s08.tech.lesson.03": {
        # "Nothing at all. A false condition means the action never runs."
        4: ([
            ("It fills again", "Hujaa tena", "Elle se remplit"),
            ("Nothing at all", "Hakuna kitu", "Rien du tout"),
            ("It empties", "Humwagika", "Elle se vide"),
        ], 1, None),
    },
    # "The turn blocks. Wrong direction is usually one wrong turn, early on."
    "s08.tech.lesson.04": {
        4: ([
            ("The colours", "Rangi", "Les couleurs"),
            ("The turn blocks", "Vitalu vya kugeuza", "Les blocs de virage"),
            ("The last step", "Hatua ya mwisho", "La dernière étape"),
        ], 1, None),
    },
    "s08.tech.lesson.05": {
        # "Tell a grown-up you trust. Do not reply, and do not delete it."
        4: ([
            ("Reply to them", "Mjibu", "Leur répondre"),
            ("Tell a grown-up", "Mwambie mtu mzima", "Le dire à un adulte"),
            ("Delete it quietly", "Ifute kimyakimya",
             "L'effacer en silence"),
        ], 1, None),
        # "Where you live, your school, or a photo of either."
        5: ([
            ("A joke", "Utani", "Une blague"),
            ("Where you live", "Unapoishi", "Où tu habites"),
            ("Your favourite song", "Wimbo unaoupenda",
             "Ta chanson préférée"),
        ], 1, None),
        # "Other people may still have it. Deleting yours does not delete
        # theirs."
        6: ([
            ("It is gone forever", "Imetoweka milele", "Il disparaît à jamais"),
            ("Others still have it", "Wengine bado wanayo",
             "Les autres l'ont encore"),
            ("Nobody ever saw it", "Hakuna aliyeiona",
             "Personne ne l'a vu"),
        ], 1, None),
    },
    "s08.tech.lesson.06": {
        # "It gets blocky. Detail needs more squares, not bigger ones."
        4: ([
            ("It gets sharper", "Huwa wazi zaidi", "Elle devient nette"),
            ("It gets blocky", "Huwa na vibonye", "Elle devient floue"),
            ("It gets brighter", "Huwa angavu zaidi",
             "Elle devient plus vive"),
        ], 1, None),
        # "Millions of pixels instead of sixteen. Every one has to be stored."
        6: ([
            ("Photos are prettier", "Picha ni nzuri zaidi",
             "Les photos sont plus jolies"),
            ("Millions of pixels", "Pikseli milioni", "Des millions de pixels"),
            ("Photos use colour", "Picha hutumia rangi",
             "Les photos ont des couleurs"),
        ], 1, None),
    },
    # "They wrote both answers side by side instead of carrying."
    "s08.math.lesson.02": {
        5: ([
            ("To add the ones", "Kujumlisha mamoja", "Ajouter les unités"),
            ("To carry the ten", "Kubeba kumi", "Retenir la dizaine"),
            ("To line up digits", "Kupanga tarakimu", "Aligner les chiffres"),
        ], 1, None),
    },
    # "They read the number, not the fives. 4 means 20 minutes."
    "s08.math.lesson.06": {
        5: ([
            ("They counted in fives", "Walihesabu kwa tano",
             "Ils ont compté par cinq"),
            ("They read the number", "Walisoma tarakimu",
             "Ils ont lu le chiffre"),
            ("They used one hand", "Walitumia mkono mmoja",
             "Ils n'ont vu qu'une aiguille"),
        ], 1, None),
    },
    # "'cle' is not a word. A prefix only counts if a real word is left."
    "s08.reading.lesson.02": {
        5: (en_only("'un' is not a prefix", "'cle' is not a word",
                    "'uncle' is too short"), 1, _MORPHOLOGY),
    },
    "s08.reading.lesson.03": {
        # "Not wide. The rest of the sentence told you, not the word itself."
        3: ([
            ("Very long", "Ndefu sana", "Très long"),
            ("Not wide", "Si pana", "Pas large"),
            ("Very old", "Kongwe sana", "Très vieux"),
        ], 1, None),
        # "Very hungry. What she did next gave it away."
        4: ([
            ("Very tired", "Amechoka sana", "Très fatiguée"),
            ("Very hungry", "Ana njaa sana", "Très affamée"),
            ("Very angry", "Amekasirika sana", "Très en colère"),
        ], 1, None),
        # "Raining only a little. 'So we did not need' is the clue."
        6: ([
            ("Snowing hard", "Theluji nyingi", "Il neige fort"),
            ("Raining a little", "Mvua kidogo", "Il pleuvine"),
            ("Very windy", "Upepo mwingi", "Très venteux"),
        ], 1, None),
    },
    # "Waiting is what happens, not where. That is plot, not setting."
    "s08.reading.lesson.04": {
        5: ([
            ("It is too short", "Ni fupi mno", "C'est trop court"),
            ("It is not a place", "Si mahali", "Ce n'est pas un lieu"),
            ("Nothing is wrong", "Hakuna kosa", "Rien n'est faux"),
        ], 1, None),
    },
    # "Honey is one detail. A main idea has to cover all of them."
    "s08.reading.lesson.06": {
        5: ([
            ("It is not in the text", "Haipo kwenye maandishi",
             "Ce n'est pas dans le texte"),
            ("It is only one detail", "Ni kidokezo kimoja tu",
             "Ce n'est qu'un détail"),
            ("It is too long", "Ni ndefu mno", "C'est trop long"),
        ], 1, None),
    },
    "s08.science.lesson.01": {
        # "The fox does not feed the rabbit. The arrows would point backwards."
        4: ([
            ("Nothing goes wrong", "Hakuna tatizo", "Rien ne cloche"),
            ("The arrows flip", "Mishale hugeuka",
             "Les flèches s'inversent"),
            ("The fox gets bigger", "Mbweha hukua", "Le renard grandit"),
        ], 1, None),
        # "They go hungry. Remove one link and everything above it suffers."
        5: ([
            ("They grow in number", "Huongezeka", "Ils se multiplient"),
            ("They go hungry", "Hupata njaa", "Ils ont faim"),
            ("Nothing changes", "Hakuna mabadiliko", "Rien ne change"),
        ], 1, None),
    },
    # "Same substance, different state. Melting changes the state, not the
    # stuff."
    "s08.science.lesson.04": {
        5: ([
            ("Ice is heavier", "Barafu ni nzito", "La glace est plus lourde"),
            ("Same stuff, new state", "Kitu kilekile, hali mpya",
             "Même matière, autre état"),
            ("Water is warmer", "Maji ni ya joto", "L'eau est plus chaude"),
        ], 1, None),
    },
    # "Push apart. Same poles repel; opposite poles attract."
    "s08.science.lesson.06": {
        4: ([
            ("Pull together", "Huvutana", "Ils s'attirent"),
            ("Push apart", "Husukumana", "Ils se repoussent"),
            ("Do nothing", "Hakuna kinachotokea", "Rien ne se passe"),
        ], 1, None),
    },
    "s08.social.lesson.01": {
        # "'Pyramids were huge tombs for pharaohs.'"
        0: ([
            ("A royal palace", "Kasri la kifalme", "Un palais royal"),
            ("A tomb", "Kaburi", "Un tombeau"),
            ("A grain store", "Ghala la nafaka", "Un grenier"),
        ], 1, None),
        # "Tombs. Enormous stone graves for pharaohs and their belongings."
        3: ([
            ("Palaces", "Makasri", "Des palais"),
            ("Tombs", "Makaburi", "Des tombeaux"),
            ("Temples", "Mahekalu", "Des temples"),
        ], 1, None),
        # "It flooded every year and left rich soil."
        4: ([
            ("It was very long", "Ulikuwa mrefu sana", "Il était très long"),
            ("It left rich soil", "Uliacha udongo bora",
             "Il laissait un sol riche"),
            ("It was easy to cross", "Ulikuwa rahisi kuvuka",
             "Il était facile à traverser"),
        ], 1, None),
        # "The pictures stood for sounds and words, not just drawings."
        5: ([
            ("They were just art", "Yalikuwa sanaa tu",
             "C'était juste de l'art"),
            ("Pictures meant sounds", "Picha ziliwakilisha sauti",
             "Les images notaient des sons"),
            ("Only kings could read", "Wafalme pekee walisoma",
             "Seuls les rois lisaient"),
        ], 1, None),
    },
    "s08.social.lesson.02": {
        # "South. Opposites are always across the circle from each other."
        3: ([
            ("East", "Mashariki", "L'est"),
            ("South", "Kusini", "Le sud"),
            ("West", "Magharibi", "L'ouest"),
        ], 1, None),
        # "North is up on a map, not on the ground."
        6: ([
            ("North is downhill", "Kaskazini ni mteremko",
             "Le nord descend"),
            ("Maps are not hills", "Ramani si vilima",
             "Une carte n'est pas une colline"),
            ("Hills have no north", "Vilima havina kaskazini",
             "Les collines n'ont pas de nord"),
        ], 1, None),
    },
    "s08.social.lesson.03": {
        # "The council and the mayor — chosen by the people who live there."
        3: ([
            ("The shopkeepers", "Wafanyabiashara", "Les commerçants"),
            ("The elected council", "Halmashauri iliyochaguliwa",
             "Le conseil élu"),
            ("The oldest person", "Mtu mzee zaidi", "La personne la plus âgée"),
        ], 1, None),
        # "A leader can be voted out. That is the whole difference."
        4: ([
            ("A leader is older", "Kiongozi ni mzee zaidi",
             "Un chef est plus âgé"),
            ("A leader is elected", "Kiongozi huchaguliwa", "Un chef est élu"),
            ("A leader is richer", "Kiongozi ni tajiri zaidi",
             "Un chef est plus riche"),
        ], 1, None),
        # "Speak at a meeting, write to them, and vote differently next time."
        6: ([
            ("Nothing at all", "Hakuna kitu", "Rien du tout"),
            ("Speak up and vote", "Kusema na kupiga kura",
             "Parler et voter"),
            ("Move away", "Kuhama", "Déménager"),
        ], 1, None),
    },
    # "A river. The river is usually what cut the valley in the first place."
    "s08.social.lesson.04": {
        4: ([
            ("A road", "Barabara", "Une route"),
            ("A river", "Mto", "Une rivière"),
            ("A wall", "Ukuta", "Un mur"),
        ], 1, None),
    },
    "s08.social.lesson.05": {
        # "A consumer. The same person swaps roles many times a day."
        4: ([
            ("A producer", "Mzalishaji", "Un producteur"),
            ("A consumer", "Mlaji", "Un consommateur"),
            ("A seller", "Muuzaji", "Un vendeur"),
        ], 1, None),
        # "Making with nobody buying is waste; buying with nobody making is
        # nothing."
        5: ([
            ("Producers earn more", "Wazalishaji hupata zaidi",
             "Les producteurs gagnent plus"),
            ("One needs the other", "Kila mmoja humhitaji mwingine",
             "L'un a besoin de l'autre"),
            ("Consumers work less", "Walaji hufanya kazi kidogo",
             "Les consommateurs travaillent moins"),
        ], 1, None),
    },
    # "Enough food to last the winter. That used to be far from certain."
    "s08.social.lesson.06": {
        3: ([
            ("A day off work", "Siku ya mapumziko", "Un jour de congé"),
            ("Enough food for winter", "Chakula cha kutosha baridi",
             "Assez à manger pour l'hiver"),
            ("Good weather", "Hali nzuri ya hewa", "Le beau temps"),
        ], 1, None),
    },
    # "'Go' is irregular. Its past is 'went', and no rule predicts it."
    "s08.writing.lesson.01": {
        5: (en_only("The past is 'went'", "'Go' has no past",
                    "'Home' needs a capital"), 0, _MORPHOLOGY),
    },
    # "Length has nothing to do with it. Only names get capitals."
    "s08.writing.lesson.02": {
        5: (en_only("Names get capitals", "Long words do",
                    "Verbs get capitals"), 1, _ORTHOGRAPHY),
    },
    "s08.writing.lesson.04": {
        # "It's — short for 'it is'."
        5: (en_only("its raining", "it's raining"), 1, _ORTHOGRAPHY),
        # "Between n and t, where the 'o' of 'not' was removed."
        6: (en_only("do'nt", "don't", "dont'"), 1, _ORTHOGRAPHY),
    },
    # "One. Two points means you needed two paragraphs."
    "s08.writing.lesson.06": {
        5: ([
            ("Two", "Mbili", "Deux"),
            ("One", "Moja", "Un"),
            ("As many as you like", "Nyingi upendavyo",
             "Autant que tu veux"),
        ], 1, None),
    },

    # ---- stage 9 ----------------------------------------------------------
    "s09.coding.lesson.02": {
        # "The first. The else branch is skipped entirely."
        4: ([
            ("The else branch", "Tawi la else", "La branche else"),
            ("The first branch", "Tawi la kwanza", "La première branche"),
            ("Both of them", "Zote mbili", "Les deux"),
        ], 1, None),
        # "Nothing happens when it is warm — which may be fine, or the bug."
        5: ([
            ("The condition", "Sharti", "La condition"),
            ("The warm-day case", "Hali ya joto", "Le cas où il fait chaud"),
            ("The coat", "Koti", "Le manteau"),
        ], 1, None),
    },
    # "'Right' is not a measurement. The follower has to guess."
    "s09.coding.lesson.06": {
        4: ([
            ("It is too short", "Ni fupi mno", "C'est trop court"),
            ("'Right' is a guess", "'Sahihi' ni kubahatisha",
             "« Bonne » est un devinette"),
            ("Salt is not needed", "Chumvi haihitajiki",
             "Le sel est inutile"),
        ], 1, None),
    },
    # "Division does not flip like multiplication. The whole comes first."
    "s09.math.lesson.01": {
        5: ([
            ("6 is the wrong answer", "6 si jibu sahihi",
             "6 est un mauvais résultat"),
            ("Division cannot flip", "Kugawanya hakugeuki",
             "La division ne s'inverse pas"),
            ("24 is too big", "24 ni kubwa mno", "24 est trop grand"),
        ], 1, None),
    },
    # "Fractions need equal parts. Four pieces is not four quarters."
    "s09.math.lesson.02": {
        5: ([
            ("There are too few", "Ni chache mno", "Il y en a trop peu"),
            ("The parts are unequal", "Sehemu si sawa",
             "Les parts sont inégales"),
            ("A cake has no parts", "Keki haina sehemu",
             "Un gâteau n'a pas de parts"),
        ], 1, None),
    },
    # "They wrote the zero beside the 6 instead of multiplying by 2 first."
    "s09.math.lesson.04": {
        5: ([
            ("They added instead", "Walijumlisha badala yake",
             "Ils ont additionné"),
            ("They just added a 0", "Waliongeza sifuri tu",
             "Ils ont juste mis un 0"),
            ("They forgot the 6", "Walisahau 6", "Ils ont oublié le 6"),
        ], 1, None),
    },
    "s09.math.lesson.06": {
        # "If each step is worth 2, that bar is 10. The scale changes
        # everything."
        5: ([
            ("The bar is too short", "Mstari ni mfupi mno",
             "La barre est trop courte"),
            ("Each step may be 2", "Kila hatua yaweza kuwa 2",
             "Chaque pas peut valoir 2"),
            ("Bars cannot be read", "Mistari haisomeki",
             "Les barres sont illisibles"),
        ], 1, None),
        # "Nicest is an opinion. Graphs count things; they do not judge them."
        6: ([
            ("Which pet is common", "Mnyama gani ni wa kawaida",
             "Quel animal est courant"),
            ("Which pet is nicest", "Mnyama gani ni mzuri zaidi",
             "Quel animal est le plus gentil"),
        ], 1, None),
    },
    "s09.reading.lesson.01": {
        # "A simile — the word 'like' gives it away every time."
        3: ([
            ("A metaphor", "Sitiari", "Une métaphore"),
            ("A simile", "Tashbihi", "Une comparaison"),
            ("A fact", "Ukweli", "Un fait"),
        ], 1, None),
        # "A metaphor. It does not say like a zoo; it says it was one."
        4: ([
            ("A simile", "Tashbihi", "Une comparaison"),
            ("A metaphor", "Sitiari", "Une métaphore"),
            ("A fact", "Ukweli", "Un fait"),
        ], 1, None),
    },
    "s09.reading.lesson.02": {
        # "It is raining, and she is not pleased about it."
        3: ([
            ("She is going to bed", "Anaenda kulala", "Elle va se coucher"),
            ("It is raining", "Kunanyesha", "Il pleut"),
            ("She lost her coat", "Amepoteza koti",
             "Elle a perdu son manteau"),
        ], 1, None),
        # "He was very hungry, or ate very fast."
        4: ([
            ("He was not hungry", "Hakuwa na njaa", "Il n'avait pas faim"),
            ("He was very hungry", "Alikuwa na njaa sana",
             "Il avait très faim"),
            ("He cooked the meal", "Alipika chakula",
             "Il a préparé le repas"),
        ], 1, None),
        # "One meal is not a character. An inference stays near its clue."
        5: ([
            ("It is not written", "Haijaandikwa", "Ce n'est pas écrit"),
            ("One meal is not him", "Mlo mmoja si tabia",
             "Un repas n'est pas lui"),
            ("Ben is not real", "Ben si halisi", "Ben n'est pas réel"),
        ], 1, None),
    },
    "s09.reading.lesson.04": {
        # "The headings, or the contents list built from them."
        4: ([
            ("The first page", "Ukurasa wa kwanza", "La première page"),
            ("The headings", "Vichwa vya habari", "Les titres"),
            ("The pictures", "Picha", "Les images"),
        ], 1, None),
        # "That it matters, and is probably explained nearby."
        5: ([
            ("It is a mistake", "Ni kosa", "C'est une erreur"),
            ("It matters here", "Ni muhimu hapa", "C'est important ici"),
            ("It is a new page", "Ni ukurasa mpya", "C'est une page neuve"),
        ], 1, None),
    },
    "s09.reading.lesson.05": {
        # "Examples, numbers and side comments."
        4: ([
            ("The main point", "Hoja kuu", "L'idée principale"),
            ("The examples", "Mifano", "Les exemples"),
            ("The title", "Kichwa", "Le titre"),
        ], 1, None),
        # "A summary reports what the author said, not what you thought."
        5: ([
            ("It was too short", "Ilikuwa fupi mno", "C'était trop court"),
            ("It is not the author's", "Si ya mwandishi",
             "Ce n'est pas l'auteur"),
            ("Opinions are wrong", "Maoni ni makosa",
             "Les avis sont faux"),
        ], 1, None),
    },
    # "Persuading text picks the facts that help it."
    "s09.reading.lesson.06": {
        5: ([
            ("Adverts are all true", "Matangazo yote ni kweli",
             "Les pubs sont vraies"),
            ("It leaves facts out", "Huacha baadhi ya ukweli",
             "Elle omet des faits"),
            ("Adverts are too long", "Matangazo ni marefu mno",
             "Les pubs sont longues"),
        ], 1, None),
    },
    "s09.science.lesson.02": {
        # "Camouflage. It works on the eyes of whatever is hunting it."
        4: ([
            ("Migration", "Uhamaji", "La migration"),
            ("Camouflage", "Kujificha kwa rangi", "Le camouflage"),
            ("Hibernation", "Usingizi wa baridi", "L'hibernation"),
        ], 1, None),
        # "They solve heat and thirst. The Arctic sets the opposite problems."
        5: ([
            ("Camels are too big", "Ngamia ni wakubwa mno",
             "Les chameaux sont trop gros"),
            ("The Arctic is cold", "Aktiki ni baridi",
             "L'Arctique est froid"),
            ("Camels cannot walk", "Ngamia hawawezi kutembea",
             "Les chameaux ne marchent pas"),
        ], 1, None),
    },
    "s09.science.lesson.03": {
        # "Eats more rabbits. A web bends where a chain would snap."
        4: ([
            ("It goes hungry", "Hupata njaa", "Il a faim"),
            ("It eats more rabbits", "Hula sungura zaidi",
             "Il mange plus de lapins"),
            ("It leaves the web", "Huondoka", "Il quitte le réseau"),
        ], 1, None),
        # "Every animal has somewhere else to turn. Variety is the safety."
        6: ([
            ("Webs are shorter", "Utando ni mfupi",
             "Les réseaux sont courts"),
            ("There is another way", "Kuna njia nyingine",
             "Il reste une autre voie"),
            ("Chains have no links", "Minyororo haina viungo",
             "Les chaînes n'ont pas de maillons"),
        ], 1, None),
    },
    # "That land was once under the sea."
    "s09.science.lesson.04": {
        4: ([
            ("Shells can climb", "Makombe hupanda",
             "Les coquilles grimpent"),
            ("It was once seabed", "Palikuwa chini ya bahari",
             "C'était le fond marin"),
            ("Someone left them", "Mtu aliziacha",
             "Quelqu'un les a posées"),
        ], 1, None),
    },
    "s09.science.lesson.05": {
        # "The same lift spread over more distance. Less push, for longer."
        3: ([
            ("It is shorter", "Ni fupi", "Elle est plus courte"),
            ("Less push, for longer", "Nguvu kidogo, muda mrefu",
             "Moins de force, plus longtemps"),
            ("It weighs less", "Ina uzito mdogo", "Elle pèse moins"),
        ], 1, None),
        # "Far from the pivot."
        4: ([
            ("Close to the pivot", "Karibu na egemeo", "Près du pivot"),
            ("Far from the pivot", "Mbali na egemeo", "Loin du pivot"),
            ("On the load itself", "Juu ya mzigo", "Sur la charge"),
        ], 1, None),
        # "The direction. You pull down, and the bucket comes up."
        5: ([
            ("The weight", "Uzito", "Le poids"),
            ("The direction", "Mwelekeo", "La direction"),
            ("The depth", "Kina", "La profondeur"),
        ], 1, None),
    },
    # "The Earth spins, which makes the Sun appear to move."
    "s09.science.lesson.06": {
        6: ([
            ("The Sun goes round", "Jua huzunguka", "Le Soleil tourne"),
            ("The Earth spins", "Dunia huzunguka", "La Terre tourne"),
            ("Neither one moves", "Hakuna kinachosogea",
             "Aucun des deux ne bouge"),
        ], 1, None),
    },
    # "They could never be found wrong."
    "s09.social.lesson.01": {
        5: ([
            ("Laws would be shorter", "Sheria zingekuwa fupi",
             "Les lois seraient courtes"),
            ("Nobody could check it", "Hakuna angeweza kuhakiki",
             "Personne ne les contrôlerait"),
            ("Judges would be busy", "Majaji wangekuwa na shughuli",
             "Les juges seraient occupés"),
        ], 1, None),
    },
    "s09.social.lesson.02": {
        # "The legend. Symbols mean nothing until the map defines them."
        3: ([
            ("The scale", "Kipimo", "L'échelle"),
            ("The legend", "Ufunguo wa ramani", "La légende"),
            ("The title", "Kichwa", "Le titre"),
        ], 1, None),
        # "Every distance comes out wildly wrong."
        5: ([
            ("The symbols change", "Alama hubadilika",
             "Les symboles changent"),
            ("Distances go wrong", "Umbali hukosea",
             "Les distances sont fausses"),
            ("The north moves", "Kaskazini husogea", "Le nord bouge"),
        ], 1, None),
    },
    "s09.social.lesson.05": {
        # "The right. Left is oldest, right is newest, always."
        3: ([
            ("The left end", "Upande wa kushoto", "À gauche"),
            ("The right end", "Upande wa kulia", "À droite"),
            ("The middle", "Katikati", "Au milieu"),
        ], 1, None),
        # "Little time passed between them. Distance on the line is time."
        5: ([
            ("They are alike", "Zinafanana", "Ils se ressemblent"),
            ("Little time passed", "Muda mfupi ulipita",
             "Peu de temps a passé"),
            ("One caused the other", "Moja ilisababisha nyingine",
             "L'un a causé l'autre"),
        ], 1, None),
    },
    # "Each one trades something: space for services, or quiet for choice."
    "s09.social.lesson.06": {
        6: ([
            ("Cities are bigger", "Miji ni mikubwa",
             "Les villes sont plus grandes"),
            ("Each trades something", "Kila moja hutoa kitu",
             "Chacun échange quelque chose"),
            ("Farms are older", "Mashamba ni ya zamani",
             "Les fermes sont plus vieilles"),
        ], 1, None),
    },
    "s09.writing.lesson.01": {
        # "The opinion. It goes first, so the reader knows what you argue."
        3: ([
            ("A reason", "Sababu", "Une raison"),
            ("The opinion", "Maoni", "L'opinion"),
            ("The closing", "Hitimisho", "La conclusion"),
        ], 1, None),
        # "A close that returns to the opinion."
        5: ([
            ("Another reason", "Sababu nyingine", "Une autre raison"),
            ("A closing sentence", "Sentensi ya kufunga",
             "Une phrase de clôture"),
            ("A longer opinion", "Maoni marefu zaidi",
             "Une opinion plus longue"),
        ], 1, None),
    },
    # "It gets clunky. Transitions are signposts, and too many is clutter."
    "s09.writing.lesson.02": {
        6: ([
            ("It reads better", "Husomeka vizuri", "Ça se lit mieux"),
            ("It gets cluttered", "Hujaa maneno", "Ça devient encombré"),
            ("It gets shorter", "Hufupika", "Ça raccourcit"),
        ], 1, None),
    },
    # "Quotation marks promise the exact words."
    "s09.writing.lesson.03": {
        5: ([
            ("It was too short", "Ilikuwa fupi mno", "C'était trop court"),
            ("The words changed", "Maneno yalibadilika",
             "Les mots ont changé"),
            ("Friends cannot speak", "Marafiki hawasemi",
             "On ne cite pas un ami"),
        ], 1, None),
    },
    # "Any doctor, not a named one. 'Doctor Amina' would take the capital."
    "s09.writing.lesson.04": {
        5: ([
            ("Doctors are important", "Madaktari ni muhimu",
             "Les médecins comptent"),
            ("It names no one", "Halitaji mtu yeyote",
             "Il ne nomme personne"),
            ("It is a long word", "Ni neno refu", "C'est un mot long"),
        ], 1, None),
    },
    # "The reader is doing it now."
    "s09.writing.lesson.05": {
        6: ([
            ("It sounds older", "Hisikika ya zamani", "Ça fait ancien"),
            ("The reader acts now", "Msomaji anatenda sasa",
             "Le lecteur agit maintenant"),
            ("It is easier to spell", "Ni rahisi kuandika",
             "C'est plus simple à écrire"),
        ], 1, None),
    },
    # "A capital at the start and a full stop at the end. Both, every time."
    "s09.writing.lesson.06": {
        3: ([
            ("Only a capital", "Herufi kubwa tu", "Juste une majuscule"),
            ("A capital and a stop", "Herufi kubwa na nukta",
             "Majuscule et point"),
            ("Only a full stop", "Nukta tu", "Juste un point"),
        ], 1, None),
    },

    # ---- stage 10 ---------------------------------------------------------
    # "The first. 'Or more' includes exactly ten, which is the usual trap."
    "s10.coding.lesson.04": {
        4: ([
            ("The else branch", "Tawi la else", "La branche else"),
            ("The first branch", "Tawi la kwanza", "La première branche"),
            ("Neither branch", "Hakuna tawi", "Aucune des deux"),
        ], 1, None),
    },
    # "Nothing reports it. A silent wrong answer is worse than a crash."
    "s10.coding.lesson.05": {
        6: ([
            ("It takes longer", "Huchukua muda mrefu", "C'est plus long"),
            ("Nothing reports it", "Hakuna kinachoripoti",
             "Rien ne le signale"),
            ("The code is longer", "Msimbo ni mrefu",
             "Le code est plus long"),
        ], 1, None),
    },
    # "Lower it. Somebody willing to be named can be checked."
    "s10.coding.lesson.06": {
        5: ([
            ("Raise it", "Iongeze", "L'augmenter"),
            ("Lower it", "Ipunguze", "La baisser"),
            ("Change nothing", "Usibadilishe", "Ne rien changer"),
        ], 1, None),
    },
    # "Far too small — a single digit where two belong."
    "s10.math.lesson.01": {
        6: ([
            ("Far too big", "Kubwa mno", "Bien trop grand"),
            ("Far too small", "Ndogo mno", "Bien trop petit"),
            ("Exactly right", "Sahihi kabisa", "Tout à fait juste"),
        ], 1, None),
    },
    # "The 3 x 4. Splitting only works if you add both parts back."
    "s10.math.lesson.02": {
        6: ([
            ("The 20 x 4", "20 x 4", "Le 20 x 4"),
            ("The 3 x 4", "3 x 4", "Le 3 x 4"),
            ("Nothing at all", "Hakuna kitu", "Rien du tout"),
        ], 1, None),
    },
    # "They added the bottoms too. The pieces cannot shrink halfway through."
    "s10.math.lesson.04": {
        6: ([
            ("They added the tops", "Walijumlisha juu",
             "Ils ont additionné le haut"),
            ("They added the bottoms", "Walijumlisha chini",
             "Ils ont additionné le bas"),
            ("They forgot to add", "Walisahau kujumlisha",
             "Ils ont oublié d'additionner"),
        ], 1, None),
    },
    # "Area covers a surface, so its unit is squared."
    "s10.math.lesson.06": {
        6: ([
            ("Metres are too small", "Mita ni ndogo mno",
             "Le mètre est trop petit"),
            ("Area needs squares", "Eneo hutumia mraba",
             "L'aire se mesure au carré"),
            ("Area has no unit", "Eneo halina kipimo",
             "L'aire n'a pas d'unité"),
        ], 1, None),
    },
    "s10.reading.lesson.01": {
        # "A metaphor. It says they were, not that they were like."
        4: ([
            ("A simile", "Tashbihi", "Une comparaison"),
            ("A metaphor", "Sitiari", "Une métaphore"),
            ("A fact", "Ukweli", "Un fait"),
        ], 1, None),
        # "A simile. One small word does all the marking."
        5: ([
            ("A metaphor", "Sitiari", "Une métaphore"),
            ("A simile", "Tashbihi", "Une comparaison"),
            ("A fact", "Ukweli", "Un fait"),
        ], 1, None),
    },
    "s10.reading.lesson.02": {
        # "Very easy. Nothing to do with cake."
        4: ([
            ("Very tasty", "Tamu sana", "Très bon"),
            ("Very easy", "Rahisi sana", "Très facile"),
            ("Very slow", "Polepole sana", "Très lent"),
        ], 1, None),
        # "Good luck. Its history is odd."
        5: ([
            ("Be careful", "Kuwa makini", "Fais attention"),
            ("Good luck", "Kila la heri", "Bonne chance"),
            ("Sit down", "Kaa chini", "Assieds-toi"),
        ], 1, None),
        # "Someone telling them. Idioms have to be learned, not reasoned out."
        6: ([
            ("A dictionary", "Kamusi", "Un dictionnaire"),
            ("Someone telling them", "Mtu wa kumweleza",
             "Que quelqu'un le dise"),
            ("Reading it again", "Kuisoma tena", "Le relire"),
        ], 1, None),
    },
    # "It names an event. A theme would be 'kindness builds friendship'."
    "s10.reading.lesson.03": {
        6: ([
            ("It is too short", "Ni fupi mno", "C'est trop court"),
            ("It names an event", "Hutaja tukio", "Il nomme un événement"),
            ("It is not in the book", "Haipo kitabuni",
             "Ce n'est pas dans le livre"),
        ], 1, None),
    },
    # "You feel it instead of watching it, and you know less than they do."
    "s10.reading.lesson.04": {
        6: ([
            ("The house changes", "Nyumba hubadilika", "La maison change"),
            ("You feel it, not watch", "Unahisi, huangalii",
             "On le ressent, on ne regarde pas"),
            ("The story gets longer", "Hadithi hurefuka",
             "L'histoire s'allonge"),
        ], 1, None),
    },
    # "A summary reports the author, not the reader."
    "s10.reading.lesson.05": {
        6: ([
            ("It was too long", "Ilikuwa ndefu mno", "C'était trop long"),
            ("It reports the reader", "Inaripoti msomaji",
             "Elle rapporte le lecteur"),
            ("Summaries are wrong", "Muhtasari ni makosa",
             "Les résumés sont faux"),
        ], 1, None),
    },
    "s10.reading.lesson.06": {
        # "It is cold. Nothing in the sentence says so."
        4: ([
            ("He is late", "Amechelewa", "Il est en retard"),
            ("It is cold", "Kuna baridi", "Il fait froid"),
            ("He is happy", "Ana furaha", "Il est content"),
        ], 1, None),
        # "The clock fits hunger just as well."
        6: ([
            ("Boredom is not a clue", "Uchovu si dalili",
             "L'ennui n'est pas un indice"),
            ("Hunger fits too", "Njaa nayo yafaa",
             "La faim convient aussi"),
            ("The clock is broken", "Saa imeharibika",
             "L'horloge est cassée"),
        ], 1, None),
    },
    "s10.social.lesson.01": {
        # "Longitude. They meet at the poles."
        4: ([
            ("Latitude", "Latitudo", "La latitude"),
            ("Longitude", "Longitudo", "La longitude"),
            ("The equator", "Ikweta", "L'équateur"),
        ], 1, None),
        # "The other one. One line is a whole circle round the world."
        5: ([
            ("The map", "Ramani", "La carte"),
            ("The other number", "Namba nyingine", "L'autre nombre"),
            ("The scale", "Kipimo", "L'échelle"),
        ], 1, None),
    },
    "s10.social.lesson.02": {
        # "The legislative branch. Writing the rule is its only job."
        4: ([
            ("The executive", "Utekelezaji", "L'exécutif"),
            ("The legislative", "Utungaji sheria", "Le législatif"),
            ("The judicial", "Mahakama", "Le judiciaire"),
        ], 1, None),
        # "Carries it out — the police, the schools, the offices that act."
        6: ([
            ("Writes it", "Huitunga", "Il l'écrit"),
            ("Carries it out", "Huitekeleza", "Il l'applique"),
            ("Judges it", "Huihukumu", "Il la juge"),
        ], 1, None),
    },
    "s10.social.lesson.03": {
        # "It rises. High demand and low supply push the same way."
        5: ([
            ("It falls", "Hushuka", "Il baisse"),
            ("It rises", "Hupanda", "Il monte"),
            ("It stays the same", "Hubaki vilevile", "Il ne change pas"),
        ], 1, None),
        # "The price falls. Supply and demand work in both directions."
        6: ([
            ("The price rises", "Bei hupanda", "Le prix monte"),
            ("The price falls", "Bei hushuka", "Le prix baisse"),
            ("The shop closes", "Duka hufungwa", "La boutique ferme"),
        ], 1, None),
    },
    "s10.social.lesson.05": {
        # "Its libraries and scholars. A centre of learning."
        4: ([
            ("Its gold mines", "Migodi ya dhahabu", "Ses mines d'or"),
            ("Its libraries", "Maktaba zake", "Ses bibliothèques"),
            ("Its high walls", "Kuta zake ndefu", "Ses hauts murs"),
        ], 1, None),
        # "It was shorter, and the goods were worth the risk."
        5: ([
            ("It was safer", "Ilikuwa salama zaidi", "C'était plus sûr"),
            ("It was much shorter", "Ilikuwa fupi zaidi",
             "C'était bien plus court"),
            ("It was more scenic", "Ilikuwa na mandhari",
             "C'était plus joli"),
        ], 1, None),
    },
    "s10.social.lesson.06": {
        # "Chooses who decides, and makes them replaceable. Both parts."
        5: ([
            ("It ends all argument", "Humaliza mabishano",
             "Ça met fin aux débats"),
            ("It picks who decides", "Huchagua mwenye kuamua",
             "Ça choisit qui décide"),
            ("It writes the laws", "Hutunga sheria", "Ça écrit les lois"),
        ], 1, None),
        # "Your rights end where someone else's begin."
        6: ([
            ("Rights are for adults", "Haki ni za watu wazima",
             "Les droits sont aux adultes"),
            ("Others have rights too", "Wengine nao wana haki",
             "Les autres ont des droits"),
            ("Rights can be bought", "Haki zanunulika",
             "Les droits s'achètent"),
        ], 1, None),
    },
    "s10.writing.lesson.01": {
        # "The reasons and evidence. The introduction claims; the body proves."
        5: ([
            ("The main claim", "Hoja kuu", "L'idée défendue"),
            ("The evidence", "Ushahidi", "Les preuves"),
            ("The closing line", "Sentensi ya mwisho", "La dernière phrase"),
        ], 1, None),
        # "A conclusion gathers what was argued."
        6: ([
            ("Conclusions are short", "Hitimisho ni fupi",
             "Les conclusions sont courtes"),
            ("A conclusion gathers", "Hitimisho hukusanya",
             "Une conclusion rassemble"),
            ("Reasons are boring", "Sababu huchosha",
             "Les raisons sont ennuyeuses"),
        ], 1, None),
    },
    # "First, so the reader knows what the paragraph is trying to prove."
    "s10.writing.lesson.02": {
        6: ([
            ("Last, as a summary", "Mwisho, kama muhtasari",
             "À la fin, en résumé"),
            ("First, to set it up", "Mwanzo, kuweka wazi",
             "Au début, pour annoncer"),
            ("Anywhere at all", "Mahali popote", "N'importe où"),
        ], 1, None),
    },
    # "Lose track. A new line for each speaker costs nothing and fixes it."
    "s10.writing.lesson.04": {
        6: ([
            ("Read it twice", "Kuisoma mara mbili", "Le lire deux fois"),
            ("Lose track of who", "Kuchanganya wasemaji",
             "Perdre le fil de qui parle"),
            ("Enjoy it more", "Kuifurahia zaidi", "L'apprécier davantage"),
        ], 1, None),
    },
}


def check_spec() -> None:
    """Fail loudly on a spec that the player or the tests would reject."""
    for item_id, steps in STAGED.items():
        for index, (options, answer, english) in steps.items():
            where = f"{item_id} step{index}"
            words = [o[0] for o in options]
            if len(options) < 2:
                sys.exit(f"{where}: needs at least two options")
            if len(set(w.lower() for w in words)) != len(options):
                sys.exit(f"{where}: duplicate options")
            if not 0 <= answer < len(options):
                sys.exit(f"{where}: answer index {answer} out of range")
            for option in options:
                if not option[0].strip():
                    sys.exit(f"{where}: blank option")
                if len(option[0]) > MAX_OPTION:
                    sys.exit(f"{where}: option '{option[0]}' is too long")
                if english is None:
                    if option[1] in (None, option[0]) or \
                            option[2] in (None, option[0]):
                        sys.exit(f"{where}: '{option[0]}' is not translated "
                                 f"and is not marked english-by-design")
                elif option[1] is not None or option[2] is not None:
                    sys.exit(f"{where}: '{option[0]}' is marked "
                             f"english-by-design but carries a translation")


def stage(library: dict) -> tuple[int, dict[str, dict[str, str]],
                                  dict[str, str]]:
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
            words = [o[0] for o in options]
            before = (
                step.get("mechanic"),
                step.get("choices"),
                step.get("choiceIndex"),
            )
            step["mechanic"] = "multiChoice"
            step["choices"] = list(words)
            step["choiceIndex"] = answer
            if before != ("multiChoice", list(words), answer):
                changed += 1
            for position, option in enumerate(options):
                key = f"{item_id}.steps.{index}.choices.{position}"
                wanted["en"][key] = option[0]
                if english is not None:
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
        print(f"ok: {sum(len(s) for s in STAGED.values())} comprehension "
              f"step(s) offer what they ask")
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
