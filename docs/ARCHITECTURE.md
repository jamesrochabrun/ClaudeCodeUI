# ClaudeCodeUI Architecture

This document provides a detailed overview of the ClaudeCodeUI architecture, design patterns, and key components.

## Table of Contents

1. [Overview](#overview)
2. [Architecture Patterns](#architecture-patterns)
3. [Project Structure](#project-structure)
4. [Core Components](#core-components)
5. [Data Flow](#data-flow)
6. [Key Services](#key-services)
7. [Tool System](#tool-system)
8. [Storage Layer](#storage-layer)

## Overview

ClaudeCodeUI is built using modern Swift and SwiftUI, following Apple's recommended architecture patterns for macOS applications. The application provides a native GUI for Claude Code, with deep integration into the macOS ecosystem.

## Architecture Patterns

### MVVM (Model-View-ViewModel)

The application follows the MVVM pattern:

- **Models**: Data structures and business logic
- **Views**: SwiftUI views for UI presentation
- **ViewModels**: Bridge between models and views, handling state and business logic

### Dependency Injection

Uses a central `DependencyContainer` for managing service instances:

```swift
class DependencyContainer {
    let chatSDK: ClaudeCodeSDK
    let sessionStorage: SessionStorage
    let settingsManager: SettingsStorageManager
    // ... other services
}
```

### Observation Pattern

Leverages Swift's `@Observable` macro for reactive state management:

```swift
@Observable
class ChatViewModel {
    var messages: [ChatMessage] = []
    var isLoading: Bool = false
}
```

## Project Structure

```
ClaudeCodeUI/
├── ClaudeCodeUIApp.swift          # App entry point
├── RootView.swift                 # Root view with dependency injection
├── Core/
│   ├── DependencyContainer.swift  # Service container
│   └── Configuration/             # App configuration
├── Models/
│   ├── ChatMessage.swift         # Message models
│   ├── Tool.swift               # Tool definitions
│   └── Session.swift            # Session management
├── ViewModels/
│   ├── ChatViewModel.swift      # Main chat logic
│   ├── ContextManager.swift     # Code context management
│   └── XcodeObservationViewModel.swift
├── UI/
│   ├── Screens/
│   │   ├── ChatScreen.swift    # Main chat interface
│   │   └── SettingsView.swift  # Settings interface
│   ├── Components/
│   │   ├── ChatInputView.swift # Message input
│   │   ├── ChatMessageView.swift
│   │   └── ToolDisplayView.swift
│   └── Formatters/             # Tool output formatters
├── Services/
│   ├── ApprovalService.swift   # Tool approval system
│   ├── PermissionsService.swift
│   └── XcodeObserverService/   # Xcode integration
├── Storage/
│   ├── SessionStorage.swift     # Session persistence
│   ├── MessageStore.swift       # Message storage
│   └── SettingsStorageManager.swift
└── Utilities/
    ├── Extensions/
    └── Helpers/
```

## Core Components

### 1. Chat System

The chat system is the heart of the application:

```swift
// ChatViewModel manages the chat state and logic
@Observable
class ChatViewModel {
    func sendMessage(_ content: String, attachments: [FileAttachment])
    func handleToolExecution(_ tool: Tool)
    func clearMessages()
}
```

### 2. Tool System

Tools are Claude Code's way of interacting with the system:

- **Tool Types**: Bash, Read, Write, Edit, Search, etc.
- **Tool Approval**: Optional approval flow for tool execution
- **Tool Formatting**: Custom formatters for different tool outputs

### 3. Context Management

Manages code context from various sources:

```swift
@Observable
class ContextManager {
    func captureXcodeSelection()
    func addFileContext(_ file: URL)
    func clearContext()
}
```

## Data Flow

### Message Flow

1. User types message in `ChatInputView`
2. `ChatViewModel` receives the message
3. Message sent to Claude Code SDK
4. Response streams back with tool executions
5. Tools are formatted and displayed
6. Messages stored in `MessageStore`

### Tool Execution Flow

```
User Input → ChatViewModel → ClaudeCodeSDK
    ↓
Tool Request ← Response with Tools
    ↓
ApprovalService (if enabled)
    ↓
Tool Execution → Formatted Output
    ↓
Display in ChatMessageView
```

## Key Services

### ClaudeCodeSDK

Core SDK for Claude Code integration:
- Handles API communication
- Manages tool execution
- Streams responses

### ApprovalService

MCP-based tool approval system:
- Intercepts tool requests
- Presents approval UI
- Manages approval state

### XcodeObserverService

Integrates with Xcode:
- Observes active windows
- Captures code selections
- Provides project context

### PermissionsService

Manages macOS permissions:
- Accessibility API access
- File system permissions
- Security scoped resources

## Tool System

### Tool Definition

Tools are defined with structured data:

```swift
struct Tool {
    let name: String
    let parameters: [String: Any]
    let description: String
}
```

### Tool Formatters

Each tool type has a dedicated formatter:

- `BashFormatter`: Formats command output
- `FileFormatter`: Formats file operations
- `DiffFormatter`: Renders file diffs
- `SearchFormatter`: Formats search results

### Tool Approval

When enabled, tools go through approval:

1. Tool request intercepted
2. Approval UI presented
3. User approves/rejects
4. Execution proceeds/cancelled

## Storage Layer

### Session Storage

Manages chat sessions:
- Persists session state
- Handles session switching
- Manages working directories

### Message Store

Stores chat messages:
- SQLite-based storage
- Full-text search
- Message history

### Settings Storage

Manages app preferences:
- User preferences
- API configuration
- UI customization

## Security Considerations

### Sandboxing

The app runs in a macOS sandbox with:
- Limited file system access
- Scoped bookmarks for directories
- Permission-based access

### API Key Management

- Stored in macOS Keychain
- Never exposed in logs
- Encrypted in transit

### Tool Execution

- Optional approval system
- Execution logging
- Resource limits

## Performance Optimizations

### Lazy Loading

- Messages loaded on demand
- Virtual scrolling for long chats
- Efficient diff rendering

### Caching

- Response caching
- File content caching
- Search index caching

### Concurrency

- Async/await for all I/O
- Background processing
- Main thread UI updates

## Testing Strategy

### Unit Tests

- ViewModel logic
- Service functionality
- Model validation

### Integration Tests

- SDK integration
- Storage operations
- Tool execution

### UI Tests

- User flows
- Keyboard shortcuts
- Drag and drop

## Future Considerations

### Extensibility

- Plugin system for custom tools
- Theme support
- Custom formatters

### Performance

- Message streaming optimization
- Incremental diff updates
- Background indexing

### Features

- Collaboration support
- Cloud sync
- Voice input