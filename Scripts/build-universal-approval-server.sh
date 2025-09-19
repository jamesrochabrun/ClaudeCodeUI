#!/bin/bash

# Build script for creating a universal binary of ApprovalMCPServer
# This creates a fat binary that works on both Intel and Apple Silicon Macs
# for distribution via Swift Package Manager

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Building Universal Binary for ApprovalMCPServer${NC}"

# Get the project directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APPROVAL_SERVER_DIR="${PROJECT_DIR}/modules/ApprovalMCPServer"
RESOURCES_DIR="${PROJECT_DIR}/Sources/ClaudeCodeCore/Resources"

# Check if the approval server directory exists
if [ ! -d "${APPROVAL_SERVER_DIR}" ]; then
    echo -e "${RED}Error: ApprovalMCPServer directory not found at ${APPROVAL_SERVER_DIR}${NC}"
    exit 1
fi

# Create Resources directory if it doesn't exist
echo -e "${YELLOW}Creating Resources directory...${NC}"
mkdir -p "${RESOURCES_DIR}"

# Clean previous builds
echo -e "${YELLOW}Cleaning previous builds...${NC}"
cd "${APPROVAL_SERVER_DIR}"
swift package clean

# Build for x86_64 (Intel)
echo -e "${YELLOW}Building for x86_64 (Intel)...${NC}"
swift build -c release --arch x86_64
X86_BINARY="${APPROVAL_SERVER_DIR}/.build/x86_64-apple-macosx/release/ApprovalMCPServer"

if [ ! -f "${X86_BINARY}" ]; then
    echo -e "${RED}Error: x86_64 build failed${NC}"
    exit 1
fi

# Build for arm64 (Apple Silicon)
echo -e "${YELLOW}Building for arm64 (Apple Silicon)...${NC}"
swift build -c release --arch arm64
ARM_BINARY="${APPROVAL_SERVER_DIR}/.build/arm64-apple-macosx/release/ApprovalMCPServer"

if [ ! -f "${ARM_BINARY}" ]; then
    echo -e "${RED}Error: arm64 build failed${NC}"
    exit 1
fi

# Create universal binary using lipo
UNIVERSAL_BINARY="${RESOURCES_DIR}/ApprovalMCPServer"
echo -e "${YELLOW}Creating universal binary...${NC}"
lipo -create "${X86_BINARY}" "${ARM_BINARY}" -output "${UNIVERSAL_BINARY}"

# Strip debug symbols to reduce size
echo -e "${YELLOW}Stripping debug symbols...${NC}"
strip "${UNIVERSAL_BINARY}"

# Sign with ad-hoc signature for Gatekeeper
echo -e "${YELLOW}Signing with ad-hoc signature...${NC}"
codesign --force --sign - "${UNIVERSAL_BINARY}"

# Verify the universal binary
echo -e "${YELLOW}Verifying universal binary...${NC}"
lipo -info "${UNIVERSAL_BINARY}"

# Check file size
SIZE=$(du -h "${UNIVERSAL_BINARY}" | cut -f1)
echo -e "${GREEN}Universal binary created successfully!${NC}"
echo -e "Location: ${UNIVERSAL_BINARY}"
echo -e "Size: ${SIZE}"

# Verify both architectures are present
if lipo -info "${UNIVERSAL_BINARY}" | grep -q "x86_64 arm64"; then
    echo -e "${GREEN}✓ Both architectures (x86_64 and arm64) verified${NC}"
else
    echo -e "${RED}Warning: Universal binary may not contain both architectures${NC}"
    lipo -info "${UNIVERSAL_BINARY}"
fi

echo -e "${GREEN}Build complete! The universal binary is ready for distribution.${NC}"
echo -e "${YELLOW}Note: Remember to commit the updated binary when making changes to ApprovalMCPServer${NC}"