"""What the brief classifier must get right, and what it must refuse.

    python tool/test_brief_classifier.py

Plain unittest so it runs anywhere Python does — the repo has no pytest and
this is a build tool, not app code.

The first group is the reason the classifier was rewritten: every one of these
is a real brief from the library that the substring cascade got wrong, and the
picture it drew is in the comment.
"""
from __future__ import annotations

import unittest

from brief_classifier import MOTIFS, classify, classify_key


class SubstringCollisions(unittest.TestCase):
    """Whole-word matching, i.e. the bugs that prompted all this."""

    def test_that_and_what_are_not_hats(self):
        # "that" contains "hat" -> the old cascade drew a red hat. Two of the
        # commonest words in English, so this was not a rare miss.
        self.assertNotEqual(
            classify_key("anything that reveals it"), "hat")
        self.assertNotEqual(
            classify_key("What is the answer"), "hat")
        self.assertNotEqual(
            classify_key("Loops save us from writing the same step over and "
                         "over"), "hat")

    def test_start_is_not_a_star(self):
        # -> night sky, over a counting lesson.
        self.assertNotEqual(
            classify_key("The quick way: start at the bigger number and "
                         "count on"), "night")

    def test_grain_is_not_rain(self):
        # -> rain cloud, for a food-groups question.
        self.assertNotEqual(
            classify_key("Is an apple a fruit or a grain?"), "rain")

    def test_style_boilerplate_is_not_a_car(self):
        # "cartoon" contains "car". Documented in generate_art_batch.scene_of,
        # which worked around it by splitting the string rather than fixing
        # the matching.
        self.assertNotEqual(
            classify_key("Flat pastel cartoon, 512x512, soft rounded shapes, "
                         "no text"), "vehicle")

    def test_already_is_not_read(self):
        self.assertNotEqual(classify_key("She had already eaten"), "book")

    def test_prefix_wildcard_collisions_are_prevented(self):
        # "grown-up" is not a plant ("grow*"), "window" is not wind ("wind*"),
        # "goodnight" is not market goods ("good*"), "today" is not ancient
        # history, and "rule that repeats" is a pattern, not civic government.
        self.assertEqual(classify_key("Tap the smiling grown-up"), "face")
        self.assertEqual(classify_key("Look out of the window"), "door")
        self.assertEqual(
            classify_key("Dim the light and say goodnight"), "lamp")
        self.assertNotEqual(
            classify_key("Say goodnight to the moon"), "market")
        self.assertNotEqual(
            classify_key("You mixed three new colours today"), "history")
        self.assertEqual(
            classify_key("A pattern is a rule that repeats"), "robot")
        self.assertNotEqual(
            classify_key("Each thing you are wearing right now"), "community")

    def test_real_words_still_match(self):
        # The point is not to stop matching, so the honest versions of each
        # collision above must still land.
        self.assertEqual(classify_key("Put on a warm hat"), "hat")
        self.assertEqual(classify_key("A star in the night sky"), "night")
        self.assertEqual(classify_key("Rain falls from a grey cloud"), "rain")
        self.assertEqual(classify_key("A red car drives past"), "vehicle")


class Abstains(unittest.TestCase):
    """Saying nothing, when saying something would be a guess."""

    def test_abstains_on_briefs_with_no_subject(self):
        for brief in (
            "Again. Softer this time",
            "Roll it the other way",
            "Do it one more time",
            "Now try it yourself",
        ):
            with self.subTest(brief=brief):
                self.assertIsNone(classify_key(brief))

    def test_abstains_when_two_motifs_tie(self):
        # A bird and a fish, once each: the brief is about both and drawing
        # either is a coin toss.
        verdict = classify("The bird and the fish")
        self.assertIsNone(verdict.motif)
        self.assertLess(verdict.margin, 1.0)

    def test_repetition_breaks_a_tie(self):
        # Same two animals, but the brief is plainly about the fish.
        self.assertEqual(
            classify_key("The fish swims. Another fish joins it. Two fish, "
                         "and one bird watching"),
            "fish")

    def test_empty_brief_abstains(self):
        self.assertIsNone(classify_key(""))
        self.assertIsNone(classify_key("   "))
        self.assertIsNone(classify_key("the and of it"))


class Matches(unittest.TestCase):
    """Briefs the classifier should be confident about."""

    CASES = (
        ("Pop the big blue bubble", "bubble"),
        ("The bunny claps. Your hands too", "hands"),
        ("Wave together", "hands"),
        ("Wiggle like a fish in the water", "fish"),
        ("Give each rabbit one carrot", "bunny"),
        ("A teddy bear under a cup", "bear"),
        ("Sing the alphabet song together", "music"),
        ("Head, shoulders, knees and toes", "body"),
        ("The moon is full tonight", "moon"),
        ("Water the flowers in the garden", "flower"),
        ("Which command list reaches the pond fastest?", "water"),
        ("Before you touch food, hands come first", "hands"),
        ("Count the mangoes in the basket", "apple"),
        ("A map of the world", "map"),
        ("Three and one more is", "number"),
        ("Draw from dot 1 to dot 2 to dot 3", "writing"),
        ("Word with the short i sound: b-i-g", "reading"),
        ("The clock shows 7 o'clock", "clock"),
        ("Empty dark sky", "night"),
    )

    def test_cases(self):
        for brief, expected in self.CASES:
            with self.subTest(brief=brief):
                self.assertEqual(classify_key(brief), expected)


class TableHygiene(unittest.TestCase):
    """The motif table itself."""

    def test_keys_are_unique(self):
        keys = [m.key for m in MOTIFS]
        self.assertEqual(len(keys), len(set(keys)))

    def test_no_term_is_claimed_by_two_motifs(self):
        # A term in two motifs guarantees a tie, and a tie is an abstention —
        # so a duplicated term silently removes both motifs from play.
        seen: dict[str, str] = {}
        clashes = []
        for motif in MOTIFS:
            for term in motif.terms:
                if term in seen:
                    clashes.append(f"{term!r} in {seen[term]} and {motif.key}")
                seen[term] = motif.key
        self.assertEqual(clashes, [])

    def test_terms_are_lowercase_and_stripped(self):
        for motif in MOTIFS:
            for term in motif.terms:
                with self.subTest(motif=motif.key, term=term):
                    self.assertEqual(term, term.lower().strip())

    def test_no_term_is_a_stopword(self):
        from brief_classifier import STOP
        for motif in MOTIFS:
            for term in motif.terms:
                if " " in term or term.endswith("*"):
                    continue
                with self.subTest(motif=motif.key, term=term):
                    self.assertNotIn(term, STOP)

    def test_terms_are_tokenizable(self):
        # WORD_RE strips hyphens and apostrophes ("b-i-g" -> "b i g",
        # "o'clock" -> "o clock"), so any punctuation inside a term makes it
        # dead code that can never match.
        import re
        valid = re.compile(r"^[a-z0-9]+(?: [a-z0-9]+)*\*?$")
        for motif in MOTIFS:
            for term in motif.terms:
                with self.subTest(motif=motif.key, term=term):
                    self.assertRegex(term, valid)


if __name__ == "__main__":
    unittest.main(verbosity=2)
