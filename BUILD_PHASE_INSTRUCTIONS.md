# Adding Build Phase for MCP Approval Server

To ensure the MCP Approval Server is built automatically, follow these steps in Xcode:

## Steps to Add Build Phase

1. Open `ClaudeCodeUI.xcodeproj` in Xcode
2. Select the `ClaudeCodeUI` target in the project navigator
3. Go to the "Build Phases" tab
4. Click the "+" button and select "New Run Script Phase"
5. Drag the new "Run Script" phase to be **before** the "Compile Sources" phase
6. Rename it to "Build MCP Approval Server"
7. In the script editor, paste the following:

```bash
# Build MCP Approval Server if needed
"${PROJECT_DIR}/Scripts/build-approval-server.sh"
```

8. Uncheck "Based on dependency analysis" to ensure it runs every build
9. Build the project (⌘+B)

## What This Does

- Checks if the approval server is already built
- If not, builds it automatically
- For release builds, copies it into the app bundle
- Shows clear error messages if something goes wrong

## Troubleshooting

If you see errors about the approval server:

1. Check that you have Swift installed: `swift --version`
2. Manually build the server: `cd modules/ApprovalMCPServer && swift build`
3. Check the build logs in Xcode for detailed error messages

The approval server only needs to be built once - subsequent builds will be fast.