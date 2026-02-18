#!/bin/bash
# Complete packaging workflow for Voxa
# This script builds, signs, and creates a distributable DMG
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "╔════════════════════════════════════════╗"
echo "║   Voxa Release Packaging Workflow     ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Step 1: Build the app
echo "Step 1/5: Building Voxa..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
"${SCRIPT_DIR}/build-app.sh" --release

echo ""
echo "✓ Build complete"
echo ""

# Step 2: Create DMG
echo "Step 2/5: Creating DMG installer..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
"${SCRIPT_DIR}/create-dmg.sh"

echo ""
echo "✓ DMG created"
echo ""

# Step 3: Generate appcast + update archive
echo "Step 3/5: Generating Sparkle appcast..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if "${SCRIPT_DIR}/generate-appcast.sh"; then
    echo ""
    echo "✓ Sparkle appcast generated"
else
    echo ""
    echo "⚠️  Sparkle appcast generation failed (continuing with DMG packaging)"
    echo "   Configure Sparkle keys/feed and rerun ./scripts/generate-appcast.sh"
fi
echo ""

# Step 4: Publish update feed to GitHub Pages
echo "Step 4/5: Publishing updates to GitHub Pages..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if "${SCRIPT_DIR}/publish-updates-github-pages.sh"; then
    echo ""
    echo "✓ Published updates to GitHub Pages"
else
    echo ""
    echo "⚠️  GitHub Pages publish failed (continuing)"
    echo "   Rerun ./scripts/publish-updates-github-pages.sh after fixing auth/repo settings"
fi
echo ""

# Step 5: Optional notarization
echo "Step 5/5: Notarization (optional)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "To notarize the app for distribution:"
echo "  1. Set environment variables:"
echo "     export APPLE_ID='your-apple-id@email.com'"
echo "     export APPLE_TEAM_ID='9785XZK34L'"
echo ""
echo "  2. Store app-specific password:"
echo "     xcrun notarytool store-credentials 'notarytool-password' \\"
echo "       --apple-id 'your-apple-id@email.com' \\"
echo "       --team-id '9785XZK34L' \\"
echo "       --password 'your-app-specific-password'"
echo ""
echo "  3. Run notarization:"
echo "     ${SCRIPT_DIR}/notarize-app.sh"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🎉 Packaging complete!"
echo ""
echo "Your distributable DMG is ready at:"
echo "  $(cd "${SCRIPT_DIR}/.." && pwd)/.build/Voxa-Installer.dmg"
echo ""
echo "Your Sparkle update artifacts are ready at:"
echo "  $(cd "${SCRIPT_DIR}/.." && pwd)/.build/updates"
echo ""
