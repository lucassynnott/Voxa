#!/bin/bash
# Build Voxa as a macOS app bundle
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/.build"
APP_NAME="Voxa"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

# Parse arguments
BUILD_CONFIG="debug"
if [ "${1:-}" = "--release" ] || [ "${1:-}" = "-r" ]; then
    BUILD_CONFIG="release"
fi

echo "Building Voxa ($BUILD_CONFIG)..."

# Build with Swift
cd "$ROOT_DIR"
swift build -c "$BUILD_CONFIG"

# Create app bundle structure
echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy executable
cp "${BUILD_DIR}/${BUILD_CONFIG}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"

# Copy Info.plist
cp "${ROOT_DIR}/Resources/Info.plist" "${APP_BUNDLE}/Contents/"

# Copy app icon
if [ -f "${ROOT_DIR}/Resources/AppIcon.icns" ]; then
    cp "${ROOT_DIR}/Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/"
    echo "Copied app icon"
fi

# Copy menubar icon
if [ -f "${ROOT_DIR}/Resources/menubar.png" ]; then
    cp "${ROOT_DIR}/Resources/menubar.png" "${APP_BUNDLE}/Contents/Resources/"
    cp "${ROOT_DIR}/Resources/menubar@2x.png" "${APP_BUNDLE}/Contents/Resources/" 2>/dev/null || true
    echo "Copied menubar icon"
fi

# Create Frameworks directory and copy required frameworks
mkdir -p "${APP_BUNDLE}/Contents/Frameworks"

# Copy llama.framework from various possible locations
LLAMA_LOCATIONS=(
    "${BUILD_DIR}/arm64-apple-macosx/${BUILD_CONFIG}/llama.framework"
    "${BUILD_DIR}/${BUILD_CONFIG}/llama.framework"
    "${BUILD_DIR}/artifacts/llama.swift/llama-cpp/llama.xcframework/macos-arm64_x86_64/llama.framework"
)

for LLAMA_FRAMEWORK in "${LLAMA_LOCATIONS[@]}"; do
    if [ -d "$LLAMA_FRAMEWORK" ]; then
        echo "Bundling llama.framework from: $LLAMA_FRAMEWORK"
        cp -R "$LLAMA_FRAMEWORK" "${APP_BUNDLE}/Contents/Frameworks/"
        break
    fi
done

# Copy any dylibs from build directory
for dylib in "${BUILD_DIR}/${BUILD_CONFIG}"/*.dylib; do
    if [ -f "$dylib" ]; then
        echo "Bundling $(basename "$dylib")..."
        cp "$dylib" "${APP_BUNDLE}/Contents/Frameworks/"
    fi
done

# Fix rpath for the executable to find frameworks
install_name_tool -add_rpath "@executable_path/../Frameworks" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" 2>/dev/null || true

# Set executable permissions
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Ad-hoc code sign the app
echo "Code signing app bundle..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "App bundle created at: ${APP_BUNDLE}"
echo ""
echo "To run: open ${APP_BUNDLE}"
echo "Or: ${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
