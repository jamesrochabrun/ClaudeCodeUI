# ClaudeCodeUI

A native macOS application providing a graphical user interface for Claude Code SDK, enabling seamless AI-powered coding assistance with a beautiful, intuitive interface.

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

The MCP approval tool provides a secure way for Claude Code to request permissions for various operations. It's automatically built and configured when you run the app.

### How It Works

1. **Automatic Building**: The ApprovalMCPServer is automatically built when you first run the app
2. **Dynamic Path Resolution**: The app finds the server executable using smart path detection
3. **Permission Requests**: When Claude needs permissions, a native macOS dialog appears
4. **Session Persistence**: Approved permissions are stored per chat session

### Technical Details

The approval tool is instantiated in `DependencyContainer.swift`:

```swift
// Create the custom permission service
let customPermissionService = CustomPermissionService()

// Pass it to ChatViewModel initialization
let vm = ChatViewModel(
    claudeClient: claudeClient,
    customPermissionService: container.customPermissionService
)
```

The MCP server configuration happens in `RootView.swift`:

```swift
// Configure MCP approval server
let approvalTool = MCPApprovalTool(permissionService: container.customPermissionService)
approvalTool.configure(options: &options)
config.claudeOptions = options
```

### Developer Notes

- No manual setup required - the approval server builds automatically
- The server executable is located at: `modules/ApprovalMCPServer/.build/*/debug/ApprovalMCPServer`
- For release builds, the server is copied into the app bundle
- If you encounter issues, try running `swift build` in the `modules/ApprovalMCPServer` directory

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

3. Build and run the project (⌘+R)

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
