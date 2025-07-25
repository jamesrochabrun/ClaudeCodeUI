import Foundation
import ClaudeCodeSDK
import CustomPermissionServiceInterface

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
    
    /// Configure the MCP approval tool with ClaudeCodeSDK options
    /// This method should be called when setting up ClaudeCodeOptions for MCP integration
    /// - Parameter options: The ClaudeCodeOptions to configure
    public func configure(options: inout ClaudeCodeOptions) {
        // Set up the permission prompt tool name
        options.permissionPromptToolName = "mcp__approval_server__\(toolName)"
        
        // Add the approval server to MCP servers if not already present
        if options.mcpServers == nil {
            options.mcpServers = [:]
        }
        
        // Configure the approval server to use our Swift MCP executable
        let approvalServerPath = getApprovalServerExecutablePath()
        options.mcpServers?["approval_server"] = .stdio(McpStdioServerConfig(
            command: approvalServerPath,
            args: []
        ))
        
        // Ensure the approval tool is allowed
        var allowedTools = options.allowedTools ?? []
        let approvalToolName = "mcp__approval_server__\(toolName)"
        if !allowedTools.contains(approvalToolName) {
            allowedTools.append(approvalToolName)
            options.allowedTools = allowedTools
        }
    }
    
    /// Get the path to the compiled Swift MCP approval server executable
    /// This locates our ApprovalMCPServer binary that handles approval requests
    private func getApprovalServerExecutablePath() -> String {
        // First, check if it's in the app bundle (for packaged apps)
        if let bundlePath = Bundle.main.path(forResource: "ApprovalMCPServer", ofType: nil) {
            if FileManager.default.fileExists(atPath: bundlePath) {
                return bundlePath
            }
        }
        
        // For development, find the project root directory
        let fileManager = FileManager.default
        var currentPath = fileManager.currentDirectoryPath
        
        // If we're running from Xcode, try to find the project root
        if let xcodeProjectPath = ProcessInfo.processInfo.environment["BUILD_ROOT"] {
            // Navigate from build directory to project root
            let buildURL = URL(fileURLWithPath: xcodeProjectPath)
            if let projectRoot = buildURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().path as String? {
                currentPath = projectRoot
            }
        }
        
        // Try to find the project root by looking for ClaudeCodeUI.xcodeproj
        var searchPath = URL(fileURLWithPath: currentPath)
        for _ in 0..<5 {
            let projectFile = searchPath.appendingPathComponent("ClaudeCodeUI.xcodeproj")
            if fileManager.fileExists(atPath: projectFile.path) {
                currentPath = searchPath.path
                break
            }
            searchPath = searchPath.deletingLastPathComponent()
        }
        
        // Determine the architecture
        let architecture = ProcessInfo.processInfo.machineHardwareName ?? "arm64"
        
        // Build possible paths relative to project root
        let possiblePaths = [
            // Architecture-specific paths
            "\(currentPath)/modules/ApprovalMCPServer/.build/\(architecture)-apple-macosx/debug/ApprovalMCPServer",
            "\(currentPath)/modules/ApprovalMCPServer/.build/\(architecture)-apple-macosx/release/ApprovalMCPServer",
            // Generic paths
            "\(currentPath)/modules/ApprovalMCPServer/.build/debug/ApprovalMCPServer",
            "\(currentPath)/modules/ApprovalMCPServer/.build/release/ApprovalMCPServer",
        ]
        
        // Check each path
        for path in possiblePaths {
            if fileManager.fileExists(atPath: path) {
                return path
            }
        }
        
        // If not found, try to build it
        let buildPath = "\(currentPath)/modules/ApprovalMCPServer"
        if fileManager.fileExists(atPath: buildPath) {
            // Build the server (this will only work in development)
            let task = Process()
            task.launchPath = "/usr/bin/swift"
            task.arguments = ["build", "-c", "debug"]
            task.currentDirectoryPath = buildPath
            
            do {
                try task.run()
                task.waitUntilExit()
                
                // Check if build succeeded
                let builtPath = "\(buildPath)/.build/\(architecture)-apple-macosx/debug/ApprovalMCPServer"
                if fileManager.fileExists(atPath: builtPath) {
                    return builtPath
                }
            } catch {
                print("Failed to build ApprovalMCPServer: \(error)")
            }
        }
        
        // Final fallback - return expected debug path
        return "\(currentPath)/modules/ApprovalMCPServer/.build/\(architecture)-apple-macosx/debug/ApprovalMCPServer"
    }
    
    /// Create a custom MCP configuration for the approval tool
    /// - Returns: MCP configuration dictionary
    public func createMCPConfiguration() -> [String: Any] {
        let approvalServerPath = getApprovalServerExecutablePath()
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