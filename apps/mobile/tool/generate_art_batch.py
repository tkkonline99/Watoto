"""Generate flat kid-friendly illustrations from image_manifest.csv.

Matches the shipped starter pack style: 512x512 RGBA, soft pastels, simple
shapes, no embedded text. Free-tier default is stages 1–5; use --all for the
full 543-image library.

Usage (from apps/mobile):
    python tool/generate_art_batch.py                  # stages 1-5
    python tool/generate_art_batch.py --all            # all stages
    python tool/generate_art_batch.py --stages 1,2,3
    python tool/generate_art_batch.py --force          # overwrite existing
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import math
import os
import re
import sys
from pathlib import Path

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


def draw_abstract(draw, seed: str, stage: int):
    """Distinct abstract composition when no keyword matches."""
    h = _hash(seed)
    rng = [(h >> (i * 4)) & 0xF for i in range(8)]
    for i in range(5):
        cx = 80 + (rng[i % 8] * 37 + i * 70) % 360
        cy = 90 + (rng[(i + 3) % 8] * 41 + i * 55) % 340
        r = 40 + (rng[(i + 1) % 8] % 8) * 12
        col = ACCENTS[(h + i * 3) % len(ACCENTS)]
        if i % 3 == 0:
            draw_star(draw, cx, cy, r * 0.7, col)
        elif i % 3 == 1:
            _circle(draw, cx, cy, r, col)
        else:
            draw.rounded_rectangle(
                [cx - r, cy - r * 0.7, cx + r, cy + r * 0.7],
                radius=20,
                fill=col,
            )
    # warm sun accent
    draw_sun(draw, 420, 90, 36, GOLD)


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


def classify_and_draw(draw, brief: str, name: str, stage: int, seed: str):
    t = f"{scene_of(brief)} {name}".lower()
    cx, cy = SIZE // 2, SIZE // 2 + 10

    # Body, hands and music come first: the pre-reading band leans on them
    # constantly (clap to the beat, head shoulders knees and toes, sing the
    # alphabet) and without a primitive each one fell through to an abstract
    # blob — which is worse than the emoji the app falls back to when the file
    # is simply absent. A drawn image has to beat that emoji to be worth
    # shipping.
    if any(k in t for k in ("shoulder", "knees", "toes", "whole body", "head, ")):
        draw_body(draw, cx, cy - 10, 190)
        return
    if any(k in t for k in ("clap", "hands", "wave", "waving", "pat-a-cake")):
        draw_hands(draw, cx, cy, 150)
        return
    if any(k in t for k in ("music", "song", "sing", "beat", "rhythm", "drum", "tune", "melody")):
        draw_note(draw, cx, cy, 170)
        return

    # faces / people
    if any(k in t for k in ("face", "baby", "smile", "caregiver", "mama", "dada", "child", "kid", "person", "people", "family", "hug", "kiss", "sneeze", "yawn", "head")):
        draw_face(draw, cx, cy - 10, 140, PEACH if "baby" in t else SOFT_BROWN)
        return
    if "bear" in t or "teddy" in t:
        draw_bear(draw, cx, cy, 130)
        return
    if "bunny" in t or "rabbit" in t:
        draw_bunny(draw, cx, cy + 30, 110)
        return
    if "bird" in t:
        draw_bird(draw, cx, cy, 100, _accent(seed))
        if "nest" in t:
            _ellipse(draw, [cx - 120, cy + 80, cx + 120, cy + 160], BROWN)
            _ellipse(draw, [cx - 90, cy + 90, cx + 90, cy + 140], SOFT_BROWN)
        if "leaf" in t:
            _ellipse(draw, [cx - 160, cy - 40, cx - 40, cy + 60], LEAF)
        return
    if "fish" in t:
        draw_fish(draw, cx, cy, 110, TEAL)
        return
    if any(k in t for k in ("cow", "farm", "animal", "cat", "kitten", "dog", "puppy", "lion", "elephant", "giraffe", "koala", "duck", "hen", "chick")):
        # generic friendly animal blob + face
        col = _accent(seed)
        _ellipse(draw, [cx - 140, cy - 80, cx + 140, cy + 120], col)
        _circle(draw, cx + 90, cy - 60, 70, col)
        _circle(draw, cx + 110, cy - 70, 10, NAVY)
        _circle(draw, cx - 40, cy - 20, 12, NAVY)
        _circle(draw, cx + 20, cy - 20, 12, NAVY)
        if "elephant" in t:
            _ellipse(draw, [cx + 60, cy + 20, cx + 160, cy + 140], col)
        return

    # nature / sky
    if "star" in t or "twinkle" in t or "night" in t or "sky" in t and "star" in t:
        # dark-ish night with stars
        draw.rectangle([0, 0, SIZE, SIZE], fill=(40, 70, 110, 255))
        draw_star(draw, cx, cy - 20, 90, GOLD)
        for i in range(8):
            draw_star(draw, 40 + (i * 60 + _hash(seed + str(i))) % 420, 40 + (i * 37) % 200, 12 + i % 10, GOLD)
        return
    if "sun" in t or "sunrise" in t:
        draw_sun(draw, cx, cy - 20, 100)
        return
    if "moon" in t:
        _circle(draw, cx, cy, 110, GOLD)
        _circle(draw, cx + 35, cy - 20, 90, STAGE_BG.get(stage, CREAM)[:3] + (255,))
        return
    if "cloud" in t or "rain" in t:
        draw_cloud(draw, cx, cy - 40, 90)
        if "rain" in t:
            for i in range(6):
                x = cx - 80 + i * 30
                draw.line([(x, cy + 40), (x - 8, cy + 100)], fill=TEAL, width=6)
        return
    if "tree" in t or "leaf" in t or "forest" in t:
        draw_tree(draw, cx, cy - 20, 120)
        return
    if "flower" in t or "garden" in t:
        draw_flower(draw, cx, cy, 80, _accent(seed))
        return
    if "bubble" in t:
        for i, (dx, dy, r) in enumerate([(-80, 40, 50), (20, -30, 70), (100, 50, 40), (-20, 90, 30)]):
            col = (*TEAL[:3], 120) if i % 2 else (*SKY[:3], 160)
            _circle(draw, cx + dx, cy + dy, r, col)
            _circle(draw, cx + dx - r * 0.3, cy + dy - r * 0.3, r * 0.15, WHITE)
        return

    # objects
    if "ball" in t:
        draw_ball(draw, cx, cy, 120, _accent(seed), GOLD)
        if "bell" in t:
            _circle(draw, cx + 100, cy - 80, 50, GOLD)
            draw.rectangle([cx + 92, cy - 130, cx + 108, cy - 100], fill=SOFT_GRAY)
        return
    if "bell" in t:
        _ellipse(draw, [cx - 70, cy - 60, cx + 70, cy + 80], GOLD)
        draw.rectangle([cx - 12, cy - 100, cx + 12, cy - 50], fill=SOFT_GRAY)
        _circle(draw, cx, cy + 90, 14, CORAL)
        return
    if "drum" in t:
        _ellipse(draw, [cx - 130, cy - 40, cx + 130, cy + 80], CORAL)
        _ellipse(draw, [cx - 130, cy - 70, cx + 130, cy - 10], GOLD)
        return
    if "cup" in t:
        draw.rounded_rectangle([cx - 70, cy - 40, cx + 70, cy + 100], radius=16, fill=TEAL)
        draw.arc([cx + 50, cy - 10, cx + 110, cy + 60], -90, 90, fill=TEAL, width=10)
        return
    if "hat" in t:
        _ellipse(draw, [cx - 120, cy + 20, cx + 120, cy + 80], CORAL)
        draw.rectangle([cx - 60, cy - 80, cx + 60, cy + 40], fill=CORAL)
        return
    if "door" in t:
        draw.rounded_rectangle([cx - 90, cy - 140, cx + 90, cy + 140], radius=12, fill=BROWN)
        _circle(draw, cx + 50, cy + 10, 12, GOLD)
        return
    if "box" in t:
        draw.rounded_rectangle([cx - 110, cy - 60, cx + 110, cy + 100], radius=16, fill=_accent(seed))
        if "car" in t:
            draw_car(draw, cx, cy + 20, 70, CORAL)
        return
    if "car" in t or "train" in t or "bus" in t:
        draw_car(draw, cx, cy, 120, _accent(seed))
        return
    if "house" in t or "home" in t or "coop" in t:
        draw_house(draw, cx, cy, 110)
        return
    if "book" in t or "letter" in t or "word" in t or "read" in t or "phon" in t:
        draw_book(draw, cx, cy, 110)
        return
    if "apple" in t or "fruit" in t:
        draw_apple(draw, cx, cy, 100)
        return
    if "cloth" in t or "blanket" in t:
        draw.rounded_rectangle([cx - 140, cy - 80, cx + 140, cy + 100], radius=30, fill=LAVENDER)
        draw.rounded_rectangle([cx - 100, cy - 40, cx + 100, cy + 60], radius=20, fill=PEACH)
        return
    if "shoe" in t:
        _ellipse(draw, [cx - 120, cy - 20, cx + 120, cy + 80], CORAL)
        draw.rounded_rectangle([cx - 40, cy - 70, cx + 100, cy + 20], radius=30, fill=CORAL)
        return
    if "lamp" in t or "light" in t or "glow" in t:
        _ellipse(draw, [cx - 80, cy - 100, cx + 80, cy + 40], GOLD)
        draw.rectangle([cx - 14, cy + 30, cx + 14, cy + 120], fill=SOFT_GRAY)
        _ellipse(draw, [cx - 50, cy + 110, cx + 50, cy + 140], SOFT_GRAY)
        return
    if "color" in t or "swirl" in t or "gradient" in t or "spiral" in t:
        for i, col in enumerate([CORAL, GOLD, TEAL, LAVENDER, MINT, PINK]):
            _circle(draw, cx, cy, 160 - i * 24, col)
        return
    if "texture" in t or "tile" in t:
        draw.rounded_rectangle([cx - 160, cy - 80, cx - 20, cy + 80], radius=20, fill=TEAL)
        draw.rounded_rectangle([cx + 20, cy - 80, cx + 160, cy + 80], radius=20, fill=CORAL)
        return
    if "bath" in t or "splash" in t or "water" in t or "pond" in t:
        _ellipse(draw, [cx - 160, cy - 20, cx + 160, cy + 100], SKY)
        _circle(draw, cx - 40, cy - 10, 30, WHITE)
        _circle(draw, cx + 50, cy, 22, WHITE)
        return
    if "drum" in t or "music" in t or "maraca" in t:
        _ellipse(draw, [cx - 100, cy - 50, cx + 100, cy + 90], _accent(seed))
        return
    if re.search(r"\b\d+\b", t) or "number" in t or "count" in t:
        m = re.search(r"\b(\d+)\b", t)
        draw_number_badge(draw, cx, cy, m.group(1) if m else "3", _accent(seed))
        return
    if "hand" in t or "clap" in t or "wave" in t:
        # simple mitten/hand
        _ellipse(draw, [cx - 70, cy - 40, cx + 70, cy + 120], PEACH)
        for i in range(4):
            x = cx - 60 + i * 40
            _ellipse(draw, [x - 18, cy - 120, x + 18, cy - 20], PEACH)
        return
    if "heart" in t or "love" in t:
        _circle(draw, cx - 50, cy - 20, 70, PINK)
        _circle(draw, cx + 50, cy - 20, 70, PINK)
        draw.polygon([(cx - 110, cy), (cx + 110, cy), (cx, cy + 130)], fill=PINK)
        return
    if "map" in t or "world" in t or "earth" in t:
        _circle(draw, cx, cy, 140, SKY)
        _ellipse(draw, [cx - 80, cy - 60, cx + 20, cy + 40], GREEN)
        _ellipse(draw, [cx + 10, cy + 10, cx + 100, cy + 90], LEAF)
        return
    if "shape" in t or "circle" in t or "square" in t or "triangle" in t or "pattern" in t:
        draw.rounded_rectangle([cx - 140, cy - 60, cx - 20, cy + 60], radius=12, fill=CORAL)
        _circle(draw, cx + 80, cy, 70, TEAL)
        draw.polygon([(cx, cy - 130), (cx - 50, cy - 50), (cx + 50, cy - 50)], fill=GOLD)
        return

    draw_abstract(draw, seed, stage)


def render_image(image_ref: str, stage_raw: str, art_brief: str) -> Image.Image:
    stage = _stage_primary(stage_raw)
    bg = STAGE_BG.get(stage, CREAM)
    img = Image.new("RGBA", (SIZE, SIZE), bg)
    draw = ImageDraw.Draw(img, "RGBA")
    name = Path(image_ref).stem
    seed = image_ref
    # soft vignette-ish corner sun for warmth
    if stage <= 3:
        _circle(draw, 60, 60, 40, (*GOLD[:3], 90))
    classify_and_draw(draw, art_brief, name, stage, seed)
    # Softer preschool look; stages 1–3 get an extra pass (hero free-tier pack).
    img = img.filter(ImageFilter.SMOOTH)
    if stage <= 3:
        img = img.filter(ImageFilter.SMOOTH_MORE)
    return img


def load_rows(stages: set[int] | None) -> list[dict]:
    rows = []
    with MANIFEST.open(encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            st = set(_parse_stages(row["stage"]))
            if stages is None or st & stages:
                rows.append(row)
    return rows


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

    written = skipped = 0
    for row in rows:
        ref = row["image_ref"].replace("\\", "/").lstrip("/")
        # image_ref is like img/s01/ball.png
        dest = out_root / ref
        if dest.exists() and not args.force:
            skipped += 1
            continue
        dest.parent.mkdir(parents=True, exist_ok=True)
        img = render_image(ref, row["stage"], row.get("art_brief") or Path(ref).stem)
        img.save(dest, "PNG", optimize=True)
        written += 1
        if written % 50 == 0:
            print(f"  … {written} written")

    print(f"Art batch done: wrote {written}, skipped existing {skipped}, total rows {len(rows)}")
    print(f"Output: {out_root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
