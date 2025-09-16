#!/bin/bash

# Create DMG for ClaudeCodeUI
# This script creates a distributable DMG file with the app

set -e

# Load signing configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ -f "$SCRIPT_DIR/signing_config.sh" ]; then
  source "$SCRIPT_DIR/signing_config.sh"
fi

# Configuration
APP_NAME="ClaudeCodeUI"
APP_PATH="build/export/$APP_NAME.app"
DMG_NAME="$APP_NAME"
DMG_DIR="build/dmg"
DMG_TEMP="$DMG_DIR/temp"
DMG_FINAL="$DMG_DIR/$DMG_NAME.dmg"
VOLUME_NAME="$APP_NAME"
BACKGROUND_IMG="scripts/dmg_background.png"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Creating DMG for $APP_NAME...${NC}"

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
  echo -e "${RED}Error: App not found at $APP_PATH${NC}"
  echo -e "${YELLOW}Please run ./scripts/build_app.sh first${NC}"
  exit 1
fi

# Clean and create directories
echo -e "${YELLOW}Preparing directories...${NC}"
rm -rf "$DMG_DIR"
mkdir -p "$DMG_TEMP"

# Copy app to temp directory
echo -e "${YELLOW}Copying app...${NC}"
cp -R "$APP_PATH" "$DMG_TEMP/"

# Create Applications symlink
echo -e "${YELLOW}Creating Applications symlink...${NC}"
ln -s /Applications "$DMG_TEMP/Applications"

# Create temporary DMG
echo -e "${YELLOW}Creating temporary DMG...${NC}"
hdiutil create -volname "$VOLUME_NAME" \
  -srcfolder "$DMG_TEMP" \
  -ov \
  -format UDRW \
  -size 200m \
  "$DMG_DIR/temp.dmg"

# Mount temporary DMG
echo -e "${YELLOW}Mounting temporary DMG...${NC}"
device=$(hdiutil attach -readwrite -noverify "$DMG_DIR/temp.dmg" | egrep '^/dev/' | sed 1q | awk '{print $1}')

# Optional: Set custom icon positions and window properties
echo -e "${YELLOW}Setting DMG properties...${NC}"
echo '
  tell application "Finder"
    tell disk "'${VOLUME_NAME}'"
      open
      set current view of container window to icon view
      set toolbar visible of container window to false
      set statusbar visible of container window to false
      set the bounds of container window to {400, 100, 900, 450}
      set viewOptions to the icon view options of container window
      set arrangement of viewOptions to not arranged
      set icon size of viewOptions to 100
      set position of item "'${APP_NAME}'.app" of container window to {125, 180}
      set position of item "Applications" of container window to {375, 180}
      close
      open
      update without registering applications
      delay 2
    end tell
  end tell
' | osascript

# Set window background (if image exists)
if [ -f "$BACKGROUND_IMG" ]; then
  echo -e "${YELLOW}Setting background image...${NC}"
  # This would require additional AppleScript to set background
fi

# Unmount temporary DMG
echo -e "${YELLOW}Unmounting temporary DMG...${NC}"
hdiutil detach "$device"

# Convert to compressed DMG
echo -e "${YELLOW}Creating final DMG...${NC}"
hdiutil convert "$DMG_DIR/temp.dmg" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG_FINAL"

# Clean up temp DMG
rm -f "$DMG_DIR/temp.dmg"
rm -rf "$DMG_TEMP"

# Sign the DMG
echo -e "${YELLOW}Signing DMG...${NC}"
if [ -n "$TEAM_ID" ]; then
  codesign --force --sign "Developer ID Application: James Rochabrun (${TEAM_ID})" \
    --timestamp \
    "$DMG_FINAL"

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ DMG signed successfully${NC}"
  else
    echo -e "${RED}Warning: DMG signing failed${NC}"
  fi
else
  echo -e "${YELLOW}Skipping DMG signing (no TEAM_ID configured)${NC}"
fi

# Display DMG info
echo -e "${GREEN}✅ DMG created successfully${NC}"
echo -e "${GREEN}Location: $DMG_FINAL${NC}"
echo -e "${YELLOW}Size: $(du -h "$DMG_FINAL" | cut -f1)${NC}"

# Verify DMG
echo -e "\n${YELLOW}Verifying DMG...${NC}"
hdiutil verify "$DMG_FINAL"

# Check signing
if [ -n "$TEAM_ID" ]; then
  echo -e "\n${YELLOW}Checking DMG signature...${NC}"
  codesign -dv "$DMG_FINAL" 2>&1 || true
fi

echo -e "${GREEN}DMG is ready for distribution!${NC}"