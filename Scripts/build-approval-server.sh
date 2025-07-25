#!/bin/bash

# Build script for ApprovalMCPServer
# This script is run as a build phase in Xcode to ensure the approval server is built

set -e

# Get the project directory
PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
APPROVAL_SERVER_DIR="${PROJECT_DIR}/modules/ApprovalMCPServer"
BUILT_PRODUCTS_DIR="${BUILT_PRODUCTS_DIR:-${PROJECT_DIR}/build}"

echo "Building ApprovalMCPServer..."
echo "Project directory: ${PROJECT_DIR}"
echo "Approval server directory: ${APPROVAL_SERVER_DIR}"

# Check if the approval server directory exists
if [ ! -d "${APPROVAL_SERVER_DIR}" ]; then
    echo "Error: ApprovalMCPServer directory not found at ${APPROVAL_SERVER_DIR}"
    exit 1
fi

# Build the approval server
cd "${APPROVAL_SERVER_DIR}"
swift build -c debug

# Find the built executable
ARCH=$(uname -m)
BUILT_EXECUTABLE="${APPROVAL_SERVER_DIR}/.build/${ARCH}-apple-macosx/debug/ApprovalMCPServer"

if [ ! -f "${BUILT_EXECUTABLE}" ]; then
    # Try generic path
    BUILT_EXECUTABLE="${APPROVAL_SERVER_DIR}/.build/debug/ApprovalMCPServer"
fi

if [ ! -f "${BUILT_EXECUTABLE}" ]; then
    echo "Error: Built executable not found"
    exit 1
fi

echo "ApprovalMCPServer built successfully at: ${BUILT_EXECUTABLE}"

# Copy to app bundle if building for release
if [ "${CONFIGURATION}" = "Release" ] && [ -n "${BUILT_PRODUCTS_DIR}" ]; then
    APP_BUNDLE="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app"
    if [ -d "${APP_BUNDLE}" ]; then
        RESOURCES_DIR="${APP_BUNDLE}/Contents/Resources"
        mkdir -p "${RESOURCES_DIR}"
        cp "${BUILT_EXECUTABLE}" "${RESOURCES_DIR}/"
        echo "Copied ApprovalMCPServer to app bundle"
    fi
fi