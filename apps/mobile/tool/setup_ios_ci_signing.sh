#!/usr/bin/env bash
# Configures a temporary macOS Keychain, imports the Apple Distribution
# certificate (.p12), installs the App Store Provisioning Profile, and stages
# the App Store Connect API private key (.p8) for `xcrun altool` / `xcrun notarytool`.
#
# Expected environment variables (from GitHub Actions secrets or CI environment):
#   IOS_DIST_CERT_BASE64                 - base64-encoded Apple Distribution .p12
#   IOS_DIST_CERT_PASSWORD               - password for the .p12 certificate
#   IOS_PROVISIONING_PROFILE_BASE64      - base64-encoded .mobileprovision profile
#   APP_STORE_CONNECT_KEY_ID             - (optional) ASC API Key ID
#   APP_STORE_CONNECT_PRIVATE_KEY_BASE64 - (optional) base64-encoded AuthKey_<ID>.p8
set -euo pipefail

WORK_DIR="${RUNNER_TEMP:-$(mktemp -d)}"
KEYCHAIN_PATH="$WORK_DIR/watoto-signing.keychain-db"
KEYCHAIN_PASSWORD="$(uuidgen)"

echo "$IOS_DIST_CERT_BASE64" | base64 --decode > "$WORK_DIR/cert.p12"
echo "$IOS_PROVISIONING_PROFILE_BASE64" | base64 --decode > "$WORK_DIR/profile.mobileprovision"

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security import "$WORK_DIR/cert.p12" \
  -P "$IOS_DIST_CERT_PASSWORD" \
  -A -t cert -f pkcs12 \
  -k "$KEYCHAIN_PATH"
security set-key-partition-list -S apple-tool:,apple: -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
# shellcheck disable=SC2046
security list-keychain -d user -s "$KEYCHAIN_PATH" $(security list-keychains -d user | tr -d '"')

PROFILE_UUID=$(/usr/libexec/PlistBuddy -c "Print UUID" /dev/stdin <<< "$(security cms -D -i "$WORK_DIR/profile.mobileprovision")")
mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
cp "$WORK_DIR/profile.mobileprovision" "$HOME/Library/MobileDevice/Provisioning Profiles/$PROFILE_UUID.mobileprovision"
echo "Installed provisioning profile UUID: $PROFILE_UUID"

if [[ -n "${APP_STORE_CONNECT_KEY_ID:-}" && -n "${APP_STORE_CONNECT_PRIVATE_KEY_BASE64:-}" ]]; then
  mkdir -p "$HOME/.appstoreconnect/private_keys"
  echo "$APP_STORE_CONNECT_PRIVATE_KEY_BASE64" | base64 --decode > "$HOME/.appstoreconnect/private_keys/AuthKey_${APP_STORE_CONNECT_KEY_ID}.p8"
  chmod 600 "$HOME/.appstoreconnect/private_keys/AuthKey_${APP_STORE_CONNECT_KEY_ID}.p8"
  echo "Staged App Store Connect API key AuthKey_${APP_STORE_CONNECT_KEY_ID}.p8"
fi
