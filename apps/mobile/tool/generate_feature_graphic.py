"""Generate Google Play feature graphic (1024x500) with exact Watoto wordmark.

Usage (from apps/mobile):
    python tool/generate_feature_graphic.py
"""
from __future__ import annotations

import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]  # repo root (…/watoto)
OUT = ROOT / "docs" / "store-assets"
W, H = 1024, 500


def _font(size: int, bold: bool = False) -> ImageFont.ImageFont:
    names = (
        ["arialbd.ttf", "C:/Windows/Fonts/arialbd.ttf"]
        if bold
        else ["arial.ttf", "C:/Windows/Fonts/arial.ttf"]
    )
    for n in names:
        try:
            return ImageFont.truetype(n, size)
        except OSError:
            continue
    return ImageFont.load_default()


def main() -> None:
    img = Image.new("RGB", (W, H), (255, 247, 230))
    d = ImageDraw.Draw(img)
    for y in range(H):
        t = y / H
        r = int(255 * (1 - t) + 251 * t)
        g = int(247 * (1 - t) + 133 * t)
        b = int(230 * (1 - t) + 0 * t)
        d.line([(0, y), (W, y)], fill=(r, g, b))
    d.ellipse([(-80, 320), (1100, 700)], fill=(167, 206, 124))
    d.ellipse([(200, 360), (900, 720)], fill=(194, 221, 156))
    d.ellipse([(780, 40), (960, 220)], fill=(255, 209, 102))
    # Simple characters
    d.ellipse([(110, 230), (250, 370)], fill=(255, 183, 148))
    d.ellipse([(280, 250), (390, 360)], fill=(255, 200, 87))
    d.ellipse([(480, 300), (580, 400)], fill=(238, 108, 90))
    d.rounded_rectangle([620, 310, 720, 400], radius=8, fill=(33, 158, 188))

    big = _font(96, bold=True)
    sub = _font(34, bold=False)
    d.text((52, 52), "Watoto", font=big, fill=(2, 48, 71))
    d.text((48, 48), "Watoto", font=big, fill=(255, 255, 255))
    tag = "Learn & Grow  ·  Ages 0-10  ·  Offline"
    d.text((52, 158), tag, font=sub, fill=(2, 48, 71))
    d.text((50, 156), tag, font=sub, fill=(255, 250, 240))

    OUT.mkdir(parents=True, exist_ok=True)
    out = OUT / "feature_graphic_1024x500.png"
    img.save(out, "PNG", optimize=True)
    print(f"wrote {out} ({W}x{H})")


if __name__ == "__main__":
    main()
