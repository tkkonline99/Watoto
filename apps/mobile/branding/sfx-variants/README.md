# Sound-effect variants (audition set)

Three tonal styles of the app's interaction sounds, generated from the same
synthesis recipe (additive sine partials + soft attack, exponential decay).
Each folder holds drop-in replacements for the shipped set:

| Style | Character | Register |
|---|---|---|
| `bell/` | glassy, rounded | mid (C major) |
| `warm-marimba/` | woodier, softer, strong 4th partial — **the shipped set** | low (G major) |
| `bright-kalimba/` | plucky, sparkly, sparse harmonics | high (A major) |

Each set contains:

- `tap.wav` — pop on each counted/tapped object
- `correct.wav` — rising two-note success chime
- `celebrate.wav` — ascending arpeggio on lesson/quiz/story completion

## Auditioning

Double-click any `.wav` in Explorer (or select a folder and play through).
Compare like-for-like: the three `celebrate.wav` files differ only in timbre
and key.

## Swapping the shipped set

The app bundles only `apps/mobile/assets/audio/sfx/`. To switch styles, copy a
variant's three files over it, e.g. from `apps/mobile`:

```powershell
Copy-Item branding\sfx-variants\warm-marimba\*.wav assets\audio\sfx\ -Force
```

then rebuild. File names match, so no code changes are needed.

**This folder is not bundled with the app** (see `pubspec.yaml` assets — only
`assets/audio/sfx/` ships). It lives in the repo like `branding/app_icon.png`:
a source-asset workspace. Regenerate or tweak styles with
`python tool/generate_sfx.py branding/sfx-variants` — frequencies, decay, and
harmonics are declared per style in the script's `STYLES` table.
