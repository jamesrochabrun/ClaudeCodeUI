import Foundation
import ClaudeCodeSDK
import CCCustomPermissionServiceInterface

// Extension to get machine architecture
extension ProcessInfo {
    var machineHardwareName: String? {
        var sysinfo = utsname()
        let result = uname(&sysinfo)
        guard result == 0 else { return nil }
        return String(bytes: Data(bytes: &sysinfo.machine, count: Int(_SYS_NAMELEN)), encoding: .ascii)?
            .trimmingCharacters(in: .controlCharacters)
    }
}

/// MCP tool integration for approval_prompt functionality
/// This class provides the bridge between ClaudeCodeSDK's MCP system and our CustomPermissionService
public final class MCPApprovalTool: @unchecked Sendable {
    private let permissionService: CustomPermissionService
    private let toolName: String
    
    /// Initialize the MCP approval tool
    /// - Parameters:
    ///   - permissionService: The permission service to handle approval requests
    ///   - toolName: The name of the MCP tool (typically "approval_prompt")
    public init(permissionService: CustomPermissionService, toolName: String = "approval_prompt") {
        self.permissionService = permissionService
        self.toolName = toolName
    }
    
    /// Get debug information about the last search for ApprovalMCPServer
    public func getDebugInfo() -> String {
        // Try to find it again to get fresh debug info
        _ = getApprovalServerExecutablePath()
        return lastSearchDebugInfo
    }

    /// Configure the MCP approval tool with ClaudeCodeSDK options
    /// This method should be called when setting up ClaudeCodeOptions for MCP integration
    /// - Parameter options: The ClaudeCodeOptions to configure
    public func configure(options: inout ClaudeCodeOptions) {
        // Try to get the approval server path
        guard let approvalServerPath = getApprovalServerExecutablePath() else {
            print("[MCPApprovalTool] Approval server not available - skipping configuration")
            return
        }

        // Set up the permission prompt tool name
        let permissionToolName = "mcp__approval_server__\(toolName)"
        options.permissionPromptToolName = permissionToolName
        print("[MCPApprovalTool] Setting permissionPromptToolName: \(permissionToolName)")

        // Add the approval server to MCP servers if not already present
        if options.mcpServers == nil {
            options.mcpServers = [:]
        }

        // Configure the approval server to use our Swift MCP executable
        options.mcpServers?["approval_server"] = .stdio(McpStdioServerConfig(
            command: approvalServerPath,
            args: []
        ))
        print("[MCPApprovalTool] Configured approval server at: \(approvalServerPath)")

        // Ensure the approval tool is allowed
        var allowedTools = options.allowedTools ?? []
        let approvalToolName = "mcp__approval_server__\(toolName)"
        if !allowedTools.contains(approvalToolName) {
            allowedTools.append(approvalToolName)
            options.allowedTools = allowedTools
            print("[MCPApprovalTool] Added \(approvalToolName) to allowed tools")
        } else {
            print("[MCPApprovalTool] Tool \(approvalToolName) already in allowed tools")
        }
        print("[MCPApprovalTool] Final allowed tools: \(options.allowedTools ?? [])")
    }
    
    /// Debug information about bundle search
    public var lastSearchDebugInfo: String = ""

    /// Get the path to the compiled Swift MCP approval server executable
    /// This locates our ApprovalMCPServer binary that handles approval requests
    private func getApprovalServerExecutablePath() -> String? {
        var debugInfo: [String] = []
        debugInfo.append("=== ApprovalMCPServer Search Debug Info ===\n")

        // First check if it's in the app bundle (for DMG/Xcode builds)
        debugInfo.append("1. Checking Bundle.main: \(Bundle.main.bundleURL.path)")
        if let bundlePath = Bundle.main.path(forResource: "ApprovalMCPServer", ofType: nil) {
            if FileManager.default.fileExists(atPath: bundlePath) {
                debugInfo.append("✅ FOUND in Bundle.main at: \(bundlePath)")
                lastSearchDebugInfo = debugInfo.joined(separator: "\n")
                print("MCPApprovalTool: Found bundled approval server at: \(bundlePath)")
                return bundlePath
            }
        } else {
            debugInfo.append("❌ Not found in Bundle.main")
        }

        // Try base64 extraction approach for Swift Package
        debugInfo.append("\n2. Attempting base64 extraction:")
        debugInfo.append(ApprovalServerExtractor.getDebugInfo())

        if let extractedPath = ApprovalServerExtractor.extractApprovalServer() {
            debugInfo.append("✅ Successfully extracted from base64")
            lastSearchDebugInfo = debugInfo.joined(separator: "\n")
            print("MCPApprovalTool: Using extracted approval server at: \(extractedPath)")
            return extractedPath
        } else {
            debugInfo.append("❌ Base64 extraction failed")
        }

        // Check for Swift Package resource (for SPM integration)
        debugInfo.append("\n3. Checking for Swift Package resources:")

        // Try to find the resource using different bundle lookup methods
        var bundles: [Bundle] = [
            Bundle(for: MCPApprovalTool.self)
        ]

        debugInfo.append("   - MCPApprovalTool bundle: \(Bundle(for: MCPApprovalTool.self).bundleURL.path)")

        // Try to find the ClaudeCodeCore bundle using our helper
        if let coreBundle = BundleHelper.findClaudeCodeCoreBundle() {
            bundles.append(coreBundle)
            debugInfo.append("   - Found ClaudeCodeCore bundle: \(coreBundle.bundleURL.path)")
        } else {
            debugInfo.append("   - ClaudeCodeCore bundle NOT FOUND via BundleHelper")
        }

        // Add bundle debug info
        debugInfo.append("\n" + BundleHelper.getBundleDebugInfo())

        // Also check all loaded bundles for the resource
        debugInfo.append("\n4. Checking all loaded bundles containing 'ClaudeCode':")
        for bundle in Bundle.allBundles {
            if bundle.bundleURL.path.contains("ClaudeCodeCore") ||
               bundle.bundleIdentifier?.contains("ClaudeCode") == true {
                bundles.append(bundle)
                debugInfo.append("   - Found: \(bundle.bundleURL.path)")
            }
        }

        // Also check frameworks
        debugInfo.append("\n5. Checking frameworks containing 'ClaudeCodeCore':")
        for bundle in Bundle.allFrameworks {
            if bundle.bundleURL.path.contains("ClaudeCodeCore") {
                bundles.append(bundle)
                debugInfo.append("   - Found: \(bundle.bundleURL.path)")
            }
        }

        if bundles.count == 1 {
            debugInfo.append("\n⚠️ Only found 1 bundle to check")
        } else {
            debugInfo.append("\n📦 Found \(bundles.count) bundles to check")
        }

        debugInfo.append("\n6. Searching for ApprovalMCPServer in bundles:")
        for bundle in bundles {
            debugInfo.append("\n   Checking: \(bundle.bundleURL.path)")
            print("MCPApprovalTool: Checking bundle: \(bundle.bundleURL.path)")

            // List contents of bundle's Resources directory if it exists
            let resourcesPath = bundle.bundleURL.appendingPathComponent("Resources")
            if FileManager.default.fileExists(atPath: resourcesPath.path) {
                do {
                    let contents = try FileManager.default.contentsOfDirectory(atPath: resourcesPath.path)
                    debugInfo.append("      Resources: \(contents.joined(separator: ", "))")
                } catch {
                    debugInfo.append("      Could not list Resources: \(error)")
                }
            }

            // Try looking in Resources subdirectory first
            if let moduleBundle = bundle.url(forResource: "ApprovalMCPServer", withExtension: nil, subdirectory: "Resources") {
                debugInfo.append("      ✅ FOUND in Resources subdirectory!")
            let modulePath = moduleBundle.path

            // The resource might not have executable permissions when copied from Bundle.module
            // We need to extract it to a location where we can set executable permissions
            let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appName = Bundle.main.bundleIdentifier ?? "ClaudeCodeUI"
            let destinationDir = appSupportURL.appendingPathComponent(appName)
            let destinationPath = destinationDir.appendingPathComponent("ApprovalMCPServer")

            do {
                // Create directory if it doesn't exist
                try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true)

                // Check if we already have a copy and if it's up to date
                if FileManager.default.fileExists(atPath: destinationPath.path) {
                    // For now, always use the existing copy
                    // In the future, we could check modification dates to update if needed
                    print("MCPApprovalTool: Using cached approval server at: \(destinationPath.path)")
                    debugInfo.append("      Using cached copy at: \(destinationPath.path)")
                    lastSearchDebugInfo = debugInfo.joined(separator: "\n")
                    return destinationPath.path
                }

                // Copy the binary to Application Support
                try FileManager.default.copyItem(at: moduleBundle, to: destinationPath)

                // Make it executable
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destinationPath.path)

                debugInfo.append("      ✅ FOUND and extracted to: \(destinationPath.path)")
                lastSearchDebugInfo = debugInfo.joined(separator: "\n")
                print("MCPApprovalTool: Extracted approval server from package to: \(destinationPath.path)")
                return destinationPath.path
            } catch {
                print("MCPApprovalTool: Error extracting approval server: \(error)")
                debugInfo.append("      ❌ Error extracting: \(error)")
                // Fall back to using the bundle path directly (might work on some systems)
                if FileManager.default.fileExists(atPath: modulePath) {
                    print("MCPApprovalTool: Falling back to bundle resource at: \(modulePath)")
                    lastSearchDebugInfo = debugInfo.joined(separator: "\n")
                    return modulePath
                }
            }
            } else if let moduleBundle = bundle.url(forResource: "ApprovalMCPServer", withExtension: nil) {
                debugInfo.append("      Found in root (not Resources subdirectory)")
            let modulePath = moduleBundle.path

            // The resource might not have executable permissions when copied from Bundle.module
            // We need to extract it to a location where we can set executable permissions
            let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appName = Bundle.main.bundleIdentifier ?? "ClaudeCodeUI"
            let destinationDir = appSupportURL.appendingPathComponent(appName)
            let destinationPath = destinationDir.appendingPathComponent("ApprovalMCPServer")

            do {
                // Create directory if it doesn't exist
                try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true)

                // Check if we already have a copy and if it's up to date
                if FileManager.default.fileExists(atPath: destinationPath.path) {
                    // For now, always use the existing copy
                    // In the future, we could check modification dates to update if needed
                    print("MCPApprovalTool: Using cached approval server at: \(destinationPath.path)")
                    debugInfo.append("      Using cached copy at: \(destinationPath.path)")
                    lastSearchDebugInfo = debugInfo.joined(separator: "\n")
                    return destinationPath.path
                }

                // Copy the binary to Application Support
                try FileManager.default.copyItem(at: moduleBundle, to: destinationPath)

                // Make it executable
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destinationPath.path)

                debugInfo.append("      ✅ FOUND and extracted to: \(destinationPath.path)")
                lastSearchDebugInfo = debugInfo.joined(separator: "\n")
                print("MCPApprovalTool: Extracted approval server from package to: \(destinationPath.path)")
                return destinationPath.path
            } catch {
                print("MCPApprovalTool: Error extracting approval server: \(error)")
                debugInfo.append("      ❌ Error extracting: \(error)")
                // Fall back to using the bundle path directly (might work on some systems)
                if FileManager.default.fileExists(atPath: modulePath) {
                    print("MCPApprovalTool: Falling back to bundle resource at: \(modulePath)")
                    lastSearchDebugInfo = debugInfo.joined(separator: "\n")
                    return modulePath
                }
            }
            } else {
                debugInfo.append("      ❌ ApprovalMCPServer not found in this bundle")
            }
        }

        // Not found anywhere
        debugInfo.append("\n\n❌ ApprovalMCPServer NOT FOUND in any bundle!")
        debugInfo.append("\n📱 App Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        debugInfo.append("📍 App Path: \(Bundle.main.bundlePath)")

        lastSearchDebugInfo = debugInfo.joined(separator: "\n")
        print("MCPApprovalTool: ApprovalMCPServer not found in app bundle or package resources")
        print("MCPApprovalTool: The approval server feature will be disabled")
        print("Debug Info:\n\(lastSearchDebugInfo)")
        return nil
    }
    
    /// Create a custom MCP configuration for the approval tool
    /// - Returns: MCP configuration dictionary
    public func createMCPConfiguration() -> [String: Any] {
        guard let approvalServerPath = getApprovalServerExecutablePath() else {
            // Return empty config if server not available
            return ["mcpServers": [:]]
        }
        return [
            "mcpServers": [
                "approval_server": [
                    "command": approvalServerPath,
                    "args": [],
                    "env": [:]
                ]
            ]
        ]
    }
    
    /// Process an approval request from MCP
    /// This is the main entry point for handling approval requests from Claude Code
    /// - Parameter toolCallData: Raw tool call data from MCP
    /// - Returns: JSON-encoded approval response
    @MainActor
    public func processApprovalRequest(_ toolCallData: [String: Any]) async throws -> String {
        return try await permissionService.processMCPToolCall(toolCallData)
    }
}

/// Extension to help with ClaudeCodeSDK integration
extension MCPApprovalTool {
    
    /// Convenience method to create a complete ClaudeCodeOptions with approval tool configured
    /// - Parameters:
    ///   - baseOptions: Base options to extend (optional)
    ///   - workingDirectory: Working directory for Claude Code
    /// - Returns: Configured ClaudeCodeOptions
    public static func createConfiguredOptions(
        permissionService: CustomPermissionService,
        baseOptions: ClaudeCodeOptions? = nil,
        workingDirectory: String? = nil
    ) -> ClaudeCodeOptions {
        var options = baseOptions ?? ClaudeCodeOptions()
        
        // Set working directory if provided
        if let workingDirectory = workingDirectory {
            // Note: This would need to be set on ClaudeCodeConfiguration instead
            // options.workingDirectory = workingDirectory
        }
        
        // Create and configure the approval tool
        let approvalTool = MCPApprovalTool(permissionService: permissionService)
        approvalTool.configure(options: &options)
        
        return options
    }
    
    /// Write MCP configuration to a temporary file for use with ClaudeCodeSDK
    /// - Returns: Path to the temporary configuration file
    public func writeTemporaryMCPConfig() throws -> String {
        let config = createMCPConfiguration()
        let configData = try JSONSerialization.data(withJSONObject: config, options: .prettyPrinted)
        
        let tempDir = FileManager.default.temporaryDirectory
        let configFile = tempDir.appendingPathComponent("approval_mcp_config.json")
        
        try configData.write(to: configFile)
        
        return configFile.path
    }
}

/// Helper for creating approval-enabled MCP configurations
public struct ApprovalMCPHelper {
    private let permissionService: CustomPermissionService
    
    public init(permissionService: CustomPermissionService) {
        self.permissionService = permissionService
    }
    
    /// Create a complete MCP configuration that includes approval functionality
    /// - Parameter existingServers: Any existing MCP server configurations
    /// - Returns: Complete MCP configuration dictionary
    public func createCompleteMCPConfig(existingServers: [String: Any] = [:]) -> [String: Any] {
        let approvalTool = MCPApprovalTool(permissionService: permissionService)
        let approvalConfig = approvalTool.createMCPConfiguration()
        
        var mcpServers = existingServers
        
        // Add approval server configuration
        if let approvalServers = approvalConfig["mcpServers"] as? [String: Any] {
            for (key, value) in approvalServers {
                mcpServers[key] = value
            }
        }
        
        return [
            "mcpServers": mcpServers
        ]
    }
    
    /// Configure ClaudeCodeOptions with approval support and existing MCP servers
    /// - Parameters:
    ///   - options: Options to configure
    public func configureOptions(_ options: inout ClaudeCodeOptions) {
        let approvalTool = MCPApprovalTool(permissionService: permissionService)
        
        // Initialize mcpServers if needed
        if options.mcpServers == nil {
            options.mcpServers = [:]
        }
        
        // Add approval tool configuration
        approvalTool.configure(options: &options)
    }
}

/// Errors specific to MCP approval tool integration
public enum MCPApprovalError: Error, LocalizedError {
    case configurationError(String)
    case serverSetupError(String)
    case communicationError(String)
    
    public var errorDescription: String? {
        switch self {
        case .configurationError(let details):
            return "MCP approval configuration error: \(details)"
        case .serverSetupError(let details):
            return "MCP approval server setup error: \(details)"
        case .communicationError(let details):
            return "MCP approval communication error: \(details)"
        }
    }
}