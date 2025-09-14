# ClaudeCodeUI Release Process

This document describes how to build and distribute ClaudeCodeUI as a DMG for macOS.

## Prerequisites

1. **Apple Developer Account**: Required for code signing and notarization
2. **Developer ID Certificate**: Install from Apple Developer portal
3. **Xcode**: Latest stable version
4. **macOS**: Version 14.0 or later

## Setup

### 1. Configure Code Signing

Edit `scripts/signing_config.sh` and update with your credentials:

```bash
export TEAM_ID="YOUR_TEAM_ID"           # Found in Apple Developer account
export APPLE_ID="your@email.com"        # Your Apple ID
export BUNDLE_ID="com.yourcompany.ClaudeCodeUI"  # Your bundle ID
export APP_PASSWORD="xxxx-xxxx-xxxx"    # App-specific password from appleid.apple.com
```

### 2. Update App Info

Edit `ClaudeCodeUI/Info.plist`:
- Update `CFBundleShortVersionString` with your version (e.g., "1.0.0")
- Update `NSHumanReadableCopyright` with your copyright

### 3. Configure Export Options

Edit `scripts/export_options.plist`:
- Replace `YOUR_TEAM_ID` with your actual Team ID

## Manual Release Process

### Build the App

```bash
# Make script executable
chmod +x scripts/build_app.sh

# Build and archive the app
./scripts/build_app.sh
```

This creates the signed app in `build/export/ClaudeCodeUI.app`

### Create DMG

```bash
# Make script executable
chmod +x scripts/create_dmg.sh

# Create the DMG
./scripts/create_dmg.sh
```

This creates `build/dmg/ClaudeCodeUI.dmg`

### Notarize the DMG

```bash
# Make script executable
chmod +x scripts/notarize.sh

# Source credentials
source scripts/signing_config.sh

# Notarize
./scripts/notarize.sh
```

This submits the DMG to Apple for notarization and staples the ticket.

## Automated Release (GitHub Actions)

### Setup GitHub Secrets

In your GitHub repository settings, add these secrets:

1. **CERTIFICATE_BASE64**: Your Developer ID certificate as base64
   ```bash
   base64 -i certificate.p12 | pbcopy
   ```

2. **CERTIFICATE_PASSWORD**: Password for the certificate

3. **KEYCHAIN_PASSWORD**: A password for the temporary keychain

4. **TEAM_ID**: Your Apple Developer Team ID

5. **APPLE_ID**: Your Apple ID email

6. **APP_PASSWORD**: App-specific password from appleid.apple.com

### Trigger a Release

#### Option 1: Push a Tag
```bash
git tag v1.0.0
git push origin v1.0.0
```

#### Option 2: Manual Workflow
Go to Actions tab in GitHub and manually trigger the "Release" workflow.

## Distribution

Once the DMG is created and notarized, users can:

1. Download the DMG file
2. Open it
3. Drag ClaudeCodeUI to their Applications folder
4. Launch the app

The app will be verified by Gatekeeper on first launch.

## Troubleshooting

### Code Signing Issues

Check if your certificate is valid:
```bash
security find-identity -v -p codesigning
```

### Notarization Issues

Check notarization history:
```bash
xcrun notarytool history --apple-id YOUR_APPLE_ID --password YOUR_APP_PASSWORD --team-id YOUR_TEAM_ID
```

Get details for a specific submission:
```bash
xcrun notarytool log SUBMISSION_ID --apple-id YOUR_APPLE_ID --password YOUR_APP_PASSWORD --team-id YOUR_TEAM_ID
```

### DMG Won't Open

If the DMG is reported as damaged:
1. Check if it's properly notarized
2. Verify with: `spctl -a -t open --context context:primary-signature -v YourApp.dmg`

## Version Management

- Update version in `ClaudeCodeUI/Info.plist`
- Tag releases with semantic versioning: `v1.0.0`
- Keep build numbers sequential or use timestamps

## Security Notes

- Never commit credentials to the repository
- Use GitHub Secrets for CI/CD
- Rotate app-specific passwords regularly
- Keep your Developer ID certificate secure