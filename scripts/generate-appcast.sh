#!/bin/bash
# Generate Sparkle appcast + signed update archive for Voxa
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/.build"
APP_BUNDLE="${BUILD_DIR}/Voxa.app"
UPDATES_DIR="${BUILD_DIR}/updates"
REMOTE_URL="$(git -C "${ROOT_DIR}" remote get-url origin 2>/dev/null || true)"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: App bundle not found at $APP_BUNDLE"
    echo "Run ./scripts/build-app.sh --release first"
    exit 1
fi

APP_PLIST="${APP_BUNDLE}/Contents/Info.plist"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PLIST" 2>/dev/null || echo "0.0.0")
BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP_PLIST" 2>/dev/null || echo "0")
ARCHIVE_NAME="Voxa-${VERSION}-${BUILD_NUMBER}.zip"
ARCHIVE_PATH="${UPDATES_DIR}/${ARCHIVE_NAME}"

mkdir -p "$UPDATES_DIR"

echo "Creating Sparkle update archive: $ARCHIVE_NAME"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ARCHIVE_PATH"

# Locate Sparkle's generate_appcast tool from SwiftPM artifacts/checkouts.
GENERATE_APPCAST=""
CANDIDATES=(
    "${BUILD_DIR}/artifacts/sparkle/Sparkle/bin/generate_appcast"
    "${BUILD_DIR}/checkouts/Sparkle/bin/generate_appcast"
    "${BUILD_DIR}/checkouts/sparkle/bin/generate_appcast"
)

for candidate in "${CANDIDATES[@]}"; do
    if [ -x "$candidate" ]; then
        GENERATE_APPCAST="$candidate"
        break
    fi
done

if [ -z "$GENERATE_APPCAST" ]; then
    GENERATE_APPCAST=$(find "$BUILD_DIR" -type f -path "*/Sparkle/bin/generate_appcast" -perm -u+x | head -n 1 || true)
fi

if [ -z "$GENERATE_APPCAST" ]; then
    echo "Error: Could not locate Sparkle's generate_appcast tool"
    echo "Expected it under .build/artifacts or .build/checkouts after building Sparkle"
    exit 1
fi

echo "Using generate_appcast: $GENERATE_APPCAST"

# Compute a GitHub Pages download prefix from the origin remote.
DOWNLOAD_URL_PREFIX=""
if [[ "$REMOTE_URL" =~ github\.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]}"
    DOWNLOAD_URL_PREFIX="https://${OWNER}.github.io/${REPO}/updates/"
fi

APPCAST_ARGS=()
if [ -n "$DOWNLOAD_URL_PREFIX" ]; then
    APPCAST_ARGS+=(--download-url-prefix "$DOWNLOAD_URL_PREFIX")
fi

# Signing options:
# 1) SPARKLE_PRIVATE_KEY env var (CI secret; base64 private key)
# 2) SPARKLE_PRIVATE_KEY_FILE path
# 3) fallback to keychain account "ed25519"
if [ -n "${SPARKLE_PRIVATE_KEY:-}" ]; then
    echo "Using Sparkle private key from SPARKLE_PRIVATE_KEY secret"
    # shellcheck disable=SC2086
    printf '%s' "$SPARKLE_PRIVATE_KEY" | "$GENERATE_APPCAST" "${APPCAST_ARGS[@]}" --ed-key-file - "$UPDATES_DIR"
elif [ -n "${SPARKLE_PRIVATE_KEY_FILE:-}" ]; then
    if [ ! -f "$SPARKLE_PRIVATE_KEY_FILE" ]; then
        echo "Error: SPARKLE_PRIVATE_KEY_FILE does not exist: $SPARKLE_PRIVATE_KEY_FILE"
        exit 1
    fi
    echo "Using Sparkle private key file: $SPARKLE_PRIVATE_KEY_FILE"
    "$GENERATE_APPCAST" "${APPCAST_ARGS[@]}" --ed-key-file "$SPARKLE_PRIVATE_KEY_FILE" "$UPDATES_DIR"
else
    echo "Using Sparkle private key from keychain account 'ed25519'"
    "$GENERATE_APPCAST" "${APPCAST_ARGS[@]}" --account ed25519 "$UPDATES_DIR"
fi

echo ""
echo "✅ Appcast generated successfully"
echo "Update directory: $UPDATES_DIR"
echo "Appcast file: $UPDATES_DIR/appcast.xml"
if [ -n "$DOWNLOAD_URL_PREFIX" ]; then
    echo "Download URL prefix: $DOWNLOAD_URL_PREFIX"
fi
echo ""
echo "Next step: publish all files from $UPDATES_DIR to your update host"
