/// Curriculum text (curriculum.pptx) in Swahili and French: stage titles,
/// themes, grown-up tips, age bands, grades and every topic's activities.
///
/// The curriculum is authored in English and used to reach every family in
/// English — the "what we'll explore" list on each subject screen, the age
/// picker's band and grade, and the curriculum browser. Keyed by the English
/// source string, like `localizedSubject`; anything missing falls back to
/// English, and test/subjects_test.dart fails the build if anything is.
///
/// These translations have not yet been reviewed by a native speaker.
String localizedCurriculum(String english, String lang) {
  final code = lang.split(RegExp('[_-]')).first;
  if (code == 'en') return english;
  return _curriculum[code]?[english] ?? english;
}

const _curriculum = <String, Map<String, String>>{
  'sw': {
    // ---- age bands and grades
    "Babies & Toddlers": "Watoto Wachanga na Wadogo",
    "Preschool": "Elimu ya Awali",
    "Early Elementary": "Msingi wa Awali",
    "Upper Elementary": "Msingi wa Juu",
    "Kindergarten": "Chekechea",
    "Grade 1": "Darasa la 1",
    "Grade 2": "Darasa la 2",
    "Grade 3": "Darasa la 3",
    "Grade 4": "Darasa la 4",

    // ---- stage titles
    "Sensory & Cause-and-Effect": "Hisia na Sababu-na-Athari",
    "First Words & Concepts": "Maneno na Dhana za Kwanza",
    "Language Explosion & Early Logic": "Mlipuko wa Lugha na Mantiki ya Awali",
    "Pre-Literacy & Foundational Math": "Maandalizi ya Kusoma na Msingi wa Hesabu",
    "Early Reading & Number Sense": "Kusoma kwa Awali na Uelewa wa Namba",
    "Foundations in Academic Subjects": "Misingi ya Masomo",
    "Fluency & Deeper Understanding": "Ufasaha na Uelewa wa Kina",
    "Expanding Knowledge & Skills": "Kupanua Maarifa na Ujuzi",
    "Critical Thinking & Independence": "Kufikiri kwa Kina na Kujitegemea",
    "Abstract Thinking & Synthesis": "Kufikiri kwa Dhana na Kuunganisha Mawazo",

    // ---- stage themes
    "Learning is entirely sensory-motor — foundational cognitive and physical experiences rather than school subjects.":
        "Kujifunza ni kwa hisia na mwili pekee — uzoefu wa msingi wa akili na mwili, si masomo ya shule.",
    "Toddlers build vocabulary and begin to categorize the world around them.":
        "Watoto wadogo hujenga msamiati na kuanza kupanga ulimwengu unaowazunguka katika makundi.",
    "Vocabulary booms and symbolic thinking emerges; pretend play becomes a major driver of learning.":
        "Msamiati huongezeka kwa kasi na fikra za kiishara huanza; michezo ya kuigiza inakuwa chanzo kikuu cha kujifunza.",
    "The golden age for laying the groundwork of reading, writing and arithmetic through play.":
        "Kipindi bora cha kujenga msingi wa kusoma, kuandika na hesabu kupitia michezo.",
    "Kindergarten-readiness skills dominate — but play remains the vehicle for every lesson.":
        "Ujuzi wa kujiandaa kwa shule unatawala — lakini mchezo unabaki kuwa njia ya kila somo.",
    "Children handle more structured learning while still thriving with hands-on, colorful activities.":
        "Watoto hushughulikia masomo yenye mpangilio zaidi huku bado wakistawi kwa shughuli za vitendo zenye rangi.",
    "Reading fluency takes off and math begins to grow more abstract.":
        "Ufasaha wa kusoma unaanza kupaa na hesabu zinaanza kuwa za kidhahania zaidi.",
    "More independent learners who can handle longer, richer interactive lessons.":
        "Wanafunzi wanaojitegemea zaidi wanaoweza kumudu masomo marefu na tajiri ya kushirikiana.",
    "A major shift from “learning to read” to “reading to learn,” with more abstract math.":
        "Mabadiliko makubwa kutoka “kujifunza kusoma” hadi “kusoma ili kujifunza,” pamoja na hesabu za kidhahania zaidi.",
    "Pre-adolescents reason abstractly, tackle multi-step problems, and use technology to create.":
        "Watoto wanaokaribia ujana hufikiri kwa dhana, hutatua matatizo ya hatua nyingi, na hutumia teknolojia kubuni.",

    // ---- grown-up tips
    "Zero reading. Large, slow visuals, gentle sounds, guided-access mode — parent narration is key.":
        "Hakuna kusoma. Picha kubwa na za polepole, sauti laini, hali ya ufikiaji ulioongozwa — masimulizi ya mzazi ni muhimu.",
    "Everything responds to a single tap. Real photos, cheerful voice encouragement — no text needed yet.":
        "Kila kitu hujibu mguso mmoja. Picha halisi, sauti ya kutia moyo yenye furaha — hakuna maandishi yanayohitajika bado.",
    "Limit text to one word or emoji. A friendly character guide speaks directly; let parents record their own voice.":
        "Punguza maandishi hadi neno moja au emoji. Mhusika rafiki huongea moja kwa moja; waache wazazi warekodi sauti zao.",
    "Use a friendly narrator, reward effort over correct answers, and avoid any time pressure.":
        "Tumia msimulizi rafiki, tuza juhudi kuliko majibu sahihi, na epuka shinikizo lolote la muda.",
    "Build on the friendly-narrator model with picture prompts, gentle pacing and playful coding warm-ups.":
        "Jenga juu ya msimulizi rafiki kwa vidokezo vya picha, mwendo wa taratibu na mazoezi ya awali ya usimbaji yenye mchezo.",
    "Introduce gentle gamification while keeping instructions clear and repeatable.":
        "Anzisha michezo ya zawadi kwa upole huku maelekezo yakibaki wazi na yanayoweza kurudiwa.",
    "Lean into badges and levels, but keep every instruction clear and repeatable.":
        "Tumia beji na viwango zaidi, lakini kila maelekezo yabaki wazi na yanayoweza kurudiwa.",
    "Offer growing autonomy with clear goals and steady, repeatable structure.":
        "Toa uhuru unaoongezeka pamoja na malengo wazi na mpangilio thabiti unaoweza kurudiwa.",
    "Offer autonomy, progress dashboards and creative build-and-code tools.":
        "Toa uhuru, dashibodi za maendeleo na zana za ubunifu za kujenga na kusimba.",
    "Maximize autonomy with dashboards and open-ended creative and coding projects.":
        "Ongeza uhuru kwa dashibodi na miradi huru ya ubunifu na usimbaji.",

    // ---- stage 1 activities
    "Swipe high-contrast patterns": "Telezesha kidole kwenye michoro yenye utofauti mkubwa",
    "Tap rattle, bell & nature sounds": "Gusa sauti za njuga, kengele na mazingira",
    "Press to feel textures (haptics)": "Bonyeza kuhisi maumbile ya vitu (mtetemo)",
    "Tap to make a star appear": "Gusa ili nyota itokee",
    "Shake the device for sound": "Tikisa kifaa upate sauti",
    "Pop floating bubbles": "Pasua mapovu yanayoelea",
    "Peekaboo reveal games": "Michezo ya kujificha na kujitokeza",
    "Hide a toy behind a virtual cloth": "Ficha mwanasesere nyuma ya kitambaa cha skrini",
    "Find the hidden animal": "Tafuta mnyama aliyejificha",
    "First words: mama, dada": "Maneno ya kwanza: mama, baba",
    "Tap animals to hear their sounds": "Gusa wanyama usikie sauti zao",
    "Sing-along nursery rhymes": "Imba pamoja nyimbo za watoto",
    "Clap along with the screen": "Piga makofi pamoja na skrini",
    "Wave bye-bye to characters": "Wapungie wahusika kwaheri",
    "Copy finger-drag gestures": "Iga ishara za kuburuta kidole",

    // ---- stage 2 activities
    "Tap to hear names & sounds": "Gusa usikie majina na sauti",
    "Where they live: farm, jungle, ocean": "Wanapoishi: shambani, msituni, baharini",
    "Match babies to parent animals": "Linganisha watoto na wazazi wao wanyama",
    "Point to eyes, nose, mouth": "Onyesha macho, pua, mdomo",
    "Drag features onto a face": "Buruta sehemu za uso mahali pake",
    "Sing head, shoulders, knees": "Imba kichwa, mabega, magoti",
    "Red, blue, yellow": "Nyekundu, bluu, njano",
    "Circle, square, triangle": "Duara, mraba, pembetatu",
    "Tap the matching color": "Gusa rangi inayolingana",
    "Match by color or size": "Linganisha kwa rangi au ukubwa",
    "Big & small into buckets": "Vikubwa na vidogo kwenye ndoo",
    "Drag shapes into slots": "Buruta maumbo kwenye nafasi zake",
    "Count 1–3 with objects": "Hesabu 1–3 kwa vitu",
    "Recognize the numeral 1": "Tambua tarakimu 1",
    "Tap each item to count": "Gusa kila kitu ili kuhesabu",
    "Action songs & drum tapping": "Nyimbo za vitendo na kupiga ngoma",
    "Teeth, dressing, bath time": "Kupiga mswaki, kuvaa, kuoga",
    "Follow a daily routine chart": "Fuata chati ya ratiba ya kila siku",

    // ---- stage 3 activities
    "Categories: food, clothes, vehicles": "Makundi: chakula, nguo, magari",
    "Action words: run, jump, eat": "Maneno ya vitendo: kimbia, ruka, kula",
    "Tap a picture to hear the word": "Gusa picha usikie neno",
    "Rhyming games": "Michezo ya vina",
    "Beginning sounds & syllable clapping": "Sauti za mwanzo na kupiga makofi kwa silabi",
    "Tap the words that rhyme": "Gusa maneno yenye vina",
    "Rote count to 5–10": "Hesabu kwa mdomo hadi 5–10",
    "One carrot per rabbit": "Karoti moja kwa kila sungura",
    "Numerals 1–5": "Tarakimu 1–5",
    "AB patterns: red-blue-red": "Mifumo AB: nyekundu-bluu-nyekundu",
    "Hot/cold, big/small, up/down": "Moto/baridi, kubwa/ndogo, juu/chini",
    "Tap what comes next": "Gusa kinachofuata",
    "Happy, sad, angry faces": "Nyuso za furaha, huzuni, hasira",
    "“How does she feel?”": "“Anajisikiaje?”",
    "Match the face to the feeling": "Linganisha uso na hisia",
    "Trace a dotted path to mom": "Fuatisha njia ya vitone hadi kwa mama",
    "Tap to turn the page": "Gusa ili kugeuza ukurasa",
    "Listen to a narrated story": "Sikiliza hadithi inayosimuliwa",

    // ---- stage 4 activities
    "Uppercase letters & sounds": "Herufi kubwa na sauti zake",
    "Recognize own name": "Tambua jina lako",
    "Story: beginning–middle–end": "Hadithi: mwanzo–kati–mwisho",
    "Count to 10, shapes around us": "Hesabu hadi 10, maumbo yanayotuzunguka",
    "Longer/shorter, AB & AABB": "Ndefu zaidi/fupi zaidi, AB na AABB",
    "Simple puzzles & mazes": "Mafumbo rahisi na njia za kutatanisha",
    "Habitats: ocean, desert, arctic": "Makazi: bahari, jangwa, ncha ya dunia",
    "Weather, seasons, seed-to-flower": "Hali ya hewa, majira, kutoka mbegu hadi ua",
    "The five senses": "Hisia tano",
    "Family & community helpers": "Familia na wasaidizi wa jamii",
    "Doctor, firefighter, teacher": "Daktari, mzima moto, mwalimu",
    "Celebrations worldwide": "Sherehe duniani kote",
    "Color mixing: red + blue = purple": "Kuchanganya rangi: nyekundu + bluu = zambarau",
    "Rhythm, pitch & free drawing": "Mdundo, kiimbo na kuchora huru",
    "Finger-paint on the screen": "Paka rangi kwa kidole kwenye skrini",
    "Name & manage feelings": "Taja na dhibiti hisia",
    "Turn-taking & sharing": "Kupeana zamu na kushirikiana",
    "Calm-down breathing game": "Mchezo wa kupumua ili kutulia",

    // ---- stage 5 activities
    "Blend CVC words: c-a-t → cat": "Unganisha sauti kuwa neno: p-a-k-a → paka",
    "Beginning sight words": "Maneno ya kwanza ya kuona",
    "Trace lowercase letters": "Fuatisha herufi ndogo",
    "Count to 20 & back from 10": "Hesabu hadi 20 na kurudi nyuma kutoka 10",
    "Add/subtract within 5": "Jumlisha/toa ndani ya 5",
    "3D shapes, days of the week": "Maumbo ya 3D, siku za wiki",
    "Living vs. non-living": "Vitu hai na visivyo hai",
    "Sink vs. float experiments": "Majaribio ya kuzama au kuelea",
    "Mountains, rivers, oceans": "Milima, mito, bahari",
    "Maps & globes: land vs. water": "Ramani na globu: nchi kavu na maji",
    "Jobs & why they matter": "Kazi na umuhimu wake",
    "Safety signs & symbols": "Alama na ishara za usalama",
    "Story from picture prompts": "Hadithi kutokana na vidokezo vya picha",
    "High/low, fast/slow music": "Muziki wa juu/chini, kasi/polepole",
    "Commands: forward, turn left": "Amri: mbele, geuka kushoto",

    // ---- stage 6 activities
    "Read decodable books": "Soma vitabu vinavyosomeka kwa sauti za herufi",
    "Write short sentences": "Andika sentensi fupi",
    "Capitals & end punctuation": "Herufi kubwa na alama za mwisho wa sentensi",
    "Numbers to 100, skip-count": "Namba hadi 100, kuhesabu kwa kuruka",
    "Ten frames & number lines": "Fremu za kumi na mistari ya namba",
    "Place value, coins, time to hour": "Thamani ya nafasi, sarafu, saa kamili",
    "Mammals, birds, reptiles, fish": "Mamalia, ndege, reptilia, samaki",
    "Solid, liquid, gas": "Yabisi, kimiminika, gesi",
    "Sun, moon & stars": "Jua, mwezi na nyota",
    "How communities work": "Jinsi jamii zinavyofanya kazi",
    "Flag & anthem": "Bendera na wimbo wa taifa",
    "Then vs. now timelines": "Ratiba za zamani na sasa",
    "First-then-next sequencing": "Kupanga kwa mfuatano: kwanza, kisha, baadaye",
    "Drag-and-drop block coding": "Usimbaji wa vitalu kwa kuburuta na kuachia",
    "Guide a robot through a maze": "Ongoza roboti kupitia njia za kutatanisha",

    // ---- stage 7 activities
    "Fluency, predict & question": "Ufasaha, kutabiri na kuuliza maswali",
    "Silent-e, vowel teams": "Kanuni za tahajia: e kimya, jozi za irabu",
    "Sight words": "Maneno ya kuona",
    "Simple paragraphs": "Aya rahisi",
    "“I like __ because…”": "“Ninapenda __ kwa sababu…”",
    "Nouns, verbs, adjectives": "Nomino, vitenzi, vivumishi",
    "Add/subtract within 20": "Jumlisha/toa ndani ya 20",
    "Place value to 100": "Thamani ya nafasi hadi 100",
    "Ruler, half-hour, bar graphs": "Rula, nusu saa, grafu za mihimili",
    "Habitats & adaptations": "Makazi na namna viumbe vinavyojizoesha",
    "Life cycles: butterfly, frog": "Mizunguko ya maisha: kipepeo, chura",
    "Simple machines, solar system": "Mashine rahisi, mfumo wa jua",
    "Continents & oceans": "Mabara na bahari",
    "Legend & compass rose": "Ufunguo wa ramani na dira",
    "Needs vs. wants": "Mahitaji na matakwa",
    "Food groups & hygiene": "Makundi ya vyakula na usafi",
    "Coping: deep breaths, count to ten": "Kukabiliana: pumua kwa kina, hesabu hadi kumi",
    "Safe vs. unsafe choices": "Maamuzi salama na yasiyo salama",

    // ---- stage 8 activities
    "Chapter-book excerpts": "Vipande vya vitabu vya sura",
    "Story structure, compare/contrast": "Muundo wa hadithi, kulinganisha na kutofautisha",
    "Folk tales & fables": "Hadithi za jadi na ngano",
    "Personal narratives, letters": "Masimulizi binafsi, barua",
    "Plurals & verb tenses": "Wingi na nyakati za vitenzi",
    "Punctuation": "Uakifishaji",
    "Two-digit regrouping": "Kupanga upya kwa namba za tarakimu mbili",
    "Multiplication: arrays & groups": "Kuzidisha: safu na makundi",
    "Fractions: halves, thirds, fourths": "Sehemu: nusu, theluthi, robo",
    "Rocks, minerals & erosion": "Miamba, madini na mmomonyoko",
    "Food chains & webs": "Minyororo na mitandao ya chakula",
    "Engineering design cycle": "Mzunguko wa usanifu wa kihandisi",
    "Ancient Egypt & China": "Misri na China ya kale",
    "Map scale & grid": "Kipimo cha ramani na gridi",
    "Urban, suburban, rural": "Mjini, pembezoni mwa mji, vijijini",
    "Coding with Scratch Jr.": "Usimbaji kwa Scratch Jr.",
    "Digital art": "Sanaa ya kidijitali",
    "Notation: quarter note, rest": "Nukuu za muziki: noti ya robo, kituo",

    // ---- stage 9 activities
    "Main idea & inferencing": "Wazo kuu na kukisia",
    "Biography, poetry, nonfiction": "Wasifu, ushairi, maandishi yasiyo ya kubuni",
    "Simile & metaphor": "Tashbihi na sitiari",
    "Organized paragraphs": "Aya zilizopangwa",
    "Opinion pieces & note-taking": "Maandishi ya maoni na kuchukua kumbukumbu",
    "Cursive or typing": "Mwandiko wa kuunganisha au kuchapa",
    "Multiplication & division facts": "Kanuni za kuzidisha na kugawanya",
    "Area & perimeter": "Eneo na mzingo",
    "Equivalent fractions, elapsed time": "Sehemu sawa, muda uliopita",
    "Force, motion & magnetism": "Nguvu, mwendo na sumaku",
    "Ecosystems & body systems": "Mifumo ikolojia na mifumo ya mwili",
    "Weather vs. climate": "Hali ya hewa na tabianchi",
    "Branches of government": "Mihimili ya serikali",
    "Famous inventors & scientists": "Wagunduzi na wanasayansi maarufu",
    "Goods, services & saving": "Bidhaa, huduma na kuweka akiba",
    "Loops & conditionals": "Vitanzi na masharti",
    "Logic puzzles": "Mafumbo ya mantiki",
    "Intro to keyboarding": "Utangulizi wa kutumia kibodi",

    // ---- stage 10 activities
    "Novel excerpts": "Vipande vya riwaya",
    "Author’s purpose & point of view": "Lengo la mwandishi na mtazamo wake",
    "Nonfiction text features": "Sifa za maandishi yasiyo ya kubuni",
    "Multi-paragraph essays": "Insha za aya nyingi",
    "Persuasive writing": "Uandishi wa kushawishi",
    "Editing for clarity": "Kuhariri ili kuleta uwazi",
    "Long division, decimals": "Kugawanya kwa kirefu, desimali",
    "Add/subtract like fractions": "Jumlisha/toa sehemu zenye kiasi sawa",
    "Angles, symmetry, probability": "Pembe, ulinganifu, uwezekano",
    "Electricity & circuits": "Umeme na saketi",
    "Adaptations & heredity": "Kujizoesha na urithi",
    "Moon phases; build-a-bridge STEM": "Awamu za mwezi; kujenga daraja (STEM)",
    "State & regional history": "Historia ya nchi na kanda",
    "Medieval & Indigenous cultures": "Tamaduni za zama za kati na za wenyeji",
    "Latitude, longitude, enterprise": "Latitudo, longitudo, ujasiriamali",
    "Internet safety": "Usalama mtandaoni",
    "Evaluate online sources": "Tathmini vyanzo vya mtandaoni",
    "Scratch games & intro Python": "Michezo ya Scratch na utangulizi wa Python",
  },
  'fr': {
    // ---- age bands and grades
    "Babies & Toddlers": "Bébés et tout-petits",
    "Preschool": "Préscolaire",
    "Early Elementary": "Début du primaire",
    "Upper Elementary": "Fin du primaire",
    "Kindergarten": "Grande section",
    "Grade 1": "CP",
    "Grade 2": "CE1",
    "Grade 3": "CE2",
    "Grade 4": "CM1",

    // ---- stage titles
    "Sensory & Cause-and-Effect": "Les sens et la cause à effet",
    "First Words & Concepts": "Premiers mots et concepts",
    "Language Explosion & Early Logic": "Explosion du langage et logique précoce",
    "Pre-Literacy & Foundational Math": "Pré-lecture et mathématiques de base",
    "Early Reading & Number Sense": "Premières lectures et sens du nombre",
    "Foundations in Academic Subjects": "Bases des matières scolaires",
    "Fluency & Deeper Understanding": "Fluidité et compréhension approfondie",
    "Expanding Knowledge & Skills": "Élargir connaissances et compétences",
    "Critical Thinking & Independence": "Esprit critique et autonomie",
    "Abstract Thinking & Synthesis": "Pensée abstraite et synthèse",

    // ---- stage themes
    "Learning is entirely sensory-motor — foundational cognitive and physical experiences rather than school subjects.":
        "L'apprentissage est entièrement sensori-moteur — des expériences cognitives et physiques fondamentales plutôt que des matières scolaires.",
    "Toddlers build vocabulary and begin to categorize the world around them.":
        "Les tout-petits enrichissent leur vocabulaire et commencent à classer le monde qui les entoure.",
    "Vocabulary booms and symbolic thinking emerges; pretend play becomes a major driver of learning.":
        "Le vocabulaire explose et la pensée symbolique apparaît ; le jeu de faire-semblant devient un moteur essentiel de l'apprentissage.",
    "The golden age for laying the groundwork of reading, writing and arithmetic through play.":
        "L'âge d'or pour poser les bases de la lecture, de l'écriture et du calcul par le jeu.",
    "Kindergarten-readiness skills dominate — but play remains the vehicle for every lesson.":
        "Les compétences de préparation à l'école dominent — mais le jeu reste le moyen de chaque leçon.",
    "Children handle more structured learning while still thriving with hands-on, colorful activities.":
        "Les enfants abordent un apprentissage plus structuré tout en s'épanouissant avec des activités concrètes et colorées.",
    "Reading fluency takes off and math begins to grow more abstract.":
        "La fluidité en lecture décolle et les maths deviennent plus abstraites.",
    "More independent learners who can handle longer, richer interactive lessons.":
        "Des apprenants plus autonomes, capables de suivre des leçons interactives plus longues et plus riches.",
    "A major shift from “learning to read” to “reading to learn,” with more abstract math.":
        "Un grand passage de « apprendre à lire » à « lire pour apprendre », avec des maths plus abstraites.",
    "Pre-adolescents reason abstractly, tackle multi-step problems, and use technology to create.":
        "Les préadolescents raisonnent de façon abstraite, résolvent des problèmes en plusieurs étapes et créent avec la technologie.",

    // ---- grown-up tips
    "Zero reading. Large, slow visuals, gentle sounds, guided-access mode — parent narration is key.":
        "Aucune lecture. De grandes images lentes, des sons doux, le mode accès guidé — la narration du parent est essentielle.",
    "Everything responds to a single tap. Real photos, cheerful voice encouragement — no text needed yet.":
        "Tout réagit à un seul toucher. De vraies photos, une voix joyeuse et encourageante — pas encore besoin de texte.",
    "Limit text to one word or emoji. A friendly character guide speaks directly; let parents record their own voice.":
        "Limitez le texte à un mot ou un emoji. Un personnage guide amical parle directement ; laissez les parents enregistrer leur voix.",
    "Use a friendly narrator, reward effort over correct answers, and avoid any time pressure.":
        "Utilisez un narrateur bienveillant, récompensez l'effort plutôt que les bonnes réponses et évitez toute pression de temps.",
    "Build on the friendly-narrator model with picture prompts, gentle pacing and playful coding warm-ups.":
        "Prolongez le modèle du narrateur bienveillant avec des images-indices, un rythme doux et des échauffements ludiques au code.",
    "Introduce gentle gamification while keeping instructions clear and repeatable.":
        "Introduisez une ludification douce en gardant des consignes claires et répétables.",
    "Lean into badges and levels, but keep every instruction clear and repeatable.":
        "Misez sur les badges et les niveaux, mais gardez chaque consigne claire et répétable.",
    "Offer growing autonomy with clear goals and steady, repeatable structure.":
        "Offrez une autonomie croissante avec des objectifs clairs et une structure stable et répétable.",
    "Offer autonomy, progress dashboards and creative build-and-code tools.":
        "Offrez de l'autonomie, des tableaux de progression et des outils créatifs pour construire et coder.",
    "Maximize autonomy with dashboards and open-ended creative and coding projects.":
        "Maximisez l'autonomie avec des tableaux de bord et des projets ouverts de création et de code.",

    // ---- stage 1 activities
    "Swipe high-contrast patterns": "Glisser sur des motifs très contrastés",
    "Tap rattle, bell & nature sounds": "Toucher des sons de hochet, de cloche et de nature",
    "Press to feel textures (haptics)": "Appuyer pour sentir des textures (vibrations)",
    "Tap to make a star appear": "Toucher pour faire apparaître une étoile",
    "Shake the device for sound": "Secouer l'appareil pour faire un son",
    "Pop floating bubbles": "Éclater des bulles qui flottent",
    "Peekaboo reveal games": "Jeux de coucou-caché",
    "Hide a toy behind a virtual cloth": "Cacher un jouet derrière un tissu virtuel",
    "Find the hidden animal": "Trouver l'animal caché",
    "First words: mama, dada": "Premiers mots : maman, papa",
    "Tap animals to hear their sounds": "Toucher les animaux pour entendre leurs cris",
    "Sing-along nursery rhymes": "Chanter ensemble des comptines",
    "Clap along with the screen": "Taper des mains avec l'écran",
    "Wave bye-bye to characters": "Faire au revoir aux personnages",
    "Copy finger-drag gestures": "Imiter des gestes de glissement du doigt",

    // ---- stage 2 activities
    "Tap to hear names & sounds": "Toucher pour entendre les noms et les cris",
    "Where they live: farm, jungle, ocean": "Où ils vivent : ferme, jungle, océan",
    "Match babies to parent animals": "Associer les bébés à leurs parents",
    "Point to eyes, nose, mouth": "Montrer les yeux, le nez, la bouche",
    "Drag features onto a face": "Glisser les traits sur un visage",
    "Sing head, shoulders, knees": "Chanter tête, épaules, genoux",
    "Red, blue, yellow": "Rouge, bleu, jaune",
    "Circle, square, triangle": "Cercle, carré, triangle",
    "Tap the matching color": "Toucher la couleur assortie",
    "Match by color or size": "Associer par couleur ou par taille",
    "Big & small into buckets": "Grands et petits dans des seaux",
    "Drag shapes into slots": "Glisser des formes dans leurs encoches",
    "Count 1–3 with objects": "Compter de 1 à 3 avec des objets",
    "Recognize the numeral 1": "Reconnaître le chiffre 1",
    "Tap each item to count": "Toucher chaque objet pour compter",
    "Action songs & drum tapping": "Chansons à gestes et tambour",
    "Teeth, dressing, bath time": "Dents, habillage, heure du bain",
    "Follow a daily routine chart": "Suivre un tableau de routine quotidienne",

    // ---- stage 3 activities
    "Categories: food, clothes, vehicles": "Catégories : nourriture, vêtements, véhicules",
    "Action words: run, jump, eat": "Mots d'action : courir, sauter, manger",
    "Tap a picture to hear the word": "Toucher une image pour entendre le mot",
    "Rhyming games": "Jeux de rimes",
    "Beginning sounds & syllable clapping": "Sons du début et syllabes frappées",
    "Tap the words that rhyme": "Toucher les mots qui riment",
    "Rote count to 5–10": "Réciter les nombres jusqu'à 5–10",
    "One carrot per rabbit": "Une carotte par lapin",
    "Numerals 1–5": "Chiffres de 1 à 5",
    "AB patterns: red-blue-red": "Motifs AB : rouge-bleu-rouge",
    "Hot/cold, big/small, up/down": "Chaud/froid, grand/petit, haut/bas",
    "Tap what comes next": "Toucher ce qui vient ensuite",
    "Happy, sad, angry faces": "Visages joyeux, tristes, fâchés",
    "“How does she feel?”": "« Comment se sent-elle ? »",
    "Match the face to the feeling": "Associer le visage à l'émotion",
    "Trace a dotted path to mom": "Suivre un chemin en pointillés jusqu'à maman",
    "Tap to turn the page": "Toucher pour tourner la page",
    "Listen to a narrated story": "Écouter une histoire racontée",

    // ---- stage 4 activities
    "Uppercase letters & sounds": "Lettres majuscules et leurs sons",
    "Recognize own name": "Reconnaître son prénom",
    "Story: beginning–middle–end": "Histoire : début–milieu–fin",
    "Count to 10, shapes around us": "Compter jusqu'à 10, les formes autour de nous",
    "Longer/shorter, AB & AABB": "Plus long/plus court, AB et AABB",
    "Simple puzzles & mazes": "Puzzles simples et labyrinthes",
    "Habitats: ocean, desert, arctic": "Habitats : océan, désert, Arctique",
    "Weather, seasons, seed-to-flower": "Météo, saisons, de la graine à la fleur",
    "The five senses": "Les cinq sens",
    "Family & community helpers": "La famille et ceux qui aident dans la communauté",
    "Doctor, firefighter, teacher": "Médecin, pompier, enseignant",
    "Celebrations worldwide": "Fêtes du monde entier",
    "Color mixing: red + blue = purple": "Mélange des couleurs : rouge + bleu = violet",
    "Rhythm, pitch & free drawing": "Rythme, hauteur des sons et dessin libre",
    "Finger-paint on the screen": "Peindre avec le doigt sur l'écran",
    "Name & manage feelings": "Nommer et gérer ses émotions",
    "Turn-taking & sharing": "Chacun son tour et partager",
    "Calm-down breathing game": "Jeu de respiration pour se calmer",

    // ---- stage 5 activities
    "Blend CVC words: c-a-t → cat": "Fusionner des sons en mots : c-h-a-t → chat",
    "Beginning sight words": "Premiers mots-outils",
    "Trace lowercase letters": "Tracer les lettres minuscules",
    "Count to 20 & back from 10": "Compter jusqu'à 20 et à rebours depuis 10",
    "Add/subtract within 5": "Additionner/soustraire jusqu'à 5",
    "3D shapes, days of the week": "Solides 3D, jours de la semaine",
    "Living vs. non-living": "Vivant ou non vivant",
    "Sink vs. float experiments": "Expériences : couler ou flotter",
    "Mountains, rivers, oceans": "Montagnes, rivières, océans",
    "Maps & globes: land vs. water": "Cartes et globes : terre ou eau",
    "Jobs & why they matter": "Les métiers et leur utilité",
    "Safety signs & symbols": "Panneaux et symboles de sécurité",
    "Story from picture prompts": "Inventer une histoire à partir d'images",
    "High/low, fast/slow music": "Musique aiguë/grave, rapide/lente",
    "Commands: forward, turn left": "Commandes : avancer, tourner à gauche",

    // ---- stage 6 activities
    "Read decodable books": "Lire des livres déchiffrables",
    "Write short sentences": "Écrire des phrases courtes",
    "Capitals & end punctuation": "Majuscules et ponctuation finale",
    "Numbers to 100, skip-count": "Nombres jusqu'à 100, compter par bonds",
    "Ten frames & number lines": "Cadres à dix cases et droites numériques",
    "Place value, coins, time to hour": "Valeur de position, pièces, heure pile",
    "Mammals, birds, reptiles, fish": "Mammifères, oiseaux, reptiles, poissons",
    "Solid, liquid, gas": "Solide, liquide, gaz",
    "Sun, moon & stars": "Soleil, lune et étoiles",
    "How communities work": "Comment fonctionnent les communautés",
    "Flag & anthem": "Drapeau et hymne",
    "Then vs. now timelines": "Frises chronologiques : autrefois et aujourd'hui",
    "First-then-next sequencing": "Mettre en ordre : d'abord, puis, ensuite",
    "Drag-and-drop block coding": "Code par blocs en glisser-déposer",
    "Guide a robot through a maze": "Guider un robot dans un labyrinthe",

    // ---- stage 7 activities
    "Fluency, predict & question": "Fluidité, prédire et questionner",
    "Silent-e, vowel teams": "Règles d'orthographe : e muet, groupes de voyelles",
    "Sight words": "Mots-outils",
    "Simple paragraphs": "Paragraphes simples",
    "“I like __ because…”": "« J'aime __ parce que… »",
    "Nouns, verbs, adjectives": "Noms, verbes, adjectifs",
    "Add/subtract within 20": "Additionner/soustraire jusqu'à 20",
    "Place value to 100": "Valeur de position jusqu'à 100",
    "Ruler, half-hour, bar graphs": "Règle, demi-heure, diagrammes en barres",
    "Habitats & adaptations": "Habitats et adaptations des êtres vivants",
    "Life cycles: butterfly, frog": "Cycles de vie : papillon, grenouille",
    "Simple machines, solar system": "Machines simples, système solaire",
    "Continents & oceans": "Continents et océans",
    "Legend & compass rose": "Légende et rose des vents",
    "Needs vs. wants": "Besoins ou envies",
    "Food groups & hygiene": "Groupes d'aliments et hygiène",
    "Coping: deep breaths, count to ten": "Faire face : respirer profondément, compter jusqu'à dix",
    "Safe vs. unsafe choices": "Choix sûrs ou dangereux",

    // ---- stage 8 activities
    "Chapter-book excerpts": "Extraits de romans à chapitres",
    "Story structure, compare/contrast": "Structure du récit, comparer et opposer",
    "Folk tales & fables": "Contes populaires et fables",
    "Personal narratives, letters": "Récits personnels, lettres",
    "Plurals & verb tenses": "Pluriels et temps des verbes",
    "Punctuation": "Ponctuation",
    "Two-digit regrouping": "Retenues avec des nombres à deux chiffres",
    "Multiplication: arrays & groups": "Multiplication : tableaux et groupes",
    "Fractions: halves, thirds, fourths": "Fractions : demis, tiers, quarts",
    "Rocks, minerals & erosion": "Roches, minéraux et érosion",
    "Food chains & webs": "Chaînes et réseaux alimentaires",
    "Engineering design cycle": "Cycle de conception en ingénierie",
    "Ancient Egypt & China": "L'Égypte et la Chine anciennes",
    "Map scale & grid": "Échelle et quadrillage de carte",
    "Urban, suburban, rural": "Urbain, périurbain, rural",
    "Coding with Scratch Jr.": "Coder avec Scratch Jr.",
    "Digital art": "Art numérique",
    "Notation: quarter note, rest": "Notation : noire, silence",

    // ---- stage 9 activities
    "Main idea & inferencing": "Idée principale et inférences",
    "Biography, poetry, nonfiction": "Biographie, poésie, documentaires",
    "Simile & metaphor": "Comparaison et métaphore",
    "Organized paragraphs": "Paragraphes organisés",
    "Opinion pieces & note-taking": "Textes d'opinion et prise de notes",
    "Cursive or typing": "Écriture cursive ou au clavier",
    "Multiplication & division facts": "Tables de multiplication et de division",
    "Area & perimeter": "Aire et périmètre",
    "Equivalent fractions, elapsed time": "Fractions équivalentes, durée écoulée",
    "Force, motion & magnetism": "Force, mouvement et magnétisme",
    "Ecosystems & body systems": "Écosystèmes et systèmes du corps",
    "Weather vs. climate": "Météo ou climat",
    "Branches of government": "Les pouvoirs de l'État",
    "Famous inventors & scientists": "Inventeurs et scientifiques célèbres",
    "Goods, services & saving": "Biens, services et épargne",
    "Loops & conditionals": "Boucles et conditions",
    "Logic puzzles": "Énigmes de logique",
    "Intro to keyboarding": "Initiation au clavier",

    // ---- stage 10 activities
    "Novel excerpts": "Extraits de romans",
    "Author’s purpose & point of view": "Intention de l'auteur et point de vue",
    "Nonfiction text features": "Caractéristiques des textes documentaires",
    "Multi-paragraph essays": "Rédactions en plusieurs paragraphes",
    "Persuasive writing": "Écriture argumentative",
    "Editing for clarity": "Réviser pour plus de clarté",
    "Long division, decimals": "Division posée, nombres décimaux",
    "Add/subtract like fractions": "Additionner/soustraire des fractions de même dénominateur",
    "Angles, symmetry, probability": "Angles, symétrie, probabilités",
    "Electricity & circuits": "Électricité et circuits",
    "Adaptations & heredity": "Adaptations et hérédité",
    "Moon phases; build-a-bridge STEM": "Phases de la Lune ; construire un pont (STIM)",
    "State & regional history": "Histoire nationale et régionale",
    "Medieval & Indigenous cultures": "Cultures médiévales et autochtones",
    "Latitude, longitude, enterprise": "Latitude, longitude, entreprise",
    "Internet safety": "Sécurité sur Internet",
    "Evaluate online sources": "Évaluer les sources en ligne",
    "Scratch games & intro Python": "Jeux Scratch et initiation à Python",
  },
};
