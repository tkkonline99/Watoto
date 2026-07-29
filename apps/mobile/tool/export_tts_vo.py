"""Export offline VO MP3s from audio_manifest.csv via Edge neural TTS.

Paths match the app convention: assets/audio/<lang>/<i18n-key>.mp3
The Flutter narration controller loads these first, then falls back to EN,
then to on-device TTS.

Usage (from apps/mobile):
    python tool/export_tts_vo.py                       # free-tier stages 1-5, all langs
    python tool/export_tts_vo.py --stages 1,2 --langs en
    python tool/export_tts_vo.py --all --concurrency 12
    python tool/export_tts_vo.py --force               # re-export existing

Requires: pip install --user edge-tts
"""
from __future__ import annotations

import argparse
import asyncio
import csv
import os
import sys
import tempfile
from pathlib import Path

try:
    import edge_tts
except ImportError as e:
    sys.exit("edge-tts required: python -m pip install --user edge-tts\n" + str(e))

MOBILE = Path(__file__).resolve().parents[1]
REPO = MOBILE.parents[1]
MANIFEST = REPO / "content" / "production" / "audio" / "audio_manifest.csv"
OUT_ROOT = MOBILE / "assets" / "audio"

# Warm, kid-friendly neural voices (verified via edge_tts.list_voices).
VOICES = {
    "en": "en-US-AriaNeural",
    "fr": "fr-FR-DeniseNeural",
    "sw": "sw-KE-ZuriNeural",
}

# Slightly slower / warmer for younger stages.
RATE_BY_STAGE = {
    1: "-15%",
    2: "-12%",
    3: "-8%",
    4: "-5%",
    5: "-3%",
}


def rate_for(stage: int) -> str:
    if stage <= 5:
        return RATE_BY_STAGE.get(stage, "-5%")
    return "+0%"


def load_rows(stages: set[int] | None, langs: set[str] | None) -> list[dict]:
    rows = []
    with MANIFEST.open(encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            try:
                st = int(row["stage"])
            except (KeyError, ValueError):
                continue
            lang = (row.get("language") or "en").strip().lower()
            if stages is not None and st not in stages:
                continue
            if langs is not None and lang not in langs:
                continue
            text = (row.get("text") or "").strip()
            if not text:
                continue
            rows.append(row)
    return rows


async def export_one(row: dict, out_root: Path, force: bool, sem: asyncio.Semaphore) -> str:
    """Returns 'wrote' | 'skip' | 'fail'."""
    lang = row["language"].strip().lower()
    key = row["i18n_key"].strip()
    # Prefer manifest audio_path basename structure: audio/<lang>/<key>.mp3
    rel = row.get("audio_path") or f"audio/{lang}/{key}.mp3"
    rel = rel.replace("\\", "/").lstrip("/")
    # Strip leading "audio/" if present so we nest under out_root correctly
    if rel.startswith("audio/"):
        rel = rel[len("audio/") :]
    dest = out_root / rel
    if dest.exists() and not force:
        return "skip"

    text = row["text"].strip()
    try:
        stage = int(row["stage"])
    except ValueError:
        stage = 5
    voice = VOICES.get(lang, VOICES["en"])
    rate = rate_for(stage)

    async with sem:
        dest.parent.mkdir(parents=True, exist_ok=True)
        # Write outside assets/ so Flutter never sees incomplete *.partial.mp3 files.
        tmp = Path(tempfile.gettempdir()) / f"watoto-vo-{os.getpid()}-{hash(rel) & 0xFFFFFFFF:x}.mp3"
        try:
            communicate = edge_tts.Communicate(text, voice, rate=rate)
            await communicate.save(str(tmp))
            # Atomic-ish replace onto the assets path.
            if dest.exists():
                dest.unlink()
            tmp.replace(dest)
            return "wrote"
        except Exception as exc:  # noqa: BLE001 — batch must continue
            if tmp.exists():
                try:
                    tmp.unlink()
                except OSError:
                    pass
            print(f"  FAIL {rel}: {exc}", file=sys.stderr, flush=True)
            return "fail"


async def run(rows: list[dict], out_root: Path, force: bool, concurrency: int) -> dict:
    sem = asyncio.Semaphore(concurrency)
    counts = {"wrote": 0, "skip": 0, "fail": 0}
    total = len(rows)
    done = 0

    async def wrapped(row):
        nonlocal done
        status = await export_one(row, out_root, force, sem)
        counts[status] = counts.get(status, 0) + 1
        done += 1
        if done % 50 == 0 or done == total:
            print(
                f"  … {done}/{total} "
                f"(wrote={counts['wrote']} skip={counts['skip']} fail={counts['fail']})",
                flush=True,
            )

    await asyncio.gather(*(wrapped(r) for r in rows))
    return counts


def main():
    ap = argparse.ArgumentParser(description="Export VO MP3s from audio_manifest via edge-tts")
    ap.add_argument("--stages", default="1,2,3,4,5", help="Comma stages (default free-tier 1-5)")
    ap.add_argument("--all", action="store_true", help="All stages 1-10")
    ap.add_argument("--langs", default="en,fr,sw", help="Comma language codes")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--concurrency", type=int, default=8)
    ap.add_argument("--out", default=str(OUT_ROOT))
    ap.add_argument("--limit", type=int, default=0, help="Optional max rows (debug)")
    args = ap.parse_args()

    stages = None if args.all else {int(x) for x in args.stages.split(",") if x.strip()}
    langs = {x.strip().lower() for x in args.langs.split(",") if x.strip()}
    rows = load_rows(stages, langs)
    if args.limit and args.limit > 0:
        rows = rows[: args.limit]
    if not rows:
        sys.exit("No audio rows matched filters")

    out_root = Path(args.out)
    print(f"Exporting {len(rows)} clips → {out_root}")
    print(f"  stages={stages or 'all'} langs={sorted(langs)} concurrency={args.concurrency}")
    counts = asyncio.run(run(rows, out_root, args.force, max(1, args.concurrency)))
    print(
        f"VO export done: wrote={counts['wrote']} skip={counts['skip']} "
        f"fail={counts['fail']} total={len(rows)}"
    )
    return 0 if counts.get("fail", 0) == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
