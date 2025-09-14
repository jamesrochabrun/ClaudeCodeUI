#!/bin/bash

# Build and Archive ClaudeCodeUI App
# This script builds the app and exports it with Developer ID signing

set -e

# Configuration
APP_NAME="ClaudeCodeUI"
SCHEME_NAME="$APP_NAME"
PROJECT_PATH="ClaudeCodeUI.xcodeproj"
BUILD_DIR="build"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
EXPORT_OPTIONS_PLIST="scripts/export_options.plist"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Building $APP_NAME...${NC}"

# Clean build directory
echo -e "${YELLOW}Cleaning build directory...${NC}"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build and archive
echo -e "${YELLOW}Building and archiving...${NC}"
xcodebuild -project "$PROJECT_PATH" \
  -scheme "$SCHEME_NAME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  clean archive

# Check if archive was created
if [ ! -d "$ARCHIVE_PATH" ]; then
  echo -e "${RED}Error: Archive was not created${NC}"
  exit 1
fi

echo -e "${GREEN}Archive created successfully${NC}"

# Export the archive
echo -e "${YELLOW}Exporting archive...${NC}"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

# Check if app was exported
if [ ! -d "$EXPORT_PATH/$APP_NAME.app" ]; then
  echo -e "${RED}Error: App was not exported${NC}"
  exit 1
fi

echo -e "${GREEN}✅ App built and exported successfully${NC}"
echo -e "${GREEN}Location: $EXPORT_PATH/$APP_NAME.app${NC}"

# Display app info
echo -e "\n${YELLOW}App Information:${NC}"
defaults read "$EXPORT_PATH/$APP_NAME.app/Contents/Info.plist" CFBundleShortVersionString
defaults read "$EXPORT_PATH/$APP_NAME.app/Contents/Info.plist" CFBundleVersion
codesign -dv "$EXPORT_PATH/$APP_NAME.app" 2>&1 | grep "Authority"