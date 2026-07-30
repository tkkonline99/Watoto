<#
.SYNOPSIS
  Build the Watoto iOS app (macOS only) with free-only defaults.

.DESCRIPTION
  Apple requires macOS + Xcode for `flutter build ios` / ipa. On Windows this
  script prints the exact commands for a Mac or CI runner and exits 0 so
  docs/scripts can still reference it.

  Free-offline launch (default): PUBLISH_FREE_ONLY=true unlocks stages 1–10
  and hides IAP UI — same define as tool/build-android.ps1.

.PARAMETER Mode
  release (default), profile, or debug.

.PARAMETER Ipa
  When set on macOS, builds an IPA (needs signing configured in Xcode).

.PARAMETER PublishFreeOnly
  Default $true for the free offline launch.

.EXAMPLE
  # On a Mac:
  pwsh tool/build-ios.ps1 -Mode release
  pwsh tool/build-ios.ps1 -Ipa -Mode release

  # CI: see codemagic.yaml and .github/workflows/build.yml
#>
param(
  [ValidateSet('debug', 'profile', 'release')] [string]$Mode = 'release',
  [switch]$Ipa,
  [bool]$PublishFreeOnly = $true
)

$ErrorActionPreference = 'Stop'

$define = if ($PublishFreeOnly) { 'true' } else { 'false' }

# Prefer explicit Windows/macOS flags (PS 6+); fall back to env on Windows PS 5.
$onWindows = ($env:OS -match 'Windows') -or
  ($null -ne (Get-Variable IsWindows -ErrorAction SilentlyContinue) -and $IsWindows)
$onMac = (-not $onWindows) -and (
  ($null -ne (Get-Variable IsMacOS -ErrorAction SilentlyContinue) -and $IsMacOS)
)

if (-not $onMac) {
  Write-Host @"
iOS builds require macOS + Xcode (this host is not macOS).

On a Mac, from apps/mobile:

  flutter pub get
  flutter gen-l10n
  flutter build ios --$Mode --dart-define=PUBLISH_FREE_ONLY=$define
  # or IPA:
  flutter build ipa --$Mode --dart-define=PUBLISH_FREE_ONLY=$define

CI (already free-only aware):
  - codemagic.yaml
  - .github/workflows/build.yml

Bundle ID: app.watoto.watotoMobile  (docs/APP_IDS.md)
"@
  exit 0
}

$flutter = if ($env:FLUTTER_BIN) { $env:FLUTTER_BIN } else { 'flutter' }
Write-Host "flutter build ios  mode=$Mode  PUBLISH_FREE_ONLY=$define"
if ($Ipa) {
  & $flutter build ipa "--$Mode" "--dart-define=PUBLISH_FREE_ONLY=$define"
} else {
  & $flutter build ios "--$Mode" "--dart-define=PUBLISH_FREE_ONLY=$define"
}
exit $LASTEXITCODE
