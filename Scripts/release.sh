#!/bin/bash

# Automated Release Script for ClaudeCodeUI
# This script handles the complete release process with security checks

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}📦 ClaudeCodeUI Release Script${NC}"
echo "================================"
echo ""

# Function to check if we're on a clean git state
check_git_status() {
  if [ ! -z "$(git status --porcelain)" ]; then
    echo -e "${YELLOW}⚠️  You have uncommitted changes${NC}"
    echo "Please commit or stash your changes before releasing."
    git status --short
    exit 1
  fi
}

# Function to run security check
run_security_check() {
  echo -e "${BLUE}🔒 Running security check...${NC}"
  if [ -f "Scripts/security_check.sh" ]; then
    bash Scripts/security_check.sh || {
      echo -e "${RED}Security check failed! Aborting release.${NC}"
      exit 1
    }
  fi
  echo ""
}

# Function to verify credentials
verify_credentials() {
  echo -e "${BLUE}🔑 Verifying credentials...${NC}"

  if [ ! -f "Scripts/signing_config.sh" ]; then
    echo -e "${RED}❌ Error: Scripts/signing_config.sh not found${NC}"
    echo "Please copy Scripts/signing_config_template.sh to Scripts/signing_config.sh"
    echo "and configure your credentials."
    exit 1
  fi

  source Scripts/signing_config.sh

  if ! check_credentials 2>/dev/null; then
    echo -e "${RED}❌ Credentials not properly configured${NC}"
    exit 1
  fi

  # Check for Developer ID certificate
  if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    echo -e "${RED}❌ Developer ID Application certificate not found${NC}"
    echo "Please install your Developer ID certificate"
    exit 1
  fi

  echo -e "${GREEN}✅ Credentials verified${NC}"
  echo ""
}

# Function to get version input
get_version() {
  # Read current version from Info.plist
  CURRENT_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" ClaudeCodeUI/Info.plist 2>/dev/null || echo "1.0.0")

  echo "Current version: ${CURRENT_VERSION}"
  echo ""
  echo "Enter new version number (e.g., 1.0.1) or press Enter to keep current:"
  read -r NEW_VERSION

  if [ -z "$NEW_VERSION" ]; then
    NEW_VERSION=$CURRENT_VERSION
  fi

  # Validate version format
  if ! echo "$NEW_VERSION" | grep -E "^[0-9]+\.[0-9]+\.[0-9]+$" >/dev/null; then
    echo -e "${RED}Invalid version format. Please use X.Y.Z format${NC}"
    exit 1
  fi

  echo "Using version: $NEW_VERSION"
  echo ""
}

# Function to update version
update_version() {
  echo -e "${BLUE}📝 Updating version to $NEW_VERSION...${NC}"

  # Update version in Info.plist
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $NEW_VERSION" ClaudeCodeUI/Info.plist

  # Update build number (using timestamp)
  BUILD_NUMBER=$(date +%Y%m%d%H%M)
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" ClaudeCodeUI/Info.plist

  echo -e "${GREEN}✅ Version updated${NC}"
  echo ""
}

# Function to build the app
build_app() {
  echo -e "${BLUE}🔨 Building app...${NC}"
  ./Scripts/build_app.sh || {
    echo -e "${RED}Build failed!${NC}"
    exit 1
  }
  echo ""
}

# Function to create DMG
create_dmg() {
  echo -e "${BLUE}💿 Creating DMG...${NC}"
  ./Scripts/create_dmg.sh || {
    echo -e "${RED}DMG creation failed!${NC}"
    exit 1
  }
  echo ""
}

# Function to notarize
notarize_dmg() {
  echo -e "${BLUE}🍎 Notarizing with Apple...${NC}"
  echo -e "${YELLOW}This may take 5-10 minutes...${NC}"
  ./Scripts/notarize.sh || {
    echo -e "${RED}Notarization failed!${NC}"
    exit 1
  }
  echo ""
}

# Function to create git tag
create_git_tag() {
  echo -e "${BLUE}🏷️  Creating git tag...${NC}"

  TAG="v$NEW_VERSION"

  # Check if tag already exists
  if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo -e "${YELLOW}Tag $TAG already exists. Skipping.${NC}"
  else
    git tag -a "$TAG" -m "Release $NEW_VERSION"
    echo -e "${GREEN}✅ Created tag: $TAG${NC}"

    echo ""
    echo "To push this release to GitHub:"
    echo -e "${YELLOW}  git push origin $TAG${NC}"
  fi
  echo ""
}

# Main release flow
main() {
  echo "This script will:"
  echo "1. Run security checks"
  echo "2. Verify credentials"
  echo "3. Build the app"
  echo "4. Create DMG"
  echo "5. Notarize with Apple"
  echo "6. Create git tag"
  echo ""
  echo "Press Enter to continue or Ctrl+C to cancel..."
  read

  # Run all steps
  check_git_status
  run_security_check
  verify_credentials
  get_version
  update_version
  build_app
  create_dmg
  notarize_dmg
  create_git_tag

  # Success message
  echo ""
  echo "================================"
  echo -e "${GREEN}🎉 Release $NEW_VERSION completed successfully!${NC}"
  echo ""
  echo "📦 DMG location: build/dmg/ClaudeCodeUI.dmg"
  echo ""
  echo "Next steps:"
  echo "1. Test the DMG locally"
  echo "2. Push the tag to trigger GitHub release: git push origin v$NEW_VERSION"
  echo "3. Or manually upload the DMG to GitHub releases"
  echo ""
  echo -e "${YELLOW}Remember: Never commit Scripts/signing_config.sh!${NC}"
}

# Run main function
main