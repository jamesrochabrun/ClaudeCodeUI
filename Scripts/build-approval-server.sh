#!/bin/bash

# Build script for ApprovalMCPServer
# This script is run as a build phase in Xcode to ensure the approval server is built and bundled

set -e

# Get the project directory
PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
APPROVAL_SERVER_DIR="${PROJECT_DIR}/modules/ApprovalMCPServer"

echo "Building ApprovalMCPServer for bundling..."

# Check if the approval server directory exists
if [ ! -d "${APPROVAL_SERVER_DIR}" ]; then
    echo "Error: ApprovalMCPServer directory not found at ${APPROVAL_SERVER_DIR}"
    exit 1
fi

# Always build in release mode for bundling
cd "${APPROVAL_SERVER_DIR}"
echo "Building ApprovalMCPServer in release mode..."
swift build -c release

# Determine architecture and get built executable
ARCH=$(uname -m)
BUILT_EXECUTABLE="${APPROVAL_SERVER_DIR}/.build/${ARCH}-apple-macosx/release/ApprovalMCPServer"

# Verify build succeeded
if [ ! -f "${BUILT_EXECUTABLE}" ]; then
    # Try generic path
    BUILT_EXECUTABLE="${APPROVAL_SERVER_DIR}/.build/release/ApprovalMCPServer"
    if [ ! -f "${BUILT_EXECUTABLE}" ]; then
        echo "Error: Build failed - executable not found"
        exit 1
    fi
fi

echo "ApprovalMCPServer built successfully"

# Strip debug symbols to reduce size
echo "Stripping debug symbols to reduce size..."
strip "${BUILT_EXECUTABLE}"

# Always copy to app bundle (both Debug and Release configurations)
if [ -n "${BUILT_PRODUCTS_DIR}" ] && [ -n "${CONTENTS_FOLDER_PATH}" ]; then
    RESOURCES_DIR="${BUILT_PRODUCTS_DIR}/${CONTENTS_FOLDER_PATH}/Resources"
    mkdir -p "${RESOURCES_DIR}"
    cp "${BUILT_EXECUTABLE}" "${RESOURCES_DIR}/ApprovalMCPServer"
    echo "Bundled ApprovalMCPServer into app (size: $(du -h "${RESOURCES_DIR}/ApprovalMCPServer" | cut -f1))"
else
    echo "Warning: Bundle environment variables not set, cannot copy to app bundle"
fi