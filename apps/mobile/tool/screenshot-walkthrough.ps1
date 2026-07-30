<#
.SYNOPSIS
  Launch Watoto for store-screenshot capture (free-only offline build).

.DESCRIPTION
  Starts the app with PUBLISH_FREE_ONLY=true so all stages are unlocked and
  purchase UI is hidden. Follow docs/SCREENSHOT_WALKTHROUGH.md while the app
  is running.

.PARAMETER Device
  Flutter device id (default: chrome). Use `flutter devices` to list.

.EXAMPLE
  pwsh tool/screenshot-walkthrough.ps1
  pwsh tool/screenshot-walkthrough.ps1 -Device windows
  pwsh tool/screenshot-walkthrough.ps1 -Device emulator-5554
#>
param(
  [string]$Device = 'chrome'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host @"

Watoto — screenshot capture mode
================================
Device:  $Device
Defines: PUBLISH_FREE_ONLY=true  SCREENSHOT_MODE=true
Guide:   docs/SCREENSHOT_WALKTHROUGH.md
Release: docs/FREE_ONLY_RELEASE_CHECKLIST.md

Frame checklist (phone portrait):
  1. Home — Play now hero, XP/streak pills, subjects
  2. Toddler lesson (stage 1–2) — co-play tip + large target + hero art
  3. Celebration — XP/coins + Keep going
  4. First-of-day High five! sheet (fresh day profile)
  5. Story page — illustration + narration
  6. Parent lock / PIN gate (or banner if screenshot mode)
  7. Avatar shop + home themes
  8. Language picker EN / FR / SW

Tips:
  - Triple-tap parent lock on home → seed Amani + screenshot banner
  - Or Parent zone → Load demo for screenshots
  - Feature graphic: docs/store-assets/feature_graphic_1024x500.png
  - Hide system bars / browser chrome; crop to 9:16 or store sizes

"@

$flutter = if (Test-Path 'C:\dev\flutter\bin\flutter.bat') {
  'C:\dev\flutter\bin\flutter.bat'
} else {
  'flutter'
}

& $flutter run -d $Device `
  --dart-define=PUBLISH_FREE_ONLY=true `
  --dart-define=SCREENSHOT_MODE=true `
  --dart-define=FLUTTER_WEB_USE_SKIA=true
