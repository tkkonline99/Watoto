import '../../core/config/publish_config.dart';
import 'curriculum_models.dart';

/// The full curriculum from curriculum.pptx, transcribed faithfully.
/// Content is English (as authored in the deck); UI chrome is localized.
const curriculumStages = <CurriculumStage>[
  CurriculumStage(
    stage: 1, minAge: 0, maxAge: 1, ageRange: "0–1", band: "Babies & Toddlers",
    title: "Sensory & Cause-and-Effect",
    theme: "Learning is entirely sensory-motor — foundational cognitive and physical experiences rather than school subjects.",
    designTip: "Zero reading. Large, slow visuals, gentle sounds, guided-access mode — parent narration is key.",
    topics: [
      CurriculumTopic(name: "Sensory Exploration", activities: [
        "Swipe high-contrast patterns", "Tap rattle, bell & nature sounds", "Press to feel textures (haptics)"]),
      CurriculumTopic(name: "Cause & Effect", activities: [
        "Tap to make a star appear", "Shake the device for sound", "Pop floating bubbles"]),
      CurriculumTopic(name: "Object Permanence", activities: [
        "Peekaboo reveal games", "Hide a toy behind a virtual cloth", "Find the hidden animal"]),
      CurriculumTopic(name: "Early Language", activities: [
        "First words: mama, dada", "Tap animals to hear their sounds", "Sing-along nursery rhymes"]),
      CurriculumTopic(name: "Motor Imitation", activities: [
        "Clap along with the screen", "Wave bye-bye to characters", "Copy finger-drag gestures"]),
    ],
  ),
  CurriculumStage(
    stage: 2, minAge: 1, maxAge: 2, ageRange: "1–2", band: "Babies & Toddlers",
    title: "First Words & Concepts",
    theme: "Toddlers build vocabulary and begin to categorize the world around them.",
    designTip: "Everything responds to a single tap. Real photos, cheerful voice encouragement — no text needed yet.",
    topics: [
      CurriculumTopic(name: "Animals", activities: [
        "Tap to hear names & sounds", "Where they live: farm, jungle, ocean", "Match babies to parent animals"]),
      CurriculumTopic(name: "Body Parts", activities: [
        "Point to eyes, nose, mouth", "Drag features onto a face", "Sing head, shoulders, knees"]),
      CurriculumTopic(name: "Colors & Shapes", activities: [
        "Red, blue, yellow", "Circle, square, triangle", "Tap the matching color"]),
      CurriculumTopic(name: "Simple Sorting", activities: [
        "Match by color or size", "Big & small into buckets", "Drag shapes into slots"]),
      CurriculumTopic(name: "First Numbers", activities: [
        "Count 1–3 with objects", "Recognize the numeral 1", "Tap each item to count"]),
      CurriculumTopic(name: "Music & Routines", activities: [
        "Action songs & drum tapping", "Teeth, dressing, bath time", "Follow a daily routine chart"]),
    ],
  ),
  CurriculumStage(
    stage: 3, minAge: 2, maxAge: 3, ageRange: "2–3", band: "Babies & Toddlers",
    title: "Language Explosion & Early Logic",
    theme: "Vocabulary booms and symbolic thinking emerges; pretend play becomes a major driver of learning.",
    designTip: "Limit text to one word or emoji. A friendly character guide speaks directly; let parents record their own voice.",
    topics: [
      CurriculumTopic(name: "Vocabulary", activities: [
        "Categories: food, clothes, vehicles", "Action words: run, jump, eat", "Tap a picture to hear the word"]),
      CurriculumTopic(name: "Phonological Awareness", activities: [
        "Rhyming games", "Beginning sounds & syllable clapping", "Tap the words that rhyme"]),
      CurriculumTopic(name: "Counting & Numbers", activities: [
        "Rote count to 5–10", "One carrot per rabbit", "Numerals 1–5"]),
      CurriculumTopic(name: "Patterns & Opposites", activities: [
        "AB patterns: red-blue-red", "Hot/cold, big/small, up/down", "Tap what comes next"]),
      CurriculumTopic(name: "Emotions", activities: [
        "Happy, sad, angry faces", "“How does she feel?”", "Match the face to the feeling"]),
      CurriculumTopic(name: "Tracing & Stories", activities: [
        "Trace a dotted path to mom", "Tap to turn the page", "Listen to a narrated story"]),
    ],
  ),
  CurriculumStage(
    stage: 4, minAge: 3, maxAge: 4, ageRange: "3–4", band: "Preschool",
    title: "Pre-Literacy & Foundational Math",
    theme: "The golden age for laying the groundwork of reading, writing and arithmetic through play.",
    designTip: "Use a friendly narrator, reward effort over correct answers, and avoid any time pressure.",
    topics: [
      CurriculumTopic(name: "Language & Literacy", activities: [
        "Uppercase letters & sounds", "Recognize own name", "Story: beginning–middle–end"]),
      CurriculumTopic(name: "Math & Logic", activities: [
        "Count to 10, shapes around us", "Longer/shorter, AB & AABB", "Simple puzzles & mazes"]),
      CurriculumTopic(name: "Science & Nature", activities: [
        "Habitats: ocean, desert, arctic", "Weather, seasons, seed-to-flower", "The five senses"]),
      CurriculumTopic(name: "Social Studies", activities: [
        "Family & community helpers", "Doctor, firefighter, teacher", "Celebrations worldwide"]),
      CurriculumTopic(name: "Creative Arts", activities: [
        "Color mixing: red + blue = purple", "Rhythm, pitch & free drawing", "Finger-paint on the screen"]),
      CurriculumTopic(name: "Social-Emotional", activities: [
        "Name & manage feelings", "Turn-taking & sharing", "Calm-down breathing game"]),
    ],
  ),
  CurriculumStage(
    stage: 5, minAge: 4, maxAge: 5, ageRange: "4–5", band: "Preschool",
    title: "Early Reading & Number Sense",
    theme: "Kindergarten-readiness skills dominate — but play remains the vehicle for every lesson.",
    designTip: "Build on the friendly-narrator model with picture prompts, gentle pacing and playful coding warm-ups.",
    topics: [
      CurriculumTopic(name: "Reading & Writing", activities: [
        "Blend CVC words: c-a-t → cat", "Beginning sight words", "Trace lowercase letters"]),
      CurriculumTopic(name: "Math", activities: [
        "Count to 20 & back from 10", "Add/subtract within 5", "3D shapes, days of the week"]),
      CurriculumTopic(name: "Science", activities: [
        "Living vs. non-living", "Sink vs. float experiments", "Mountains, rivers, oceans"]),
      CurriculumTopic(name: "Social Studies", activities: [
        "Maps & globes: land vs. water", "Jobs & why they matter", "Safety signs & symbols"]),
      CurriculumTopic(name: "Creativity & Coding", activities: [
        "Story from picture prompts", "High/low, fast/slow music", "Commands: forward, turn left"]),
    ],
  ),
  CurriculumStage(
    stage: 6, minAge: 5, maxAge: 6, ageRange: "5–6", band: "Early Elementary", grade: "Kindergarten",
    title: "Foundations in Academic Subjects",
    theme: "Children handle more structured learning while still thriving with hands-on, colorful activities.",
    designTip: "Introduce gentle gamification while keeping instructions clear and repeatable.",
    topics: [
      CurriculumTopic(name: "Reading & Writing", activities: [
        "Read decodable books", "Write short sentences", "Capitals & end punctuation"]),
      CurriculumTopic(name: "Math", activities: [
        "Numbers to 100, skip-count", "Ten frames & number lines", "Place value, coins, time to hour"]),
      CurriculumTopic(name: "Science", activities: [
        "Mammals, birds, reptiles, fish", "Solid, liquid, gas", "Sun, moon & stars"]),
      CurriculumTopic(name: "Social Studies", activities: [
        "How communities work", "Flag & anthem", "Then vs. now timelines"]),
      CurriculumTopic(name: "Technology & Logic", activities: [
        "First-then-next sequencing", "Drag-and-drop block coding", "Guide a robot through a maze"]),
    ],
  ),
  CurriculumStage(
    stage: 7, minAge: 6, maxAge: 7, ageRange: "6–7", band: "Early Elementary", grade: "Grade 1",
    title: "Fluency & Deeper Understanding",
    theme: "Reading fluency takes off and math begins to grow more abstract.",
    designTip: "Lean into badges and levels, but keep every instruction clear and repeatable.",
    topics: [
      CurriculumTopic(name: "Reading", activities: [
        "Fluency, predict & question", "Silent-e, vowel teams", "Sight words"]),
      CurriculumTopic(name: "Writing & Grammar", activities: [
        "Simple paragraphs", "“I like __ because…”", "Nouns, verbs, adjectives"]),
      CurriculumTopic(name: "Math", activities: [
        "Add/subtract within 20", "Place value to 100", "Ruler, half-hour, bar graphs"]),
      CurriculumTopic(name: "Science", activities: [
        "Habitats & adaptations", "Life cycles: butterfly, frog", "Simple machines, solar system"]),
      CurriculumTopic(name: "Social Studies", activities: [
        "Continents & oceans", "Legend & compass rose", "Needs vs. wants"]),
      CurriculumTopic(name: "Health", activities: [
        "Food groups & hygiene", "Coping: deep breaths, count to ten", "Safe vs. unsafe choices"]),
    ],
  ),
  CurriculumStage(
    stage: 8, minAge: 7, maxAge: 8, ageRange: "7–8", band: "Early Elementary", grade: "Grade 2",
    title: "Expanding Knowledge & Skills",
    theme: "More independent learners who can handle longer, richer interactive lessons.",
    designTip: "Offer growing autonomy with clear goals and steady, repeatable structure.",
    topics: [
      CurriculumTopic(name: "Reading", activities: [
        "Chapter-book excerpts", "Story structure, compare/contrast", "Folk tales & fables"]),
      CurriculumTopic(name: "Writing & Grammar", activities: [
        "Personal narratives, letters", "Plurals & verb tenses", "Punctuation"]),
      CurriculumTopic(name: "Math", activities: [
        "Two-digit regrouping", "Multiplication: arrays & groups", "Fractions: halves, thirds, fourths"]),
      CurriculumTopic(name: "Science", activities: [
        "Rocks, minerals & erosion", "Food chains & webs", "Engineering design cycle"]),
      CurriculumTopic(name: "Social Studies", activities: [
        "Ancient Egypt & China", "Map scale & grid", "Urban, suburban, rural"]),
      CurriculumTopic(name: "Creativity & Tech", activities: [
        "Coding with Scratch Jr.", "Digital art", "Notation: quarter note, rest"]),
    ],
  ),
  CurriculumStage(
    stage: 9, minAge: 8, maxAge: 9, ageRange: "8–9", band: "Upper Elementary", grade: "Grade 3",
    title: "Critical Thinking & Independence",
    theme: "A major shift from “learning to read” to “reading to learn,” with more abstract math.",
    designTip: "Offer autonomy, progress dashboards and creative build-and-code tools.",
    topics: [
      CurriculumTopic(name: "Reading", activities: [
        "Main idea & inferencing", "Biography, poetry, nonfiction", "Simile & metaphor"]),
      CurriculumTopic(name: "Writing", activities: [
        "Organized paragraphs", "Opinion pieces & note-taking", "Cursive or typing"]),
      CurriculumTopic(name: "Math", activities: [
        "Multiplication & division facts", "Area & perimeter", "Equivalent fractions, elapsed time"]),
      CurriculumTopic(name: "Science", activities: [
        "Force, motion & magnetism", "Ecosystems & body systems", "Weather vs. climate"]),
      CurriculumTopic(name: "Social Studies", activities: [
        "Branches of government", "Famous inventors & scientists", "Goods, services & saving"]),
      CurriculumTopic(name: "Logic & Coding", activities: [
        "Loops & conditionals", "Logic puzzles", "Intro to keyboarding"]),
    ],
  ),
  CurriculumStage(
    stage: 10, minAge: 9, maxAge: 11, ageRange: "9–10", band: "Upper Elementary", grade: "Grade 4",
    title: "Abstract Thinking & Synthesis",
    theme: "Pre-adolescents reason abstractly, tackle multi-step problems, and use technology to create.",
    designTip: "Maximize autonomy with dashboards and open-ended creative and coding projects.",
    topics: [
      CurriculumTopic(name: "Reading", activities: [
        "Novel excerpts", "Author’s purpose & point of view", "Nonfiction text features"]),
      CurriculumTopic(name: "Writing", activities: [
        "Multi-paragraph essays", "Persuasive writing", "Editing for clarity"]),
      CurriculumTopic(name: "Math", activities: [
        "Long division, decimals", "Add/subtract like fractions", "Angles, symmetry, probability"]),
      CurriculumTopic(name: "Science", activities: [
        "Electricity & circuits", "Adaptations & heredity", "Moon phases; build-a-bridge STEM"]),
      CurriculumTopic(name: "Social Studies", activities: [
        "State & regional history", "Medieval & Indigenous cultures", "Latitude, longitude, enterprise"]),
      CurriculumTopic(name: "Digital Literacy & Coding", activities: [
        "Internet safety", "Evaluate online sources", "Scratch games & intro Python"]),
    ],
  ),
];

/// The stages this build actually offers.
///
/// [curriculumStages] stays the full ten because it is reference data — the
/// parent's curriculum guide, and the index behind `curriculumStages[stage-1]`
/// lookups. This is the list a child is ever offered. See [maxPublishedStage]
/// for why it stops where it does.
List<CurriculumStage> get publishedCurriculumStages => [
  for (final s in curriculumStages)
    if (s.stage <= maxPublishedStage) s,
];

/// Maps a child's age (years) to a curriculum stage, clamped to what this
/// build publishes.
///
/// An eight-year-old resolves to the highest published stage rather than to
/// stage 9: better the top of the real curriculum than an age band with two
/// steps a lesson in it.
CurriculumStage stageForAge(int age) {
  final published = publishedCurriculumStages;
  for (final s in published) {
    if (age >= s.minAge && age < s.maxAge) return s;
  }
  return age < 0 ? published.first : published.last;
}

/// Maps a birth year to a stage using the current year.
CurriculumStage stageForBirthYear(int birthYear, {DateTime? now}) {
  final year = (now ?? DateTime.now()).year;
  return stageForAge(year - birthYear);
}
