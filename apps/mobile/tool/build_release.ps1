# Build store-oriented free-only release artifacts (no payments).
# Usage (from apps/mobile):
#   pwsh tool/build_release.ps1
#   pwsh tool/build_release.ps1 -Platform android
#   pwsh tool/build_release.ps1 -WebsiteUrl https://your.domain

param(
  [ValidateSet('android', 'web', 'windows', 'all')]
  [string]$Platform = 'android',
  [string]$WebsiteUrl = 'https://watoto.app',
  [string]$SupportEmail = 'support@watoto.app',
  [string]$PrivacyEmail = 'privacy@watoto.app'
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot\..

$defines = @(
  "PUBLISH_FREE_ONLY=true",
  "WATOTO_WEBSITE_URL=$WebsiteUrl",
  "WATOTO_SUPPORT_EMAIL=$SupportEmail",
  "WATOTO_PRIVACY_EMAIL=$PrivacyEmail",
  "USE_FIREBASE=false"
)
$defineArgs = ($defines | ForEach-Object { "--dart-define=$_" }) -join ' '

Write-Host "flutter pub get / gen-l10n / test..."
flutter pub get
flutter gen-l10n
flutter test

function Build-One([string]$p) {
  switch ($p) {
    'android' {
      Write-Host "Building App Bundle (release, free-only)..."
      Invoke-Expression "flutter build appbundle --release $defineArgs"
      Write-Host "-> build/app/outputs/bundle/release/app-release.aab"
    }
    'web' {
      Invoke-Expression "flutter build web --release $defineArgs"
    }
    'windows' {
      Invoke-Expression "flutter build windows --release $defineArgs"
    }
  }
}

if ($Platform -eq 'all') {
  Build-One android
  Build-One web
} else {
  Build-One $Platform
}

Write-Host "Done. Host docs/site/ on $WebsiteUrl before store submit."
