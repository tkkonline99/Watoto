#!/usr/bin/env bash
# Generates an Android Play App Signing upload keystore (upload.jks),
# writes local apps/mobile/android/key.properties (gitignored), and optionally
# uploads the signing secrets directly to GitHub Actions via `gh secret set`.
#
# Usage:
#   ./apps/mobile/tool/generate_upload_keystore.sh [--set-gh-secrets]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDROID_DIR="$(cd "$SCRIPT_DIR/../android" && pwd)"
KEYSTORE_FILE="$ANDROID_DIR/upload.jks"
KEY_PROPS_FILE="$ANDROID_DIR/key.properties"
KEY_ALIAS="${ANDROID_KEY_ALIAS:-upload}"

if [[ -f "$KEYSTORE_FILE" ]]; then
  echo "Keystore already exists at: $KEYSTORE_FILE"
  echo "Refusing to overwrite. Move or back up the existing file first."
  exit 1
fi

if [[ -z "${ANDROID_KEYSTORE_PASSWORD:-}" ]]; then
  read -r -s -p "Enter new keystore password (min 6 chars): " ANDROID_KEYSTORE_PASSWORD
  echo ""
fi

if [[ ${#ANDROID_KEYSTORE_PASSWORD} -lt 6 ]]; then
  echo "Error: password must be at least 6 characters."
  exit 1
fi

ANDROID_KEY_PASSWORD="${ANDROID_KEY_PASSWORD:-$ANDROID_KEYSTORE_PASSWORD}"
DNAME="${ANDROID_KEY_DNAME:-CN=Watoto Learning, OU=Mobile, O=Watoto Learning, L=Nairobi, S=Nairobi, C=KE}"

echo "Generating 2048-bit RSA upload keystore at $KEYSTORE_FILE ..."
keytool -genkeypair -v \
  -keystore "$KEYSTORE_FILE" \
  -storetype JKS \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias "$KEY_ALIAS" \
  -storepass "$ANDROID_KEYSTORE_PASSWORD" \
  -keypass "$ANDROID_KEY_PASSWORD" \
  -dname "$DNAME"

cat > "$KEY_PROPS_FILE" <<EOF
storePassword=$ANDROID_KEYSTORE_PASSWORD
keyPassword=$ANDROID_KEY_PASSWORD
keyAlias=$KEY_ALIAS
storeFile=../upload.jks
EOF
chmod 600 "$KEYSTORE_FILE" "$KEY_PROPS_FILE"

echo ""
echo "Created:"
echo "  Keystore:       $KEYSTORE_FILE (gitignored — BACK THIS UP SECURELY!)"
echo "  key.properties: $KEY_PROPS_FILE (gitignored)"

if [[ "${1:-}" == "--set-gh-secrets" ]]; then
  echo ""
  echo "Uploading ANDROID_* secrets to GitHub Actions via gh CLI..."
  base64 < "$KEYSTORE_FILE" | tr -d '\n' | gh secret set ANDROID_KEYSTORE_BASE64
  printf '%s' "$ANDROID_KEYSTORE_PASSWORD" | gh secret set ANDROID_KEYSTORE_PASSWORD
  printf '%s' "$KEY_ALIAS" | gh secret set ANDROID_KEY_ALIAS
  printf '%s' "$ANDROID_KEY_PASSWORD" | gh secret set ANDROID_KEY_PASSWORD
  echo "GitHub Actions secrets ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD configured."
else
  echo ""
  echo "To push these secrets to GitHub Actions automatically, re-run with --set-gh-secrets or run:"
  echo "  base64 < \"$KEYSTORE_FILE\" | tr -d '\\n' | gh secret set ANDROID_KEYSTORE_BASE64"
  echo "  gh secret set ANDROID_KEYSTORE_PASSWORD"
  echo "  gh secret set ANDROID_KEY_ALIAS --body \"$KEY_ALIAS\""
  echo "  gh secret set ANDROID_KEY_PASSWORD"
fi
