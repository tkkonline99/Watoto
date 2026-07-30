<#
.SYNOPSIS
  Preflight checks before free-only store submit.

.DESCRIPTION
  Runs local gates that catch missing assets, broken l10n, and failing tests
  before you spend time on store consoles. Does not build store binaries
  (use build-android.ps1 / build-ios.ps1 for that).

.PARAMETER SkipTests
  Skip flutter test (faster asset/doc-only check).

.PARAMETER Analyze
  Also run flutter analyze.

.EXAMPLE
  powershell -File tool/preflight-release.ps1
  powershell -File tool/preflight-release.ps1 -Analyze
#>
param(
  [switch]$SkipTests,
  [switch]$Analyze
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$flutter = if ($env:FLUTTER_BIN) {
  $env:FLUTTER_BIN
} elseif (Test-Path 'C:\dev\flutter\bin\flutter.bat') {
  'C:\dev\flutter\bin\flutter.bat'
} else {
  'flutter'
}

$fail = 0
function Ok($msg) { Write-Host "  OK  $msg" -ForegroundColor Green }
function Bad($msg) { Write-Host "  FAIL $msg" -ForegroundColor Red; $script:fail++ }
function Info($msg) { Write-Host "  --  $msg" }

Write-Host ""
Write-Host "Watoto free-only preflight" -ForegroundColor Cyan
Write-Host ("=" * 40)

# --- Docs & store assets ----------------------------------------------------
Write-Host "`n[docs / store assets]"
# $root = apps/mobile → repo root is two levels up
$repoRoot = (Resolve-Path (Join-Path $root '..\..')).Path

$docPaths = @(
  'docs/FREE_ONLY_RELEASE_CHECKLIST.md',
  'docs/STORE_LISTING.md',
  'docs/SCREENSHOT_WALKTHROUGH.md',
  'docs/LAUNCH_RUNBOOK.md',
  'docs/store-assets/feature_graphic_1024x500.png',
  'docs/APP_IDS.md'
)
foreach ($rel in $docPaths) {
  $p = Join-Path $repoRoot $rel
  if (Test-Path $p) { Ok $rel } else { Bad "missing $rel" }
}

# --- Hero art samples (stages 1–10) -----------------------------------------
Write-Host "`n[hero art samples]"
$heroes = @(
  'assets/images/img/s01/ball.png',
  'assets/images/img/s02/duck.png',
  'assets/images/img/s03/apple.png',
  'assets/images/img/s04/rainbow.png',
  'assets/images/img/s05/robot_start.png',
  'assets/images/img/s06/flag.png',
  'assets/images/img/s07/globe.png',
  'assets/images/img/s08/water_cycle.png',
  'assets/images/img/s09/solar_system.png',
  'assets/images/img/s10/world_map.png'
)
foreach ($rel in $heroes) {
  $p = Join-Path $root $rel
  if ((Test-Path $p) -and ((Get-Item $p).Length -gt 100)) {
    Ok $rel
  } else {
    Bad "missing/empty $rel"
  }
}

# --- Flutter ----------------------------------------------------------------
Write-Host "`n[flutter]"
Info "using: $flutter"
& $flutter pub get
if ($LASTEXITCODE -ne 0) { Bad 'flutter pub get'; exit 1 } else { Ok 'pub get' }

& $flutter gen-l10n
if ($LASTEXITCODE -ne 0) { Bad 'gen-l10n' } else { Ok 'gen-l10n' }

if ($Analyze) {
  & $flutter analyze
  if ($LASTEXITCODE -ne 0) { Bad 'analyze' } else { Ok 'analyze' }
}

if (-not $SkipTests) {
  Write-Host "`n[tests]"
  & $flutter test
  if ($LASTEXITCODE -ne 0) { Bad 'flutter test' } else { Ok 'flutter test' }
} else {
  Info 'tests skipped (-SkipTests)'
}

Write-Host ""
Write-Host ("=" * 40)
if ($fail -gt 0) {
  Write-Host "PREFLIGHT FAILED ($fail check(s))" -ForegroundColor Red
  Write-Host "Fix issues above, then see docs/FREE_ONLY_RELEASE_CHECKLIST.md"
  exit 1
}

Write-Host "PREFLIGHT OK - free-only code/assets gates passed." -ForegroundColor Green
Write-Host ""
Write-Host "Next (human):"
Write-Host "  1. docs/FREE_ONLY_RELEASE_CHECKLIST.md"
Write-Host "  2. Screenshots: tool/screenshot-walkthrough.ps1"
Write-Host "  3. Android AAB: tool/build-android.ps1 -Target appbundle -Mode release"
Write-Host "  4. iOS: tool/build-ios.ps1 (macOS/CI)"
exit 0
