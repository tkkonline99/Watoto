# Watoto — Screenshot Walkthrough

Use this while capturing App Store / Play Console screenshots for the **free-only offline** launch.

## Launch the app

```powershell
cd C:\dev\watoto\apps\mobile
pwsh tool/screenshot-walkthrough.ps1              # Chrome (default)
pwsh tool/screenshot-walkthrough.ps1 -Device windows
# or a phone / emulator id from: flutter devices
```

### Demo data (recommended)

**Fast path:** triple-tap the 🔒 parent lock on child home within ~1 second.  
That enables **screenshot mode** (PIN skipped), seeds **Amani**, and shows a capture banner.

**Menu path:**

1. Complete onboarding once (or use an existing family).  
2. Open **Parent zone** (lock) → PIN (or already in screenshot mode).  
3. Tap **Load demo for screenshots** — sample XP, coins, ocean theme, tour dismissed.  
4. Snackbar **Play now** jumps to home ready for frames 1–3.

Exit capture: banner **Exit**, or restart the app without `SCREENSHOT_MODE`.

The script runs with `--dart-define=PUBLISH_FREE_ONLY=true` so:

- Stages **1–10** are unlocked without Premium  
- Purchase / paywall CTAs are hidden  
- Parent zone shows “Everything is free offline” instead of IAP  

## Capture frames (phone portrait)

| # | Route / action | What to frame |
|---|----------------|---------------|
| 1 | Finish onboarding → **Home** | Play now hero, streak/XP pills, daily challenge |
| 2 | Play now → stage 1–2 lesson | Co-play “Grown-up tip” + large tap target + hero art |
| 3 | Finish activity | Celebration: XP/coins chips + **Keep going** |
| 4 | First activity of a fresh day | **High five!** sheet with grown-up tip |
| 5 | Story item | Illustration + page narration |
| 6 | Parent lock → PIN | Grown-ups only gate (no real email) |
| 7 | Parent → Avatar shop | Animals + **Home themes** (ocean/sunset/night/candy) |
| 8 | Language menu | EN / FR / SW |

Optional: daily challenge completed state; stretch break sheet after long play.

## Device tips

- **Android:** `flutter run -d <id> --dart-define=PUBLISH_FREE_ONLY=true` then system screenshot.  
- **Chrome:** F11 fullscreen; crop to phone aspect (9:16) in an editor.  
- **iOS:** needs a Mac or Codemagic; same define.  
- Prefer a child nickname like **Amani** and a free avatar (lion).  
- No debug banner: release/profile builds, or Flutter’s screenshot tools.

## Crop / size targets

| Store | Typical size |
|-------|----------------|
| Google Play phone | 1080×1920 (or 16:9 variants) |
| Apple 6.7" | 1290×2796 (device-specific) |

Keep safe margins; avoid system status bar if store policy requires.

## After capture

1. Paste metadata from `STORE_LISTING.md` (EN/FR/SW).  
2. Complete Data Safety / App Privacy to match free-only offline (no IAP, no ads).  
3. Tick off `FREE_ONLY_RELEASE_CHECKLIST.md`.  
4. See `LAUNCH_RUNBOOK.md` for accounts, legal, and CI.  
