#!/usr/bin/env python3
"""Generate a 20-image starter illustration pack (no Pillow required).

Writes simple, warm, high-contrast PNGs matching the first 20 image_ref rows
from image_manifest.csv into apps/mobile/assets/images/... so the Flutter
client can show real art for the earliest activities.
"""
from __future__ import annotations

import csv
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CSV = Path(__file__).resolve().parent / "image_manifest.csv"
OUT = ROOT / "apps" / "mobile" / "assets" / "images"

# Soft savanna palette
PALETTE = {
    "sky": (135, 206, 235),
    "sun": (255, 200, 87),
    "leaf": (82, 183, 136),
    "sand": (255, 243, 224),
    "coral": (238, 108, 90),
    "deep": (2, 48, 71),
    "mango": (244, 162, 42),
    "cream": (255, 250, 240),
    "lilac": (157, 111, 216),
    "teal": (43, 179, 163),
}

# Map filename stem → (bg, primary, secondary, shape_kind)
STYLES = {
    "baby_face": ("cream", "sun", "coral", "face"),
    "ball": ("sky", "coral", "sun", "circle"),
    "ball_bell": ("sky", "mango", "leaf", "circle"),
    "bath_splash": ("sky", "teal", "cream", "splash"),
    "bear_wave": ("sand", "mango", "deep", "bear"),
    "bell": ("lilac", "sun", "cream", "bell"),
    "big_drum": ("sand", "coral", "deep", "drum"),
    "bird_leaf": ("leaf", "sky", "cream", "bird"),
    "bird_nest": ("sand", "leaf", "mango", "nest"),
    "bird_peek": ("sky", "coral", "leaf", "bird"),
    "box_car": ("sand", "teal", "deep", "car"),
    "bubbles": ("sky", "cream", "teal", "bubbles"),
    "bunny_clap": ("cream", "lilac", "coral", "bunny"),
    "cloth": ("sand", "lilac", "cream", "cloth"),
    "cloud_rain": ("sky", "deep", "teal", "rain"),
    "clouds": ("sky", "cream", "lilac", "clouds"),
    "color_glow": ("deep", "sun", "coral", "glow"),
    "cup": ("sand", "teal", "cream", "cup"),
    "dada": ("cream", "mango", "leaf", "face"),
    "door": ("sand", "deep", "sun", "door"),
}


def _chunk(tag: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + tag + data + struct.pack(
        ">I", zlib.crc32(tag + data) & 0xFFFFFFFF
    )


def write_png(path: Path, w: int, h: int, rgba: bytes) -> None:
    """Write a raw RGBA PNG (no filter optimization)."""
    raw = bytearray()
    stride = w * 4
    for y in range(h):
        raw.append(0)  # filter none
        raw.extend(rgba[y * stride : (y + 1) * stride])
    compressed = zlib.compress(bytes(raw), 9)
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + _chunk(b"IHDR", ihdr) + _chunk(b"IDAT", compressed) + _chunk(
        b"IEND", b""
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


def _fill(buf: bytearray, w: int, h: int, color: tuple[int, int, int], a: int = 255) -> None:
    r, g, b = color
    for i in range(0, len(buf), 4):
        buf[i] = r
        buf[i + 1] = g
        buf[i + 2] = b
        buf[i + 3] = a


def _circle(
    buf: bytearray, w: int, h: int, cx: int, cy: int, rad: int, color: tuple[int, int, int]
) -> None:
    r, g, b = color
    r2 = rad * rad
    for y in range(max(0, cy - rad), min(h, cy + rad + 1)):
        for x in range(max(0, cx - rad), min(w, cx + rad + 1)):
            if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r2:
                i = (y * w + x) * 4
                buf[i] = r
                buf[i + 1] = g
                buf[i + 2] = b
                buf[i + 3] = 255


def _rect(
    buf: bytearray,
    w: int,
    h: int,
    x0: int,
    y0: int,
    x1: int,
    y1: int,
    color: tuple[int, int, int],
) -> None:
    r, g, b = color
    for y in range(max(0, y0), min(h, y1)):
        for x in range(max(0, x0), min(w, x1)):
            i = (y * w + x) * 4
            buf[i] = r
            buf[i + 1] = g
            buf[i + 2] = b
            buf[i + 3] = 255


def paint(kind: str, bg, prim, sec) -> bytes:
    w = h = 512
    buf = bytearray(w * h * 4)
    _fill(buf, w, h, bg)
    # decorative sun disk
    _circle(buf, w, h, 420, 90, 48, PALETTE["sun"])
    if kind in ("circle", "ball", "glow"):
        _circle(buf, w, h, 256, 280, 120, prim)
        _circle(buf, w, h, 220, 240, 36, sec)
    elif kind == "bubbles":
        for cx, cy, r in ((160, 200, 50), (280, 300, 70), (360, 180, 40), (200, 360, 55)):
            _circle(buf, w, h, cx, cy, r, prim)
            _circle(buf, w, h, cx - r // 3, cy - r // 3, r // 4, sec)
    elif kind in ("face", "bear", "bunny"):
        _circle(buf, w, h, 256, 260, 130, prim)
        _circle(buf, w, h, 210, 240, 16, PALETTE["deep"])
        _circle(buf, w, h, 302, 240, 16, PALETTE["deep"])
        _circle(buf, w, h, 256, 300, 18, sec)
        if kind == "bunny":
            _circle(buf, w, h, 190, 120, 36, prim)
            _circle(buf, w, h, 322, 120, 36, prim)
    elif kind == "bird":
        _circle(buf, w, h, 256, 260, 80, prim)
        _circle(buf, w, h, 320, 240, 36, prim)
        _circle(buf, w, h, 330, 230, 8, PALETTE["deep"])
        _rect(buf, w, h, 180, 250, 240, 280, sec)
    elif kind == "nest":
        _circle(buf, w, h, 256, 320, 100, prim)
        _circle(buf, w, h, 230, 280, 30, sec)
        _circle(buf, w, h, 280, 280, 30, sec)
    elif kind == "drum":
        _rect(buf, w, h, 140, 200, 372, 380, prim)
        _circle(buf, w, h, 256, 200, 116, sec)
    elif kind == "bell":
        _circle(buf, w, h, 256, 220, 90, prim)
        _rect(buf, w, h, 220, 280, 292, 360, prim)
        _circle(buf, w, h, 256, 370, 24, sec)
    elif kind == "car":
        _rect(buf, w, h, 120, 240, 400, 340, prim)
        _rect(buf, w, h, 180, 180, 340, 240, sec)
        _circle(buf, w, h, 180, 340, 36, PALETTE["deep"])
        _circle(buf, w, h, 340, 340, 36, PALETTE["deep"])
    elif kind == "cloth":
        _rect(buf, w, h, 100, 160, 412, 380, prim)
        _rect(buf, w, h, 140, 200, 372, 340, sec)
    elif kind == "cup":
        _rect(buf, w, h, 180, 200, 332, 380, prim)
        _rect(buf, w, h, 332, 240, 380, 320, sec)
        _circle(buf, w, h, 256, 200, 76, sec)
    elif kind == "door":
        _rect(buf, w, h, 150, 100, 362, 420, prim)
        _circle(buf, w, h, 320, 270, 14, sec)
        _rect(buf, w, h, 170, 120, 340, 400, sec)
    elif kind == "rain":
        _circle(buf, w, h, 200, 160, 50, prim)
        _circle(buf, w, h, 260, 140, 60, prim)
        _circle(buf, w, h, 320, 160, 50, prim)
        for x in range(160, 360, 40):
            _rect(buf, w, h, x, 240, x + 10, 360, sec)
    elif kind == "clouds":
        for cx, cy, r in ((180, 240, 60), (250, 220, 80), (330, 250, 55)):
            _circle(buf, w, h, cx, cy, r, prim)
    elif kind == "splash":
        _circle(buf, w, h, 256, 300, 100, prim)
        for cx, cy, r in ((180, 180, 30), (320, 160, 24), (256, 140, 20)):
            _circle(buf, w, h, cx, cy, r, sec)
    else:
        _circle(buf, w, h, 256, 256, 100, prim)
    return bytes(buf)


def main() -> None:
    with CSV.open(encoding="utf-8") as f:
        rows = list(csv.DictReader(f))[:20]
    written = []
    for row in rows:
        ref = row["image_ref"]  # e.g. img/s01/ball.png
        stem = Path(ref).stem
        style = STYLES.get(stem, ("sand", "mango", "leaf", "circle"))
        bg_k, prim_k, sec_k, kind = style
        rgba = paint(kind, PALETTE[bg_k], PALETTE[prim_k], PALETTE[sec_k])
        out = OUT / ref
        write_png(out, 512, 512, rgba)
        written.append(str(out.relative_to(ROOT)))
    manifest = OUT / "starter_pack.json"
    import json

    manifest.write_text(
        json.dumps({"count": len(written), "files": written}, indent=2),
        encoding="utf-8",
    )
    print(f"Wrote {len(written)} images under {OUT}")


if __name__ == "__main__":
    main()
