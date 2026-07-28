<#
.SYNOPSIS
  Build every Watoto app (one shared codebase) from a single command.

.DESCRIPTION
  Watoto is ONE Flutter project: lib/ is compiled into all platforms, so an edit
  there ships to every app. This script rebuilds the platforms that can be built
  on this Windows machine, so after any change you run one thing and all your
  apps are up to date:

    * Windows desktop  (.exe bundle)
    * Web              (static site)
    * Android          (.apk / .aab)  - best-effort; needs the Android SDK + JDK
    * iOS              - SKIPPED: Apple requires macOS. Build it on a Mac or in
                         CI (see codemagic.yaml / .github/workflows/build.yml).

  It builds OUT OF TREE in a clean workspace (default C:\dev\watoto-build) rather
  than inside the OneDrive repo, because Controlled Folder Access blocks the
  Dart/Gradle toolchain from writing build output into the synced folder. The
  workspace keeps its build/ and .dart_tool between runs, so rebuilds are
  incremental (fast). Source is re-synced from the repo on every run.

  Machine-specific workarounds (shared with build-android.ps1): TMP/TEMP are
  redirected to a clean path (Gradle's AF_UNIX self-pipe is blocked under the
  normal %TEMP%), and JAVA_HOME is pinned outside OneDrive.

.PARAMETER Platforms
  Comma-separated: windows, web, apk, appbundle, all. Default: windows,web.

.PARAMETER Mode
  release (default), profile, or debug.

.PARAMETER Install
  After a successful Windows build, install it to %LOCALAPPDATA%\Programs\Watoto
  and refresh the Desktop shortcut (double-click to launch).

.EXAMPLE
  pwsh tool/build-all.ps1                       # windows + web, release
  pwsh tool/build-all.ps1 -Platforms all        # + android apk
  pwsh tool/build-all.ps1 -Platforms windows -Install
#>
param(
  [string]$Platforms = 'windows,web',
  [ValidateSet('debug', 'profile', 'release')] [string]$Mode = 'release',
  [switch]$Install
)

$ErrorActionPreference = 'Stop'

# --- Tunables (override via env; defaults match this machine) ---------------
$cleanTmp = if ($env:WATOTO_TMP)   { $env:WATOTO_TMP }   else { 'C:\dev\tmp' }
$jdkHome  = if ($env:JAVA_HOME)    { $env:JAVA_HOME }    else { 'C:\dev\jdk-21' }
$flutter  = if ($env:FLUTTER_BIN)  { $env:FLUTTER_BIN }  else { 'C:\dev\flutter\bin\flutter.bat' }
$work     = if ($env:WATOTO_BUILD) { $env:WATOTO_BUILD } else { 'C:\dev\watoto-build' }
# flutter_tts Windows plugin requires nuget.exe on PATH during CMake configure.
$nugetDir = if ($env:WATOTO_NUGET) { $env:WATOTO_NUGET } else { 'C:\dev\nuget' }

$repoMobile = Split-Path $PSScriptRoot -Parent          # apps/mobile (script is in tool/)

# Expand 'all' and normalise the platform list.
$want = $Platforms.Split(',') | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ }
if ($want -contains 'all') { $want = @('windows', 'web', 'apk') }

Write-Host "Watoto build-all  |  mode=$Mode  platforms=$($want -join ', ')"
Write-Host "Source : $repoMobile"
Write-Host "Workdir: $work"
Write-Host ('-' * 70)

# --- 1. Sync source into the out-of-tree workspace --------------------------
# /E copies the tree; we keep the workspace's own build/ + .dart_tool so
# rebuilds stay incremental. Never copy build artefacts or VCS metadata in.
New-Item -ItemType Directory -Force $work | Out-Null
New-Item -ItemType Directory -Force $cleanTmp | Out-Null
$rc = robocopy $repoMobile $work /E /XD build .dart_tool .git ephemeral .idea /XF '*.iml' /NFL /NDL /NJH /NJS /NP
# robocopy exit codes < 8 are success (files copied / nothing to do).
if ($LASTEXITCODE -ge 8) { throw "robocopy failed syncing source (code $LASTEXITCODE)" }

# --- 2. Toolchain env (AF_UNIX + JDK + nuget workarounds) -------------------
$env:TMP = $cleanTmp
$env:TEMP = $cleanTmp
$env:JAVA_HOME = $jdkHome
# Ensure nuget.exe is available for Windows plugin packages (flutter_tts).
New-Item -ItemType Directory -Force $nugetDir | Out-Null
$nugetExe = Join-Path $nugetDir 'nuget.exe'
if (-not (Test-Path $nugetExe)) {
  Write-Host "Downloading nuget.exe -> $nugetExe"
  Invoke-WebRequest -Uri 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' `
    -OutFile $nugetExe -UseBasicParsing
}
$env:Path = "$nugetDir;$env:Path"

Push-Location $work
try {
  Write-Host "flutter pub get"
  & $flutter pub get
  if ($LASTEXITCODE -ne 0) { throw "pub get failed" }
  Write-Host "flutter gen-l10n"
  & $flutter gen-l10n

  # --- 3. Build each requested platform (continue on failure) ---------------
  $results = [ordered]@{}
  $artifacts = [ordered]@{}

  function Build-One($name, $buildArgs, $artifact) {
    Write-Host ('-' * 70)
    Write-Host "flutter $($buildArgs -join ' ')"
    & $flutter @buildArgs
    if ($LASTEXITCODE -eq 0) {
      $script:results[$name] = 'OK'
      $script:artifacts[$name] = Join-Path $work $artifact
    } else {
      $script:results[$name] = "FAILED (exit $LASTEXITCODE)"
    }
  }

  if ($want -contains 'windows') {
    Build-One 'windows' @('build', 'windows', "--$Mode") "build\windows\x64\runner\$((Get-Culture).TextInfo.ToTitleCase($Mode))"
  }
  if ($want -contains 'web') {
    Build-One 'web' @('build', 'web', "--$Mode") 'build\web'
  }
  if ($want -contains 'apk') {
    Build-One 'apk' @('build', 'apk', "--$Mode") 'build\app\outputs\flutter-apk\app-release.apk'
  }
  if ($want -contains 'appbundle') {
    Build-One 'appbundle' @('build', 'appbundle', "--$Mode") 'build\app\outputs\bundle\release\app-release.aab'
  }

  # --- 4. Optional: install the Windows build for double-click launch -------
  if ($Install -and $results['windows'] -eq 'OK') {
    $rel = $artifacts['windows']
    $dest = Join-Path $env:LOCALAPPDATA 'Programs\Watoto'
    Write-Host ('-' * 70)
    Write-Host "Installing Windows build -> $dest"
    # Stop a running instance so its DLLs aren't locked during the overwrite.
    Get-Process -Name watoto_mobile -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 500
    if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
    New-Item -ItemType Directory -Force $dest | Out-Null
    Copy-Item "$rel\*" $dest -Recurse -Force
    $exe = Join-Path $dest 'watoto_mobile.exe'
    $ws = New-Object -ComObject WScript.Shell
    foreach ($lnk in @((Join-Path ([Environment]::GetFolderPath('Desktop')) 'Watoto.lnk'),
                       "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Watoto.lnk")) {
      $s = $ws.CreateShortcut($lnk)
      $s.TargetPath = $exe; $s.WorkingDirectory = $dest; $s.IconLocation = "$exe,0"
      $s.Description = 'Watoto - learning for children 0-10'; $s.Save()
    }
    $artifacts['windows'] = $dest
    Write-Host "Installed. Double-click 'Watoto' on the Desktop to launch."
  }
} finally {
  Pop-Location
}

# --- 5. Summary -------------------------------------------------------------
Write-Host ('=' * 70)
Write-Host "BUILD SUMMARY ($Mode)"
foreach ($k in $results.Keys) {
  $line = "  {0,-10} {1}" -f $k, $results[$k]
  if ($artifacts[$k]) { $line += "  ->  $($artifacts[$k])" }
  Write-Host $line
}
Write-Host "  ios        SKIPPED (needs macOS - build on a Mac or in CI)"
Write-Host ('=' * 70)

# Non-zero exit if any requested build failed.
$failed = @($results.Values | Where-Object { $_ -ne 'OK' })
if ($failed.Count -gt 0) {
  exit 1
}
exit 0
