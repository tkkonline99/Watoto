#!/usr/bin/env python3
"""
Seed the French (fr) and Swahili (sw) locale bundles with the hand-written
Stage 1 translations held below.

Every key mirrors a key in i18n/en.json. Missing keys fall back to English at
runtime, so a partial bundle is always safe to ship.

**This script merges; it does not rebuild.** It was written when the bundles
held only what is in this file, and it wrote them with a plain `json.dump` -- so
running it after `translate_content.py` had taken the two locales to 12,149 keys
replaced all of them with the ~75 below, destroying every translation not
hand-written here. That is not a hypothetical: it happened. The keys in this
file are the authoritative version of *those* keys, and nothing else in the
bundle is touched.

    python build_locale.py            # merge the seeds into fr.json / sw.json
    python build_locale.py --check    # report what would change, write nothing
"""
import json, os, sys

OUTDIR = "i18n"

# ---------------------------------------------------------------- FRENCH ----
fr = {
    # cause.lesson.01 — Tap to Make a Star
    "s01.cause.lesson.01.title": "Touche pour faire une étoile",
    "s01.cause.lesson.01.steps.0.narration": "Touche le ciel sombre.",
    "s01.cause.lesson.01.steps.0.feedback": "Une étoile brillante apparaît avec un son scintillant.",
    "s01.cause.lesson.01.steps.1.narration": "Touche encore — fais plus d'étoiles !",
    "s01.cause.lesson.01.steps.1.feedback": "D'autres étoiles apparaissent et scintillent.",
    "s01.cause.lesson.01.parentNote": "Encouragez chaque touche. C'est le premier moment « C'est moi qui l'ai fait ! » de bébé.",
    # cause.lesson.02 — Pop the Bubbles
    "s01.cause.lesson.02.title": "Fais éclater les bulles",
    "s01.cause.lesson.02.steps.0.narration": "Les bulles montent doucement. Touches-en une.",
    "s01.cause.lesson.02.steps.0.feedback": "Pof ! avec un petit bruit d'éclaboussure.",
    "s01.cause.lesson.02.steps.1.narration": "Fais éclater la grosse bulle bleue.",
    "s01.cause.lesson.02.steps.1.feedback": "Un « pof » plus grave et plus fort.",
    # cause.lesson.03 — Shake for a Sound
    "s01.cause.lesson.03.title": "Secoue pour faire du son",
    "s01.cause.lesson.03.steps.0.narration": "Secoue doucement l'appareil.",
    "s01.cause.lesson.03.steps.0.feedback": "Les maracas crépitent et les formes remuent.",
    "s01.cause.lesson.03.steps.1.narration": "Secoue encore — plus doucement cette fois.",
    "s01.cause.lesson.03.steps.1.feedback": "Un mouvement plus calme. C'est toi qui commandes !",
    # lang.lesson.01 — First Words: Mama & Dada
    "s01.lang.lesson.01.title": "Premiers mots : maman et papa",
    "s01.lang.lesson.01.steps.0.narration": "Touche l'adulte qui sourit.",
    "s01.lang.lesson.01.steps.0.feedback": "Voix douce : « Maman ! »",
    "s01.lang.lesson.01.steps.1.narration": "Touche l'autre adulte.",
    "s01.lang.lesson.01.steps.1.feedback": "Voix douce : « Papa ! »",
    "s01.lang.lesson.01.parentNote": "Enregistrez votre propre voix pour « maman » / « papa » dans les Réglages pour un effet maximal.",
    # lang.lesson.02 — Animal Names
    "s01.lang.lesson.02.title": "Noms des animaux",
    "s01.lang.lesson.02.steps.0.narration": "Touche le chien.",
    "s01.lang.lesson.02.steps.0.feedback": "« Chien ! Ouaf. »",
    "s01.lang.lesson.02.steps.1.narration": "Touche le chat.",
    "s01.lang.lesson.02.steps.1.feedback": "« Chat ! Miaou. »",
    # lang.story.01 — Goodnight, Little Stars
    "s01.lang.story.01.title": "Bonne nuit, petites étoiles",
    "s01.lang.story.01.pages.0.narration": "Une petite étoile dit bonne nuit.",
    "s01.lang.story.01.pages.1.narration": "Deux nuages tout doux passent.",
    "s01.lang.story.01.pages.2.narration": "La lune sourit. Chut... c'est l'heure de se reposer.",
    "s01.lang.story.01.parentNote": "Une histoire apaisante pour le coucher. Baissez la luminosité et lisez à voix basse.",
    # motor.lesson.01 — Clap Along
    "s01.motor.lesson.01.title": "Tape dans tes mains",
    "s01.motor.lesson.01.steps.0.narration": "Le lapin tape dans ses mains. Tape dans les tiennes aussi !",
    "s01.motor.lesson.01.steps.0.feedback": "Bruit de mains qui tapent, le lapin sourit.",
    "s01.motor.lesson.01.steps.1.narration": "Touche l'écran chaque fois que le lapin tape.",
    "s01.motor.lesson.01.steps.1.feedback": "Un claquement résonne à chaque touche.",
    # motor.lesson.02 — Wave Bye-Bye
    "s01.motor.lesson.02.title": "Fais au revoir de la main",
    "s01.motor.lesson.02.steps.0.narration": "L'ours fait au revoir de la main. Réponds-lui !",
    "s01.motor.lesson.02.steps.0.feedback": "L'ours rit et fait coucou.",
    "s01.motor.lesson.02.steps.1.narration": "Touche pour faire coucou ensemble.",
    "s01.motor.lesson.02.steps.1.feedback": "« Au revoir ! » dit joyeusement.",
    # object.lesson.01 — Peekaboo Cloth
    "s01.object.lesson.01.title": "Le tissu cache-cache",
    "s01.object.lesson.01.steps.0.narration": "Un tissu cache le chiot. Où est-il passé ?",
    "s01.object.lesson.01.steps.0.feedback": "Le chiot pointe le museau sous le tissu.",
    "s01.object.lesson.01.steps.1.narration": "Touche le tissu pour le soulever.",
    "s01.object.lesson.01.steps.1.feedback": "Coucou ! Le chiot apparaît. Aboiement joyeux.",
    "s01.object.lesson.01.parentNote": "Jouez d'abord à cache-cache avec vos mains, puis sur l'écran.",
    # object.quiz.01 — Where Did Teddy Go?
    "s01.object.quiz.01.title": "Où est passé Nounours ?",
    "s01.object.quiz.01.questions.0.prompt": "Nounours s'est caché sous un gobelet. Touche le gobelet où il se trouve.",
    "s01.object.quiz.01.questions.0.options.0.label": "Gobelet de gauche",
    "s01.object.quiz.01.questions.0.options.1.label": "Gobelet de droite",
    "s01.object.quiz.01.questions.0.correctFeedback": "Le voilà ! Tu as trouvé Nounours. 🧸",
    "s01.object.quiz.01.questions.0.retryFeedback": "Soulève un gobelet et regarde — essaie encore !",
    "s01.object.quiz.01.parentNote": "Pas de score, pas de minuteur — juste le plaisir de retrouver Nounours.",
    # sensory.lesson.01 — High-Contrast Swirls
    "s01.sensory.lesson.01.title": "Spirales très contrastées",
    "s01.sensory.lesson.01.steps.0.narration": "Regarde les spirales noires et blanches.",
    "s01.sensory.lesson.01.steps.0.feedback": "Un doux carillon pendant que la spirale tourne.",
    "s01.sensory.lesson.01.steps.1.narration": "Glisse ton doigt sur l'écran.",
    "s01.sensory.lesson.01.steps.1.feedback": "Le motif suit ton doigt avec un doux bourdonnement.",
    "s01.sensory.lesson.01.parentNote": "Tenez bébé tout près et suivez la spirale ensemble. Dites : « ça tourne, ça tourne ! »",
    # sensory.lesson.02 — Touch & Feel
    "s01.sensory.lesson.02.title": "Touche et ressens",
    "s01.sensory.lesson.02.steps.0.narration": "Appuie sur la zone toute douce.",
    "s01.sensory.lesson.02.steps.0.feedback": "Légère vibration + « mmm, tout doux ! »",
    "s01.sensory.lesson.02.steps.1.narration": "Appuie sur la zone bosselée.",
    "s01.sensory.lesson.02.steps.1.feedback": "Double vibration rapide + « bosselé ! »",
    "s01.sensory.lesson.02.parentNote": "Associez-y un vrai jouet tout doux et un vrai objet bosselé à proximité.",
    # sensory.lesson.03 — Nature Sounds
    "s01.sensory.lesson.03.title": "Sons de la nature",
    "s01.sensory.lesson.03.steps.0.narration": "Touche le hochet.",
    "s01.sensory.lesson.03.steps.0.feedback": "Un doux bruit de hochet.",
    "s01.sensory.lesson.03.steps.1.narration": "Touche la petite cloche.",
    "s01.sensory.lesson.03.steps.1.feedback": "Ting ! Un doux tintement.",
    "s01.sensory.lesson.03.steps.2.narration": "Touche l'oiseau.",
    "s01.sensory.lesson.03.steps.2.feedback": "Cui-cui, un chant d'oiseau paisible.",
    "s01.sensory.lesson.03.parentNote": "Nommez chaque son à voix haute pendant que bébé touche.",
}

# --------------------------------------------------------------- SWAHILI ----
sw = {
    # cause.lesson.01
    "s01.cause.lesson.01.title": "Gusa ili kutengeneza nyota",
    "s01.cause.lesson.01.steps.0.narration": "Gusa anga lenye giza.",
    "s01.cause.lesson.01.steps.0.feedback": "Nyota inayong'aa inatokea na sauti ya kumeta.",
    "s01.cause.lesson.01.steps.1.narration": "Gusa tena — tengeneza nyota zaidi!",
    "s01.cause.lesson.01.steps.1.feedback": "Nyota zaidi zinatokea, zikimeta.",
    "s01.cause.lesson.01.parentNote": "Mpongeze kwa kila mguso. Huu ni wakati wa kwanza wa mtoto wa 'Nimefanya mimi!'",
    # cause.lesson.02
    "s01.cause.lesson.02.title": "Pasua viputo",
    "s01.cause.lesson.02.steps.0.narration": "Viputo vinapanda polepole. Gusa kimoja.",
    "s01.cause.lesson.02.steps.0.feedback": "Pup! na sauti laini ya kufoka.",
    "s01.cause.lesson.02.steps.1.narration": "Pasua kiputo kikubwa cha buluu.",
    "s01.cause.lesson.02.steps.1.feedback": "Sauti kubwa zaidi ya kupasuka.",
    # cause.lesson.03
    "s01.cause.lesson.03.title": "Tikisa ili kupata sauti",
    "s01.cause.lesson.03.steps.0.narration": "Tikisa kifaa kwa upole.",
    "s01.cause.lesson.03.steps.0.feedback": "Marakas zinalia na maumbo yanatikisika.",
    "s01.cause.lesson.03.steps.1.narration": "Tikisa tena — kwa upole zaidi sasa.",
    "s01.cause.lesson.03.steps.1.feedback": "Mtikiso wa chini. Wewe ndiye unaongoza!",
    # lang.lesson.01
    "s01.lang.lesson.01.title": "Maneno ya kwanza: mama na baba",
    "s01.lang.lesson.01.steps.0.narration": "Gusa mtu mzima anayetabasamu.",
    "s01.lang.lesson.01.steps.0.feedback": "Sauti ya upendo: 'Mama!'",
    "s01.lang.lesson.01.steps.1.narration": "Gusa mtu mzima mwingine.",
    "s01.lang.lesson.01.steps.1.feedback": "Sauti ya upendo: 'Baba!'",
    "s01.lang.lesson.01.parentNote": "Rekodi sauti yako mwenyewe kwa 'mama'/'baba' katika Mipangilio kwa matokeo bora.",
    # lang.lesson.02
    "s01.lang.lesson.02.title": "Majina ya wanyama",
    "s01.lang.lesson.02.steps.0.narration": "Gusa mbwa.",
    "s01.lang.lesson.02.steps.0.feedback": "'Mbwa! Wof.'",
    "s01.lang.lesson.02.steps.1.narration": "Gusa paka.",
    "s01.lang.lesson.02.steps.1.feedback": "'Paka! Miau.'",
    # lang.story.01
    "s01.lang.story.01.title": "Usiku mwema, nyota ndogo",
    "s01.lang.story.01.pages.0.narration": "Nyota ndogo moja inasema usiku mwema.",
    "s01.lang.story.01.pages.1.narration": "Mawingu mawili laini yanapita.",
    "s01.lang.story.01.pages.2.narration": "Mwezi unatabasamu. Shhh... ni wakati wa kupumzika.",
    "s01.lang.story.01.parentNote": "Hadithi ya kutuliza kabla ya kulala. Punguza mwangaza wa skrini na soma kwa sauti ya chini.",
    # motor.lesson.01
    "s01.motor.lesson.01.title": "Piga makofi pamoja",
    "s01.motor.lesson.01.steps.0.narration": "Sungura anapiga makofi. Piga makofi wewe pia!",
    "s01.motor.lesson.01.steps.0.feedback": "Sauti ya makofi, sungura anatabasamu.",
    "s01.motor.lesson.01.steps.1.narration": "Gusa skrini kila sungura anapopiga makofi.",
    "s01.motor.lesson.01.steps.1.feedback": "Sauti ya kofi inalia kwa kila mguso.",
    # motor.lesson.02
    "s01.motor.lesson.02.title": "Punga mkono wa kwaheri",
    "s01.motor.lesson.02.steps.0.narration": "Dubu anapunga mkono wa kwaheri. Mpunge naye!",
    "s01.motor.lesson.02.steps.0.feedback": "Dubu anacheka na kupunga mkono.",
    "s01.motor.lesson.02.steps.1.narration": "Gusa ili kupunga mkono pamoja.",
    "s01.motor.lesson.02.steps.1.feedback": "'Kwaheri!' kwa furaha.",
    # object.lesson.01
    "s01.object.lesson.01.title": "Kitambaa cha kuchungulia",
    "s01.object.lesson.01.steps.0.narration": "Kitambaa kinamfunika mbwa. Amekwenda wapi?",
    "s01.object.lesson.01.steps.0.feedback": "Mbwa anachungulia chini ya ukingo wa kitambaa.",
    "s01.object.lesson.01.steps.1.narration": "Gusa kitambaa ili kukiinua.",
    "s01.object.lesson.01.steps.1.feedback": "Tushuu! Mbwa anatokea. Bweka la furaha.",
    "s01.object.lesson.01.parentNote": "Cheza kuchungulia kwa mikono yako kwanza, kisha kwenye skrini.",
    # object.quiz.01
    "s01.object.quiz.01.title": "Teddy amekwenda wapi?",
    "s01.object.quiz.01.questions.0.prompt": "Teddy amejificha chini ya kikombe. Gusa kikombe alichopo.",
    "s01.object.quiz.01.questions.0.options.0.label": "Kikombe cha kushoto",
    "s01.object.quiz.01.questions.0.options.1.label": "Kikombe cha kulia",
    "s01.object.quiz.01.questions.0.correctFeedback": "Yupo hapa! Umempata Teddy. 🧸",
    "s01.object.quiz.01.questions.0.retryFeedback": "Inua kikombe na uchungulie — jaribu tena!",
    "s01.object.quiz.01.parentNote": "Hakuna alama, hakuna saa — furaha tu ya kumpata Teddy.",
    # sensory.lesson.01
    "s01.sensory.lesson.01.title": "Miviringo yenye rangi tofauti kabisa",
    "s01.sensory.lesson.01.steps.0.narration": "Angalia miviringo myeusi na myeupe.",
    "s01.sensory.lesson.01.steps.0.feedback": "Mlio laini wakati mviringo unapozunguka.",
    "s01.sensory.lesson.01.steps.1.narration": "Telezesha kidole chako kwenye skrini.",
    "s01.sensory.lesson.01.steps.1.feedback": "Mchoro unafuata kidole chako na mvumo laini.",
    "s01.sensory.lesson.01.parentNote": "Mshikilie mtoto karibu na mfuate mviringo pamoja. Sema: 'mzunguko na mzunguko!'",
    # sensory.lesson.02
    "s01.sensory.lesson.02.title": "Gusa na uhisi",
    "s01.sensory.lesson.02.steps.0.narration": "Bonyeza kipande laini chenye manyoya.",
    "s01.sensory.lesson.02.steps.0.feedback": "Mtetemo laini + 'mmm, laini!'",
    "s01.sensory.lesson.02.steps.1.narration": "Bonyeza kipande chenye matuta.",
    "s01.sensory.lesson.02.steps.1.feedback": "Mtetemo wa haraka mara mbili + 'matuta!'",
    "s01.sensory.lesson.02.parentNote": "Ambatanisha na toy halisi laini na kitu halisi chenye matuta karibu.",
    # sensory.lesson.03
    "s01.sensory.lesson.03.title": "Sauti za asili",
    "s01.sensory.lesson.03.steps.0.narration": "Gusa njuga.",
    "s01.sensory.lesson.03.steps.0.feedback": "Sauti laini ya tikitiki.",
    "s01.sensory.lesson.03.steps.1.narration": "Gusa kengele ndogo.",
    "s01.sensory.lesson.03.steps.1.feedback": "Ting! Mlio laini.",
    "s01.sensory.lesson.03.steps.2.narration": "Gusa ndege.",
    "s01.sensory.lesson.03.steps.2.feedback": "Twii-twii, wimbo tulivu wa ndege.",
    "s01.sensory.lesson.03.parentNote": "Taja kila sauti kwa sauti wakati mtoto wako anagusa.",
}

check = "--check" in sys.argv
os.makedirs(OUTDIR, exist_ok=True)
for code, seeds in (("fr", fr), ("sw", sw)):
    path = f"{OUTDIR}/{code}.json"
    try:
        with open(path, encoding="utf-8") as f:
            bundle = json.load(f)
    except FileNotFoundError:
        bundle = {}
    before = len(bundle)
    changed = [k for k, v in seeds.items() if bundle.get(k) != v]
    if check:
        print(f"{path}: {before} strings, {len(changed)} of {len(seeds)} "
              f"seeds would change")
        continue
    bundle.update(seeds)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(dict(sorted(bundle.items())), f, indent=2, ensure_ascii=False)
    print(f"{path}: merged {len(seeds)} seeds, {before} -> {len(bundle)} "
          f"strings, {len(changed)} changed")
