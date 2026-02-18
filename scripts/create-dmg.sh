#!/bin/bash
# Create a beautiful DMG installer for Voxa
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/.build"
export BUILD_DIR
APP_BUNDLE="${BUILD_DIR}/Voxa.app"
DMG_DIR="${BUILD_DIR}/dmg"
DMG_NAME="Voxa-Installer.dmg"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}"
VOLUME_NAME="Voxa"

# Check if app exists
if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: App bundle not found at $APP_BUNDLE"
    echo "Please run ./scripts/build-app.sh first"
    exit 1
fi

# Clean up previous DMG
echo "Cleaning up previous DMG..."
rm -rf "$DMG_DIR"
rm -f "$DMG_PATH"

# Create DMG directory structure
echo "Creating DMG directory structure..."
mkdir -p "$DMG_DIR"
cp -R "$APP_BUNDLE" "$DMG_DIR/"

# Create Applications symlink
ln -s /Applications "$DMG_DIR/Applications"

# Create custom background directory
mkdir -p "$DMG_DIR/.background"

# Generate custom background image using Python
echo "Generating custom DMG background..."
python3 - <<'PYTHON_SCRIPT'
from PIL import Image, ImageDraw, ImageFont
import os

# DMG window size (standard size)
width = 600
height = 400

# Voxa brand colors (from the app UI)
bg_color = (20, 20, 25)  # Dark background
accent_color = (220, 100, 80)  # Accent red/orange
text_color = (240, 240, 245)  # Light text

# Create image
img = Image.new('RGB', (width, height), bg_color)
draw = ImageDraw.Draw(img)

# Draw title
try:
    # Try to use system font
    title_font = ImageFont.truetype('/System/Library/Fonts/SFNS.ttf', 48)
    subtitle_font = ImageFont.truetype('/System/Library/Fonts/SFNS.ttf', 18)
except:
    # Fallback to default font
    title_font = ImageFont.load_default()
    subtitle_font = ImageFont.load_default()

# Draw "Voxa" title
title_text = "Voxa"
# Calculate text position for centering
title_bbox = draw.textbbox((0, 0), title_text, font=title_font)
title_width = title_bbox[2] - title_bbox[0]
title_x = (width - title_width) // 2
draw.text((title_x, 40), title_text, fill=text_color, font=title_font)

# Draw subtitle
subtitle_text = "Voice Transcription for Mac"
subtitle_bbox = draw.textbbox((0, 0), subtitle_text, font=subtitle_font)
subtitle_width = subtitle_bbox[2] - subtitle_bbox[0]
subtitle_x = (width - subtitle_width) // 2
draw.text((subtitle_x, 100), subtitle_text, fill=(180, 180, 190), font=subtitle_font)

# Draw arrow (from app icon position to Applications)
arrow_start_x = 180
arrow_end_x = 420
arrow_y = 270
arrow_color = accent_color

# Draw arrow line
draw.line([(arrow_start_x, arrow_y), (arrow_end_x, arrow_y)], fill=arrow_color, width=3)

# Draw arrowhead
arrow_head_size = 12
draw.polygon([
    (arrow_end_x, arrow_y),
    (arrow_end_x - arrow_head_size, arrow_y - arrow_head_size // 2),
    (arrow_end_x - arrow_head_size, arrow_y + arrow_head_size // 2)
], fill=arrow_color)

# Draw instruction text
instruction_text = "Drag Voxa to Applications to install"
instruction_bbox = draw.textbbox((0, 0), instruction_text, font=subtitle_font)
instruction_width = instruction_bbox[2] - instruction_bbox[0]
instruction_x = (width - instruction_width) // 2
draw.text((instruction_x, 340), instruction_text, fill=(160, 160, 170), font=subtitle_font)

# Save
build_dir = os.environ.get('BUILD_DIR', '.')
img.save(f'{build_dir}/dmg/.background/background.png')
print("Background image created successfully")
PYTHON_SCRIPT

# Check if Python script succeeded
if [ ! -f "$DMG_DIR/.background/background.png" ]; then
    echo "Warning: Could not create custom background, using default"
    rmdir "$DMG_DIR/.background" 2>/dev/null || true
fi

# Create temporary DMG
echo "Creating temporary DMG..."
TEMP_DMG="${BUILD_DIR}/temp.dmg"
hdiutil create -srcfolder "$DMG_DIR" -volname "$VOLUME_NAME" -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" -format UDRW -size 200m "$TEMP_DMG"

# Mount the DMG
echo "Mounting DMG to configure layout..."
MOUNT_DIR="/Volumes/$VOLUME_NAME"
hdiutil attach "$TEMP_DMG" -readwrite -noverify -noautoopen

# Wait for mount
sleep 2

# Configure the DMG window appearance using AppleScript
echo "Configuring DMG appearance..."
if [ -f "$DMG_DIR/.background/background.png" ]; then
    # With custom background
    osascript <<EOF
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 700, 500}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set background picture of viewOptions to file ".background:background.png"
        set position of item "Voxa.app" of container window to {120, 220}
        set position of item "Applications" of container window to {480, 220}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF
else
    # Without custom background (fallback)
    osascript <<EOF
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 700, 500}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set position of item "Voxa.app" of container window to {120, 220}
        set position of item "Applications" of container window to {480, 220}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF
fi

# Unmount
echo "Unmounting DMG..."
hdiutil detach "$MOUNT_DIR"

# Convert to compressed, read-only DMG
echo "Creating final compressed DMG..."
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH"

# Clean up
rm -f "$TEMP_DMG"
rm -rf "$DMG_DIR"

# Sign the DMG
echo "Signing DMG..."
codesign --force --sign "Developer ID Application: LUCAS GARRETT NOLAN SYNOTT (9785XZK34L)" "$DMG_PATH"

echo ""
echo "✅ DMG created successfully!"
echo "Location: $DMG_PATH"
echo ""
echo "You can now distribute this DMG to users"
echo ""
echo "Optional: Notarize the DMG with:"
echo "  xcrun notarytool submit $DMG_PATH \\"
echo "    --apple-id \$APPLE_ID \\"
echo "    --team-id \$APPLE_TEAM_ID \\"
echo "    --password '@keychain:notarytool-password' \\"
echo "    --wait"
