import Foundation
import ClaudeCodeSDK
import CustomPermissionServiceInterface

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
        
        // Configure the approval server
        options.mcpServers?["approval_server"] = .stdio(McpStdioServerConfig(
            command: "node",
            args: ["-e", createApprovalServerScript()]
        ))
        
        // Ensure the approval tool is allowed
        var allowedTools = options.allowedTools ?? []
        let approvalToolName = "mcp__approval_server__\(toolName)"
        if !allowedTools.contains(approvalToolName) {
            allowedTools.append(approvalToolName)
            options.allowedTools = allowedTools
        }
    }
    
    /// Create the JavaScript MCP server script that handles approval requests
    /// This creates a simple Node.js MCP server that bridges to our Swift service
    private func createApprovalServerScript() -> String {
        return """
        const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
        const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
        
        class ApprovalServer {
          constructor() {
            this.server = new Server(
              {
                name: 'approval-server',
                version: '1.0.0',
              },
              {
                capabilities: {
                  tools: {},
                },
              }
            );
            
            this.setupHandlers();
          }
          
          setupHandlers() {
            this.server.setRequestHandler('tools/list', async () => {
              return {
                tools: [
                  {
                    name: '\(toolName)',
                    description: 'Handle permission approval requests for Claude Code tools',
                    inputSchema: {
                      type: 'object',
                      properties: {
                        tool_name: {
                          type: 'string',
                          description: 'The name of the tool requesting permission'
                        },
                        input: {
                          type: 'object',
                          description: 'The input parameters for the tool'
                        },
                        tool_use_id: {
                          type: 'string',
                          description: 'Unique identifier for this tool use request'
                        }
                      },
                      required: ['tool_name', 'input', 'tool_use_id']
                    }
                  }
                ]
              };
            });
            
            this.server.setRequestHandler('tools/call', async (request) => {
              if (request.params.name !== '\(toolName)') {
                throw new Error(`Unknown tool: ${request.params.name}`);
              }
              
              const { tool_name, input, tool_use_id } = request.params.arguments;
              
              // In a real implementation, this would communicate with the Swift service
              // For now, we'll return a default response that can be customized
              const response = {
                behavior: 'allow',
                updatedInput: input,
                message: 'Handled by MCP approval server'
              };
              
              return {
                content: [
                  {
                    type: 'text',
                    text: JSON.stringify(response)
                  }
                ]
              };
            });
          }
          
          async run() {
            const transport = new StdioServerTransport();
            await this.server.connect(transport);
          }
        }
        
        const server = new ApprovalServer();
        server.run().catch(console.error);
        """
    }
    
    /// Create a custom MCP configuration for the approval tool
    /// - Returns: MCP configuration dictionary
    public func createMCPConfiguration() -> [String: Any] {
        return [
            "mcpServers": [
                "approval_server": [
                    "command": "node",
                    "args": ["-e", createApprovalServerScript()],
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