"""Author stage 1 (ages 0–1) to full depth, in EN/SW/FR.

Why this exists
---------------
`_buildPlan.priorityOrder` says "Finish Stage 1-3 to full depth (foundation
band, highest daily-use)" — and stage 1 was the least finished band in the
library: 30 lessons of two steps each, one story per subject instead of two,
and two or three quizzes instead of four.

What "full depth" means here is deliberately *not* what it meant for stage 7.
The stage-7 pilot (deepen_stage7.py) built 8–10 step teaching arcs with worked
examples and a recap question, for children of 6 and 7. Stage 1 is ages 0–1,
design tier `parent-led`: the parent is the primary user, there is zero
reading, and a one-year-old cannot sit through a teaching arc or answer a
multiple-choice recap. Holding this band to the stage-7 shape would produce
lessons no baby can finish and no parent wants to read aloud.

So each lesson grows to four or five steps on an infant-appropriate arc:

    notice → do → do again, changed → carry it into the room

The last step is the one that matters most at this age and the one the library
had nowhere: a `celebrate` step that sends the pair off the glass and into the
real world — crinkle a real paper, wave at a real person, hide a real toy.
That is where object permanence and first words are actually learned; the
screen is the prompt, not the lesson.

For the same reason this script adds **no recap questions**. A recap is a
multiple-choice question (`play_recap_view.dart`) and a pre-verbal child has no
way to answer one. `lesson_depth_test.dart` scores depth per tier for exactly
this reason.

Everything is written in all three languages, English included, because
`LocalizedItem._t` prefers the i18n overlay over the text embedded in the
library — a missing `en` key would keep showing the old two-step script.

Idempotent: re-running replaces the same items and keys.

    python content/author_stage1.py            # from the repo root
    python content/author_stage1.py --check    # verify only, exit 1 on drift
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# The app reads assets/; content/ is the authoring copy. Both are written from
# the same in-memory object so they cannot drift (validate_content.py fails if
# they ever do).
LIBRARIES = [
    ROOT / "apps/mobile/assets/content/watoto_content_library.json",
    ROOT / "content/watoto_content_library.json",
]
I18N_DIRS = [ROOT / "apps/mobile/assets/i18n", ROOT / "content/i18n"]
LANGS = ("en", "sw", "fr")

ACCESSIBILITY = "All narration is also shown as captions; playable audio-only."

# How many steps each stage-1 lesson shipped with, before this script. Used to
# truncate back to the original before re-appending, so the script is
# idempotent no matter how often the authored lines are reworded.
BASE_STEP_COUNTS = {
    "s01.cause.lesson.01": 2, "s01.cause.lesson.02": 2, "s01.cause.lesson.03": 2,
    "s01.cause.lesson.04": 2, "s01.cause.lesson.05": 2, "s01.cause.lesson.06": 2,
    "s01.lang.lesson.01": 2, "s01.lang.lesson.02": 2, "s01.lang.lesson.03": 2,
    "s01.lang.lesson.04": 3, "s01.lang.lesson.05": 2, "s01.lang.lesson.06": 2,
    "s01.motor.lesson.01": 2, "s01.motor.lesson.02": 2, "s01.motor.lesson.03": 2,
    "s01.motor.lesson.04": 2, "s01.motor.lesson.05": 2, "s01.motor.lesson.06": 2,
    "s01.object.lesson.01": 2, "s01.object.lesson.02": 2, "s01.object.lesson.03": 2,
    "s01.object.lesson.04": 2, "s01.object.lesson.05": 2, "s01.object.lesson.06": 2,
    "s01.sensory.lesson.01": 2, "s01.sensory.lesson.02": 2, "s01.sensory.lesson.03": 3,
    "s01.sensory.lesson.04": 2, "s01.sensory.lesson.05": 2, "s01.sensory.lesson.06": 2,
}

# --------------------------------------------------------------------------
# Extra steps per lesson.
#
# Each entry: (action, mechanic, (en_narration, sw_narration, fr_narration),
#                                (en_feedback,  sw_feedback,  fr_feedback))
# --------------------------------------------------------------------------
EXTRA_STEPS: dict[str, list[tuple]] = {
    # ---- Sensory Exploration ----
    "s01.sensory.lesson.01": [
        ("swipe", "drag",
         ("Swipe the other way. The swirl follows.",
          "Telezesha upande mwingine. Duara linafuata.",
          "Glissez dans l'autre sens. La spirale suit."),
         ("The pattern curls back with a soft hum.",
          "Muundo unajikunja nyuma kwa mngurumo laini.",
          "Le motif s'enroule avec un doux bourdonnement.")),
        ("real-world", "celebrate",
         ("Now look around for stripes or spots.",
          "Sasa tazama pande zote uone mistari au madoa.",
          "Cherchez maintenant des rayures ou des taches."),
         ("Real patterns are everywhere. Point at one together!",
          "Miundo halisi iko kila mahali. Ionesheni pamoja!",
          "Les motifs sont partout. Montrez-en un ensemble !")),
    ],
    "s01.sensory.lesson.02": [
        ("press", "tap",
         ("Press the soft patch again. Feel it buzz.",
          "Bonyeza kipande laini tena. Sikia mtetemo.",
          "Appuyez encore sur la zone douce. Sentez-la vibrer."),
         ("A gentle buzz — soft!",
          "Mtetemo mpole — laini!",
          "Une vibration douce — tout doux !")),
        ("real-world", "celebrate",
         ("Find something soft in the room and touch it.",
          "Tafuta kitu laini chumbani na ukiguse.",
          "Trouvez quelque chose de doux et touchez-le."),
         ("Real soft, real bumpy. Say the word out loud!",
          "Laini halisi, matuta halisi. Sema neno kwa sauti!",
          "Doux, rugueux. Dites le mot à voix haute !")),
    ],
    "s01.sensory.lesson.03": [
        ("tap", "tap",
         ("Tap the rattle one more time.",
          "Gusa kayamba mara moja zaidi.",
          "Touchez le hochet encore une fois."),
         ("Shake-shake. The same friendly sound.",
          "Tikisa-tikisa. Sauti ile ile ya kirafiki.",
          "Chac-chac. Le même son amical.")),
        ("real-world", "celebrate",
         ("Listen for a real sound near you.",
          "Sikiliza sauti halisi karibu nawe.",
          "Écoutez un vrai son près de vous."),
         ("Name it out loud together.",
          "Litajeni kwa sauti pamoja.",
          "Nommez-le à voix haute ensemble.")),
    ],
    "s01.sensory.lesson.04": [
        ("tap", "tap",
         ("Tap the lamp again. Off, then on.",
          "Gusa taa tena. Zima, kisha washa.",
          "Touchez la lampe. Éteint, puis allumé."),
         ("Dark, then a warm glow. You did that!",
          "Giza, kisha mwanga wa joto. Umefanya hivyo!",
          "Sombre, puis une lueur chaude. C'est vous !")),
        ("real-world", "celebrate",
         ("Make a shadow with your hand together.",
          "Tengenezeni kivuli kwa mkono wenu pamoja.",
          "Faites une ombre avec votre main ensemble."),
         ("Your hand made that shape. Wave it!",
          "Mkono wako umetengeneza umbo hilo. Upunge!",
          "Votre main a fait cette forme. Agitez-la !")),
    ],
    "s01.sensory.lesson.05": [
        ("press", "tap",
         ("Press with your whole hand. A big bloom!",
          "Bonyeza kwa mkono mzima. Uchanuaji mkubwa!",
          "Appuyez avec toute la main. Une grande fleur !"),
         ("A wide, soft wash of color.",
          "Rangi laini inayoenea kote.",
          "Une large vague de couleur douce.")),
        ("real-world", "celebrate",
         ("Find something this color near you.",
          "Tafuta kitu chenye rangi hii karibu nawe.",
          "Trouvez un objet de cette couleur près de vous."),
         ("Point and say the color out loud.",
          "Onesha na useme rangi kwa sauti.",
          "Montrez-le et dites la couleur à voix haute.")),
    ],
    "s01.sensory.lesson.06": [
        ("press", "tap",
         ("Press the leaf softly, then hard.",
          "Bonyeza jani taratibu, kisha kwa nguvu.",
          "Appuyez doucement sur la feuille, puis fort."),
         ("A quiet crinkle, then a loud one.",
          "Mkwaruzo mtulivu, kisha wa sauti kubwa.",
          "Un froissement doux, puis un fort.")),
        ("real-world", "celebrate",
         ("Crinkle a real paper together.",
          "Kunjeni karatasi halisi pamoja.",
          "Froissez un vrai papier ensemble."),
         ("Same sound, real hands!",
          "Sauti ile ile, mikono halisi!",
          "Le même son, avec de vraies mains !")),
    ],
    # ---- Cause & Effect ----
    "s01.cause.lesson.01": [
        ("tap", "tap",
         ("Tap slowly. One star at a time.",
          "Gusa taratibu. Nyota moja kwa wakati.",
          "Touchez lentement. Une étoile à la fois."),
         ("One star. Then another. You choose.",
          "Nyota moja. Kisha nyingine. Wewe unachagua.",
          "Une étoile. Puis une autre. C'est vous qui choisissez.")),
        ("real-world", "celebrate",
         ("Clap once and say 'I did it!'",
          "Piga makofi mara moja na useme 'Nimefanya!'",
          "Tapez une fois et dites « J'ai réussi ! »"),
         ("You made the stars. Cheer together!",
          "Umetengeneza nyota. Shangilieni pamoja!",
          "Vous avez fait les étoiles. Bravo !")),
    ],
    "s01.cause.lesson.02": [
        ("tap", "tap",
         ("Pop the tiny bubble at the top.",
          "Pasua kiputo kidogo kilicho juu.",
          "Faites éclater la petite bulle en haut."),
         ("A small, high pop!",
          "Mlio mdogo, wa juu!",
          "Un petit pop aigu !")),
        ("real-world", "celebrate",
         ("Blow a real puff of air together.",
          "Pulizeni upepo halisi pamoja.",
          "Soufflez un vrai souffle d'air ensemble."),
         ("Whoosh! You moved the air.",
          "Vuu! Umeusogeza upepo.",
          "Whoosh ! Vous avez déplacé l'air.")),
    ],
    "s01.cause.lesson.03": [
        ("shake", "celebrate",
         ("Shake fast! Then stop.",
          "Tikisa haraka! Kisha simama.",
          "Secouez vite ! Puis arrêtez."),
         ("A rush of rattles, then quiet.",
          "Mfululizo wa mlio, kisha utulivu.",
          "Une pluie de sons, puis le calme.")),
        ("real-world", "celebrate",
         ("Shake a real rattle or a set of keys.",
          "Tikisa kayamba halisi au funguo.",
          "Secouez un vrai hochet ou des clés."),
         ("You made that sound happen.",
          "Wewe umeifanya sauti hiyo itokee.",
          "C'est vous qui avez fait ce son.")),
    ],
    "s01.cause.lesson.04": [
        # NB: the shipped step 1 is already "Roll it the other way." — an extra
        # with the same narration would be deduplicated against the original.
        ("swipe", "drag",
         ("Now roll it slowly to the bell.",
          "Sasa livingirishe taratibu hadi kwenye kengele.",
          "Faites-la rouler doucement vers la cloche."),
         ("A slow roll, then a soft ding.",
          "Mvingirisho wa taratibu, kisha ding laini.",
          "Un roulement lent, puis un doux ding.")),
        ("real-world", "celebrate",
         ("Roll a real ball to each other.",
          "Vingirisheni mpira halisi kwa kila mmoja.",
          "Faites rouler une vraie balle l'un vers l'autre."),
         ("Push, and it goes. Again!",
          "Sukuma, nao unakwenda. Tena!",
          "Poussez, et elle roule. Encore !")),
    ],
    "s01.cause.lesson.05": [
        ("tap", "tap",
         ("Tap two lights together.",
          "Gusa taa mbili kwa pamoja.",
          "Touchez deux lumières en même temps."),
         ("Two twinkles at once!",
          "Mimeto miwili kwa mara moja!",
          "Deux scintillements à la fois !")),
        ("real-world", "celebrate",
         ("Turn a real light on and off together.",
          "Washeni na kuzimeni taa halisi pamoja.",
          "Allumez et éteignez une vraie lampe ensemble."),
         ("On. Off. You did that!",
          "Washa. Zima. Umefanya hivyo!",
          "Allumé. Éteint. C'est vous !")),
    ],
    "s01.cause.lesson.06": [
        ("tap", "tap",
         ("Tap softly. A little boom.",
          "Gusa taratibu. Mlio mdogo.",
          "Touchez doucement. Un petit boum."),
         ("A gentle, low boom.",
          "Mlio mpole wa chini.",
          "Un boum doux et grave.")),
        ("real-world", "celebrate",
         ("Pat a real pot or your knees.",
          "Pigeni sufuria halisi au magoti yenu.",
          "Tapotez une vraie casserole ou vos genoux."),
         ("Boom-boom! Your hands made it.",
          "Bum-bum! Mikono yenu imeutoa.",
          "Boum-boum ! Vos mains l'ont fait.")),
    ],
    # ---- Early Language ----
    "s01.lang.lesson.01": [
        ("tap", "tap",
         ("Tap Mama again. Say it with me: ma-ma.",
          "Gusa Mama tena. Sema nami: ma-ma.",
          "Touchez Maman. Dites avec moi : ma-man."),
         ("'Mama!' Warm and happy.",
          "'Mama!' Kwa uchangamfu na furaha.",
          "« Maman ! » Chaleureux et joyeux.")),
        ("real-world", "celebrate",
         ("Say your own name for each grown-up here.",
          "Sema jina lako mwenyewe kwa kila mtu mzima hapa.",
          "Dites votre propre nom pour chaque adulte ici."),
         ("Your voice is the best sound of all.",
          "Sauti yako ndiyo bora kuliko zote.",
          "Votre voix est le plus beau des sons.")),
    ],
    "s01.lang.lesson.02": [
        ("tap", "tap",
         ("Tap the dog once more. Woof!",
          "Gusa mbwa mara moja zaidi. Woof!",
          "Touchez le chien encore une fois. Ouaf !"),
         ("'Dog! Woof-woof.'",
          "'Mbwa! Woof-woof.'",
          "« Chien ! Ouaf-ouaf. »")),
        ("real-world", "celebrate",
         ("Make the animal sound out loud together.",
          "Toeni sauti ya mnyama kwa sauti pamoja.",
          "Faites le cri de l'animal ensemble."),
         ("Woof! Meow! Your turn.",
          "Woof! Miau! Zamu yako.",
          "Ouaf ! Miaou ! À votre tour.")),
    ],
    "s01.lang.lesson.03": [
        ("tap", "tap",
         ("Tap and babble back: ba-ba-ba.",
          "Gusa na ujibu kwa gugumizi: ba-ba-ba.",
          "Touchez et babillez : ba-ba-ba."),
         ("'Ba-ba-ba!' A happy chatter.",
          "'Ba-ba-ba!' Mazungumzo ya furaha.",
          "« Ba-ba-ba ! » Un babillage joyeux.")),
        ("real-world", "celebrate",
         ("Copy the sound your baby makes.",
          "Iga sauti anayotoa mtoto wako.",
          "Imitez le son que fait votre bébé."),
         ("Taking turns is how talking starts.",
          "Kupokezana ndiyo mwanzo wa kuzungumza.",
          "Parler commence par se répondre.")),
    ],
    "s01.lang.lesson.04": [
        ("tap", "tap",
         ("Tap the ball again. Say: ball.",
          "Gusa mpira tena. Sema: mpira.",
          "Touchez le ballon. Dites : ballon."),
         ("'Ball!' Round and bouncy.",
          "'Mpira!' Wa mviringo na wa kuruka.",
          "« Ballon ! » Rond et rebondissant.")),
        ("real-world", "celebrate",
         ("Find a real cup and name it together.",
          "Tafuteni kikombe halisi na mkitaje pamoja.",
          "Trouvez une vraie tasse et nommez-la."),
         ("Same word, real thing!",
          "Neno lile lile, kitu halisi!",
          "Le même mot, un vrai objet !")),
    ],
    "s01.lang.lesson.05": [
        ("tap", "tap",
         ("Point with me. Tap what you see.",
          "Onesha nami. Gusa unachokiona.",
          "Montrez avec moi. Touchez ce que vous voyez."),
         ("'Yes! You found it.'",
          "'Ndiyo! Umekipata.'",
          "« Oui ! Vous l'avez trouvé. »")),
        ("real-world", "celebrate",
         ("Point at a book in your room and name it.",
          "Onesha kitabu chumbani mwako na ukitaje.",
          "Montrez un livre dans la pièce et nommez-le."),
         ("Pointing is talking too.",
          "Kuonesha nako ni kuzungumza.",
          "Montrer, c'est déjà parler.")),
    ],
    "s01.lang.lesson.06": [
        ("tap", "tap",
         ("Tap for one more silly sound.",
          "Gusa upate sauti nyingine ya kuchekesha.",
          "Touchez pour un autre son rigolo."),
         ("A funny squeak. Giggle together!",
          "Mlio wa kuchekesha. Chekeni pamoja!",
          "Un couinement drôle. Riez ensemble !")),
        ("real-world", "celebrate",
         ("Make a silly sound together.",
          "Toeni sauti ya kuchekesha pamoja.",
          "Faites un son rigolo ensemble."),
         ("Laughing is learning.",
          "Kucheka ni kujifunza.",
          "Rire, c'est apprendre.")),
    ],
    # ---- Motor Imitation ----
    "s01.motor.lesson.01": [
        ("tap-rhythm", "count",
         ("Clap slowly. Clap, clap.",
          "Piga makofi taratibu. Kofi, kofi.",
          "Tapez lentement. Clap, clap."),
         ("Two slow claps. Bunny copies you.",
          "Makofi mawili ya taratibu. Sungura anakuiga.",
          "Deux claps lents. Le lapin vous imite.")),
        ("real-world", "celebrate",
         ("Clap your baby's hands gently together.",
          "Pigeni makofi mikono ya mtoto taratibu.",
          "Tapez doucement dans les mains de bébé."),
         ("Hands together. Well done!",
          "Mikono pamoja. Hongera!",
          "Les mains ensemble. Bravo !")),
    ],
    "s01.motor.lesson.02": [
        ("tap-wave", "celebrate",
         ("Wave with your other hand.",
          "Punga kwa mkono wako mwingine.",
          "Saluez avec l'autre main."),
         ("Bear waves back with both paws!",
          "Dubu anapunga kwa makucha yote mawili!",
          "L'ours salue avec ses deux pattes !")),
        ("real-world", "celebrate",
         ("Wave to someone real in the room.",
          "Mpungie mtu halisi aliye chumbani.",
          "Saluez quelqu'un de réel dans la pièce."),
         ("'Bye-bye!' A real hello and goodbye.",
          "'Kwaheri!' Salamu halisi na kwaheri.",
          "« Au revoir ! » Un vrai bonjour et au revoir.")),
    ],
    "s01.motor.lesson.03": [
        # Reaching happens in the room, not on the glass — celebrate stages it
        # as "do it, then tap when you're ready" rather than faking a target.
        ("stretch", "celebrate",
         ("Reach up once more. So tall!",
          "Nyoosha juu mara moja zaidi. Mrefu sana!",
          "Levez les bras encore. Si grand !"),
         ("Arms high. What a stretch!",
          "Mikono juu. Mnyoosho gani!",
          "Les bras en l'air. Quel étirement !")),
        ("real-world", "celebrate",
         ("Reach up together and wiggle your fingers.",
          "Nyoosheni juu pamoja na mtikise vidole.",
          "Levez les bras et remuez les doigts."),
         ("Up high! Now down low.",
          "Juu sana! Sasa chini kabisa.",
          "Tout en haut ! Maintenant tout en bas.")),
    ],
    "s01.motor.lesson.04": [
        ("tap", "celebrate",
         ("Blow one more kiss.",
          "Rusha busu moja zaidi.",
          "Envoyez un autre bisou."),
         ("Mwah! It floats across the screen.",
          "Mwah! Linaelea skrini nzima.",
          "Mwah ! Il traverse l'écran.")),
        ("real-world", "celebrate",
         ("Blow a real kiss to each other.",
          "Rushianeni busu halisi.",
          "Envoyez-vous un vrai bisou."),
         ("Mwah! Kisses are for sharing.",
          "Mwah! Busu ni za kushirikiana.",
          "Mwah ! Les bisous, ça se partage.")),
    ],
    "s01.motor.lesson.05": [
        ("tap-rhythm", "count",
         ("Stomp softly. Little steps.",
          "Kanyaga taratibu. Hatua ndogo.",
          "Tapez du pied doucement. De petits pas."),
         ("Quiet stomps. Tip-toe!",
          "Mikanyago tulivu. Kwa vidole!",
          "Des pas légers. Sur la pointe des pieds !")),
        ("real-world", "celebrate",
         ("Stomp your real feet on the floor.",
          "Kanyageni miguu yenu halisi sakafuni.",
          "Tapez vos vrais pieds sur le sol."),
         ("Stomp-stomp! Feel the floor.",
          "Kanya-kanya! Hisi sakafu.",
          "Boum-boum ! Sentez le sol.")),
    ],
    "s01.motor.lesson.06": [
        ("tap", "tap",
         ("Open and shut your hands faster!",
          "Fungua na funga mikono yako haraka zaidi!",
          "Ouvrez et fermez vos mains plus vite !"),
         ("Open, shut, open, shut!",
          "Fungua, funga, fungua, funga!",
          "Ouvert, fermé, ouvert, fermé !")),
        ("real-world", "celebrate",
         ("Open and shut your real hands together.",
          "Fungueni na kufunga mikono yenu halisi pamoja.",
          "Ouvrez et fermez vos vraies mains ensemble."),
         ("Your hands can do it too.",
          "Mikono yako nayo inaweza.",
          "Vos mains aussi savent le faire.")),
    ],
    # ---- Object Permanence ----
    "s01.object.lesson.01": [
        ("tap", "tap",
         ("Cover the puppy again. Where is it?",
          "Mfunike mbwa tena. Yuko wapi?",
          "Recouvrez le chiot. Où est-il ?"),
         ("The cloth settles. Puppy is hiding.",
          "Kitambaa kinatulia. Mbwa amejificha.",
          "Le tissu retombe. Le chiot se cache.")),
        ("real-world", "celebrate",
         ("Hide your face with your hands. Peekaboo!",
          "Ficha uso wako kwa mikono. Peekaboo!",
          "Cachez votre visage avec vos mains. Coucou !"),
         ("You were there all along!",
          "Ulikuwepo muda wote!",
          "Vous étiez là depuis le début !")),
    ],
    "s01.object.lesson.02": [
        ("tap", "tap",
         ("Lift the other box.",
          "Inua sanduku lingine.",
          "Soulevez l'autre boîte."),
         ("Empty! Try the first one again.",
          "Tupu! Jaribu la kwanza tena.",
          "Vide ! Réessayez la première.")),
        ("real-world", "celebrate",
         ("Hide a toy under a real cloth.",
          "Ficha kichezeo chini ya kitambaa halisi.",
          "Cachez un jouet sous un vrai tissu."),
         ("Still there! Lift and find.",
          "Bado kipo! Inua na ukipate.",
          "Toujours là ! Soulevez et trouvez.")),
    ],
    "s01.object.lesson.03": [
        ("tap", "tap",
         ("Knock, then open it again.",
          "Bisha, kisha ufungue tena.",
          "Frappez, puis rouvrez."),
         ("Knock-knock. Hello again!",
          "Hodi-hodi. Habari tena!",
          "Toc-toc. Rebonjour !")),
        ("real-world", "celebrate",
         ("Peek around a real door together.",
          "Chungulieni mlango halisi pamoja.",
          "Jetez un œil derrière une vraie porte."),
         ("Gone, then back. Peekaboo!",
          "Ametoweka, kisha amerudi. Peekaboo!",
          "Parti, puis revenu. Coucou !")),
    ],
    "s01.object.lesson.04": [
        ("tap", "tap",
         ("Reach into the other pocket.",
          "Tia mkono katika mfuko mwingine.",
          "Fouillez dans l'autre poche."),
         ("Something soft is tucked inside!",
          "Kitu laini kimefichwa ndani!",
          "Quelque chose de doux est caché dedans !")),
        ("real-world", "celebrate",
         ("Put a toy in a real pocket and find it.",
          "Weka kichezeo mfukoni halisi na ukipate.",
          "Mettez un jouet dans une vraie poche et trouvez-le."),
         ("Hidden, but not gone.",
          "Kimefichwa, lakini hakijapotea.",
          "Caché, mais pas disparu.")),
    ],
    "s01.object.lesson.05": [
        ("tap", "tap",
         ("Open the hands slowly this time.",
          "Fungua mikono taratibu safari hii.",
          "Ouvrez les mains lentement cette fois."),
         ("Slowly... peekaboo!",
          "Taratibu... peekaboo!",
          "Doucement... coucou !")),
        ("real-world", "celebrate",
         ("Cover and uncover your own eyes.",
          "Funika na ufunue macho yako mwenyewe.",
          "Couvrez et découvrez vos propres yeux."),
         ("You are still here. Hooray!",
          "Bado upo hapa. Hongera!",
          "Vous êtes toujours là. Hourra !")),
    ],
    "s01.object.lesson.06": [
        # Waiting for the ball to reappear is the whole lesson; there is
        # nothing to tap while it is still inside the tunnel.
        ("watch", "explain",
         ("Watch the other end. Here it comes!",
          "Tazama upande mwingine. Unakuja!",
          "Regardez l'autre bout. Le voilà !"),
         ("Out it rolls, right on time.",
          "Unatoka ukivingirika, kwa wakati.",
          "Il ressort, juste à temps.")),
        ("real-world", "celebrate",
         ("Roll a toy behind a cushion and wait.",
          "Vingirisha kichezeo nyuma ya mto na usubiri.",
          "Faites rouler un jouet derrière un coussin et attendez."),
         ("It comes back. It was always there.",
          "Kinarudi. Kilikuwepo daima.",
          "Il revient. Il a toujours été là.")),
    ],
}

# --------------------------------------------------------------------------
# New quizzes. Stage 1 quizzes are "gentlest matching": two options, one tap,
# no score and no timer. Two questions each — the shipped ones had a single
# question, which is a tap, not a check.
#
# Each field: (en, sw, fr)
# --------------------------------------------------------------------------
def Q(prompt, opts, answer, correct, retry):
    return {"prompt": prompt, "options": opts, "answer": answer,
            "correctFeedback": correct, "retryFeedback": retry}


NEW_QUIZZES = [
    {
        "id": "s01.sensory.quiz.03", "subject": "Sensory Exploration",
        "title": ("Loud or Soft?", "Kubwa au Laini?", "Fort ou Doux ?"),
        "objective": ("Notice the difference between a loud and a soft sound.",
                      "Tambua tofauti kati ya sauti kubwa na laini.",
                      "Remarquer la différence entre un son fort et un son doux."),
        "interaction": "tap",
        "parentNote": ("Say 'loud!' and 'soft!' out loud as your baby taps.",
                       "Sema 'kubwa!' na 'laini!' kwa sauti mtoto anapogusa.",
                       "Dites « fort ! » et « doux ! » pendant que bébé touche."),
        "questions": [
            Q(("Tap the one that makes a big, loud sound.",
               "Gusa kile kinachotoa sauti kubwa.",
               "Touchez celui qui fait un grand bruit."),
              [(("Drum", "Ngoma", "Tambour"), "img/s01/drum_loud.png"),
               (("Feather", "Unyoya", "Plume"), "img/s01/feather_soft.png")], 0,
              ("Boom! That is a loud one.", "Bum! Hiyo ni kubwa.", "Boum ! Celui-là est fort."),
              ("Try the other one. Listen closely!", "Jaribu kingine. Sikiliza kwa makini!",
               "Essayez l'autre. Écoutez bien !")),
            Q(("Now tap the soft, quiet one.",
               "Sasa gusa kile laini na tulivu.",
               "Touchez maintenant le doux et calme."),
              [(("Feather", "Unyoya", "Plume"), "img/s01/feather_soft.png"),
               (("Drum", "Ngoma", "Tambour"), "img/s01/drum_loud.png")], 0,
              ("Shhh. Soft and gentle.", "Shhh. Laini na mpole.", "Chut. Doux et léger."),
              ("That one is loud. Try again!", "Hicho ni kikubwa. Jaribu tena!",
               "Celui-là est fort. Réessayez !")),
        ],
    },
    {
        "id": "s01.sensory.quiz.04", "subject": "Sensory Exploration",
        "title": ("Which One Is Fuzzy?", "Kipi Chenye Manyoya?", "Lequel est Duveteux ?"),
        "objective": ("Match a word to a texture you can see.",
                      "Linganisha neno na muundo unaouona.",
                      "Associer un mot à une texture visible."),
        "interaction": "tap",
        "parentNote": ("Let your baby touch a real fuzzy thing right after.",
                       "Mruhusu mtoto aguse kitu halisi chenye manyoya baadaye.",
                       "Laissez bébé toucher un vrai objet duveteux ensuite."),
        "questions": [
            Q(("Tap the fuzzy one.", "Gusa chenye manyoya.", "Touchez le duveteux."),
              [(("Fuzzy", "Manyoya", "Duveteux"), "img/s01/fuzzy_patch.png"),
               (("Smooth", "Laini", "Lisse"), "img/s01/smooth_patch.png")], 0,
              ("Fuzzy! Soft and furry.", "Manyoya! Laini na yenye nywele.",
               "Duveteux ! Doux et poilu."),
              ("That one is smooth. Try again!", "Hicho ni laini. Jaribu tena!",
               "Celui-là est lisse. Réessayez !")),
            Q(("Now tap the smooth one.", "Sasa gusa kilicho laini.",
               "Touchez maintenant le lisse."),
              [(("Smooth", "Laini", "Lisse"), "img/s01/smooth_patch.png"),
               (("Fuzzy", "Manyoya", "Duveteux"), "img/s01/fuzzy_patch.png")], 0,
              ("Smooth as a stone!", "Laini kama jiwe!", "Lisse comme un galet !"),
              ("That one is fuzzy. Try again!", "Hicho kina manyoya. Jaribu tena!",
               "Celui-là est duveteux. Réessayez !")),
        ],
    },
    {
        "id": "s01.cause.quiz.03", "subject": "Cause & Effect",
        "title": ("What Made the Sound?", "Nini Kimetoa Sauti?", "Qu'est-ce qui a Sonné ?"),
        "objective": ("Link a sound back to the thing that made it.",
                      "Unganisha sauti na kitu kilichoitoa.",
                      "Relier un son à ce qui l'a produit."),
        "interaction": "tap",
        "parentNote": ("Ring a real bell first, then let your baby choose.",
                       "Piga kengele halisi kwanza, kisha mwache mtoto achague.",
                       "Faites sonner une vraie cloche, puis laissez bébé choisir."),
        "questions": [
            Q(("Ting! Tap the bell that rang.",
               "Ting! Gusa kengele iliyolia.",
               "Ding ! Touchez la cloche qui a sonné."),
              [(("Ringing bell", "Kengele inayolia", "Cloche qui sonne"), "img/s01/bell_ringing.png"),
               (("Quiet bell", "Kengele tulivu", "Cloche silencieuse"), "img/s01/bell_still.png")], 0,
              ("Yes! That one rang.", "Ndiyo! Hiyo ndiyo iliyolia.", "Oui ! C'est elle qui a sonné."),
              ("That one is still. Try again!", "Hiyo iko kimya. Jaribu tena!",
               "Celle-là est immobile. Réessayez !")),
            Q(("Tap the bell that is quiet now.",
               "Gusa kengele iliyo kimya sasa.",
               "Touchez la cloche qui est silencieuse."),
              [(("Quiet bell", "Kengele tulivu", "Cloche silencieuse"), "img/s01/bell_still.png"),
               (("Ringing bell", "Kengele inayolia", "Cloche qui sonne"), "img/s01/bell_ringing.png")], 0,
              ("Shhh. All quiet.", "Shhh. Kimya kabisa.", "Chut. Tout est calme."),
              ("That one is ringing! Try again.", "Hiyo inalia! Jaribu tena.",
               "Celle-là sonne ! Réessayez.")),
        ],
    },
    {
        "id": "s01.cause.quiz.04", "subject": "Cause & Effect",
        "title": ("Which Light Is On?", "Taa Ipi Imewaka?", "Quelle Lampe est Allumée ?"),
        "objective": ("See that an action turns something on and off.",
                      "Ona kuwa kitendo huwasha na kuzima kitu.",
                      "Voir qu'une action allume et éteint quelque chose."),
        "interaction": "tap",
        "parentNote": ("Flick a real switch together afterwards.",
                       "Bonyezeni swichi halisi pamoja baadaye.",
                       "Actionnez un vrai interrupteur ensemble après."),
        "questions": [
            Q(("Tap the lamp that is glowing.",
               "Gusa taa inayong'aa.",
               "Touchez la lampe qui brille."),
              [(("Light on", "Taa imewaka", "Lampe allumée"), "img/s01/lamp_on.png"),
               (("Light off", "Taa imezimwa", "Lampe éteinte"), "img/s01/lamp_off.png")], 0,
              ("Bright! The light is on.", "Ing'aa! Taa imewaka.", "Brillant ! La lampe est allumée."),
              ("That one is dark. Try again!", "Hiyo ina giza. Jaribu tena!",
               "Celle-là est éteinte. Réessayez !")),
            Q(("Now tap the dark one.", "Sasa gusa yenye giza.",
               "Touchez maintenant celle qui est éteinte."),
              [(("Light off", "Taa imezimwa", "Lampe éteinte"), "img/s01/lamp_off.png"),
               (("Light on", "Taa imewaka", "Lampe allumée"), "img/s01/lamp_on.png")], 0,
              ("Dark and sleepy.", "Giza na usingizi.", "Sombre et endormi."),
              ("That one is bright! Try again.", "Hiyo ing'aa! Jaribu tena.",
               "Celle-là brille ! Réessayez.")),
        ],
    },
    {
        "id": "s01.object.quiz.03", "subject": "Object Permanence",
        "title": ("Under Which Blanket?", "Chini ya Blanketi Gani?", "Sous Quelle Couverture ?"),
        "objective": ("Remember where something was hidden.",
                      "Kumbuka mahali kitu kilipofichwa.",
                      "Se souvenir où un objet a été caché."),
        "interaction": "tap",
        "parentNote": ("Hide a real toy under a cloth first so the idea is familiar.",
                       "Ficha kichezeo halisi chini ya kitambaa kwanza ili wazo lijulikane.",
                       "Cachez d'abord un vrai jouet sous un tissu."),
        "questions": [
            Q(("The kitten hid under the left blanket. Tap it.",
               "Paka amejificha chini ya blanketi la kushoto. Ligusa.",
               "Le chaton s'est caché sous la couverture de gauche. Touchez-la."),
              [(("Left blanket", "Blanketi la kushoto", "Couverture gauche"), "img/s01/blanket_left.png"),
               (("Right blanket", "Blanketi la kulia", "Couverture droite"), "img/s01/blanket_right.png")], 0,
              ("There he is! You remembered.", "Yupo hapo! Umekumbuka.",
               "Le voilà ! Vous vous en souvenez."),
              ("Peek under the other one. Try again!", "Chungulia chini ya lingine. Jaribu tena!",
               "Regardez sous l'autre. Réessayez !")),
            Q(("Now the kitten hid on the right. Tap that one.",
               "Sasa paka amejificha kulia. Gusa hilo.",
               "Le chaton s'est caché à droite. Touchez celle-là."),
              [(("Right blanket", "Blanketi la kulia", "Couverture droite"), "img/s01/blanket_right.png"),
               (("Left blanket", "Blanketi la kushoto", "Couverture gauche"), "img/s01/blanket_left.png")], 0,
              ("Found again! Hidden is not gone.", "Umempata tena! Kufichwa si kupotea.",
               "Retrouvé ! Caché ne veut pas dire parti."),
              ("Try the other blanket!", "Jaribu blanketi lingine!", "Essayez l'autre couverture !")),
        ],
    },
    {
        "id": "s01.object.quiz.04", "subject": "Object Permanence",
        "title": ("Open or Closed?", "Wazi au Umefungwa?", "Ouvert ou Fermé ?"),
        "objective": ("Tell an open door from a closed one.",
                      "Tofautisha mlango wazi na uliofungwa.",
                      "Distinguer une porte ouverte d'une porte fermée."),
        "interaction": "tap",
        "parentNote": ("Open and close a real door together as you play.",
                       "Fungueni na kufunga mlango halisi mnapocheza.",
                       "Ouvrez et fermez une vraie porte en jouant."),
        "questions": [
            Q(("Tap the door that is open.", "Gusa mlango ulio wazi.",
               "Touchez la porte ouverte."),
              [(("Open door", "Mlango wazi", "Porte ouverte"), "img/s01/door_open.png"),
               (("Closed door", "Mlango umefungwa", "Porte fermée"), "img/s01/door_closed.png")], 0,
              ("Open! Come on through.", "Wazi! Karibu upite.", "Ouverte ! Entrez."),
              ("That one is shut. Try again!", "Huo umefungwa. Jaribu tena!",
               "Celle-là est fermée. Réessayez !")),
            Q(("Tap the door that is shut.", "Gusa mlango uliofungwa.",
               "Touchez la porte fermée."),
              [(("Closed door", "Mlango umefungwa", "Porte fermée"), "img/s01/door_closed.png"),
               (("Open door", "Mlango wazi", "Porte ouverte"), "img/s01/door_open.png")], 0,
              ("Shut tight. Knock-knock!", "Umefungwa vizuri. Hodi-hodi!",
               "Bien fermée. Toc-toc !"),
              ("That one is open! Try again.", "Huo uko wazi! Jaribu tena.",
               "Celle-là est ouverte ! Réessayez.")),
        ],
    },
    {
        "id": "s01.lang.quiz.03", "subject": "Early Language",
        "title": ("Who Says Moo?", "Nani Anasema Moo?", "Qui Fait Meuh ?"),
        "objective": ("Match an animal sound to the animal.",
                      "Linganisha sauti ya mnyama na mnyama.",
                      "Associer un cri à l'animal."),
        "interaction": "tap",
        "parentNote": ("Make the sound yourself first — your voice teaches best.",
                       "Toa sauti wewe mwenyewe kwanza — sauti yako hufundisha vizuri.",
                       "Faites le cri vous-même d'abord — votre voix enseigne le mieux."),
        "questions": [
            Q(("Moo! Tap the one that says moo.",
               "Moo! Gusa yule anayesema moo.",
               "Meuh ! Touchez celui qui fait meuh."),
              [(("Cow", "Ng'ombe", "Vache"), "img/s01/cow.png"),
               (("Duck", "Bata", "Canard"), "img/s01/duck.png")], 0,
              ("Moo! That is the cow.", "Moo! Huyo ni ng'ombe.", "Meuh ! C'est la vache."),
              ("That one says quack. Try again!", "Huyo anasema kwa-kwa. Jaribu tena!",
               "Celui-là fait coin-coin. Réessayez !")),
            Q(("Quack! Tap the one that says quack.",
               "Kwa-kwa! Gusa yule anayesema kwa-kwa.",
               "Coin-coin ! Touchez celui qui fait coin-coin."),
              [(("Duck", "Bata", "Canard"), "img/s01/duck.png"),
               (("Cow", "Ng'ombe", "Vache"), "img/s01/cow.png")], 0,
              ("Quack-quack! That is the duck.", "Kwa-kwa! Huyo ni bata.",
               "Coin-coin ! C'est le canard."),
              ("That one says moo. Try again!", "Huyo anasema moo. Jaribu tena!",
               "Celui-là fait meuh. Réessayez !")),
        ],
    },
    {
        "id": "s01.lang.quiz.04", "subject": "Early Language",
        "title": ("Point to the Ball", "Onesha Mpira", "Montre le Ballon"),
        "objective": ("Find a named object among two.",
                      "Pata kitu kilichotajwa kati ya viwili.",
                      "Trouver un objet nommé parmi deux."),
        "interaction": "tap",
        "parentNote": ("Say the word, wait, then let your baby choose.",
                       "Sema neno, subiri, kisha mwache mtoto achague.",
                       "Dites le mot, attendez, puis laissez bébé choisir."),
        "questions": [
            Q(("Where is the ball? Tap it.", "Mpira uko wapi? Ugusa.",
               "Où est le ballon ? Touchez-le."),
              [(("Ball", "Mpira", "Ballon"), "img/s01/ball_red.png"),
               (("Cup", "Kikombe", "Tasse"), "img/s01/cup_blue.png")], 0,
              ("Ball! Round and bouncy.", "Mpira! Wa mviringo na wa kuruka.",
               "Ballon ! Rond et rebondissant."),
              ("That is a cup. Try again!", "Hicho ni kikombe. Jaribu tena!",
               "C'est une tasse. Réessayez !")),
            Q(("Where is the cup? Tap it.", "Kikombe kiko wapi? Kigusa.",
               "Où est la tasse ? Touchez-la."),
              [(("Cup", "Kikombe", "Tasse"), "img/s01/cup_blue.png"),
               (("Ball", "Mpira", "Ballon"), "img/s01/ball_red.png")], 0,
              ("Cup! We drink from it.", "Kikombe! Tunakunywa nacho.",
               "Tasse ! On y boit."),
              ("That is a ball. Try again!", "Huo ni mpira. Jaribu tena!",
               "C'est un ballon. Réessayez !")),
        ],
    },
    {
        "id": "s01.motor.quiz.03", "subject": "Motor Imitation",
        "title": ("Which Bear Is Waving?", "Dubu Yupi Anapunga?", "Quel Ours Salue ?"),
        "objective": ("Spot the movement you have been copying.",
                      "Tambua mwendo uliokuwa ukiuiga.",
                      "Repérer le geste que vous imitez."),
        "interaction": "tap",
        "parentNote": ("Wave first, then ask. Copying comes before choosing.",
                       "Punga kwanza, kisha uliza. Kuiga hutangulia kuchagua.",
                       "Saluez d'abord, puis demandez. Imiter précède choisir."),
        "questions": [
            Q(("Tap the bear that is waving.", "Gusa dubu anayepunga.",
               "Touchez l'ours qui salue."),
              [(("Waving bear", "Dubu anayepunga", "Ours qui salue"), "img/s01/bear_wave2.png"),
               (("Still bear", "Dubu aliyetulia", "Ours immobile"), "img/s01/bear_still2.png")], 0,
              ("Hello, bear! Wave back.", "Habari, dubu! Mpungie.",
               "Bonjour l'ours ! Saluez-le."),
              ("That bear is still. Try again!", "Dubu huyo ametulia. Jaribu tena!",
               "Cet ours ne bouge pas. Réessayez !")),
            Q(("Tap the bear sitting still.", "Gusa dubu aliyeketi kimya.",
               "Touchez l'ours assis sans bouger."),
              [(("Still bear", "Dubu aliyetulia", "Ours immobile"), "img/s01/bear_still2.png"),
               (("Waving bear", "Dubu anayepunga", "Ours qui salue"), "img/s01/bear_wave2.png")], 0,
              ("Still and calm.", "Ametulia na yuko shwari.", "Immobile et calme."),
              ("That bear is waving! Try again.", "Dubu huyo anapunga! Jaribu tena.",
               "Cet ours salue ! Réessayez.")),
        ],
    },
    {
        "id": "s01.motor.quiz.04", "subject": "Motor Imitation",
        "title": ("Clap or Sleep?", "Kupiga Makofi au Kulala?", "Applaudir ou Dormir ?"),
        "objective": ("Match an action word to what you can see.",
                      "Linganisha neno la kitendo na unachokiona.",
                      "Associer un mot d'action à ce que l'on voit."),
        "interaction": "tap",
        "parentNote": ("Do each action together before tapping.",
                       "Fanyeni kila kitendo pamoja kabla ya kugusa.",
                       "Faites chaque geste ensemble avant de toucher."),
        "questions": [
            Q(("Tap the bunny that is clapping.", "Gusa sungura anayepiga makofi.",
               "Touchez le lapin qui applaudit."),
              [(("Clapping bunny", "Sungura anayepiga makofi", "Lapin qui applaudit"),
                "img/s01/bunny_clap2.png"),
               (("Sleeping bunny", "Sungura anayelala", "Lapin qui dort"),
                "img/s01/bunny_sleep2.png")], 0,
              ("Clap, clap! Join in.", "Kofi, kofi! Jiunge nao.", "Clap, clap ! Joignez-vous."),
              ("That bunny is asleep. Try again!", "Sungura huyo amelala. Jaribu tena!",
               "Ce lapin dort. Réessayez !")),
            Q(("Tap the bunny that is sleeping.", "Gusa sungura anayelala.",
               "Touchez le lapin qui dort."),
              [(("Sleeping bunny", "Sungura anayelala", "Lapin qui dort"),
                "img/s01/bunny_sleep2.png"),
               (("Clapping bunny", "Sungura anayepiga makofi", "Lapin qui applaudit"),
                "img/s01/bunny_clap2.png")], 0,
              ("Shhh. Sweet dreams.", "Shhh. Ndoto njema.", "Chut. Fais de beaux rêves."),
              ("That bunny is clapping! Try again.", "Sungura huyo anapiga makofi! Jaribu tena.",
               "Ce lapin applaudit ! Réessayez.")),
        ],
    },
]

# --------------------------------------------------------------------------
# New stories — three pages, the shape the shipped stage-1 story already uses.
# --------------------------------------------------------------------------
NEW_STORIES = [
    {
        "id": "s01.sensory.story.02", "subject": "Sensory Exploration",
        "title": ("A Warm, Bright Day", "Siku ya Joto na Mwanga", "Une Journée Chaude et Claire"),
        "objective": ("A slow sensory walk through warm, soft and breezy.",
                      "Matembezi ya polepole ya hisia: joto, ulaini na upepo.",
                      "Une promenade sensorielle : chaud, doux et venteux."),
        "parentNote": ("Pause on each page. Let your baby touch your hand as you read.",
                       "Simama kila ukurasa. Mwache mtoto aguse mkono wako unaposoma.",
                       "Faites une pause à chaque page. Laissez bébé toucher votre main."),
        "pages": [
            (("The sun is warm on your face.", "Jua ni la joto usoni mwako.",
              "Le soleil est chaud sur ton visage."), "img/s01/sun_warm.png"),
            (("The grass is soft under your hands.", "Nyasi ni laini chini ya mikono yako.",
              "L'herbe est douce sous tes mains."), "img/s01/grass_green.png"),
            (("A little breeze says hello. Shhh...", "Upepo mdogo unasalimia. Shhh...",
              "Une petite brise dit bonjour. Chut..."), "img/s01/breeze_leaf.png"),
        ],
    },
    {
        "id": "s01.cause.story.02", "subject": "Cause & Effect",
        "title": ("Tap, Tap, Splash!", "Gusa, Gusa, Chapu!", "Tape, Tape, Plouf !"),
        "objective": ("A story where every action makes something happen.",
                      "Hadithi ambapo kila kitendo hufanya jambo litokee.",
                      "Une histoire où chaque geste produit un effet."),
        "parentNote": ("Tap your knees along with the story.",
                       "Piga magoti yako sambamba na hadithi.",
                       "Tapotez vos genoux au rythme de l'histoire."),
        "pages": [
            (("A small hand taps the water.", "Mkono mdogo unagusa maji.",
              "Une petite main tape l'eau."), "img/s01/puddle.png"),
            (("Splash! The drops jump up high.", "Chapu! Matone yanaruka juu.",
              "Plouf ! Les gouttes sautent en l'air."), "img/s01/splash.png"),
            (("A soft towel makes everything dry again.",
              "Taulo laini inakausha kila kitu tena.",
              "Une serviette douce sèche tout."), "img/s01/towel_dry.png"),
        ],
    },
    {
        "id": "s01.object.story.02", "subject": "Object Permanence",
        "title": ("Where Is Baby Bird?", "Ndege Mdogo Yuko Wapi?", "Où est Bébé Oiseau ?"),
        "objective": ("Someone goes away and comes back — the whole idea, gently.",
                      "Mtu anaondoka na kurudi — wazo zima, kwa upole.",
                      "Quelqu'un part et revient — l'idée entière, en douceur."),
        "parentNote": ("This is the story to read when you leave the room.",
                       "Hii ndiyo hadithi ya kusoma unapotoka chumbani.",
                       "Lisez cette histoire quand vous quittez la pièce."),
        "pages": [
            (("The nest is empty. Where is baby bird?",
              "Kiota kiko tupu. Ndege mdogo yuko wapi?",
              "Le nid est vide. Où est bébé oiseau ?"), "img/s01/nest_empty.png"),
            (("Look! She is flying home.", "Tazama! Anarudi nyumbani akiruka.",
              "Regarde ! Elle rentre à la maison."), "img/s01/bird_return.png"),
            (("Back in the cosy nest. She was always coming back.",
              "Amerudi kiotani. Alikuwa akirudi daima.",
              "De retour dans le nid douillet. Elle revenait toujours."), "img/s01/nest_cosy.png"),
        ],
    },
    {
        "id": "s01.lang.story.02", "subject": "Early Language",
        "title": ("Good Morning, Everyone", "Habari za Asubuhi, Nyote", "Bonjour Tout le Monde"),
        "objective": ("First greeting words, one per page.",
                      "Maneno ya kwanza ya salamu, moja kwa ukurasa.",
                      "Les premiers mots de salutation, un par page."),
        "parentNote": ("Say each greeting to a real person in the room.",
                       "Sema kila salamu kwa mtu halisi aliye chumbani.",
                       "Adressez chaque salutation à une vraie personne."),
        "pages": [
            (("The sun is up. Good morning!", "Jua limechomoza. Habari za asubuhi!",
              "Le soleil est levé. Bonjour !"), "img/s01/morning_sun.png"),
            (("Wave to everyone. Hello, hello!", "Wapungie wote. Hujambo, hujambo!",
              "Saluez tout le monde. Bonjour, bonjour !"), "img/s01/family_wave.png"),
            (("Now we eat together. Yum!", "Sasa tunakula pamoja. Tamu!",
              "Maintenant on mange ensemble. Miam !"), "img/s01/breakfast.png"),
        ],
    },
    {
        "id": "s01.motor.story.02", "subject": "Motor Imitation",
        "title": ("We Can Do It Too", "Na Sisi Tunaweza", "Nous Aussi On Peut"),
        "objective": ("Three actions to copy, one per page.",
                      "Vitendo vitatu vya kuiga, kimoja kwa ukurasa.",
                      "Trois gestes à imiter, un par page."),
        "parentNote": ("Do each action before turning the page.",
                       "Fanyeni kila kitendo kabla ya kugeuza ukurasa.",
                       "Faites chaque geste avant de tourner la page."),
        "pages": [
            (("Clap your hands. Clap, clap!", "Piga makofi. Kofi, kofi!",
              "Tapez des mains. Clap, clap !"), "img/s01/clap_together.png"),
            (("Stomp your feet. Stomp, stomp!", "Kanyaga miguu. Kanya, kanya!",
              "Tapez des pieds. Boum, boum !"), "img/s01/stomp_together.png"),
            (("Now a big hug. All done!", "Sasa kumbatio kubwa. Tumemaliza!",
              "Maintenant un gros câlin. C'est fini !"), "img/s01/hug_together.png"),
        ],
    },
]


# --------------------------------------------------------------------------
# Apply
# --------------------------------------------------------------------------
def build_quiz(spec):
    """Full library item (English) + the i18n keys for all three languages."""
    qid = spec["id"]
    item = {
        "id": qid, "stage": 1, "ages": "0-1", "subject": spec["subject"],
        "type": "quiz", "title": spec["title"][0], "objective": spec["objective"][0],
        "designTier": "parent-led", "reading": False, "timed": False,
        "interaction": spec["interaction"], "parentNote": spec["parentNote"][0],
        "accessibility": ACCESSIBILITY,
        "assets": [], "questions": [],
    }
    keys = {l: {} for l in LANGS}
    for n, lang in enumerate(LANGS):
        keys[lang][f"{qid}.title"] = spec["title"][n]
        keys[lang][f"{qid}.parentNote"] = spec["parentNote"][n]
    seen = set()
    for qn, q in enumerate(spec["questions"]):
        opts = []
        for om, (label, asset) in enumerate(q["options"]):
            opts.append({"label": label[0], "asset": asset})
            for n, lang in enumerate(LANGS):
                keys[lang][f"{qid}.questions.{qn}.options.{om}.label"] = label[n]
            if asset not in seen:
                seen.add(asset)
                item["assets"].append({"type": "image", "ref": asset, "desc": label[0]})
        item["questions"].append({
            "prompt": q["prompt"][0], "options": opts, "answer": q["answer"],
            "correctFeedback": q["correctFeedback"][0], "retryFeedback": q["retryFeedback"][0],
        })
        for n, lang in enumerate(LANGS):
            keys[lang][f"{qid}.questions.{qn}.prompt"] = q["prompt"][n]
            keys[lang][f"{qid}.questions.{qn}.correctFeedback"] = q["correctFeedback"][n]
            keys[lang][f"{qid}.questions.{qn}.retryFeedback"] = q["retryFeedback"][n]
    return item, keys


def build_story(spec):
    sid = spec["id"]
    item = {
        "id": sid, "stage": 1, "ages": "0-1", "subject": spec["subject"],
        "type": "story", "title": spec["title"][0], "objective": spec["objective"][0],
        "designTier": "parent-led", "reading": False, "timed": False,
        "interaction": "listen", "parentNote": spec["parentNote"][0],
        "accessibility": ACCESSIBILITY,
        "assets": [], "pages": [],
    }
    keys = {l: {} for l in LANGS}
    for n, lang in enumerate(LANGS):
        keys[lang][f"{sid}.title"] = spec["title"][n]
        keys[lang][f"{sid}.parentNote"] = spec["parentNote"][n]
    for pn, (narr, ill) in enumerate(spec["pages"]):
        item["pages"].append({"narration": narr[0], "illustration": ill})
        item["assets"].append({"type": "image", "ref": ill, "desc": narr[0]})
        for n, lang in enumerate(LANGS):
            keys[lang][f"{sid}.pages.{pn}.narration"] = narr[n]
    return item, keys


def apply(check_only=False):
    lib = json.loads(LIBRARIES[0].read_text(encoding="utf-8"))
    by_id = {c["id"]: c for c in lib["content"]}
    overlay = {l: {} for l in LANGS}
    problems = []

    # 1. deepen the 30 lessons
    for lid, extras in EXTRA_STEPS.items():
        item = by_id.get(lid)
        if item is None:
            problems.append(f"{lid} not in the library")
            continue
        # Idempotency. The `_authored` flag is stripped before writing (it is
        # bookkeeping, not schema), so on a second run every step looks like an
        # original and the extras get appended a second time. Identify them by
        # their English narration instead, which is stable across runs.
        # Idempotency by position, not by text. Matching on narration looked
        # tidier but broke twice: once when an extra happened to reuse a
        # shipped step's wording (and ate the original), and again whenever an
        # authored line was reworded (the old one stopped being recognised and
        # survived alongside the new). The shipped step count is a fact about
        # the library, so keep it as one and truncate to it.
        n_base = BASE_STEP_COUNTS.get(lid)
        if n_base is None:
            problems.append(f"{lid} has no BASE_STEP_COUNTS entry")
            continue
        if len(item["steps"]) < n_base:
            problems.append(
                f"{lid} has {len(item['steps'])} steps, fewer than the {n_base} "
                f"it shipped with — the library has been edited by hand")
            continue
        base = item["steps"][:n_base]
        steps = list(base)
        for action, mechanic, narr, fb in extras:
            steps.append({
                "narration": narr[0], "action": action, "feedback": fb[0],
                "mechanic": mechanic, "_authored": True,
            })
        for n, s in enumerate(steps):
            for i, lang in enumerate(LANGS):
                if n < len(base):
                    continue
                narr, fb = extras[n - len(base)][2], extras[n - len(base)][3]
                overlay[lang][f"{lid}.steps.{n}.narration"] = narr[i]
                overlay[lang][f"{lid}.steps.{n}.feedback"] = fb[i]
        if not check_only:
            item["steps"] = steps

    # 2. new quizzes and stories
    for spec in NEW_QUIZZES:
        item, keys = build_quiz(spec)
        for lang in LANGS:
            overlay[lang].update(keys[lang])
        if not check_only:
            if spec["id"] in by_id:
                lib["content"][lib["content"].index(by_id[spec["id"]])] = item
            else:
                lib["content"].append(item)
    for spec in NEW_STORIES:
        item, keys = build_story(spec)
        for lang in LANGS:
            overlay[lang].update(keys[lang])
        if not check_only:
            if spec["id"] in by_id:
                lib["content"][lib["content"].index(by_id[spec["id"]])] = item
            else:
                lib["content"].append(item)

    if check_only:
        cur = json.loads(LIBRARIES[0].read_text(encoding="utf-8"))
        cur_ids = {c["id"] for c in cur["content"]}
        for spec in NEW_QUIZZES + NEW_STORIES:
            if spec["id"] not in cur_ids:
                problems.append(f"{spec['id']} missing — re-run author_stage1.py")
        for lid, extras in EXTRA_STEPS.items():
            it = next((c for c in cur["content"] if c["id"] == lid), None)
            if it and len(it["steps"]) < 4:
                problems.append(f"{lid} is {len(it['steps'])} steps — re-run author_stage1.py")
        for p in problems:
            print("  x " + p)
        print("stage 1 check:", "FAILED" if problems else "OK")
        return 1 if problems else 0

    # strip the bookkeeping flag before writing
    for item in lib["content"]:
        for s in item.get("steps", []):
            s.pop("_authored", None)

    lib["content"].sort(key=lambda c: (c["stage"], c["subject"], c["type"], c["id"]))
    for path in LIBRARIES:
        path.write_text(json.dumps(lib, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    for d in I18N_DIRS:
        for lang in LANGS:
            p = d / f"{lang}.json"
            cur = json.loads(p.read_text(encoding="utf-8")) if p.exists() else {}
            cur.update(overlay[lang])
            p.write_text(json.dumps(dict(sorted(cur.items())), indent=2, ensure_ascii=False) + "\n",
                         encoding="utf-8")

    lessons = [c for c in lib["content"] if c["stage"] == 1 and c["type"] == "lesson"]
    print(f"stage 1: {len(EXTRA_STEPS)} lessons deepened "
          f"(now {min(len(l['steps']) for l in lessons)}-{max(len(l['steps']) for l in lessons)} steps), "
          f"{len(NEW_QUIZZES)} quizzes and {len(NEW_STORIES)} stories added")
    print(f"i18n: {len(overlay['en'])} keys per language x {len(LANGS)} languages")
    return 0


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    sys.exit(apply(check_only=ap.parse_args().check))
