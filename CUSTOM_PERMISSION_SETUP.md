# Custom Permission Service Setup Guide

This guide explains how to complete the setup of the Custom Permission Service in your Claude Code UI application.

## Overview

The Custom Permission Service provides a comprehensive permission management system for Claude Code tool requests, including:

- Custom permission prompts with SwiftUI UI
- Auto-approval settings (all tools or low-risk only)
- MCP server integration for approval_prompt tool
- Persistent settings storage
- Real-time permission status monitoring

## Xcode Project Setup

### 1. Add Package Dependencies

You need to add the following local package references to your Xcode project:

1. Open your Xcode project
2. Go to **File** > **Add Package Dependencies...**
3. Add these local packages:
   - `modules/CustomPermissionServiceInterface`
   - `modules/CustomPermissionService`

### 2. Update Target Dependencies

Add the following dependencies to your main app target:

- `CustomPermissionServiceInterface`
- `CustomPermissionService`

## Configuration

### 1. Global Settings

The permission settings are automatically integrated into the MCP Configuration view. Users can configure:

- **Auto-approve all tool calls**: Disables all permission prompts
- **Auto-approve low-risk operations**: Automatically approves read-only operations
- **Show detailed permission information**: Controls detail level in prompts
- **Max concurrent requests**: Maximum simultaneous permission requests (default: 5)

### 2. MCP Integration

The system automatically integrates with Claude Code's MCP system by:

- Adding an `approval_server` to MCP configurations
- Setting up the `approval_prompt` tool for permission handling
- Configuring the `permissionPromptToolName` in ClaudeCodeOptions

## Usage

### Permission Prompts

When a tool requires permission and auto-approval is disabled:

1. A modal dialog appears showing:
   - Tool name and operation details
   - Risk level assessment (Low/Medium/High/Critical)
   - Input parameters (editable)
   - Affected resources
   - Approval/denial options

2. Users can:
   - Approve the request (optionally modifying parameters)
   - Deny the request (with optional reason)
   - View detailed tool information

### Status Monitoring

Permission status is visible throughout the app:

- **Chat Screen**: Small status indicator in toolbar
- **Settings**: Detailed permission configuration panel
- **MCP Configuration**: Permission system status display

## API Reference

### CustomPermissionService Protocol

```swift
@MainActor
public protocol CustomPermissionService: Sendable {
    var autoApproveToolCalls: Bool { get set }
    var autoApprovePublisher: AnyPublisher<Bool, Never> { get }
    
    func requestApproval(for request: ApprovalRequest) async throws -> ApprovalResponse
    func cancelAllRequests()
    func getApprovalStatus(for toolUseId: String) -> ApprovalStatus?
    func setupMCPTool(toolName: String, handler: @escaping (ApprovalRequest) async throws -> ApprovalResponse)
    func processMCPToolCall(_ toolCallData: [String: Any]) async throws -> String
}
```

### ApprovalRequest Model

```swift
public struct ApprovalRequest: Codable, Sendable {
    public let toolName: String
    public let input: [String: Any]
    public let toolUseId: String
    public let context: ApprovalContext?
}

public struct ApprovalContext: Codable, Sendable {
    public let description: String?
    public let riskLevel: RiskLevel
    public let isSensitive: Bool
    public let affectedResources: [String]
}

public enum RiskLevel: String, Codable, CaseIterable, Sendable {
    case low, medium, high, critical
}
```

### ApprovalResponse Model

```swift
public struct ApprovalResponse: Codable, Sendable {
    public let behavior: ApprovalBehavior
    public let updatedInput: [String: Any]?
    public let message: String?
}

public enum ApprovalBehavior: String, Codable, Sendable {
    case allow, deny
}
```

## Testing

The implementation includes comprehensive tests:

- **Unit Tests**: Core functionality testing
- **Integration Tests**: ClaudeCodeSDK integration testing
- **UI Tests**: SwiftUI component testing
- **Mock Services**: For testing without actual permissions

Run tests with:
```bash
xcodebuild test -scheme ClaudeCodeUI
```

## Troubleshooting

### Common Issues

1. **Permission prompts not appearing**
   - Check that `autoApproveToolCalls` is `false`
   - Verify MCP configuration includes approval_server
   - Ensure `permissionPromptToolName` is set correctly

2. **Build errors**
   - Verify both CustomPermissionService packages are added to Xcode project
   - Check that target dependencies include both packages
   - Clean and rebuild project

3. **MCP integration issues**
   - Verify MCP configuration file includes approval_server
   - Check that approval_prompt tool is in allowedTools list
   - Ensure permissionPromptToolName matches MCP tool name

### Debug Logging

Enable debug logging to troubleshoot:

```swift
let config = ClaudeCodeConfiguration.default
config.enableDebugLogging = true
```

Look for log messages prefixed with:
- `[CustomPermission]`: Permission service events
- `[MCP]`: MCP server integration
- `[ApprovalTool]`: Tool approval processing

## Architecture

The Custom Permission Service uses a clean architecture with:

- **Interface Layer**: Protocols and models in CustomPermissionServiceInterface
- **Implementation Layer**: Concrete implementations in CustomPermissionService
- **UI Layer**: SwiftUI components for permission prompts
- **Integration Layer**: MCP server integration and ClaudeCodeSDK bridging
- **Storage Layer**: Persistent settings in GlobalPreferencesStorage

This separation allows for easy testing, mocking, and future extensibility.

## Security Considerations

- Permission prompts run on the main thread to ensure UI responsiveness
- All tool parameters are displayed to users for transparency
- Auto-approval settings are clearly indicated in the UI
- All communication with Claude Code is logged for audit purposes

## Future Enhancements

Potential improvements for future versions:

- User-defined approval rules
- Tool-specific permission policies
- Permission history and audit logging
- Bulk approval workflows
- Integration with system keychain for secure storage