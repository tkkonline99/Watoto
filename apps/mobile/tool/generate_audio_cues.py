#!/usr/bin/env python3
"""Render the 87 declared audio cues in content/production/audio/audio_sfx_manifest.csv.

- Instrumental / sound-effect cues (chimes, drums, shakers, lullabies, songs)
  are synthesized with warm marimba/bell/percussion partials and encoded to MP3
  via `lameenc`.
- Spoken / vocal cues are rendered with `edge-tts` (`en-US-AnaNeural`) using the
  item's story/lesson narration from `watoto_content_library.json`.

Usage (from repo root):
    python3 apps/mobile/tool/generate_audio_cues.py
"""
from __future__ import annotations

import asyncio
import csv
import json
import math
import random
import struct
from pathlib import Path

import edge_tts
import lameenc

REPO = Path(__file__).resolve().parents[3]
MANIFEST = REPO / "content" / "production" / "audio" / "audio_sfx_manifest.csv"
LIBRARY = REPO / "content" / "watoto_content_library.json"
ASSETS_ROOT = REPO / "apps" / "mobile" / "assets"

SR = 44100
VOICE_EN = "en-US-AnaNeural"


def _note(freq: float, dur: float, harmonics: tuple[float, ...], decay: float, attack_ms: float = 6.0) -> list[float]:
    n = int(SR * dur)
    attack = max(1, int(SR * attack_ms / 1000))
    out: list[float] = []
    for i in range(n):
        t = i / SR
        env = math.exp(-t / decay)
        if i < attack:
            env *= i / attack
        s = 0.0
        for k, amp in enumerate(harmonics, start=1):
            if amp:
                s += amp * math.sin(2 * math.pi * freq * k * t)
        out.append(env * s)
    return out


def _noise_burst(dur: float, decay: float, bandpass_hz: float = 1800.0) -> list[float]:
    rng = random.Random(42)
    n = int(SR * dur)
    out: list[float] = []
    for i in range(n):
        t = i / SR
        env = math.exp(-t / decay) * math.sin(min(1.0, t * 80.0) * math.pi / 2)
        carrier = math.sin(2 * math.pi * bandpass_hz * t)
        out.append(env * (0.65 * rng.uniform(-1.0, 1.0) + 0.35 * carrier))
    return out


def _encode_mp3(path: Path, samples: list[float]) -> None:
    hi = max(1e-9, max(abs(s) for s in samples))
    peak = 0.75
    pcm = bytearray()
    for s in samples:
        val = int(max(-1.0, min(1.0, s * peak / hi)) * 32767)
        pcm += struct.pack("<h", val)
    enc = lameenc.Encoder()
    enc.set_bit_rate(96)
    enc.set_in_sample_rate(SR)
    enc.set_channels(1)
    enc.set_quality(2)
    mp3_bytes = enc.encode(bytes(pcm)) + enc.flush()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(bytes(mp3_bytes))


SYNTH_RECIPES: dict[str, list[tuple[float, float, float]]] = {
    "twinkle": [(523.25, 0.22, 0.14), (523.25, 0.22, 0.14), (783.99, 0.22, 0.14), (783.99, 0.22, 0.14), (880.0, 0.22, 0.14), (880.0, 0.22, 0.14), (783.99, 0.45, 0.28)],
    "pop": [(420.0, 0.06, 0.03), (680.0, 0.12, 0.05)],
    "ding": [(1046.50, 0.55, 0.30)],
    "soft_chime": [(659.25, 0.25, 0.18), (987.77, 0.55, 0.35)],
    "boom": [(110.0, 0.35, 0.18), (98.0, 0.45, 0.22)],
    "stomp": [(130.81, 0.22, 0.10), (130.81, 0.28, 0.12)],
    "drum_beat": [(146.83, 0.20, 0.09), (196.00, 0.20, 0.09), (146.83, 0.30, 0.14)],
    "beat": [(164.81, 0.22, 0.10), (220.0, 0.22, 0.10), (164.81, 0.22, 0.10), (220.0, 0.30, 0.14)],
    "bird": [(1760.0, 0.12, 0.08), (2093.0, 0.14, 0.09), (1975.5, 0.18, 0.10), (2349.3, 0.25, 0.14)],
    "lullaby_bed": [(392.0, 0.40, 0.28), (493.88, 0.40, 0.28), (587.33, 0.55, 0.35), (523.25, 0.65, 0.40)],
    "peekaboo_bird": [(523.25, 0.30, 0.20), (659.25, 0.30, 0.20), (783.99, 0.45, 0.30), (659.25, 0.50, 0.32)],
    "bath_song": [(523.25, 0.22, 0.14), (587.33, 0.22, 0.14), (659.25, 0.22, 0.14), (783.99, 0.38, 0.22)],
    "hsk_song": [(523.25, 0.22, 0.14), (587.33, 0.20, 0.12), (523.25, 0.20, 0.12), (440.0, 0.35, 0.20)],
    "parade": [(392.0, 0.18, 0.11), (523.25, 0.18, 0.11), (659.25, 0.18, 0.11), (783.99, 0.38, 0.22)],
    "tidy_song": [(523.25, 0.20, 0.13), (659.25, 0.20, 0.13), (587.33, 0.20, 0.13), (783.99, 0.40, 0.25)],
    "abc_song": [(523.25, 0.22, 0.14), (523.25, 0.22, 0.14), (783.99, 0.22, 0.14), (783.99, 0.22, 0.14), (880.0, 0.22, 0.14), (880.0, 0.22, 0.14), (783.99, 0.42, 0.25)],
    "dance_music": [(440.0, 0.16, 0.10), (554.37, 0.16, 0.10), (659.25, 0.16, 0.10), (880.0, 0.30, 0.18)],
    "anthem": [(392.0, 0.30, 0.20), (493.88, 0.30, 0.20), (587.33, 0.35, 0.22), (783.99, 0.55, 0.35)],
}

NOISE_RECIPES = {"shaker", "rattle", "crinkle", "clap"}

VOCAL_TEXT_OVERRIDES: dict[str, str] = {
    "achoo": "Ah, ah, achoo! Bless you!",
    "yawn": "Ohh, big sleepy stretch and a gentle yawn.",
    "babble": "Ba, ba, ma, ma, da, da!",
    "mama": "Mama! Say ma-ma.",
    "dada": "Dada! Say da-da.",
    "peekaboo": "Peek-a-boo! I see you!",
    "moo": "Moo! The friendly cow says moo.",
    "quack": "Quack, quack, quack! The little duck says quack.",
    "meow": "Meow! The soft kitty says meow.",
    "rhyme_cat": "Cat, hat, bat! They all rhyme with at.",
    "rhyme_an": "Can, fan, pan, van! They all rhyme with an.",
    "phonemes_cat": "Cuh, ahh, tuh. Cat!",
}


def synthesize_cue(stem: str, dest: Path) -> bool:
    if stem in NOISE_RECIPES:
        chunks: list[float] = []
        repeats = 3 if stem in {"shaker", "rattle", "crinkle"} else 2
        for _ in range(repeats):
            chunks.extend(_noise_burst(0.16, 0.05, 2400.0 if stem != "clap" else 1400.0))
            chunks.extend([0.0] * int(SR * 0.08))
        _encode_mp3(dest, chunks)
        return True
    if stem in SYNTH_RECIPES:
        harmonics = (1.0, 0.30, 0.12, 0.15)
        chunks = []
        for freq, dur, dec in SYNTH_RECIPES[stem]:
            chunks.extend(_note(freq, dur, harmonics, dec))
        _encode_mp3(dest, chunks)
        return True
    return False


async def main() -> int:
    lib = json.loads(LIBRARY.read_text(encoding="utf-8"))
    items_by_id = {it["id"]: it for it in lib.get("content", [])}

    rows = list(csv.DictReader(MANIFEST.open(encoding="utf-8", newline="")))
    tts_jobs: list[tuple[Path, str]] = []
    synth_count = 0

    for row in rows:
        ref = row["ref"].strip()
        dest = ASSETS_ROOT / ref
        stem = Path(ref).stem
        if synthesize_cue(stem, dest):
            synth_count += 1
            continue

        text = VOCAL_TEXT_OVERRIDES.get(stem)
        if not text:
            item = items_by_id.get(row["first_item"].strip())
            if item:
                pages = item.get("pages") or []
                steps = item.get("steps") or []
                if pages and pages[0].get("narration"):
                    text = f"{item.get('title', '')}. {pages[0]['narration']}"
                elif steps and steps[0].get("narration"):
                    text = f"{item.get('title', '')}. {steps[0]['narration']}"
                else:
                    text = f"{item.get('title', '')}. {item.get('objective', '')}"
            else:
                text = row.get("description") or stem.replace("_", " ")
        tts_jobs.append((dest, text))

    sem = asyncio.Semaphore(8)

    async def render_tts(dest: Path, text: str) -> None:
        async with sem:
            dest.parent.mkdir(parents=True, exist_ok=True)
            comm = edge_tts.Communicate(text, VOICE_EN, rate="-8%")
            await comm.save(str(dest))

    await asyncio.gather(*(render_tts(dest, text) for dest, text in tts_jobs))
    print(f"Audio cues complete: {synth_count} synthesized, {len(tts_jobs)} spoken via edge-tts ({synth_count + len(tts_jobs)} total)")
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
