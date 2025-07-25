# ClaudeCodeUI

A native macOS application providing a graphical user interface for Claude Code SDK, enabling seamless AI-powered coding assistance with a beautiful, intuitive interface.

https://github.com/user-attachments/assets/12a3a1ff-1ba5-41b2-b6af-897e53b18331

## Overview

ClaudeCodeUI is a SwiftUI-based macOS application that wraps the Claude Code SDK, providing users with a desktop experience for interacting with Claude's coding capabilities. The app features markdown rendering, syntax highlighting, file management, and terminal integration - all within a native macOS interface.

## How It Works

ClaudeCodeUI communicates with the Claude Code SDK through the `ClaudeCodeClient` class. The app:

1. **Initializes the SDK**: Creates a `ClaudeCodeConfiguration` with the current working directory and debug settings
2. **Manages Sessions**: Uses `SessionStorage` to persist chat histories and session metadata
3. **Handles Permissions**: Implements a custom permission service to manage file system access
4. **Processes Responses**: Renders Claude's responses with markdown formatting and code syntax highlighting
5. **Executes Actions**: Handles file operations, terminal commands, and other SDK capabilities through a unified interface

The main integration point is in `RootView.swift` where the Claude Code SDK is configured and initialized:

```swift
var config = ClaudeCodeConfiguration.default
config.workingDirectory = workingDirectory
config.enableDebugLogging = debugMode

let claudeClient = ClaudeCodeClient(configuration: config)
```

## Xcode Integration

ClaudeCodeUI can automatically detect your active Xcode project and selected code, making it seamless to work with your current development context.

### Enabling Xcode Integration

To enable Xcode integration, you need to grant Accessibility permissions:

1. **Open System Settings** > **Privacy & Security** > **Accessibility**
2. **Click the lock** to make changes (you'll need to authenticate)
3. **Click the + button** and add ClaudeCodeUI to the list
4. **Enable the toggle** next to ClaudeCodeUI

### What Xcode Integration Provides

Once enabled, ClaudeCodeUI can:
- **Detect Active Project**: Automatically sets the working directory to your currently open Xcode project
- **Read Selected Code**: Access code selections in Xcode to provide context-aware assistance
- **Monitor Active Files**: Track which files you're working on for better context
- **Sync Project Paths**: Automatically update the working directory when you switch between Xcode projects

### Troubleshooting Xcode Integration

If Xcode integration isn't working:
- Ensure ClaudeCodeUI has Accessibility permissions enabled
- Restart both ClaudeCodeUI and Xcode after granting permissions
- Check that you have an Xcode project open (not just individual files)
- Verify the integration status in the app's toolbar

## MCP Approval Tool

### Overview

The MCP (Model Context Protocol) approval tool provides a secure permission system for Claude Code operations. When Claude needs to perform actions like file operations or execute commands, the approval tool presents a native macOS dialog for user consent.

### How It Works

1. **Automatic Setup**: The approval server is built automatically via an Xcode build phase
2. **Smart Path Detection**: The app finds the server using multiple fallback strategies
3. **Permission Dialogs**: Native macOS UI for approving/denying Claude's requests
4. **Session-Based**: Permissions are managed per chat session for security

### First-Time Setup Required

When you first clone the repo, you need to add a build phase in Xcode:

1. Open `ClaudeCodeUI.xcodeproj`
2. Select the `ClaudeCodeUI` target
3. Go to "Build Phases" tab
4. Click "+" → "New Run Script Phase"
5. **Important**: Drag the new phase to run **before** "Compile Sources"
6. Paste this script: `"${PROJECT_DIR}/Scripts/build-approval-server.sh"`
7. Rename to "Build MCP Approval Server" (optional)
8. Build and run!

### Troubleshooting MCP Approval Server

#### Error: "MCP tool mcp__approval_server__approval_prompt not found"

**Cause**: The approval server hasn't been built yet.

**Solutions**:
1. Ensure you've added the build phase (see setup above)
2. Clean build folder (⇧⌘K) and rebuild
3. Manually build the server:
   ```bash
   cd modules/ApprovalMCPServer
   swift build -c debug
   ```

#### Error: "ApprovalMCPServer directory not found"

**Cause**: The app can't find the project directory.

**Solutions**:
1. Ensure you're running from Xcode (not a standalone app)
2. Check the project structure is intact
3. Verify the `modules/ApprovalMCPServer` directory exists

#### Build Phase Not Working

**Symptoms**: The build phase runs but server isn't built.

**Check**:
1. Open Report Navigator (⌘9) in Xcode
2. Look for "Build MCP Approval Server" in the build log
3. Check for error messages

**Common fixes**:
- Ensure Swift is in your PATH: `which swift`
- Check script permissions: `chmod +x Scripts/build-approval-server.sh`
- Run the script manually to see errors:
  ```bash
  cd /path/to/ClaudeCodeUI
  ./Scripts/build-approval-server.sh
  ```

#### Permission Dialogs Not Appearing

**Check**:
1. Ensure the approval server is running (check Console.app for logs)
2. Verify MCP is configured in Claude Code settings
3. Check that auto-approve isn't enabled in settings

### Technical Architecture

The MCP approval system consists of three components:

1. **ApprovalMCPServer**: A Swift executable that implements the MCP protocol
2. **CustomPermissionService**: Manages permission requests and UI
3. **ApprovalBridge**: Handles IPC between the server and the app

The flow:
1. Claude Code requests a tool use via MCP
2. ApprovalMCPServer receives the request
3. IPC notification sent to the main app
4. CustomPermissionService shows approval dialog
5. User response sent back through the chain

### Developer Notes

- Build output: `modules/ApprovalMCPServer/.build/{arch}-apple-macosx/debug/ApprovalMCPServer`
- The server is only built when needed (checks if executable exists)
- For release builds, the server is copied into `ClaudeCodeUI.app/Contents/Resources/`
- Logs available in Console.app under "MCPApprovalTool" category

## Development

### Prerequisites

- macOS 14.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later
- Claude Code installed

### Getting Started

1. Clone the repository:
```bash
git clone https://github.com/jamesrochabrun/ClaudeCodeUI.git
cd ClaudeCodeUI
```

2. Open the project in Xcode:
```bash
open ClaudeCodeUI.xcodeproj
```

3. **REQUIRED: Add MCP Approval Server Build Phase**
   
   This is a one-time setup that ensures the MCP approval server is built:
   
   - Select `ClaudeCodeUI` target in project navigator
   - Go to "Build Phases" tab
   - Click "+" button → "New Run Script Phase"
   - **IMPORTANT**: Drag the new phase above "Compile Sources"
   - In the script editor, paste:
     ```bash
     "${PROJECT_DIR}/Scripts/build-approval-server.sh"
     ```
   - Optionally rename it to "Build MCP Approval Server"

4. Build and run (⌘+R)

⚠️ **Note**: Without this build phase, you'll get "MCP tool not found" errors. See [MCP Troubleshooting](#troubleshooting-mcp-approval-server) if you encounter issues.

### Project Structure

```
ClaudeCodeUI/
├── ClaudeCodeUI/
│   ├── Views/
│   │   ├── ChatScreen.swift        # Main chat interface
│   │   ├── MessageView.swift       # Individual message rendering
│   │   └── DiffView.swift          # File diff visualization
│   ├── ViewModels/
│   │   ├── ChatViewModel.swift     # Main business logic
│   │   └── SessionManager.swift    # Session management
│   ├── Services/
│   │   ├── PermissionsService.swift    # File system permissions
│   │   ├── TerminalService.swift       # Terminal integration
│   │   └── ContextManager.swift        # Context file management
│   ├── Storage/
│   │   ├── SessionStorage.swift        # Session persistence
│   │   └── SettingsStorage.swift       # User preferences
│   └── RootView.swift              # Main app entry point
```

### Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please ensure your contributions:
- Follow Swift naming conventions
- Include appropriate documentation
- Add tests where applicable
- Update the README if adding new features

## Troubleshooting

### Common Issues

**"MCP tool not found" error on first run**
- You need to add the build phase! See step 3 in [Getting Started](#getting-started)
- This is a one-time setup required for all developers
- After adding, clean build (⇧⌘K) and run again

**App doesn't launch**
- Ensure you're running macOS 14.0 or later
- Check that all Swift Package dependencies are resolved in Xcode

**Claude Code SDK not responding**
- Verify your API credentials are properly configured
- Check the debug logs in Console.app for detailed error messages
- Ensure you have an active internet connection

**File permissions errors**
- Grant the app Full Disk Access in System Preferences > Privacy & Security
- Check that custom permissions are properly configured (see CUSTOM_PERMISSION_SETUP.md)

**Terminal commands not working**
- Ensure the app has appropriate shell access permissions
- Check that the working directory is correctly set
- Verify PATH includes necessary command locations

**Markdown rendering issues**
- Clear the app's cache by deleting derived data
- Rebuild the project to ensure all resources are properly included

### Debug Mode

To enable debug logging, the app automatically detects if it's running in a debug configuration. You can also manually enable debug logging by modifying the configuration in `RootView.swift`.

## TODOs

- [ ] Fix diffing UI - improve visual diff presentation and user interaction
- [ ] Improve MCP approval flow - enhance the permission dialog UX and add more context about what each MCP server does

## Acknowledgments

Special thanks to [cmd](https://github.com/getcmd-dev/cmd) - The code for diff visualization and markdown rendering has been adapted from this excellent project. Their implementation provided a solid foundation for these features in ClaudeCodeUI.

## License

MIT License
