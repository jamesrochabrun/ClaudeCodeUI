# ClaudeCodeUI

A native macOS application providing a graphical interface for Claude Code, Anthropic's official CLI for AI-powered coding assistance.

![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![macOS](https://img.shields.io/badge/macOS-15.0+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## Overview

ClaudeCodeUI is a SwiftUI-based macOS application that brings the power of Claude Code to a native GUI experience. It features deep Xcode integration, multi-session support, and a sophisticated tool approval system.

## Features

### Core Features
- **Native macOS Experience**: Built with SwiftUI for seamless macOS integration
- **Xcode Integration**: Automatically captures code selections and project context from Xcode
- **Multi-Session Management**: Handle multiple chat sessions with different working directories
- **Tool Approval System**: Optional MCP-based approval flow for tool executions
- **File Attachments**: Drag and drop files and images directly into the chat
- **Rich Markdown Support**: Full markdown rendering with syntax highlighting

### Advanced Features
- **Diff Visualization**: Multiple diff view modes (inline, split, unified)
- **Code Context Management**: Capture and include code snippets in conversations
- **Global Keyboard Shortcuts**: System-wide shortcuts for quick access
- **File Search**: Inline file search with keyboard navigation
- **Tool Formatting**: Custom formatters for bash commands, file operations, and more
- **Session Persistence**: Automatically saves and restores chat sessions

## Requirements

- macOS 15.0 or later
- Xcode 15.0 or later (for building)
- Claude Code CLI installed and configured
- Valid Anthropic API key

## Installation

### From Source

1. Clone the repository:
```bash
git clone https://github.com/yourusername/ClaudeCodeUI.git
cd ClaudeCodeUI
```

2. Open the project in Xcode:
```bash
open ClaudeCodeUI.xcodeproj
```

3. Build and run the project (⌘+R)

### Configuration

1. **API Key**: Set your Anthropic API key in the app settings
2. **Working Directory**: Configure default working directories for your sessions
3. **Keyboard Shortcuts**: Customize global shortcuts in Settings → Shortcuts
4. **Tool Approval**: Enable/disable tool approval system in Settings → Security

## Usage

### Basic Usage

1. **Start a Chat**: Click the "+" button to create a new chat session
2. **Select Working Directory**: Choose the directory where Claude Code will operate
3. **Ask Questions**: Type your coding questions or requests in the input field
4. **Attach Files**: Drag files directly into the chat or use the attachment button
5. **Code Context**: Select code in Xcode and use the global shortcut to capture it

### Keyboard Shortcuts

- **⌘+⇧+A**: Open ClaudeCodeUI (global)
- **⌘+⇧+C**: Capture code selection from Xcode (global)
- **⌘+N**: New chat session
- **⌘+,**: Open settings
- **⌘+K**: Clear chat
- **⌘+/**: Toggle file search

### Tool Approval

When tool approval is enabled, ClaudeCodeUI will:
1. Display pending tool executions
2. Allow you to review tool parameters
3. Approve or reject individual tools
4. Batch approve multiple tools

## Architecture

ClaudeCodeUI follows the MVVM (Model-View-ViewModel) pattern with dependency injection:

```
ClaudeCodeUI/
├── UI/                    # SwiftUI Views
│   ├── ChatScreen.swift
│   ├── ChatInputView.swift
│   └── ToolDisplayView.swift
├── ViewModels/           # View Models
│   ├── ChatViewModel.swift
│   └── ContextManager.swift
├── Services/             # Core Services
│   ├── ClaudeCodeSDK/
│   ├── ApprovalService/
│   └── XcodeObserverService/
├── Models/               # Data Models
├── Storage/              # Persistence Layer
└── Utilities/            # Helper Functions
```

## Development

### Building from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/ClaudeCodeUI.git
cd ClaudeCodeUI

# Open in Xcode
open ClaudeCodeUI.xcodeproj

# Build and run
# Press ⌘+R in Xcode
```

### Running Tests

```bash
# Run all tests
xcodebuild test -scheme ClaudeCodeUI

# Run specific test suite
xcodebuild test -scheme ClaudeCodeUI -only-testing:ClaudeCodeUITests/ChatViewModelTests
```

## Contributing

Contributions are welcome! Please read our [Contributing Guidelines](CONTRIBUTING.md) for details on how to submit pull requests, report issues, and contribute to the project.

### Development Setup

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built on top of [Claude Code SDK](https://github.com/anthropics/claude-code)
- Uses [SwiftAnthropic](https://github.com/jamesrochabrun/SwiftAnthropic) for API communication
- Markdown rendering powered by [Down](https://github.com/johnxnguyen/Down)
- Syntax highlighting by [HighlightSwift](https://github.com/appstefan/HighlightSwift)

## Support

- **Issues**: Report bugs and request features on [GitHub Issues](https://github.com/yourusername/ClaudeCodeUI/issues)
- **Discussions**: Join the conversation on [GitHub Discussions](https://github.com/yourusername/ClaudeCodeUI/discussions)
- **Documentation**: Full documentation available in the [docs](docs/) directory