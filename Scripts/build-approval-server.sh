#!/bin/bash

# Build script for ApprovalMCPServer
# This script is run as a build phase in Xcode to ensure the approval server is built

set -e

# Get the project directory
PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
APPROVAL_SERVER_DIR="${PROJECT_DIR}/modules/ApprovalMCPServer"

echo "Checking ApprovalMCPServer..."

# Check if the approval server directory exists
if [ ! -d "${APPROVAL_SERVER_DIR}" ]; then
    echo "Error: ApprovalMCPServer directory not found at ${APPROVAL_SERVER_DIR}"
    exit 1
fi

# Determine architecture
ARCH=$(uname -m)
BUILT_EXECUTABLE="${APPROVAL_SERVER_DIR}/.build/${ARCH}-apple-macosx/debug/ApprovalMCPServer"

# Check if already built
if [ -f "${BUILT_EXECUTABLE}" ]; then
    echo "ApprovalMCPServer already built at: ${BUILT_EXECUTABLE}"
else
    # Build the approval server
    echo "Building ApprovalMCPServer..."
    cd "${APPROVAL_SERVER_DIR}"
    swift build -c debug
    
    # Verify build succeeded
    if [ ! -f "${BUILT_EXECUTABLE}" ]; then
        # Try generic path
        BUILT_EXECUTABLE="${APPROVAL_SERVER_DIR}/.build/debug/ApprovalMCPServer"
        if [ ! -f "${BUILT_EXECUTABLE}" ]; then
            echo "Error: Build failed - executable not found"
            exit 1
        fi
    fi
    
    echo "ApprovalMCPServer built successfully"
fi

# For release builds, copy to app bundle
if [ "${CONFIGURATION}" = "Release" ] && [ -n "${BUILT_PRODUCTS_DIR}" ]; then
    APP_BUNDLE="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app"
    if [ -d "${APP_BUNDLE}" ]; then
        RESOURCES_DIR="${APP_BUNDLE}/Contents/Resources"
        mkdir -p "${RESOURCES_DIR}"
        cp "${BUILT_EXECUTABLE}" "${RESOURCES_DIR}/"
        echo "Copied ApprovalMCPServer to app bundle"
    fi
fi