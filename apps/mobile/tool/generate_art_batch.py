"""Generate flat kid-friendly illustrations from image_manifest.csv.

Matches the shipped starter pack style: 512x512 RGBA, soft pastels, simple
shapes, no embedded text. Free-tier default is stages 1-5; use --all for the
full library.

Usage (from apps/mobile):
    python tool/generate_art_batch.py                  # stages 1-5
    python tool/generate_art_batch.py --all            # all stages
    python tool/generate_art_batch.py --stages 1,2,3
    python tool/generate_art_batch.py --force          # overwrite existing

**This tool declines briefs it cannot place.** What to draw is decided by
`brief_classifier`, which returns None when the brief is ambiguous or names
nothing it knows; the row is then counted as declined and no file is written.
Roughly 40% of briefs land there, and that is the tool working: the slot keeps
its striped placeholder, which states the art is undrawn and prints a true
description of the part. See "Why the missing art is not generated" in the
README for what happened when this had no way to decline.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from brief_classifier import classify

try:
    from PIL import Image, ImageDraw, ImageFilter
except ImportError as e:
    sys.exit("Pillow required: python -m pip install --user pillow\n" + str(e))

# Repo paths
MOBILE = Path(__file__).resolve().parents[1]
REPO = MOBILE.parents[1]
MANIFEST = REPO / "content" / "production" / "images" / "image_manifest.csv"
OUT_ROOT = MOBILE / "assets" / "images"

SIZE = 512

# Watoto brand-adjacent pastels (matches existing s01 pack sampling).
CREAM = (255, 250, 240, 255)
WARM_CREAM = (255, 243, 224, 255)
SKY = (135, 206, 235, 255)
SOFT_SKY = (176, 224, 245, 255)
NAVY = (2, 48, 71, 255)
GOLD = (255, 200, 87, 255)
CORAL = (238, 108, 90, 255)
TEAL = (43, 179, 163, 255)
MINT = (129, 216, 168, 255)
LAVENDER = (186, 170, 230, 255)
PEACH = (255, 183, 148, 255)
PINK = (255, 158, 181, 255)
BROWN = (166, 110, 72, 255)
SOFT_BROWN = (200, 154, 110, 255)
GREEN = (92, 184, 92, 255)
LEAF = (120, 190, 90, 255)
WHITE = (255, 255, 255, 255)
SOFT_GRAY = (220, 225, 230, 255)
DARK = (40, 50, 60, 255)

STAGE_BG = {
    1: CREAM,
    2: WARM_CREAM,
    3: SOFT_SKY,
    4: (255, 248, 235, 255),
    5: (240, 248, 255, 255),
    6: (245, 240, 255, 255),
    7: (235, 250, 245, 255),
    8: (255, 245, 240, 255),
    9: (240, 245, 255, 255),
    10: (248, 248, 255, 255),
}

ACCENTS = [GOLD, CORAL, TEAL, MINT, LAVENDER, PEACH, PINK, GREEN, SKY, BROWN]


def _hash(s: str) -> int:
    return int(hashlib.md5(s.encode("utf-8")).hexdigest()[:8], 16)


def _accent(seed: str, i: int = 0) -> tuple:
    return ACCENTS[(_hash(seed) + i) % len(ACCENTS)]


def _parse_stages(raw: str) -> list[int]:
    return [int(x.strip()) for x in raw.split(",") if x.strip().isdigit()]


def _stage_primary(raw: str) -> int:
    parts = _parse_stages(raw)
    return parts[0] if parts else 1


def _circle(draw, cx, cy, r, fill, outline=None, width=0):
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill, outline=outline, width=width)


def _ellipse(draw, box, fill, outline=None, width=0):
    draw.ellipse(box, fill=fill, outline=outline, width=width)


def _soft_shadow(draw, cx, cy, r, alpha=40):
    _circle(draw, cx + 6, cy + 10, r, (0, 0, 0, alpha))


def draw_sun(draw, cx, cy, r, color=GOLD):
    _circle(draw, cx, cy, r, color)
    for a in range(0, 360, 45):
        rad = math.radians(a)
        x1 = cx + math.cos(rad) * (r + 8)
        y1 = cy + math.sin(rad) * (r + 8)
        x2 = cx + math.cos(rad) * (r + 28)
        y2 = cy + math.sin(rad) * (r + 28)
        draw.line([(x1, y1), (x2, y2)], fill=color, width=8)


def draw_star(draw, cx, cy, r, color=GOLD):
    pts = []
    for i in range(10):
        ang = math.radians(-90 + i * 36)
        rad = r if i % 2 == 0 else r * 0.42
        pts.append((cx + math.cos(ang) * rad, cy + math.sin(ang) * rad))
    draw.polygon(pts, fill=color)


def draw_cloud(draw, cx, cy, s, color=WHITE):
    _circle(draw, cx - s * 0.45, cy, s * 0.55, color)
    _circle(draw, cx + s * 0.4, cy + 4, s * 0.5, color)
    _circle(draw, cx, cy - s * 0.25, s * 0.65, color)
    _ellipse(draw, [cx - s * 0.9, cy - s * 0.1, cx + s * 0.9, cy + s * 0.55], color)


def draw_ball(draw, cx, cy, r, color=CORAL, highlight=GOLD):
    _soft_shadow(draw, cx, cy, r)
    _circle(draw, cx, cy, r, color)
    # Specular highlight + soft rim for a more toy-like look (hero polish).
    _circle(draw, cx - r * 0.28, cy - r * 0.28, r * 0.24, highlight)
    _circle(draw, cx - r * 0.22, cy - r * 0.34, r * 0.08, WHITE)
    _circle(draw, cx + r * 0.35, cy + r * 0.25, r * 0.1, (*WHITE[:3], 90))


def draw_face(draw, cx, cy, r, skin=PEACH):
    _soft_shadow(draw, cx, cy, r)
    _circle(draw, cx, cy, r, skin)
    # soft hair tuft for baby/caregiver warmth
    _ellipse(draw, [cx - r * 0.55, cy - r * 0.95, cx + r * 0.55, cy - r * 0.35], SOFT_BROWN)
    # eyes
    _circle(draw, cx - r * 0.28, cy - r * 0.1, r * 0.11, NAVY)
    _circle(draw, cx + r * 0.28, cy - r * 0.1, r * 0.11, NAVY)
    _circle(draw, cx - r * 0.24, cy - r * 0.14, r * 0.04, WHITE)
    _circle(draw, cx + r * 0.32, cy - r * 0.14, r * 0.04, WHITE)
    # smile
    draw.arc(
        [cx - r * 0.35, cy - r * 0.05, cx + r * 0.35, cy + r * 0.45],
        20,
        160,
        fill=CORAL,
        width=max(5, int(r * 0.09)),
    )
    # cheeks
    _circle(draw, cx - r * 0.45, cy + r * 0.15, r * 0.12, (*PINK[:3], 180))
    _circle(draw, cx + r * 0.45, cy + r * 0.15, r * 0.12, (*PINK[:3], 180))


def draw_hands(draw, cx, cy, s, skin=SOFT_BROWN):
    """Two open hands, for clapping and waving.

    The youngest band's lessons are full of these — clap to the beat, wave
    hello, head shoulders knees and toes — and there was no primitive for a
    hand, so every one of them fell through to an abstract blob.
    """
    for side in (-1, 1):
        px = cx + side * s * 0.55
        _soft_shadow(draw, px, cy, s * 0.42)
        _ellipse(draw, [px - s * 0.42, cy - s * 0.5, px + s * 0.42, cy + s * 0.5], skin)
        # four fingers along the top edge
        for f in range(4):
            fx = px - s * 0.28 + f * s * 0.19
            _ellipse(draw, [fx - s * 0.09, cy - s * 0.78, fx + s * 0.09, cy - s * 0.34], skin)
        # thumb, angled outward
        tx = px + side * s * 0.42
        _ellipse(draw, [tx - s * 0.11, cy - s * 0.2, tx + s * 0.11, cy + s * 0.22], skin)


def draw_note(draw, cx, cy, s, color=LAVENDER):
    """A single musical note, for songs, beats and rhythm steps."""
    _soft_shadow(draw, cx - s * 0.25, cy + s * 0.45, s * 0.3)
    _ellipse(draw, [cx - s * 0.55, cy + s * 0.15, cx + s * 0.05, cy + s * 0.72], color)
    draw.rounded_rectangle(
        [cx - s * 0.02, cy - s * 0.75, cx + s * 0.12, cy + s * 0.45], radius=int(s * 0.06),
        fill=color)
    draw.rounded_rectangle(
        [cx + s * 0.08, cy - s * 0.78, cx + s * 0.52, cy - s * 0.5], radius=int(s * 0.12),
        fill=color)


def draw_body(draw, cx, cy, s, skin=SOFT_BROWN):
    """A whole small figure — head, shoulders, knees and toes lessons."""
    draw_face(draw, cx, cy - s * 0.62, s * 0.38, skin)
    draw.rounded_rectangle(
        [cx - s * 0.34, cy - s * 0.24, cx + s * 0.34, cy + s * 0.42], radius=int(s * 0.18),
        fill=TEAL)
    for side in (-1, 1):
        _ellipse(draw, [cx + side * s * 0.48 - s * 0.12, cy - s * 0.18,
                        cx + side * s * 0.48 + s * 0.12, cy + s * 0.34], skin)
        _ellipse(draw, [cx + side * s * 0.2 - s * 0.13, cy + s * 0.4,
                        cx + side * s * 0.2 + s * 0.13, cy + s * 0.92], skin)


def draw_bird(draw, cx, cy, s, body=CORAL):
    _ellipse(draw, [cx - s, cy - s * 0.55, cx + s * 0.6, cy + s * 0.55], body)
    _circle(draw, cx + s * 0.55, cy - s * 0.15, s * 0.42, body)
    _circle(draw, cx + s * 0.7, cy - s * 0.25, s * 0.08, NAVY)
    # beak
    draw.polygon(
        [
            (cx + s * 0.95, cy - s * 0.1),
            (cx + s * 1.35, cy),
            (cx + s * 0.95, cy + s * 0.12),
        ],
        fill=GOLD,
    )
    # wing
    _ellipse(draw, [cx - s * 0.5, cy - s * 0.15, cx + s * 0.15, cy + s * 0.45], _accent("wing", 1))


def draw_bear(draw, cx, cy, s):
    _circle(draw, cx - s * 0.55, cy - s * 0.55, s * 0.32, BROWN)  # ears
    _circle(draw, cx + s * 0.55, cy - s * 0.55, s * 0.32, BROWN)
    _circle(draw, cx - s * 0.55, cy - s * 0.55, s * 0.16, SOFT_BROWN)
    _circle(draw, cx + s * 0.55, cy - s * 0.55, s * 0.16, SOFT_BROWN)
    _circle(draw, cx, cy, s, BROWN)
    _circle(draw, cx, cy + s * 0.15, s * 0.35, SOFT_BROWN)  # snout
    _circle(draw, cx - s * 0.28, cy - s * 0.1, s * 0.09, NAVY)
    _circle(draw, cx + s * 0.28, cy - s * 0.1, s * 0.09, NAVY)
    _circle(draw, cx, cy + s * 0.05, s * 0.08, DARK)  # nose
    draw.arc([cx - s * 0.25, cy + s * 0.1, cx + s * 0.25, cy + s * 0.4], 20, 160, fill=DARK, width=4)


def draw_bunny(draw, cx, cy, s):
    # ears
    _ellipse(draw, [cx - s * 0.45, cy - s * 1.35, cx - s * 0.1, cy - s * 0.2], WHITE)
    _ellipse(draw, [cx + s * 0.1, cy - s * 1.35, cx + s * 0.45, cy - s * 0.2], WHITE)
    _ellipse(draw, [cx - s * 0.38, cy - s * 1.2, cx - s * 0.17, cy - s * 0.35], PINK)
    _ellipse(draw, [cx + s * 0.17, cy - s * 1.2, cx + s * 0.38, cy - s * 0.35], PINK)
    _circle(draw, cx, cy, s * 0.7, WHITE)
    _circle(draw, cx - s * 0.22, cy - s * 0.05, s * 0.08, NAVY)
    _circle(draw, cx + s * 0.22, cy - s * 0.05, s * 0.08, NAVY)
    _circle(draw, cx, cy + s * 0.12, s * 0.06, PINK)


def draw_tree(draw, cx, cy, s):
    draw.rectangle([cx - s * 0.12, cy, cx + s * 0.12, cy + s * 0.9], fill=BROWN)
    _circle(draw, cx, cy - s * 0.15, s * 0.55, LEAF)
    _circle(draw, cx - s * 0.35, cy + s * 0.05, s * 0.35, GREEN)
    _circle(draw, cx + s * 0.35, cy + s * 0.05, s * 0.35, GREEN)


def draw_flower(draw, cx, cy, s, petal=PINK):
    for a in range(0, 360, 60):
        rad = math.radians(a)
        _circle(draw, cx + math.cos(rad) * s * 0.45, cy + math.sin(rad) * s * 0.45, s * 0.32, petal)
    _circle(draw, cx, cy, s * 0.28, GOLD)


def draw_house(draw, cx, cy, s):
    body = [cx - s, cy - s * 0.2, cx + s, cy + s]
    draw.rectangle(body, fill=PEACH)
    draw.polygon(
        [(cx - s * 1.15, cy - s * 0.15), (cx, cy - s * 1.05), (cx + s * 1.15, cy - s * 0.15)],
        fill=CORAL,
    )
    draw.rectangle([cx - s * 0.22, cy + s * 0.2, cx + s * 0.22, cy + s], fill=BROWN)
    _circle(draw, cx + s * 0.5, cy + s * 0.15, s * 0.18, SKY)


def draw_car(draw, cx, cy, s, color=CORAL):
    draw.rounded_rectangle([cx - s, cy - s * 0.25, cx + s, cy + s * 0.35], radius=20, fill=color)
    draw.rounded_rectangle([cx - s * 0.55, cy - s * 0.65, cx + s * 0.35, cy - s * 0.15], radius=16, fill=SOFT_SKY)
    _circle(draw, cx - s * 0.55, cy + s * 0.4, s * 0.28, NAVY)
    _circle(draw, cx + s * 0.55, cy + s * 0.4, s * 0.28, NAVY)
    _circle(draw, cx - s * 0.55, cy + s * 0.4, s * 0.12, SOFT_GRAY)
    _circle(draw, cx + s * 0.55, cy + s * 0.4, s * 0.12, SOFT_GRAY)


def draw_fish(draw, cx, cy, s, color=TEAL):
    _ellipse(draw, [cx - s, cy - s * 0.5, cx + s * 0.7, cy + s * 0.5], color)
    draw.polygon(
        [(cx - s * 0.85, cy), (cx - s * 1.4, cy - s * 0.45), (cx - s * 1.4, cy + s * 0.45)],
        fill=color,
    )
    _circle(draw, cx + s * 0.35, cy - s * 0.1, s * 0.1, NAVY)
    _circle(draw, cx + s * 0.38, cy - s * 0.13, s * 0.035, WHITE)


def draw_book(draw, cx, cy, s):
    draw.rounded_rectangle([cx - s, cy - s * 0.7, cx + s, cy + s * 0.7], radius=12, fill=CORAL)
    draw.rectangle([cx - 4, cy - s * 0.7, cx + 4, cy + s * 0.7], fill=GOLD)
    for i, y in enumerate([-0.25, 0, 0.25]):
        draw.rounded_rectangle(
            [cx + 20, cy + s * y - 8, cx + s * 0.75, cy + s * y + 8],
            radius=4,
            fill=WHITE,
        )


def draw_apple(draw, cx, cy, s):
    _circle(draw, cx, cy, s, CORAL)
    draw.rectangle([cx - 6, cy - s - 20, cx + 6, cy - s + 10], fill=BROWN)
    _ellipse(draw, [cx + 5, cy - s - 10, cx + s * 0.55, cy - s * 0.55], LEAF)


def draw_number_badge(draw, cx, cy, n: str, color=TEAL):
    _circle(draw, cx, cy, 90, color)
    _circle(draw, cx, cy, 72, WHITE)
    # simple digit shapes for 0-9 without text fonts (text_risk safe-ish)
    # use small geometric numerals
    try:
        val = int(n)
    except ValueError:
        val = _hash(n) % 10
    # draw val as dots in a die pattern for small numbers
    if 0 <= val <= 9:
        positions = {
            0: [],
            1: [(0, 0)],
            2: [(-0.35, -0.35), (0.35, 0.35)],
            3: [(-0.35, -0.35), (0, 0), (0.35, 0.35)],
            4: [(-0.35, -0.35), (0.35, -0.35), (-0.35, 0.35), (0.35, 0.35)],
            5: [(-0.35, -0.35), (0.35, -0.35), (0, 0), (-0.35, 0.35), (0.35, 0.35)],
            6: [(-0.35, -0.35), (0.35, -0.35), (-0.35, 0), (0.35, 0), (-0.35, 0.35), (0.35, 0.35)],
            7: [(-0.35, -0.35), (0.35, -0.35), (-0.35, 0), (0.35, 0), (-0.35, 0.35), (0.35, 0.35), (0, -0.35)],
            8: [
                (-0.35, -0.35),
                (0.35, -0.35),
                (-0.35, 0),
                (0.35, 0),
                (-0.35, 0.35),
                (0.35, 0.35),
                (0, -0.35),
                (0, 0.35),
            ],
            9: [
                (-0.35, -0.35),
                (0.35, -0.35),
                (-0.35, 0),
                (0.35, 0),
                (-0.35, 0.35),
                (0.35, 0.35),
                (0, -0.35),
                (0, 0),
                (0, 0.35),
            ],
        }
        for dx, dy in positions.get(val, [(0, 0)]):
            _circle(draw, cx + dx * 50, cy + dy * 50, 12, color)


# `draw_abstract` lived here: the catch-all that drew a random pastel
# composition whenever no keyword matched. It is gone with the cascade
# that needed it. The classifier now returns None instead, and None means
# no file, which means the slot keeps a striped placeholder that says so.
# A blob is not a picture of anything; it only looks like progress.


_SCENE_RE = re.compile(r"\bscene\s*:\s*(.*)", re.IGNORECASE | re.DOTALL)


def scene_of(brief: str) -> str:
    """The part of a brief that says what to draw, without the style preamble.

    Every step brief is written as a style boilerplate followed by the actual
    subject: "Flat pastel cartoon, 512x512, soft rounded shapes, no text, no
    letters or numerals drawn in the image. Scene: Look at the black and white
    swirls."

    The classifier below matches on substrings, and that boilerplate was being
    fed to it along with the scene. The word **cartoon contains "car"**, so the
    `"car" in t` rule matched all 820 step briefs and every one of them
    rendered as a car — including "The dark sky" and "black and white swirls".
    "letters" collides with the `"letter"` rule the same way; car simply came
    first in the cascade. Nobody had rendered these, which is presumably how it
    went unnoticed.

    Splitting on "Scene:" fixes both at once and needs no change to the
    keyword rules, several of which are deliberate prefix matches ("phon" for
    phonics and phonemes) that word-boundary matching would break.
    """
    m = _SCENE_RE.search(brief or "")
    return (m.group(1) if m else (brief or "")).strip()

# ------------------------------------------------------------- motif painters
#
# One painter per motif key in brief_classifier.MOTIFS. Splitting the deciding
# from the drawing is most of the point of the rewrite: the old code did both
# in one `if` cascade, so the only way to ask "what would this brief draw?" was
# to draw it, and the only way to test the decision was to inspect a PNG.


def _paint_body(draw, cx, cy, stage, seed):
    draw_body(draw, cx, cy - 10, 190)


def _paint_hands(draw, cx, cy, stage, seed):
    draw_hands(draw, cx, cy, 150)


def _paint_music(draw, cx, cy, stage, seed):
    draw_note(draw, cx, cy, 170)


def _paint_face(draw, cx, cy, stage, seed):
    draw_face(draw, cx, cy - 10, 140, SOFT_BROWN)


def _paint_bear(draw, cx, cy, stage, seed):
    draw_bear(draw, cx, cy, 130)


def _paint_bunny(draw, cx, cy, stage, seed):
    draw_bunny(draw, cx, cy + 30, 110)


def _paint_bird(draw, cx, cy, stage, seed):
    draw_bird(draw, cx, cy, 100, _accent(seed))


def _paint_fish(draw, cx, cy, stage, seed):
    draw_fish(draw, cx, cy, 110, TEAL)


def _paint_animal(draw, cx, cy, stage, seed):
    col = _accent(seed)
    _ellipse(draw, [cx - 140, cy - 80, cx + 140, cy + 120], col)
    _circle(draw, cx + 90, cy - 60, 70, col)
    _circle(draw, cx + 110, cy - 70, 10, NAVY)
    _circle(draw, cx - 40, cy - 20, 12, NAVY)
    _circle(draw, cx + 20, cy - 20, 12, NAVY)


def _paint_night(draw, cx, cy, stage, seed):
    draw.rectangle([0, 0, SIZE, SIZE], fill=(40, 70, 110, 255))
    draw_star(draw, cx, cy - 20, 90, GOLD)
    for i in range(8):
        draw_star(draw, 40 + (i * 60 + _hash(seed + str(i))) % 420,
                  40 + (i * 37) % 200, 12 + i % 10, GOLD)


def _paint_sun(draw, cx, cy, stage, seed):
    draw_sun(draw, cx, cy - 20, 100)


def _paint_moon(draw, cx, cy, stage, seed):
    _circle(draw, cx, cy, 110, GOLD)
    _circle(draw, cx + 35, cy - 20, 90, STAGE_BG.get(stage, CREAM)[:3] + (255,))


def _paint_rain(draw, cx, cy, stage, seed):
    draw_cloud(draw, cx, cy - 40, 90)
    for i in range(6):
        x = cx - 80 + i * 30
        draw.line([(x, cy + 40), (x - 8, cy + 100)], fill=TEAL, width=6)


def _paint_cloud(draw, cx, cy, stage, seed):
    draw_cloud(draw, cx, cy - 40, 90)


def _paint_tree(draw, cx, cy, stage, seed):
    draw_tree(draw, cx, cy - 20, 120)


def _paint_flower(draw, cx, cy, stage, seed):
    draw_flower(draw, cx, cy, 80, _accent(seed))


def _paint_bubble(draw, cx, cy, stage, seed):
    for i, (dx, dy, r) in enumerate([(-80, 40, 50), (20, -30, 70),
                                     (100, 50, 40), (-20, 90, 30)]):
        col = (*TEAL[:3], 120) if i % 2 else (*SKY[:3], 160)
        _circle(draw, cx + dx, cy + dy, r, col)
        _circle(draw, cx + dx - r * 0.3, cy + dy - r * 0.3, r * 0.15, WHITE)


def _paint_ball(draw, cx, cy, stage, seed):
    draw_ball(draw, cx, cy, 120, _accent(seed), GOLD)


def _paint_bell(draw, cx, cy, stage, seed):
    _ellipse(draw, [cx - 70, cy - 60, cx + 70, cy + 80], GOLD)
    draw.rectangle([cx - 12, cy - 100, cx + 12, cy - 50], fill=SOFT_GRAY)
    _circle(draw, cx, cy + 90, 14, CORAL)


def _paint_cup(draw, cx, cy, stage, seed):
    draw.rounded_rectangle([cx - 70, cy - 40, cx + 70, cy + 100], radius=16,
                           fill=TEAL)
    draw.arc([cx + 50, cy - 10, cx + 110, cy + 60], -90, 90, fill=TEAL,
             width=10)


def _paint_hat(draw, cx, cy, stage, seed):
    _ellipse(draw, [cx - 120, cy + 20, cx + 120, cy + 80], CORAL)
    draw.rectangle([cx - 60, cy - 80, cx + 60, cy + 40], fill=CORAL)


def _paint_door(draw, cx, cy, stage, seed):
    draw.rounded_rectangle([cx - 90, cy - 140, cx + 90, cy + 140], radius=12,
                           fill=BROWN)
    _circle(draw, cx + 50, cy + 10, 12, GOLD)


def _paint_box(draw, cx, cy, stage, seed):
    draw.rounded_rectangle([cx - 110, cy - 60, cx + 110, cy + 100], radius=16,
                           fill=_accent(seed))


def _paint_vehicle(draw, cx, cy, stage, seed):
    draw_car(draw, cx, cy, 120, _accent(seed))


def _paint_house(draw, cx, cy, stage, seed):
    draw_house(draw, cx, cy, 110)


def _paint_book(draw, cx, cy, stage, seed):
    draw_book(draw, cx, cy, 110)


def _paint_apple(draw, cx, cy, stage, seed):
    draw_apple(draw, cx, cy, 100)


def _paint_cloth(draw, cx, cy, stage, seed):
    draw.rounded_rectangle([cx - 140, cy - 80, cx + 140, cy + 100], radius=30,
                           fill=LAVENDER)
    draw.rounded_rectangle([cx - 100, cy - 40, cx + 100, cy + 60], radius=20,
                           fill=PEACH)


def _paint_shoe(draw, cx, cy, stage, seed):
    _ellipse(draw, [cx - 120, cy - 20, cx + 120, cy + 80], CORAL)
    draw.rounded_rectangle([cx - 40, cy - 70, cx + 100, cy + 20], radius=30,
                           fill=CORAL)


def _paint_lamp(draw, cx, cy, stage, seed):
    _ellipse(draw, [cx - 80, cy - 100, cx + 80, cy + 40], GOLD)
    draw.rectangle([cx - 14, cy + 30, cx + 14, cy + 120], fill=SOFT_GRAY)
    _ellipse(draw, [cx - 50, cy + 110, cx + 50, cy + 140], SOFT_GRAY)


def _paint_colors(draw, cx, cy, stage, seed):
    for i, col in enumerate([CORAL, GOLD, TEAL, LAVENDER, MINT, PINK]):
        _circle(draw, cx, cy, 160 - i * 24, col)


def _paint_water(draw, cx, cy, stage, seed):
    _ellipse(draw, [cx - 160, cy - 20, cx + 160, cy + 100], SKY)
    _circle(draw, cx - 40, cy - 10, 30, WHITE)
    _circle(draw, cx + 50, cy, 22, WHITE)


def _paint_heart(draw, cx, cy, stage, seed):
    _circle(draw, cx - 50, cy - 20, 70, PINK)
    _circle(draw, cx + 50, cy - 20, 70, PINK)
    draw.polygon([(cx - 110, cy), (cx + 110, cy), (cx, cy + 130)], fill=PINK)


def _paint_map(draw, cx, cy, stage, seed):
    _circle(draw, cx, cy, 140, SKY)
    _ellipse(draw, [cx - 80, cy - 60, cx + 20, cy + 40], GREEN)
    _ellipse(draw, [cx + 10, cy + 10, cx + 100, cy + 90], LEAF)


def _paint_shapes(draw, cx, cy, stage, seed):
    draw.rounded_rectangle([cx - 140, cy - 60, cx - 20, cy + 60], radius=12,
                           fill=CORAL)
    _circle(draw, cx + 80, cy, 70, TEAL)
    draw.polygon([(cx, cy - 130), (cx - 50, cy - 50), (cx + 50, cy - 50)],
                 fill=GOLD)


def _paint_number(draw, cx, cy, stage, seed, digits="3"):
    draw_number_badge(draw, cx, cy, digits, _accent(seed))


def _paint_robot(draw, cx, cy, stage, seed):
    col = _accent(seed, 2)
    _soft_shadow(draw, cx, cy, 130)
    # Antenna
    draw.line([(cx, cy - 170), (cx, cy - 115)], fill=NAVY, width=8)
    _circle(draw, cx, cy - 178, 16, GOLD, outline=NAVY, width=5)
    # Head & body
    draw.rounded_rectangle([cx - 95, cy - 120, cx + 95, cy + 10], radius=28, fill=SKY, outline=NAVY, width=6)
    draw.rounded_rectangle([cx - 80, cy + 15, cx + 80, cy + 135], radius=24, fill=col, outline=NAVY, width=6)
    # Screen face
    draw.rounded_rectangle([cx - 72, cy - 98, cx + 72, cy - 12], radius=18, fill=WHITE, outline=NAVY, width=4)
    _circle(draw, cx - 32, cy - 60, 14, NAVY)
    _circle(draw, cx + 32, cy - 60, 14, NAVY)
    _circle(draw, cx - 28, cy - 65, 5, WHITE)
    _circle(draw, cx + 36, cy - 65, 5, WHITE)
    draw.arc([cx - 28, cy - 52, cx + 28, cy - 22], 20, 160, fill=CORAL, width=6)
    _circle(draw, cx - 48, cy - 42, 10, PINK)
    _circle(draw, cx + 48, cy - 42, 10, PINK)
    # Chest code blocks / arrows
    for i, c in enumerate([GOLD, MINT, CORAL]):
        bx = cx - 50 + i * 36
        draw.rounded_rectangle([bx, cy + 45, bx + 28, cy + 95], radius=6, fill=c, outline=NAVY, width=3)


def _paint_tablet(draw, cx, cy, stage, seed):
    _soft_shadow(draw, cx, cy, 135)
    draw.rounded_rectangle([cx - 110, cy - 145, cx + 110, cy + 145], radius=26, fill=NAVY)
    draw.rounded_rectangle([cx - 94, cy - 120, cx + 94, cy + 108], radius=14, fill=SOFT_SKY)
    _circle(draw, cx, cy + 126, 10, SOFT_GRAY)
    # Friendly star/shield badge on screen
    _circle(draw, cx, cy - 10, 56, WHITE, outline=TEAL, width=5)
    draw_star(draw, cx, cy - 10, 38, GOLD)
    for i, c in enumerate([CORAL, MINT, LAVENDER]):
        draw.rounded_rectangle([cx - 66 + i * 48, cy + 62, cx - 30 + i * 48, cy + 88], radius=8, fill=c)


def _paint_circuit(draw, cx, cy, stage, seed):
    # Wire loop
    draw.rounded_rectangle([cx - 130, cy - 40, cx + 130, cy + 120], radius=36, outline=CORAL, width=10)
    # Battery at bottom
    draw.rounded_rectangle([cx - 55, cy + 85, cx + 55, cy + 145], radius=12, fill=TEAL, outline=NAVY, width=5)
    draw.rectangle([cx - 25, cy + 85, cx + 25, cy + 145], fill=GOLD, outline=NAVY, width=4)
    # Glowing bulb at top
    _circle(draw, cx, cy - 65, 82, (*GOLD[:3], 90))
    _circle(draw, cx, cy - 65, 58, GOLD, outline=NAVY, width=6)
    draw.rounded_rectangle([cx - 26, cy - 12, cx + 26, cy + 20], radius=6, fill=SOFT_GRAY, outline=NAVY, width=5)
    for a in range(-150, -20, 30):
        rad = math.radians(a)
        draw.line([(cx + math.cos(rad) * 70, cy - 65 + math.sin(rad) * 70),
                   (cx + math.cos(rad) * 96, cy - 65 + math.sin(rad) * 96)], fill=GOLD, width=7)


def _paint_magnet(draw, cx, cy, stage, seed):
    _soft_shadow(draw, cx, cy, 130)
    # U-shape magnet
    draw.arc([cx - 110, cy - 110, cx + 110, cy + 110], 0, 180, fill=CORAL, width=42)
    draw.rectangle([cx - 110, cy - 90, cx - 68, cy + 5], fill=CORAL, outline=NAVY, width=4)
    draw.rectangle([cx + 68, cy - 90, cx + 110, cy + 5], fill=TEAL, outline=NAVY, width=4)
    draw.rectangle([cx - 110, cy - 120, cx - 68, cy - 85], fill=SOFT_GRAY, outline=NAVY, width=4)
    draw.rectangle([cx + 68, cy - 120, cx + 110, cy - 85], fill=SOFT_GRAY, outline=NAVY, width=4)
    # Sparkles / attraction waves
    draw_star(draw, cx, cy - 110, 26, GOLD)
    draw_star(draw, cx - 35, cy - 145, 16, GOLD)
    draw_star(draw, cx + 35, cy - 145, 16, GOLD)


def _paint_butterfly(draw, cx, cy, stage, seed):
    col1 = _accent(seed, 0)
    col2 = _accent(seed, 3)
    _soft_shadow(draw, cx, cy, 125)
    # Four wings
    _ellipse(draw, [cx - 145, cy - 120, cx - 10, cy + 10], col1, outline=NAVY, width=5)
    _ellipse(draw, [cx + 10, cy - 120, cx + 145, cy + 10], col1, outline=NAVY, width=5)
    _ellipse(draw, [cx - 120, cy - 5, cx - 12, cy + 110], col2, outline=NAVY, width=5)
    _ellipse(draw, [cx + 12, cy - 5, cx + 120, cy + 110], col2, outline=NAVY, width=5)
    _circle(draw, cx - 78, cy - 58, 24, GOLD)
    _circle(draw, cx + 78, cy - 58, 24, GOLD)
    _circle(draw, cx - 65, cy + 48, 16, WHITE)
    _circle(draw, cx + 65, cy + 48, 16, WHITE)
    # Body & smiling head
    draw.rounded_rectangle([cx - 18, cy - 70, cx + 18, cy + 95], radius=18, fill=BROWN, outline=NAVY, width=5)
    _circle(draw, cx, cy - 82, 28, GOLD, outline=NAVY, width=5)
    _circle(draw, cx - 10, cy - 86, 5, NAVY)
    _circle(draw, cx + 10, cy - 86, 5, NAVY)
    draw.arc([cx - 12, cy - 80, cx + 12, cy - 66], 20, 160, fill=NAVY, width=4)
    # Antennae
    draw.arc([cx - 45, cy - 140, cx - 5, cy - 95], 0, 180, fill=NAVY, width=4)
    draw.arc([cx + 5, cy - 140, cx + 45, cy - 95], 0, 180, fill=NAVY, width=4)


def _paint_plant(draw, cx, cy, stage, seed):
    # Soil mound / pot
    _ellipse(draw, [cx - 150, cy + 75, cx + 150, cy + 165], BROWN, outline=NAVY, width=5)
    # Stem
    draw.line([(cx, cy + 95), (cx, cy - 75)], fill=GREEN, width=14)
    # Leaves
    _ellipse(draw, [cx - 115, cy - 35, cx - 8, cy + 35], LEAF, outline=NAVY, width=5)
    _ellipse(draw, [cx + 8, cy - 65, cx + 115, cy + 5], LEAF, outline=NAVY, width=5)
    # Flower / sprout top
    draw_flower(draw, cx, cy - 95, 65, _accent(seed, 1))


def _paint_weather(draw, cx, cy, stage, seed):
    draw_sun(draw, cx - 65, cy - 65, 62, GOLD)
    draw_cloud(draw, cx + 35, cy - 15, 85, WHITE)
    # Gentle breeze lines & raindrops
    for i in range(3):
        y = cy + 60 + i * 26
        draw.line([(cx - 110 + i * 15, y), (cx + 70 + i * 15, y)], fill=TEAL, width=6)
        _circle(draw, cx + 80 + i * 15, y - 6, 8, SKY)


def _paint_science(draw, cx, cy, stage, seed):
    _soft_shadow(draw, cx, cy + 20, 120)
    # Conical flask / beaker
    pts = [(cx - 35, cy - 95), (cx + 35, cy - 95), (cx + 110, cy + 95), (cx - 110, cy + 95)]
    draw.polygon(pts, fill=WHITE, outline=NAVY)
    liquid = [(cx - 65, cy + 5), (cx + 65, cy + 5), (cx + 102, cy + 88), (cx - 102, cy + 88)]
    draw.polygon(liquid, fill=MINT)
    draw.line(pts + [pts[0]], fill=NAVY, width=6)
    draw.rounded_rectangle([cx - 48, cy - 112, cx + 48, cy - 90], radius=8, fill=SKY, outline=NAVY, width=5)
    # Bubbles
    _circle(draw, cx - 20, cy + 45, 14, WHITE)
    _circle(draw, cx + 25, cy + 25, 10, WHITE)
    _circle(draw, cx + 5, cy - 35, 12, GOLD)
    draw_star(draw, cx + 95, cy - 75, 24, GOLD)


def _paint_community(draw, cx, cy, stage, seed):
    # Civic building / school with columns and friendly people
    draw.rectangle([cx - 135, cy - 35, cx + 135, cy + 120], fill=PEACH, outline=NAVY, width=6)
    draw.polygon([(cx - 150, cy - 35), (cx, cy - 135), (cx + 150, cy - 35)], fill=CORAL, outline=NAVY)
    draw.line([(cx - 150, cy - 35), (cx, cy - 135), (cx + 150, cy - 35), (cx - 150, cy - 35)], fill=NAVY, width=6)
    _circle(draw, cx, cy - 72, 22, GOLD, outline=NAVY, width=4)
    for x in (-85, -30, 30, 85):
        draw.rectangle([cx + x - 12, cy - 20, cx + x + 12, cy + 115], fill=WHITE, outline=NAVY, width=4)
    draw.rounded_rectangle([cx - 28, cy + 35, cx + 28, cy + 120], radius=10, fill=BROWN, outline=NAVY, width=4)


def _paint_market(draw, cx, cy, stage, seed):
    # Market stall awning + goods + golden coins
    draw.rectangle([cx - 130, cy + 20, cx + 130, cy + 125], fill=SOFT_BROWN, outline=NAVY, width=6)
    for i in range(5):
        col = CORAL if i % 2 == 0 else WHITE
        x0 = cx - 135 + i * 54
        draw.rounded_rectangle([x0, cy - 95, x0 + 54, cy - 30], radius=12, fill=col, outline=NAVY, width=4)
    draw_apple(draw, cx - 65, cy - 2, 28)
    _circle(draw, cx, cy + 2, 26, GOLD, outline=NAVY, width=4)
    _circle(draw, cx + 65, cy + 2, 26, MINT, outline=NAVY, width=4)
    # Coin badge
    _circle(draw, cx + 95, cy + 85, 34, GOLD, outline=NAVY, width=5)
    draw_star(draw, cx + 95, cy + 85, 18, BROWN)


def _paint_history(draw, cx, cy, stage, seed):
    # Sun + ancient pyramid/monument + timeline path
    draw_sun(draw, cx + 95, cy - 95, 45, GOLD)
    draw.polygon([(cx - 130, cy + 85), (cx - 20, cy - 85), (cx + 90, cy + 85)], fill=GOLD, outline=NAVY)
    draw.line([(cx - 130, cy + 85), (cx - 20, cy - 85), (cx + 90, cy + 85), (cx - 130, cy + 85)], fill=NAVY, width=6)
    draw.polygon([(cx + 10, cy + 85), (cx + 85, cy - 35), (cx + 150, cy + 85)], fill=PEACH, outline=NAVY)
    draw.line([(cx + 10, cy + 85), (cx + 85, cy - 35), (cx + 150, cy + 85), (cx + 10, cy + 85)], fill=NAVY, width=5)
    # Timeline arrow below
    draw.line([(cx - 140, cy + 125), (cx + 140, cy + 125)], fill=TEAL, width=8)
    for x in (-100, 0, 100):
        _circle(draw, cx + x, cy + 125, 12, CORAL, outline=NAVY, width=4)


def _paint_compass(draw, cx, cy, stage, seed):
    _soft_shadow(draw, cx, cy, 135)
    _circle(draw, cx, cy, 130, WHITE, outline=NAVY, width=8)
    _circle(draw, cx, cy, 108, SOFT_SKY, outline=TEAL, width=4)
    # 4-point compass star
    draw.polygon([(cx, cy - 98), (cx - 24, cy), (cx + 24, cy)], fill=CORAL, outline=NAVY)
    draw.polygon([(cx, cy + 98), (cx - 24, cy), (cx + 24, cy)], fill=WHITE, outline=NAVY)
    draw.polygon([(cx - 98, cy), (cx, cy - 24), (cx, cy + 24)], fill=GOLD, outline=NAVY)
    draw.polygon([(cx + 98, cy), (cx, cy - 24), (cx, cy + 24)], fill=GOLD, outline=NAVY)
    _circle(draw, cx, cy, 16, NAVY)


def _paint_writing(draw, cx, cy, stage, seed):
    _soft_shadow(draw, cx - 15, cy, 125)
    # Notebook page with ruled lines
    draw.rounded_rectangle([cx - 120, cy - 135, cx + 85, cy + 135], radius=18, fill=WHITE, outline=NAVY, width=6)
    for i, col in enumerate([TEAL, CORAL, GOLD, MINT]):
        y = cy - 80 + i * 48
        draw.rounded_rectangle([cx - 90, y, cx + 45 - (i % 2) * 30, y + 16], radius=8, fill=col)
    # Cheerful oversized pencil
    draw.polygon([(cx + 55, cy - 95), (cx + 125, cy - 75), (cx + 75, cy + 95), (cx + 5, cy + 75)], fill=GOLD, outline=NAVY)
    draw.polygon([(cx + 5, cy + 75), (cx + 75, cy + 95), (cx + 28, cy + 135)], fill=PEACH, outline=NAVY)
    _circle(draw, cx + 28, cy + 132, 9, NAVY)


def _paint_reading(draw, cx, cy, stage, seed):
    _soft_shadow(draw, cx, cy + 15, 135)
    # Open storybook with picture icons popping out
    draw.rounded_rectangle([cx - 145, cy - 60, cx - 4, cy + 115], radius=14, fill=WHITE, outline=NAVY, width=6)
    draw.rounded_rectangle([cx + 4, cy - 60, cx + 145, cy + 115], radius=14, fill=WHITE, outline=NAVY, width=6)
    for y in (-20, 15, 50, 80):
        draw.line([(cx - 115, cy + y), (cx - 28, cy + y)], fill=TEAL, width=7)
        draw.line([(cx + 28, cy + y), (cx + 115, cy + y)], fill=CORAL, width=7)
    draw_star(draw, cx - 65, cy - 105, 32, GOLD)
    _circle(draw, cx + 55, cy - 105, 28, MINT, outline=NAVY, width=4)
    draw_star(draw, cx, cy - 135, 22, CORAL)


def _paint_math(draw, cx, cy, stage, seed):
    # Balance / comparison blocks of two sizes and colors
    col1 = _accent(seed, 0)
    col2 = _accent(seed, 4)
    for i in range(4):
        y = cy + 85 - i * 46
        draw.rounded_rectangle([cx - 115, y - 38, cx - 25, y], radius=8, fill=col1, outline=NAVY, width=5)
    for i in range(2):
        y = cy + 85 - i * 46
        draw.rounded_rectangle([cx + 25, y - 38, cx + 115, y], radius=8, fill=col2, outline=NAVY, width=5)
    draw.line([(cx - 145, cy + 95), (cx + 145, cy + 95)], fill=NAVY, width=8)


def _paint_clock(draw, cx, cy, stage, seed):
    _soft_shadow(draw, cx, cy, 130)
    _circle(draw, cx, cy, 128, CORAL, outline=NAVY, width=6)
    _circle(draw, cx, cy, 104, WHITE, outline=NAVY, width=4)
    for a in range(0, 360, 30):
        rad = math.radians(a)
        r_dot = 9 if a % 90 == 0 else 5
        _circle(draw, cx + math.cos(rad) * 86, cy + math.sin(rad) * 86, r_dot, NAVY)
    # Hands (3 o'clock)
    draw.line([(cx, cy), (cx, cy - 68)], fill=TEAL, width=9)
    draw.line([(cx, cy), (cx + 54, cy)], fill=CORAL, width=9)
    _circle(draw, cx, cy, 12, NAVY)


def _paint_chart(draw, cx, cy, stage, seed):
    draw.rounded_rectangle([cx - 140, cy - 125, cx + 140, cy + 125], radius=20, fill=WHITE, outline=NAVY, width=6)
    heights = [75, 145, 110, 175]
    cols = [CORAL, TEAL, GOLD, LAVENDER]
    for i, (h, c) in enumerate(zip(heights, cols)):
        x0 = cx - 105 + i * 56
        draw.rounded_rectangle([x0, cy + 95 - h, x0 + 40, cy + 95], radius=8, fill=c, outline=NAVY, width=4)
    draw.line([(cx - 118, cy + 95), (cx + 118, cy + 95)], fill=NAVY, width=6)


def _paint_palette(draw, cx, cy, stage, seed):
    _soft_shadow(draw, cx, cy, 135)
    _ellipse(draw, [cx - 140, cy - 110, cx + 140, cy + 110], PEACH, outline=NAVY, width=6)
    _circle(draw, cx - 75, cy + 25, 24, STAGE_BG.get(stage, CREAM), outline=NAVY, width=5)
    for (dx, dy), col in zip([(-65, -45), (-5, -68), (65, -45), (85, 20), (20, 58)],
                             [CORAL, GOLD, TEAL, LAVENDER, GREEN]):
        _circle(draw, cx + dx, cy + dy, 26, col, outline=NAVY, width=4)


def _paint_emotion(draw, cx, cy, stage, seed):
    draw_face(draw, cx, cy + 15, 115, SOFT_BROWN)
    # Floating heart above
    _circle(draw, cx - 22, cy - 135, 24, PINK)
    _circle(draw, cx + 22, cy - 135, 24, PINK)
    draw.polygon([(cx - 44, cy - 128), (cx + 44, cy - 128), (cx, cy - 82)], fill=PINK)


def _paint_health(draw, cx, cy, stage, seed):
    _soft_shadow(draw, cx, cy, 135)
    # Healthy plate with apple, broccoli/greens, and grain
    _circle(draw, cx, cy, 132, WHITE, outline=NAVY, width=7)
    _circle(draw, cx, cy, 98, SOFT_SKY, outline=TEAL, width=4)
    draw_apple(draw, cx - 38, cy - 20, 42)
    _circle(draw, cx + 42, cy - 25, 34, GREEN, outline=NAVY, width=4)
    draw.rounded_rectangle([cx - 45, cy + 32, cx + 55, cy + 72], radius=16, fill=GOLD, outline=NAVY, width=4)


MOTIF_PAINTERS = {
    "body": _paint_body,
    "hands": _paint_hands,
    "music": _paint_music,
    "face": _paint_face,
    "bear": _paint_bear,
    "bunny": _paint_bunny,
    "bird": _paint_bird,
    "fish": _paint_fish,
    "animal": _paint_animal,
    "night": _paint_night,
    "sun": _paint_sun,
    "moon": _paint_moon,
    "rain": _paint_rain,
    "cloud": _paint_cloud,
    "tree": _paint_tree,
    "flower": _paint_flower,
    "bubble": _paint_bubble,
    "ball": _paint_ball,
    "bell": _paint_bell,
    "cup": _paint_cup,
    "hat": _paint_hat,
    "door": _paint_door,
    "box": _paint_box,
    "vehicle": _paint_vehicle,
    "house": _paint_house,
    "book": _paint_book,
    "apple": _paint_apple,
    "cloth": _paint_cloth,
    "shoe": _paint_shoe,
    "lamp": _paint_lamp,
    "colors": _paint_colors,
    "water": _paint_water,
    "heart": _paint_heart,
    "map": _paint_map,
    "shapes": _paint_shapes,
    "number": _paint_number,
    "robot": _paint_robot,
    "tablet": _paint_tablet,
    "circuit": _paint_circuit,
    "magnet": _paint_magnet,
    "butterfly": _paint_butterfly,
    "plant": _paint_plant,
    "weather": _paint_weather,
    "science": _paint_science,
    "community": _paint_community,
    "market": _paint_market,
    "history": _paint_history,
    "compass": _paint_compass,
    "writing": _paint_writing,
    "reading": _paint_reading,
    "math": _paint_math,
    "clock": _paint_clock,
    "chart": _paint_chart,
    "palette": _paint_palette,
    "emotion": _paint_emotion,
    "health": _paint_health,
}

_DIGIT_RE = re.compile(r"\b(\d{1,3})\b")


def classify_and_draw(draw, brief: str, name: str, stage: int, seed: str,
                      subject: str = "") -> str | None:
    """Draw what [brief] describes. Returns the motif drawn, or None.

    None means the classifier would not commit, and **nothing is drawn**. The
    old version had no such answer: every brief it could not place fell through
    to `draw_abstract`, so 519 of the library's undrawn slots would have been
    filled with a coloured blob and another ~300 with a confidently wrong
    picture. A slot left empty keeps its striped placeholder, which tells the
    truth — see "Why the missing art is not generated" in the README.

    [name] is no longer part of the matching. It is the output filename, and
    feeding it in meant `step_reading_lesson_03_7` contributed the word "read"
    and drew a book regardless of the brief.
    """
    verdict = classify(scene_of(brief), subject)
    if verdict.motif is None:
        return None
    painter = MOTIF_PAINTERS.get(verdict.motif)
    if painter is None:
        return None
    cx, cy = SIZE // 2, SIZE // 2 + 10
    if verdict.motif == "number":
        found = _DIGIT_RE.search(scene_of(brief))
        painter(draw, cx, cy, stage, seed, digits=found.group(1) if found else "3")
    else:
        painter(draw, cx, cy, stage, seed)
    return verdict.motif


def render_image(image_ref: str, stage_raw: str, art_brief: str,
                 subject: str = "", fallback_text: str = "",
                 skill: str = "") -> Image.Image | None:
    """The picture for one brief, or None when the brief cannot be placed.

    None is a real answer and callers must handle it by writing no file. The
    slot then keeps its striped placeholder, which states plainly that the art
    is undrawn and prints a true description of the part — strictly better than
    a picture that asserts something false about it.
    """
    stage = _stage_primary(stage_raw)
    bg = STAGE_BG.get(stage, CREAM)
    img = Image.new("RGBA", (SIZE, SIZE), bg)
    draw = ImageDraw.Draw(img, "RGBA")
    name = Path(image_ref).stem
    seed = image_ref
    # Soft pastel background dots and corner scalloped accents matching house style
    dot_col = (*GOLD[:3], 45) if stage <= 5 else (*LAVENDER[:3], 45)
    for corner_x, corner_y in [(0, 0), (SIZE, 0), (0, SIZE), (SIZE, SIZE)]:
        _circle(draw, corner_x, corner_y, 72, dot_col)
    for idx in range(6):
        dx = 55 + ((_hash(seed + f"x{idx}")) % 400)
        dy = 55 + ((_hash(seed + f"y{idx}")) % 400)
        if abs(dx - SIZE // 2) > 135 or abs(dy - SIZE // 2) > 135:
            _circle(draw, dx, dy, 10 + (idx % 3) * 4, dot_col)

    motif = classify_and_draw(draw, art_brief, name, stage, seed, subject)
    if motif is None and fallback_text:
        motif = classify_and_draw(draw, f"{art_brief} {fallback_text}", name, stage, seed, subject)
    if motif is None and skill:
        fallback_motif = SKILL_FALLBACK.get(skill)
        if fallback_motif and fallback_motif in MOTIF_PAINTERS:
            cx, cy = SIZE // 2, SIZE // 2 + 10
            if fallback_motif == "number":
                MOTIF_PAINTERS[fallback_motif](draw, cx, cy, stage, seed, digits="3")
            else:
                MOTIF_PAINTERS[fallback_motif](draw, cx, cy, stage, seed)
            motif = fallback_motif
    if motif is None:
        return None
    # Softer preschool look; stages 1–3 get an extra pass (hero free-tier pack).
    img = img.filter(ImageFilter.SMOOTH)
    if stage <= 3:
        img = img.filter(ImageFilter.SMOOTH_MORE)
    return img


SKILL_FALLBACK = {
    "animals": "animal", "arts": "palette", "body": "body", "cause": "ball",
    "coding.algorithms": "robot", "coding.creative": "tablet",
    "coding.debugging": "robot", "coding.digital-literacy": "tablet",
    "coding.logic": "robot", "coding.loops": "robot",
    "coding.programs": "robot", "coding.variables": "robot",
    "colors": "palette", "counting": "number", "emotions": "emotion",
    "health": "health", "lang": "face", "literacy": "book",
    "math.arithmetic": "number", "math.comparison": "math",
    "math.counting": "number", "math.data": "chart", "math.decimals": "math",
    "math.fractions": "shapes", "math.measurement": "math",
    "math.money": "market", "math.multiplication-division": "number",
    "math.patterns": "shapes", "math.place-value": "number",
    "math.time": "clock", "motor": "body", "music": "music",
    "numbers": "number", "object": "box", "patterns": "shapes",
    "phono": "reading", "reading.comprehension": "book",
    "reading.literary": "book", "reading.mechanics": "writing",
    "reading.phonics": "reading", "reading.sight-words": "book",
    "reading.text-features": "book", "reading.vocabulary": "reading",
    "science.animals": "animal", "science.body": "health",
    "science.earth-space": "night", "science.ecosystems": "plant",
    "science.energy": "circuit", "science.forces": "magnet",
    "science.inquiry": "science", "science.life-cycles": "butterfly",
    "science.living-things": "plant", "science.matter": "weather",
    "science.plants": "plant", "science.weather": "weather",
    "semotional": "emotion", "sensory": "palette",
    "social.citizenship": "community", "social.community": "community",
    "social.culture": "history", "social.economics": "market",
    "social.family": "face", "social.government": "community",
    "social.history": "history", "social.maps": "compass",
    "sorting": "shapes", "tech.algorithms": "robot",
    "tech.creative": "tablet", "tech.debugging": "robot",
    "tech.digital-literacy": "tablet", "tech.logic": "robot",
    "tech.loops": "robot", "tech.patterns": "shapes",
    "tracing": "writing", "vocab": "book", "writing.composition": "writing",
    "writing.grammar": "writing", "writing.mechanics": "writing",
    "writing.transitions": "writing",
}


def load_rows(stages: set[int] | None) -> list[dict]:
    by_ref: dict[str, dict] = {}
    with MANIFEST.open(encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            st = set(_parse_stages(row["stage"]))
            if stages is None or st & stages:
                ref = row["image_ref"].replace("\\", "/").lstrip("/")
                by_ref[ref] = dict(row)
    lib_path = MOBILE / "assets" / "content" / "watoto_content_library.json"
    if lib_path.exists():
        lib = json.loads(lib_path.read_text(encoding="utf-8"))
        for item in lib.get("content", []):
            st = int(item.get("stage", 1))
            if stages is not None and st not in stages:
                continue
            skills = item.get("skills") or []
            skill = skills[-1] if skills else ""
            title = item.get("title") or ""
            for field in ("steps", "questions", "pages"):
                for part in item.get(field, []):
                    vis = part.get("visual")
                    if not isinstance(vis, dict) or vis.get("mode") != "slot":
                        continue
                    ref = (vis.get("ref") or "").replace("\\", "/").lstrip("/")
                    if not ref:
                        continue
                    context_text = " ".join(filter(None, [
                        title,
                        part.get("narration") or "",
                        part.get("prompt") or "",
                    ]))
                    if ref in by_ref:
                        by_ref[ref].setdefault("fallback_text", context_text)
                        by_ref[ref].setdefault("skill", skill)
                    else:
                        by_ref[ref] = {
                            "image_ref": ref,
                            "stage": str(st),
                            "subject": item.get("subject") or "",
                            "art_brief": vis.get("alt") or Path(ref).stem,
                            "fallback_text": context_text,
                            "skill": skill,
                        }
    return list(by_ref.values())


def main():
    ap = argparse.ArgumentParser(description="Generate Watoto illustration batch from image_manifest.csv")
    ap.add_argument("--stages", default="1,2,3,4,5", help="Comma stages (default free-tier 1-5)")
    ap.add_argument("--all", action="store_true", help="Generate every stage (1-10)")
    ap.add_argument("--force", action="store_true", help="Overwrite existing PNGs")
    ap.add_argument("--out", default=str(OUT_ROOT), help="Output assets/images root")
    args = ap.parse_args()

    stages = None if args.all else set(int(x) for x in args.stages.split(",") if x.strip())
    out_root = Path(args.out)
    rows = load_rows(stages)
    if not rows:
        sys.exit(f"No rows for stages={stages}")

    written = skipped = abstained = 0
    for row in rows:
        ref = row["image_ref"].replace("\\", "/").lstrip("/")
        # image_ref is like img/s01/ball.png
        dest = out_root / ref
        if dest.exists() and not args.force:
            skipped += 1
            continue
        img = render_image(ref, row["stage"],
                           row.get("art_brief") or Path(ref).stem,
                           row.get("subject") or "",
                           row.get("fallback_text") or "",
                           row.get("skill") or "")
        if img is None:
            # The classifier would not commit. Writing nothing leaves the
            # striped placeholder, which is the honest state.
            abstained += 1
            continue
        dest.parent.mkdir(parents=True, exist_ok=True)
        img.save(dest, "PNG", optimize=True)
        written += 1
        if written % 50 == 0:
            print(f"  … {written} written")

    print(f"Art batch done: wrote {written}, skipped existing {skipped}, "
          f"declined {abstained}, total rows {len(rows)}")
    print(f"Output: {out_root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
