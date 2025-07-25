# Approval Server Setup Guide

The approval server has been successfully integrated into ClaudeCodeUI. Here's what was done:

## 1. Built the ApprovalMCPServer

The approval server executable has been built and is located at:
```
/Users/jamesrochabrun/Desktop/git/ClaudeCodeUI/modules/ApprovalMCPServer/.build/arm64-apple-macosx/debug/ApprovalMCPServer
```

## 2. Updated MCPApprovalTool

The `MCPApprovalTool.swift` has been updated with the correct path to the built executable.

## 3. Modified RootView

The `RootView.swift` has been modified to:
- Import `CustomPermissionService`
- Create and configure the approval MCP server when setting up ClaudeCodeClient
- Load existing MCP servers from MCPConfigurationManager
- Merge them with the approval server configuration

## 4. Added to Predefined Servers

The approval server has been added to the predefined servers list in `MCPConfiguration.swift` for easy addition via the UI.

## How It Works

1. When the app starts, it automatically configures the approval server in the ClaudeCodeOptions
2. The approval server runs as a separate process and communicates with the main app via IPC (Inter-Process Communication)
3. When Claude Code tools request approval, the MCP server sends the request to the main app
4. The ApprovalBridge service in the main app receives the request and shows the approval UI
5. The user's response is sent back to the MCP server, which then responds to Claude Code

## Testing

To test the approval server:
1. Build and run the ClaudeCodeUI app
2. Use Claude Code tools that require approval (e.g., file operations with sensitive paths)
3. You should see approval prompts in the UI

## Troubleshooting

If the approval server doesn't work:
1. Ensure the executable has execute permissions: `chmod +x /path/to/ApprovalMCPServer`
2. Check that the path in MCPApprovalTool matches your built executable location
3. Verify the ApprovalBridge is listening for IPC notifications (check logs)
4. Make sure the approval_server is configured in your MCP configuration

## Next Steps

The approval server is now ready to use. You may want to:
1. Build a release version for production use
2. Copy the executable to the app bundle for distribution
3. Add more sophisticated approval rules based on tool types and parameters