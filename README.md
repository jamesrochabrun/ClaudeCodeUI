# ClaudeCodeUI

A native macOS application and Swift Package providing a graphical user interface for Claude Code SDK, enabling seamless AI-powered coding assistance with a beautiful, intuitive interface.

https://github.com/user-attachments/assets/12a3a1ff-1ba5-41b2-b6af-897e53b18331

## 🎉 Now Available as a Swift Package!

ClaudeCodeUI has been completely restructured to work as both a standalone macOS application AND a reusable Swift Package. This means you can:
- **Use the macOS app directly** - Download and run the full application
- **Integrate into your own apps** - Import `ClaudeCodeCore` and use all the functionality in your projects
- **Customize and extend** - Build on top of the comprehensive component library

## Overview

ClaudeCodeUI is a SwiftUI-based macOS application that wraps the Claude Code SDK, providing users with a desktop experience for interacting with Claude's coding capabilities. The app features markdown rendering, syntax highlighting, file management, terminal integration, and a complete MCP (Model Context Protocol) approval system - all within a native macOS interface.

### What's Included in ClaudeCodeCore

The `ClaudeCodeCore` package includes everything:
- ✅ Complete chat interface with streaming support
- ✅ Session management and persistence
- ✅ Code syntax highlighting and markdown rendering
- ✅ File diff visualization
- ✅ Terminal integration
- ✅ Xcode project detection and integration
- ✅ MCP approval system for secure tool usage
- ✅ Custom permissions handling
- ✅ All UI components and view models
- ✅ Complete dependency injection system

## Installation

### Option 1: Use as a macOS Application

#### For End Users (Simplest)
1. Download the latest release from the [Releases page](https://github.com/jamesrochabrun/ClaudeCodeUI/releases)
2. Move ClaudeCodeUI.app to your Applications folder
3. Launch the app

#### For Developers (Build from Source)
1. Clone the repository:
   ```bash
   git clone https://github.com/jamesrochabrun/ClaudeCodeUI.git
   cd ClaudeCodeUI
   ```

2. Open in Xcode:
   ```bash
   open ClaudeCodeUI.xcodeproj
   ```

3. Build and run (⌘R)

### Option 2: Use as a Swift Package

Add ClaudeCodeUI to your project as a Swift Package dependency:

#### In Xcode:
1. File → Add Package Dependencies
2. Enter: `https://github.com/jamesrochabrun/ClaudeCodeUI.git`
3. Choose the `ClaudeCodeCore` library product
4. Click "Add Package"

#### In Package.swift:
```swift
dependencies: [
    .package(url: "https://github.com/jamesrochabrun/ClaudeCodeUI.git", branch: "main")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "ClaudeCodeCore", package: "ClaudeCodeUI")
        ]
    )
]
```

## Usage Examples

### Quick Start - Use the Entire App

The simplest integration - get the full ClaudeCodeUI experience in just 3 lines:

```swift
import SwiftUI
import ClaudeCodeCore

@main
struct MyApp: App {
    var body: some Scene {
        // That's it! You get the complete app
        ClaudeCodeUIApp().body
    }
}
```

### Custom Integration - Mix Your UI with ClaudeCode

Want to integrate ClaudeCode into your existing app? Use individual components:

```swift
import SwiftUI
import ClaudeCodeCore

struct MyCustomApp: App {
    @State private var globalPreferences = GlobalPreferencesStorage()
    
    var body: some Scene {
        WindowGroup {
            NavigationSplitView {
                // Your custom sidebar
                MySidebarView()
            } detail: {
                // ClaudeCode chat interface
                RootView()
                    .environment(globalPreferences)
            }
        }
    }
}
```

### Advanced - Use Individual Components

For maximum control, use the components directly:

```swift
import ClaudeCodeCore

struct MyCustomChatView: View {
    @StateObject private var dependencyContainer: DependencyContainer
    @StateObject private var chatViewModel: ChatViewModel
    
    init() {
        let globalPrefs = GlobalPreferencesStorage()
        let container = DependencyContainer(globalPreferences: globalPrefs)
        
        _dependencyContainer = StateObject(wrappedValue: container)
        _chatViewModel = StateObject(wrappedValue: ChatViewModel(
            claudeClient: container.claudeClient,
            sessionManager: container.sessionManager,
            // ... other dependencies
        ))
    }
    
    var body: some View {
        ChatScreen(
            viewModel: chatViewModel,
            contextManager: dependencyContainer.contextManager,
            xcodeObservationViewModel: dependencyContainer.xcodeObservationViewModel,
            permissionsService: dependencyContainer.permissionsService,
            terminalService: dependencyContainer.terminalService,
            customPermissionService: dependencyContainer.customPermissionService,
            columnVisibility: .constant(.all)
        )
    }
}
```

### Configuration Options

Customize the behavior with your own settings:

```swift
import ClaudeCodeCore

// Use custom storage implementations
let customStorage = MyCustomSessionStorage()
let customSettings = MyCustomSettingsStorage()

// Configure the dependency container
let container = DependencyContainer(
    globalPreferences: globalPreferences,
    sessionStorage: customStorage,
    settingsStorage: customSettings
)
```

## Project Structure

### Package Structure
```
ClaudeCodeUI/
├── Package.swift                    # Swift Package manifest
├── Sources/
│   ├── ClaudeCodeCore/             # Main library (all reusable components)
│   │   ├── App/                    # App structure and entry points
│   │   ├── ViewModels/             # Business logic and state management
│   │   ├── Views/UI/               # All SwiftUI views and components
│   │   ├── Services/               # Core services (permissions, terminal, etc.)
│   │   ├── Storage/                # Session and settings persistence
│   │   ├── Models/                 # Data models
│   │   ├── DependencyInjection/    # DI container
│   │   ├── Diff/                   # File diff visualization
│   │   ├── FileSearch/             # File search functionality
│   │   ├── ToolFormatting/         # Tool output formatting
│   │   └── Extensions/             # Utility extensions
│   └── ClaudeCodeUI/               # Minimal executable wrapper
│       └── main.swift              # App entry point
├── modules/                        # Local Swift packages
│   ├── AccessibilityService/       # macOS accessibility APIs
│   ├── ApprovalMCPServer/          # MCP approval server
│   ├── CustomPermissionService/    # Permission handling
│   ├── TerminalService/            # Terminal integration
│   └── XcodeObserverService/       # Xcode integration
└── ClaudeCodeUI.xcodeproj          # Xcode project (for app distribution)
```

## How It Works

ClaudeCodeUI communicates with the Claude Code SDK through the `ClaudeCodeClient` class. The app:

1. **Initializes the SDK**: Creates a `ClaudeCodeConfiguration` with the current working directory and debug settings
2. **Manages Sessions**: Uses `SessionStorage` to persist chat histories and session metadata
3. **Handles Permissions**: Implements a custom permission service to manage file system access
4. **Processes Responses**: Renders Claude's responses with markdown formatting and code syntax highlighting
5. **Executes Actions**: Handles file operations, terminal commands, and other SDK capabilities through a unified interface

## Migration Guide

### For Existing Users

If you've been using ClaudeCodeUI before the package restructure:

1. **No changes needed for app users** - The macOS app works exactly the same
2. **For developers**: The source code is now in `Sources/ClaudeCodeCore/` instead of `ClaudeCodeUI/`
3. **Package imports**: Use `import ClaudeCodeCore` instead of importing individual files

### For Package Consumers

When adding ClaudeCodeUI as a dependency:
- The main library product is `ClaudeCodeCore`
- All components are public and can be used individually
- The package includes all necessary dependencies (you don't need to add them separately)

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

## MCP Approval Tool

### Overview

The MCP (Model Context Protocol) approval tool provides a secure permission system for Claude Code operations. When Claude needs to perform actions like file operations or execute commands, the approval tool presents a native macOS dialog for user consent.

### Setup Instructions by Use Case

#### For Package Users (Using ClaudeCodeCore in Your App)

When using ClaudeCodeCore as a package dependency, you need to build and include the MCP approval server in your app:

1. **Add the MCP server module to your project**:
   - The server source is included in the package at `modules/ApprovalMCPServer`
   - You'll need to build it as part of your app's build process

2. **Option A: Add Build Phase to Your App**:
   ```bash
   # Add this script to your app's build phases
   cd "$BUILD_DIR/../../SourcePackages/checkouts/ClaudeCodeUI/modules/ApprovalMCPServer"
   swift build -c release
   cp .build/release/ApprovalMCPServer "$BUILT_PRODUCTS_DIR/$PRODUCT_NAME.app/Contents/Resources/"
   ```

3. **Option B: Build Manually and Include**:
   ```bash
   # Build the server manually
   cd path/to/ClaudeCodeUI/modules/ApprovalMCPServer
   swift build -c release
   # Copy the binary to your app's Resources folder
   ```

4. **Option C: Use without MCP** (Simplest):
   - The app will work without the MCP server, but you won't get approval dialogs
   - Claude will use default permissions based on your settings

#### For Building ClaudeCodeUI from Source

When building the ClaudeCodeUI app itself from source:

1. Open `ClaudeCodeUI.xcodeproj`
2. Select the `ClaudeCodeUI` target
3. Go to "Build Phases" tab
4. Click "+" → "New Run Script Phase"
5. **Important**: Drag the new phase to run **before** "Compile Sources"
6. Paste this script: `"${PROJECT_DIR}/Scripts/build-approval-server.sh"`
7. Rename to "Build MCP Approval Server" (optional)
8. Build and run!

### How It Works

1. **Automatic Detection**: ClaudeCodeCore looks for the server in multiple locations
2. **Smart Path Detection**: Checks app bundle, build directories, and package paths
3. **Permission Dialogs**: Native macOS UI for approving/denying Claude's requests
4. **Session-Based**: Permissions are managed per chat session for security

## Development

### Prerequisites

- macOS 15.2 or later (due to package dependencies)
- Xcode 15.0 or later
- Swift 5.9 or later
- Claude Code SDK

### Building from Source

1. Clone the repository:
```bash
git clone https://github.com/jamesrochabrun/ClaudeCodeUI.git
cd ClaudeCodeUI
```

2. **Using Xcode Project** (for app development):
```bash
open ClaudeCodeUI.xcodeproj
# Build and run with ⌘R
```

3. **Using Swift Package Manager** (for package development):
```bash
swift build
swift run ClaudeCodeUI
```

### Testing the Package

```bash
# Run tests for the core library
swift test

# Or in Xcode
# Product → Test (⌘U)
```

## Contributing

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
- Work with both the Xcode project and Swift Package

## Troubleshooting

### Common Issues

**"MCP tool not found" error on first run**
- You need to add the build phase! See [First-Time Setup](#first-time-setup-required-only-for-building-from-source)
- This is only needed when building from source

**Package resolution issues**
- Clean the package cache: `swift package clean`
- Reset package resolved: `swift package reset`
- In Xcode: File → Packages → Reset Package Caches

**App doesn't launch**
- Ensure you're running macOS 15.2 or later
- Check that all Swift Package dependencies are resolved

**Claude Code SDK not responding**
- Verify your API credentials are properly configured
- Check the debug logs in Console.app for detailed error messages
- Ensure you have an active internet connection

## TODOs

- [ ] Fix diffing UI - improve visual diff presentation and user interaction
- [ ] Improve MCP approval flow - enhance the permission dialog UX
- [ ] Add iOS/iPadOS support (the package structure now makes this possible!)
- [ ] Create example apps demonstrating different integration patterns

## Acknowledgments

Special thanks to [cmd](https://github.com/getcmd-dev/cmd) - The code for diff visualization and markdown rendering has been adapted from this excellent project. Their implementation provided a solid foundation for these features in ClaudeCodeUI.

## License

MIT License