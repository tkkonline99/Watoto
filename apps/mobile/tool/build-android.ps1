<#
.SYNOPSIS
  Build the Watoto Android app on this Windows machine.

.DESCRIPTION
  Wrapper around `flutter build` that works around this machine's endpoint-
  security configuration. Two machine-specific problems are handled here:

  1. Gradle's NIO selector opens an internal AF_UNIX "self-pipe" socket file in
     %TEMP%. The security layer on this box (the same one that enforces
     Controlled Folder Access) blocks socket files under
     C:\Users\<user>\AppData\Local\Temp, so the socket connect fails with
     "Invalid argument: connect" and Gradle dies with
     "Unable to establish loopback connection". Redirecting TMP/TEMP to a
     clean path (C:\dev\tmp) fixes it. Java reads the AF_UNIX temp location
     from these env vars, NOT from -Djava.io.tmpdir.

  2. The Android SDK / JDK live outside OneDrive (Controlled Folder Access
     blocks tooling inside the synced folder), so JAVA_HOME is pinned here.

  Other developers / CI on machines without this security policy do not need
  this script and can call `flutter build apk` directly.

.PARAMETER Target
  apk (default) or appbundle (the .aab Google Play wants).

.PARAMETER Mode
  debug (default), profile, or release.

.EXAMPLE
  pwsh tool/build-android.ps1                      # debug apk
  pwsh tool/build-android.ps1 -Target appbundle -Mode release
#>
param(
  [ValidateSet('apk', 'appbundle')] [string]$Target = 'apk',
  [ValidateSet('debug', 'profile', 'release')] [string]$Mode = 'debug'
)

$ErrorActionPreference = 'Stop'

# Overridable via pre-set env vars; defaults match this machine's setup.
$cleanTmp = if ($env:WATOTO_TMP) { $env:WATOTO_TMP } else { 'C:\dev\tmp' }
$jdkHome  = if ($env:JAVA_HOME)  { $env:JAVA_HOME }  else { 'C:\dev\jdk-21' }
$flutter  = if ($env:FLUTTER_BIN) { $env:FLUTTER_BIN } else { 'C:\dev\flutter\bin\flutter.bat' }

New-Item -ItemType Directory -Force $cleanTmp | Out-Null
$env:TMP = $cleanTmp
$env:TEMP = $cleanTmp
$env:JAVA_HOME = $jdkHome

Write-Host "TMP/TEMP -> $cleanTmp   JAVA_HOME -> $jdkHome"
Write-Host "flutter build $Target --$Mode"
& $flutter build $Target "--$Mode"
exit $LASTEXITCODE
