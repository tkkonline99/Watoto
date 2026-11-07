#!/usr/bin/env bash
# Watoto — CI iOS code-signing, ExportOptions.plist injection, IPA build, and TestFlight upload.
#
# Required environment variables:
#   IOS_DIST_CERT_BASE64            Base64-encoded Apple Distribution .p12 certificate
#   IOS_DIST_CERT_PASSWORD          Password for the .p12 certificate
#   IOS_PROVISIONING_PROFILE_BASE64 Base64-encoded App Store .mobileprovision profile
#   IOS_TEAM_ID                     10-character Apple Developer Team ID (optional if embedded in profile)
#   IOS_PROVISIONING_PROFILE_NAME   Provisioning profile name (optional if embedded in profile)
#   APP_STORE_CONNECT_KEY_ID        App Store Connect API Key ID
#   APP_STORE_CONNECT_ISSUER_ID     App Store Connect API Issuer UUID
#   APP_STORE_CONNECT_KEY_P8        App Store Connect API private key (.p8 contents)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORK_DIR="${RUNNER_TEMP:-$(mktemp -d)}"
KEYCHAIN="$WORK_DIR/watoto-signing.keychain-db"
KEYCHAIN_PASSWORD="$(openssl rand -base64 24)"

cleanup() {
  security delete-keychain "$KEYCHAIN" >/dev/null 2>&1 || true
  rm -f "$WORK_DIR/cert.p12" "$WORK_DIR/profile.mobileprovision"
}
trap cleanup EXIT

echo "==> Decoding iOS distribution certificate and provisioning profile"
echo "$IOS_DIST_CERT_BASE64" | base64 --decode > "$WORK_DIR/cert.p12"
echo "$IOS_PROVISIONING_PROFILE_BASE64" | base64 --decode > "$WORK_DIR/profile.mobileprovision"

echo "==> Creating temporary signing keychain"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security import "$WORK_DIR/cert.p12" -P "$IOS_DIST_CERT_PASSWORD" \
  -A -t cert -f pkcs12 -k "$KEYCHAIN"
security set-key-partition-list -S apple-tool:,apple: -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
# shellcheck disable=SC2046
security list-keychains -d user -s "$KEYCHAIN" $(security list-keychains -d user | tr -d '"')

echo "==> Installing provisioning profile and extracting Team ID / Profile Name"
PROFILE_PLIST="$(security cms -D -i "$WORK_DIR/profile.mobileprovision")"
PROFILE_UUID="$(/usr/libexec/PlistBuddy -c 'Print :UUID' /dev/stdin <<< "$PROFILE_PLIST")"
DETECTED_TEAM_ID="$(/usr/libexec/PlistBuddy -c 'Print :TeamIdentifier:0' /dev/stdin <<< "$PROFILE_PLIST")"
DETECTED_PROFILE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :Name' /dev/stdin <<< "$PROFILE_PLIST")"

TEAM_ID="${IOS_TEAM_ID:-$DETECTED_TEAM_ID}"
PROFILE_NAME="${IOS_PROVISIONING_PROFILE_NAME:-$DETECTED_PROFILE_NAME}"

mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
cp "$WORK_DIR/profile.mobileprovision" \
  "$HOME/Library/MobileDevice/Provisioning Profiles/$PROFILE_UUID.mobileprovision"

echo "==> Populating ios/ExportOptions.plist (teamID=$TEAM_ID, profile=$PROFILE_NAME)"
/usr/libexec/PlistBuddy -c "Set :teamID $TEAM_ID" "$SCRIPT_DIR/ExportOptions.plist"
/usr/libexec/PlistBuddy -c "Set :provisioningProfiles:app.watoto.watotoMobile $PROFILE_NAME" "$SCRIPT_DIR/ExportOptions.plist"

cd "$MOBILE_DIR"
BUILD_NUM="${GITHUB_RUN_NUMBER:-1}"
echo "==> Building signed release IPA (build-number=$BUILD_NUM)"
flutter build ipa --release --build-number="$BUILD_NUM" --export-options-plist=ios/ExportOptions.plist

if [[ -n "${APP_STORE_CONNECT_KEY_ID:-}" && -n "${APP_STORE_CONNECT_ISSUER_ID:-}" ]]; then
  if [[ -n "${APP_STORE_CONNECT_KEY_P8:-}" ]]; then
    mkdir -p "$HOME/.appstoreconnect/private_keys"
    printf '%s' "$APP_STORE_CONNECT_KEY_P8" > "$HOME/.appstoreconnect/private_keys/AuthKey_${APP_STORE_CONNECT_KEY_ID}.p8"
  fi
  echo "==> Uploading IPA to TestFlight"
  xcrun altool --upload-app -f build/ios/ipa/*.ipa --type ios \
    --apiKey "$APP_STORE_CONNECT_KEY_ID" \
    --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID"
fi
