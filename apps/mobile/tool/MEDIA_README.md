# Watoto media pipeline (illustration + VO)

Complete free-tier and full-library offline media for the mobile app.

## Layout

| Path | Purpose |
|------|---------|
| `assets/images/img/sNN/*.png` | Language-neutral illustrations (512×512) |
| `assets/audio/<lang>/<i18n-key>.mp3` | Offline voiceover (en / fr / sw) |
| `assets/audio/sfx/*.wav` | Tap / correct / celebrate SFX |
| `../../content/production/images/image_manifest.csv` | Art briefs + paths |
| `../../content/production/audio/audio_manifest.csv` | VO script + paths |

## (a) Illustration batch

```powershell
cd apps/mobile
python tool/generate_art_batch.py              # free-tier stages 1–5
python tool/generate_art_batch.py --all        # all 543 images
python tool/generate_art_batch.py --force      # overwrite
```

Requires: `python -m pip install --user pillow`

Flat preschool style matching the s01 starter pack. `text_risk` briefs stay text-free (app overlays captions). Existing hand-tuned PNGs are skipped unless `--force`.

## (b) MP3-first narration (app)

`NarrationController.speak(text, lang, audioKey: '…')` tries, in order:

1. Bundled asset: `assets/audio/<lang>/<audioKey>.mp3`
2. Downloaded Parent Zone voice pack (`VoicePackService`): `<appSupport>/voice_packs/<lang>/<audioKey>.mp3`
3. On-device Flutter TTS (naturalized + chunked)

Lesson / quiz / story play screens pass the content i18n key as `audioKey`.
Parents can download or remove the `en`, `sw`, and `fr` neural voice packs
from **Parent Zone → Accessibility → Offline Neural Voice Packs**, which
fetches and SHA-256-verifies `<lang>.zip` from the `voice-pack-v1` GitHub
Release.

## (c) Offline TTS export

```powershell
cd apps/mobile
python tool/export_tts_vo.py                           # stages 1–5, en+fr+sw
python tool/export_tts_vo.py --stages 1,2 --langs en   # smaller pack
python tool/export_tts_vo.py --all --concurrency 12    # full library
```

Requires: `python -m pip install --user edge-tts` (free Microsoft Edge neural voices).

Voices: `en-US-AriaNeural`, `fr-FR-DeniseNeural`, `sw-KE-ZuriNeural`. Resume-safe: existing files are skipped.

## Scope (completed)

| Asset | Count | Notes |
|-------|------:|-------|
| Illustrations | **543** | All stages s01–s10 (`generate_art_batch.py --all`) |
| VO clips | **7,983** | 2,661 × en/fr/sw, 0 missing vs `audio_manifest.csv` |
| Free-tier VO (stages 1–5) | 3,765 | Always unlocked offline |
| SFX | 3 WAV | tap / correct / celebrate |

Approx disk: ~3 MB art + ~170 MB VO (neural Edge TTS).

## After export

`pubspec.yaml` lists each image stage folder and each VO language folder (Flutter only packs files **directly** under a listed directory). Re-run `flutter pub get` if the asset graph looks stale.

```text
assets/images/img/s01/ … s10/
assets/audio/en|fr|sw/<i18n-key>.mp3
```
