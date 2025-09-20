# ClaudeCodeUI

A beautiful, native macOS application and Swift Package providing a graphical interface for Claude Code conversations. Use it as a standalone app or integrate it directly into your own macOS applications.

⚠️ **Note**: This is not an official Anthropic product.

[**Download Latest Release (v1.4.6)**](https://github.com/jamesrochabrun/ClaudeCodeUI/releases/download/v1.4.6/ClaudeCodeUI.dmg) 

## Features

- 🎨 **Native macOS Design** - Beautiful SwiftUI interface that feels right at home on macOS
- 💬 **Full Chat Interface** - Complete conversation management with message history
- 📎 **File Attachments** - Support for images, PDFs, and other file types
- 🎯 **Code Selections** - Display and manage code snippets within conversations
- 🗂️ **Session Management** - Built-in session picker and persistence
- 🎨 **Theming** - Automatic dark/light mode support
- ⚡ **Real-time Streaming** - Live response streaming with token usage tracking
- 🛠️ **Tool Integration** - Full support for Claude's tool use capabilities
- 🔧 **MCP Support** - Model Context Protocol server integration

## Installation Options

### Option 1: Download the Standalone App (Easiest)

[**Download ClaudeCodeUI.dmg**](https://github.com/jamesrochabrun/ClaudeCodeUI/releases/download/v1.3.9/ClaudeCodeUI_v1.3.9.dmg)

1. Download the DMG file
2. Open it and drag ClaudeCodeUI to your Applications folder
3. Launch the app and start chatting with Claude

### Option 2: Use as a Swift Package (For Developers)

Integrate ClaudeCodeUI directly into your macOS app:

#### Swift Package Manager

Add ClaudeCodeUI to your project through Xcode:

1. File → Add Package Dependencies
2. Enter: `https://github.com/jamesrochabrun/ClaudeCodeUI`
3. Select "Up to Next Major Version" with `1.0.0`

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/jamesrochabrun/ClaudeCodeUI", from: "1.0.0")
]
```

#### Important: ApprovalMCPServer for Package Consumers

When using ClaudeCodeUI as a package dependency, you need to build and provide the ApprovalMCPServer separately for security reasons:

1. **Add the ApprovalMCPServer dependency**:
   ```swift
   dependencies: [
       .package(url: "https://github.com/jamesrochabrun/ClaudeCodeUI", from: "1.0.0"),
       .package(url: "https://github.com/jamesrochabrun/ClaudeCodeApprovalServer",
                .exact("1.0.0")) // Pin version for security
   ]
   ```

2. **Build the server in your build phase** (see [Package Integration Guide](PackageIntegrationGuide.md) for details)

This build-from-source approach ensures maximum security by allowing you to audit and compile the approval server yourself.

## Requirements

- macOS 14.0+
- [Claude CLI](https://github.com/anthropics/claude-cli) installed (`npm install -g @anthropic/claude-code`)

For development:
- Xcode 15.0+
- Swift 5.9+

## Quick Start (Swift Package)

The entire Claude interface in just a few lines:

```swift
import SwiftUI
import ClaudeCodeCore
import ClaudeCodeSDK

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ClaudeCodeContainer(
                claudeCodeConfiguration: ClaudeCodeConfiguration.default,
                uiConfiguration: UIConfiguration(
                    appName: "My Claude App",
                    showSettingsInNavBar: true
                )
            )
        }
    }
}
```

That's it! `ClaudeCodeContainer` handles everything else automatically.

## Configuration

### ClaudeCodeConfiguration

Configure how Claude Code operates:

```swift
var config = ClaudeCodeConfiguration.default

// Enable debug logging
config.enableDebugLogging = true

// Set working directory (defaults to user's home)
config.workingDirectory = "/path/to/project"

// Configure Claude command (if not using default)
config.command = "claude"

// Add custom PATH locations for finding the Claude CLI
config.additionalPaths = [
    "/usr/local/bin",
    "/opt/homebrew/bin",
    NSHomeDirectory() + "/.nvm/current/bin"
]

// Pass to container
ClaudeCodeContainer(
    claudeCodeConfiguration: config,
    uiConfiguration: uiConfig
)
```

### UIConfiguration

Customize the interface appearance and behavior:

```swift
let uiConfig = UIConfiguration(
    // App name shown in the interface
    appName: "My Assistant",

    // Show settings button in navigation bar
    showSettingsInNavBar: true,

    // Show risk/safety data in UI (optional)
    showRiskData: false,

    // Custom tooltip for working directory selector
    workingDirectoryToolTip: "Select your project folder",

    // Add custom system prompt
    initialAdditionalSystemPromptPrefix: """
    You are an expert Swift developer assistant.
    Focus on SwiftUI best practices and modern Swift conventions.
    """
)
```

### Handling User Messages

Track when users send messages for analytics or logging:

```swift
ClaudeCodeContainer(
    claudeCodeConfiguration: config,
    uiConfiguration: uiConfig,
    onUserMessageSent: { message, codeSelections, attachments in
        // Log the message
        print("User sent: \(message)")

        // Track code selections if any
        if let selections = codeSelections {
            print("With \(selections.count) code selections")
        }

        // Track attachments if any
        if let files = attachments {
            print("With \(files.count) attachments")
        }
    }
)
```

## MCP Configuration

ClaudeCodeUI automatically supports MCP (Model Context Protocol) servers. Users can configure MCP servers through the Settings interface.

The MCP configuration is stored at `~/.claude/mcp_settings.json`:

```json
{
  "servers": {
    "filesystem": {
      "command": "npx",
      "args": ["@anthropic/mcp-server-filesystem", "/Users/me/projects"]
    },
    "github": {
      "command": "npx",
      "args": ["@anthropic/mcp-server-github"],
      "env": {
        "GITHUB_TOKEN": "your-token"
      }
    }
  }
}
```

## Complete Example

Here's a fully configured implementation:

```swift
import SwiftUI
import ClaudeCodeCore
import ClaudeCodeSDK

@main
struct ClaudeCodeUIApp: App {
    var config: ClaudeCodeConfiguration {
        var config = ClaudeCodeConfiguration.default
        config.enableDebugLogging = true

        // Add common Node.js installation paths
        let homeDir = NSHomeDirectory()
        config.additionalPaths = [
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "\(homeDir)/.nvm/current/bin",
            "\(homeDir)/.nvm/versions/node/v22.16.0/bin"
        ]

        return config
    }

    var uiConfig: UIConfiguration {
        UIConfiguration(
            appName: "Claude Code Assistant",
            showSettingsInNavBar: true,
            showRiskData: false,
            workingDirectoryToolTip: "Select your project folder",
            initialAdditionalSystemPromptPrefix: """
            You are a helpful coding assistant with expertise in Swift and SwiftUI.
            Always provide clear explanations with your code suggestions.
            """
        )
    }

    var body: some Scene {
        WindowGroup {
            ClaudeCodeContainer(
                claudeCodeConfiguration: config,
                uiConfiguration: uiConfig,
                onUserMessageSent: { message, selections, attachments in
                    // Optional: Handle message events
                    logUserInteraction(message, selections, attachments)
                }
            )
        }
    }

    func logUserInteraction(_ message: String, _ selections: [TextSelection]?, _ attachments: [FileAttachment]?) {
        // Your analytics/logging code here
        print("User interaction logged: \(message)")
    }
}
```

## Keyboard Shortcuts

- `⌘N` - New conversation
- `⌘,` - Open settings
- `⌘K` - Clear conversation
- `⌘Enter` - Send message
- `Escape` - Cancel current operation

## App Permissions

Add these entitlements to your app's `.entitlements` file:

```xml
<!-- App Sandbox -->
<key>com.apple.security.app-sandbox</key>
<true/>

<!-- Network access for Claude API -->
<key>com.apple.security.network.client</key>
<true/>

<!-- File system access for attachments -->
<key>com.apple.security.files.user-selected.read-write</key>
<true/>

<!-- For working directory access -->
<key>com.apple.security.files.downloads.read-write</key>
<true/>
```

## Troubleshooting

### Claude CLI Not Found

If you see "Claude command not found":

1. **Install the Claude CLI**:
   ```bash
   npm install -g @anthropic/claude-code
   ```

2. **Verify installation**:
   ```bash
   which claude
   ```

3. **Add the path to your configuration**:
   ```swift
   config.additionalPaths = [
       "/path/returned/by/which/command"
   ]
   ```

### Session Storage

ClaudeCodeContainer automatically manages sessions internally. Sessions are stored in a SQLite database and include:
- Conversation history
- Working directory per session
- Timestamps and metadata

### MCP Server Issues

If MCP servers aren't working:

1. Check the MCP configuration in Settings
2. Verify server commands are installed:
   ```bash
   npm list -g | grep mcp-server
   ```
3. Check `~/.claude/mcp_settings.json` for syntax errors
4. Enable debug logging to see detailed errors

## Building from Source

If you want to build the standalone app yourself:

```bash
# Clone the repository
git clone https://github.com/jamesrochabrun/ClaudeCodeUI.git
cd ClaudeCodeUI

# Open in Xcode
open ClaudeCodeUI.xcodeproj

# Build and run
# The ApprovalMCPServer will be automatically downloaded and built from source during the build process
```

**Note**: The build process automatically downloads and compiles the [ApprovalMCPServer](https://github.com/jamesrochabrun/ClaudeCodeApprovalServer) from source for security.

## Support

For issues, questions, or contributions, please visit the [GitHub repository](https://github.com/jamesrochabrun/ClaudeCodeUI).

## License

MIT

## Acknowledgments

Built on top of [ClaudeCodeSDK](https://github.com/jamesrochabrun/ClaudeCodeSDK) and the [Claude CLI](https://github.com/anthropics/claude-cli) by Anthropic.

Thanks to [cmd](https://github.com/amrrs) for early testing, feedback, and bug reports that helped make ClaudeCodeUI better!
