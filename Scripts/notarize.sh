#!/bin/bash

# Notarize DMG with Apple
# This script submits the DMG to Apple for notarization

set -e

# Load configuration from signing_config.sh
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ -f "$SCRIPT_DIR/signing_config.sh" ]; then
  source "$SCRIPT_DIR/signing_config.sh"
else
  echo "Error: signing_config.sh not found!"
  echo "Please copy signing_config_template.sh to signing_config.sh and configure it"
  exit 1
fi

DMG_PATH="build/dmg/ClaudeCodeUI.dmg"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting notarization process...${NC}"

# Check if DMG exists
if [ ! -f "$DMG_PATH" ]; then
  echo -e "${RED}Error: DMG not found at $DMG_PATH${NC}"
  echo -e "${YELLOW}Please run ./scripts/create_dmg.sh first${NC}"
  exit 1
fi

# Check if credentials are set
if ! check_credentials; then
  exit 1
fi

# Submit for notarization
echo -e "${YELLOW}Submitting DMG for notarization...${NC}"
echo -e "${YELLOW}This may take several minutes...${NC}"

xcrun notarytool submit "$DMG_PATH" \
  --apple-id "$APPLE_ID" \
  --password "$APP_PASSWORD" \
  --team-id "$TEAM_ID" \
  --wait

# Check notarization status
if [ $? -eq 0 ]; then
  echo -e "${GREEN}✅ Notarization successful${NC}"

  # Staple the notarization ticket
  echo -e "${YELLOW}Stapling notarization ticket...${NC}"
  xcrun stapler staple "$DMG_PATH"

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Notarization ticket stapled successfully${NC}"
  else
    echo -e "${RED}Error: Failed to staple notarization ticket${NC}"
    exit 1
  fi

  # Verify the stapled DMG
  echo -e "${YELLOW}Verifying stapled DMG...${NC}"
  xcrun stapler validate "$DMG_PATH"

  echo -e "${GREEN}✅ DMG is notarized and ready for distribution!${NC}"
else
  echo -e "${RED}Error: Notarization failed${NC}"
  echo -e "${YELLOW}Check the notarization log for details${NC}"
  exit 1
fi