# ClaudeCodeUI Package Integration Guide

## Security Notice

ClaudeCodeUI now uses a **build-from-source** security model for the ApprovalMCPServer. This ensures that package consumers build their own approval server executable from auditable source code, eliminating the risk of tampered binaries.

## For Package Consumers

When using ClaudeCodeUI as a Swift Package dependency, you need to build and provide the ApprovalMCPServer executable yourself.

### Step 1: Add Dependencies

Add both ClaudeCodeUI and ApprovalMCPServer to your `Package.swift`:

```swift
dependencies: [
  .package(url: "https://github.com/jamesrochabrun/ClaudeCodeUI", from: "1.0.0"),
  .package(url: "https://github.com/jamesrochabrun/ClaudeCodeApprovalServer",
           .exact("1.0.0")) // Pin to v1.0.0 for security
]
```

### Step 2: Build ApprovalMCPServer

Add a build phase script to your Xcode project:

```bash
#!/bin/bash
# Build ApprovalMCPServer from source

APPROVAL_SERVER_PATH="$SRCROOT/.build/checkouts/ClaudeCodeApprovalServer"
if [ -d "$APPROVAL_SERVER_PATH" ]; then
  cd "$APPROVAL_SERVER_PATH"
  swift build -c release

  # Copy to your app's Resources
  EXECUTABLE="$APPROVAL_SERVER_PATH/.build/release/ApprovalMCPServer"
  if [ -f "$EXECUTABLE" ]; then
    cp "$EXECUTABLE" "$BUILT_PRODUCTS_DIR/$CONTENTS_FOLDER_PATH/Resources/"
    echo "ApprovalMCPServer bundled successfully"
  fi
fi
```

### Step 3: Configure in Your App

#### Option A: Use Default Bundle Provider

If you bundle the server in Resources (recommended):

```swift
import ClaudeCodeCore
import CCCustomPermissionService

// The default provider looks in Bundle.main Resources
let approvalTool = MCPApprovalTool(
  permissionService: customPermissionService
)
```

#### Option B: Custom Path Provider

For custom build locations:

```swift
import ClaudeCodeCore
import CCCustomPermissionServiceInterface

// Custom provider with specific path
let customProvider = CustomApprovalServerProvider(
  path: "/path/to/your/ApprovalMCPServer"
)

let approvalTool = MCPApprovalTool(
  permissionService: customPermissionService,
  serverProvider: customProvider
)
```

### Step 4: Verify Security

Before shipping:

1. **Audit the source**: Review ApprovalMCPServer source code
2. **Pin versions**: Use exact version matching in Package.swift
3. **Sign executable**: Consider code signing the built server
4. **Verify checksums**: Compare SHA256 of built executable

```bash
# Verify executable integrity
shasum -a 256 /path/to/ApprovalMCPServer
```

## For DMG Distribution

No changes needed! The existing build process:

1. Clones ApprovalMCPServer from GitHub
2. Builds from source
3. Bundles in app Resources
4. Works exactly as before

## Security Best Practices

### For Enterprise Deployments

1. **Fork the ApprovalMCPServer repository**
   - Maintain your own audited version
   - Add custom approval rules if needed

2. **Use private package registry**
   - Host packages internally
   - Control update cycles

3. **Implement build verification**
   ```bash
   # In your CI/CD pipeline
   EXPECTED_SHA="your_verified_sha256_here"
   ACTUAL_SHA=$(shasum -a 256 ApprovalMCPServer | cut -d' ' -f1)
   if [ "$EXPECTED_SHA" != "$ACTUAL_SHA" ]; then
     echo "ERROR: ApprovalMCPServer checksum mismatch!"
     exit 1
   fi
   ```

4. **Monitor for updates**
   - Subscribe to security advisories
   - Review all ApprovalMCPServer updates before adopting

## Troubleshooting

### ApprovalMCPServer not found

If you see "ApprovalMCPServer not found in bundle":

1. Verify build phase script runs
2. Check executable copied to Resources
3. Ensure file has execute permissions: `chmod +x ApprovalMCPServer`

### Custom path not working

For CustomApprovalServerProvider:

1. Verify path is absolute
2. Check file exists and is executable
3. Test with: `file /path/to/ApprovalMCPServer`

## Migration from Embedded Server

If upgrading from a version with embedded server:

1. Remove any cached/built ApprovalMCPServer binaries
2. Add ApprovalMCPServer package dependency
3. Update build scripts as shown above
4. Test approval prompts thoroughly

## Support

- Issues: https://github.com/jamesrochabrun/ClaudeCodeUI/issues
- Security: Report privately to security@example.com