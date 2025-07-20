import XCTest
@testable import CustomPermissionService
@testable import CustomPermissionServiceInterface
import ClaudeCodeSDK

@MainActor
final class MCPApprovalToolTests: XCTestCase {
    private var mockPermissionService: MockCustomPermissionService!
    private var mcpTool: MCPApprovalTool!
    
    override func setUp() {
        super.setUp()
        mockPermissionService = MockCustomPermissionService()
        mcpTool = MCPApprovalTool(permissionService: mockPermissionService)
    }
    
    override func tearDown() {
        mockPermissionService = nil
        mcpTool = nil
        super.tearDown()
    }
    
    func testMCPToolInitialization() {
        XCTAssertNotNil(mcpTool)
        
        // Test with custom tool name
        let customTool = MCPApprovalTool(permissionService: mockPermissionService, toolName: "custom_approval")
        XCTAssertNotNil(customTool)
    }
    
    func testCreateMCPConfiguration() {
        let config = mcpTool.createMCPConfiguration()
        
        XCTAssertTrue(config["mcpServers"] is [String: Any])
        
        if let servers = config["mcpServers"] as? [String: Any] {
            XCTAssertTrue(servers.keys.contains("approval_server"))
            
            if let approvalServer = servers["approval_server"] as? [String: Any] {
                XCTAssertEqual(approvalServer["command"] as? String, "node")
                XCTAssertTrue(approvalServer["args"] is [String])
                XCTAssertTrue(approvalServer["env"] is [String: Any])
            }
        }
    }
    
    func testProcessApprovalRequestSuccess() async throws {
        mockPermissionService.shouldApprove = true
        
        let toolCallData: [String: Any] = [
            "tool_name": "approval_prompt",
            "input": ["param": "value"],
            "tool_use_id": "test-123"
        ]
        
        let jsonResponse = try await mcpTool.processApprovalRequest(toolCallData)
        
        XCTAssertEqual(mockPermissionService.requestApprovalCallCount, 1)
        XCTAssertEqual(mockPermissionService.lastRequest?.toolUseId, "test-123")
        
        // Parse JSON response
        let data = jsonResponse.data(using: .utf8)!
        let response = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        XCTAssertEqual(response["behavior"] as? String, "allow")
        XCTAssertNotNil(response["updatedInput"])
    }
    
    func testProcessApprovalRequestDenial() async throws {
        mockPermissionService.shouldApprove = false
        
        let toolCallData: [String: Any] = [
            "tool_name": "approval_prompt", 
            "input": ["param": "value"],
            "tool_use_id": "test-456"
        ]
        
        let jsonResponse = try await mcpTool.processApprovalRequest(toolCallData)
        
        XCTAssertEqual(mockPermissionService.requestApprovalCallCount, 1)
        
        // Parse JSON response
        let data = jsonResponse.data(using: .utf8)!
        let response = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        XCTAssertEqual(response["behavior"] as? String, "deny")
    }
    
    func testWriteTemporaryMCPConfig() throws {
        let tempPath = try mcpTool.writeTemporaryMCPConfig()
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempPath))
        XCTAssertTrue(tempPath.hasSuffix("approval_mcp_config.json"))
        
        // Clean up
        try? FileManager.default.removeItem(atPath: tempPath)
    }
    
    func testConfigureOptions() {
        var options = ClaudeCodeOptions()
        
        mcpTool.configure(options: &options)
        
        XCTAssertEqual(options.permissionPromptToolName, "mcp__approval_server__approval_prompt")
        XCTAssertNotNil(options.mcpServers)
        XCTAssertTrue(options.mcpServers?.keys.contains("approval_server") == true)
        XCTAssertNotNil(options.allowedTools)
        XCTAssertTrue(options.allowedTools?.contains("mcp__approval_server__approval_prompt") == true)
    }
    
    func testApprovalMCPHelper() {
        let helper = ApprovalMCPHelper(permissionService: mockPermissionService)
        
        // Test creating complete config with existing servers
        let existingServers = ["existing": ["command": "test"]]
        let completeConfig = helper.createCompleteMCPConfig(existingServers: existingServers)
        
        XCTAssertTrue(completeConfig["mcpServers"] is [String: Any])
        if let servers = completeConfig["mcpServers"] as? [String: Any] {
            XCTAssertTrue(servers.keys.contains("existing"))
            XCTAssertTrue(servers.keys.contains("approval_server"))
        }
        
        // Test configuring options
        var options = ClaudeCodeOptions()
        
        helper.configureOptions(&options)
        
        XCTAssertNotNil(options.mcpServers)
        XCTAssertTrue(options.mcpServers?.keys.contains("approval_server") == true)
    }
    
    func testCreateConfiguredOptions() {
        let options = MCPApprovalTool.createConfiguredOptions(
            permissionService: mockPermissionService,
            baseOptions: nil,
            workingDirectory: "/test/path"
        )
        
        XCTAssertNotNil(options.mcpServers)
        XCTAssertNotNil(options.allowedTools)
        XCTAssertEqual(options.permissionPromptToolName, "mcp__approval_server__approval_prompt")
    }
}

final class MCPApprovalErrorTests: XCTestCase {
    
    func testMCPApprovalErrorDescriptions() {
        let configError = MCPApprovalError.configurationError("test config error")
        XCTAssertEqual(configError.errorDescription, "MCP approval configuration error: test config error")
        
        let serverError = MCPApprovalError.serverSetupError("test server error")
        XCTAssertEqual(serverError.errorDescription, "MCP approval server setup error: test server error")
        
        let commError = MCPApprovalError.communicationError("test comm error")
        XCTAssertEqual(commError.errorDescription, "MCP approval communication error: test comm error")
    }
}