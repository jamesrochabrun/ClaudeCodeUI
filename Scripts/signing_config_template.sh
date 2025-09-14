#!/bin/bash

# Code Signing Configuration Template
# Copy this to signing_config.sh and fill in your values
# DO NOT commit signing_config.sh to your repository!

# Your Apple Developer Team ID (found in Apple Developer account)
# This is okay to share publicly
export TEAM_ID="CQ45U4X9K3"

# Your Apple ID email
export APPLE_ID="YOUR_APPLE_ID@example.com"

# Bundle identifier for your app
export BUNDLE_ID="com.jamesrochabrun.ClaudeCodeUI"

# Certificate name (usually "Developer ID Application: Your Name (TEAMID)")
export SIGNING_IDENTITY="Developer ID Application"

# App-specific password for notarization
# Create this at https://appleid.apple.com/account/manage
# Under Security > App-Specific Passwords
export APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"

# Keychain profile name for storing notarization credentials
export KEYCHAIN_PROFILE="ClaudeCodeUI-notary"

# Function to check if credentials are configured
check_credentials() {
  local missing=0

  if [ "$APPLE_ID" = "YOUR_APPLE_ID@example.com" ]; then
    echo "❌ APPLE_ID not configured"
    missing=1
  fi

  if [ "$APP_PASSWORD" = "xxxx-xxxx-xxxx-xxxx" ]; then
    echo "❌ APP_PASSWORD not configured"
    missing=1
  fi

  if [ $missing -eq 1 ]; then
    echo ""
    echo "Please update the credentials in scripts/signing_config.sh"
    echo "You can find your Team ID in your Apple Developer account"
    echo "Create an app-specific password at https://appleid.apple.com"
    return 1
  fi

  return 0
}

# Function to store credentials in keychain (optional, more secure)
store_notary_credentials() {
  xcrun notarytool store-credentials "$KEYCHAIN_PROFILE" \
    --apple-id "$APPLE_ID" \
    --password "$APP_PASSWORD" \
    --team-id "$TEAM_ID"
}