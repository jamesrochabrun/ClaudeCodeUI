# Multi-Instance Notification System

This document describes the multi-instance support implementation for ClaudeCodeUI. This feature allows multiple instances of the app to run simultaneously without interfering with each other's IPC notifications.

## Problem

Previously, all app instances used the same notification names (`ClaudeCodeUIApprovalRequest` and `ClaudeCodeUIApprovalResponse`) via `DistributedNotificationCenter`. This meant:

- When any MCP server sent an approval request, ALL running app instances received it
- All instances would show the permission toast simultaneously
- Only one instance would actually be handling the correct request

## Solution

Each app instance now generates a unique identifier and uses instance-specific notification names:

- `ClaudeCodeUIApprovalRequest_{instanceId}`
- `ClaudeCodeUIApprovalResponse_{instanceId}`

The instance ID is passed to MCP servers via the `CLAUDE_CODE_UI_INSTANCE_ID` environment variable.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     ClaudeCodeUI Instance 1                      │
│  ┌─────────────────────┐    ┌─────────────────────────────────┐ │
│  │ AppInstanceIdentifier│    │        ApprovalBridge           │ │
│  │   instanceId: "123"  │────│ Listens: ...Request_123         │ │
│  └─────────────────────┘    │ Posts:   ...Response_123        │ │
│            │                 └─────────────────────────────────┘ │
│            │ env: CLAUDE_CODE_UI_INSTANCE_ID=123                 │
│            ▼                                                      │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    ApprovalMCPServer                         │ │
│  │  Posts:   ClaudeCodeUIApprovalRequest_123                   │ │
│  │  Listens: ClaudeCodeUIApprovalResponse_123                  │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                     ClaudeCodeUI Instance 2                      │
│  ┌─────────────────────┐    ┌─────────────────────────────────┐ │
│  │ AppInstanceIdentifier│    │        ApprovalBridge           │ │
│  │   instanceId: "456"  │────│ Listens: ...Request_456         │ │
│  └─────────────────────┘    │ Posts:   ...Response_456        │ │
│            │                 └─────────────────────────────────┘ │
│            │ env: CLAUDE_CODE_UI_INSTANCE_ID=456                 │
│            ▼                                                      │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    ApprovalMCPServer                         │ │
│  │  Posts:   ClaudeCodeUIApprovalRequest_456                   │ │
│  │  Listens: ClaudeCodeUIApprovalResponse_456                  │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Components Modified in ClaudeCodeUI

### 1. AppInstanceIdentifier (New)
`Sources/ClaudeCodeCore/Services/AppInstanceIdentifier.swift`

Generates and manages unique instance identifiers:
- Creates unique ID using process ID + timestamp
- Provides instance-specific notification names
- Provides environment dictionary for child processes

### 2. ApprovalBridge (Modified)
`Sources/ClaudeCodeCore/Services/ApprovalBridge.swift`

Now accepts `AppInstanceIdentifier` in its initializer and uses instance-specific notification names:
- Listens for `ClaudeCodeUIApprovalRequest_{instanceId}`
- Posts to `ClaudeCodeUIApprovalResponse_{instanceId}`

### 3. MCPApprovalTool (Modified)
`Sources/CustomPermissionService/MCPApprovalTool.swift`

Passes instance ID to MCP servers via environment variable:
- Accepts optional `instanceId` parameter
- Configures `CLAUDE_CODE_UI_INSTANCE_ID` environment variable for MCP server

### 4. DependencyContainer (Modified)
`Sources/ClaudeCodeCore/DependencyInjection/DependencyContainer.swift`

Creates and shares the `AppInstanceIdentifier`:
- Initializes `appInstanceIdentifier` on creation
- Passes it to `ApprovalBridge`
- Makes it available for `ChatViewModel` creation

### 5. ChatViewModel (Modified)
`Sources/ClaudeCodeCore/ViewModels/ChatViewModel.swift`

Accepts and uses instance ID:
- New `appInstanceId` parameter in initializer
- Passes ID to `ApprovalMCPHelper` when configuring MCP options

---

## Required Changes for ApprovalMCPServer

The `ApprovalMCPServer` binary needs to be updated to support instance-specific notifications.

### Changes Required:

1. **Read Instance ID from Environment**
   ```swift
   let instanceId = ProcessInfo.processInfo.environment["CLAUDE_CODE_UI_INSTANCE_ID"]
   ```

2. **Use Instance-Specific Notification Names**

   Instead of:
   ```swift
   let requestNotification = "ClaudeCodeUIApprovalRequest"
   let responseNotification = "ClaudeCodeUIApprovalResponse"
   ```

   Use:
   ```swift
   let instanceId = ProcessInfo.processInfo.environment["CLAUDE_CODE_UI_INSTANCE_ID"] ?? ""
   let requestNotification: String
   let responseNotification: String

   if instanceId.isEmpty {
       // Fallback for backward compatibility
       requestNotification = "ClaudeCodeUIApprovalRequest"
       responseNotification = "ClaudeCodeUIApprovalResponse"
   } else {
       requestNotification = "ClaudeCodeUIApprovalRequest_\(instanceId)"
       responseNotification = "ClaudeCodeUIApprovalResponse_\(instanceId)"
   }
   ```

3. **Update Notification Posting**
   ```swift
   DistributedNotificationCenter.default().post(
       name: NSNotification.Name(requestNotification),
       object: nil,
       userInfo: userInfo
   )
   ```

4. **Update Notification Listening**
   ```swift
   DistributedNotificationCenter.default().addObserver(
       self,
       selector: #selector(handleApprovalResponse(_:)),
       name: NSNotification.Name(responseNotification),
       object: nil,
       suspensionBehavior: .deliverImmediately
   )
   ```

### Backward Compatibility

The implementation maintains backward compatibility:
- If `CLAUDE_CODE_UI_INSTANCE_ID` is not set, the MCP server should fall back to the original notification names
- This allows older versions of the app to work with newer MCP servers and vice versa

---

## Testing Multi-Instance Support

1. Launch multiple instances of ClaudeCodeUI
2. In each instance, start a conversation that triggers approval requests
3. Verify that:
   - Each instance only shows permission toasts for its own requests
   - Approving/denying in one instance doesn't affect others
   - Each instance's MCP server correctly routes notifications

## Debugging

Enable debug logging to see instance IDs:
```
[DependencyContainer] App instance ID: 12345_678901
[ApprovalBridge] ApprovalBridge listening for: ClaudeCodeUIApprovalRequest_12345_678901
[MCPApprovalTool] Configuring for instance: 12345_678901
```
