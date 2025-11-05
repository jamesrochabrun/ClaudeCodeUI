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
    private let serverProvider: ApprovalServerProvider

    /// Initialize the MCP approval tool
    /// - Parameters:
    ///   - permissionService: The permission service to handle approval requests
    ///   - toolName: The name of the MCP tool (typically "approval_prompt")
    ///   - serverProvider: Provider for the approval server executable path
    public init(
        permissionService: CustomPermissionService,
        toolName: String = "approval_prompt",
        serverProvider: ApprovalServerProvider? = nil
    ) {
        self.permissionService = permissionService
        self.toolName = toolName
        self.serverProvider = serverProvider ?? BundleApprovalServerProvider()
    }
    
    /// Configure the MCP approval tool with ClaudeCodeSDK options
    /// This method should be called when setting up ClaudeCodeOptions for MCP integration
    /// - Parameter options: The ClaudeCodeOptions to configure
    public func configure(options: inout ClaudeCodeOptions) {
        // Try to get the approval server path from the provider
        guard let approvalServerPath = serverProvider.approvalServerPath() else {
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
    
    
    /// Create a custom MCP configuration for the approval tool
    /// - Returns: MCP configuration dictionary
    public func createMCPConfiguration() -> [String: Any] {
        guard let approvalServerPath = serverProvider.approvalServerPath() else {
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
        if let _ = workingDirectory {
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
