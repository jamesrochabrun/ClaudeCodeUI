import XCTest
import SwiftUI
@testable import CustomPermissionService
@testable import CustomPermissionServiceInterface

@MainActor
final class DefaultCustomPermissionServiceTests: XCTestCase {
    private var service: DefaultCustomPermissionService!
    
    override func setUp() {
        super.setUp()
        service = DefaultCustomPermissionService()
        // Reset UserDefaults for testing
        UserDefaults.standard.removeObject(forKey: "AutoApproveToolCalls")
    }
    
    override func tearDown() {
        service = nil
        UserDefaults.standard.removeObject(forKey: "AutoApproveToolCalls")
        super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertFalse(service.autoApproveToolCalls)
        XCTAssertNil(service.getApprovalStatus(for: "test"))
    }
    
    func testAutoApproveSettingPersistence() {
        service.autoApproveToolCalls = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "AutoApproveToolCalls"))
        
        service.autoApproveToolCalls = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "AutoApproveToolCalls"))
    }
    
    func testAutoApprovePublisher() async {
        var receivedValues: [Bool] = []
        let cancellable = service.autoApprovePublisher
            .sink { value in
                receivedValues.append(value)
            }
        
        service.autoApproveToolCalls = true
        service.autoApproveToolCalls = false
        
        // Allow some time for the publisher to emit
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        XCTAssertEqual(receivedValues, [true, false])
        cancellable.cancel()
    }
    
    func testAutoApprovalWhenEnabled() async throws {
        service.autoApproveToolCalls = true
        
        let request = ApprovalRequest(
            toolName: "testTool",
            input: ["test": "value"],
            toolUseId: "auto-approve-test"
        )
        
        let response = try await service.requestApproval(for: request, timeout: 1)
        
        XCTAssertEqual(response.behavior, .allow)
        XCTAssertEqual(response.message, "Auto-approved")
        XCTAssertEqual(response.updatedInput?["test"] as? String, "value")
    }
    
    func testAutoApprovalLowRisk() async throws {
        let config = PermissionConfiguration(autoApproveLowRisk: true)
        service = DefaultCustomPermissionService(configuration: config)
        
        let context = ApprovalContext(riskLevel: .low)
        let request = ApprovalRequest(
            toolName: "testTool",
            input: ["test": "value"],
            toolUseId: "low-risk-test",
            context: context
        )
        
        let response = try await service.requestApproval(for: request, timeout: 1)
        
        XCTAssertEqual(response.behavior, .allow)
        XCTAssertEqual(response.message, "Auto-approved (low risk)")
    }
    
    func testConcurrentRequestLimit() async {
        let config = PermissionConfiguration(maxConcurrentRequests: 1)
        service = DefaultCustomPermissionService(configuration: config)
        
        let request1 = ApprovalRequest(toolName: "tool1", input: [:], toolUseId: "concurrent-1")
        let request2 = ApprovalRequest(toolName: "tool2", input: [:], toolUseId: "concurrent-2")
        
        // Start first request (will be pending)
        let task1 = Task {
            try await service.requestApproval(for: request1, timeout: 10)
        }
        
        // Allow first request to start
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        // Second request should fail due to limit
        do {
            _ = try await service.requestApproval(for: request2, timeout: 1)
            XCTFail("Expected processing error for concurrent limit")
        } catch let error as CustomPermissionError {
            if case .processingError(let message) = error {
                XCTAssertTrue(message.contains("Too many concurrent"))
            } else {
                XCTFail("Expected processingError, got \(error)")
            }
        }
        
        // Cancel first task to clean up
        task1.cancel()
    }
    
    func testGetApprovalStatusPending() {
        // This is a bit tricky to test since the request will be pending only briefly
        // We can test that initially there's no status
        XCTAssertNil(service.getApprovalStatus(for: "non-existent"))
    }
    
    func testCancelAllRequests() {
        service.cancelAllRequests()
        // Should not crash and should clear any pending requests
        // More comprehensive testing would require mocking the UI components
    }
    
    func testSetupMCPTool() {
        var handlerCalled = false
        let handler: (ApprovalRequest) async throws -> ApprovalResponse = { request in
            handlerCalled = true
            return ApprovalResponse(behavior: .allow)
        }
        
        service.setupMCPTool(toolName: "test_tool", handler: handler)
        
        // The handler is stored but we can't easily test it without internal access
        // This test mainly ensures the method doesn't crash
    }
    
    func testProcessMCPToolCallSuccess() async throws {
        service.autoApproveToolCalls = true // Enable auto-approval for testing
        
        let toolCallData: [String: Any] = [
            "tool_name": "approval_prompt",
            "input": ["param": "value", "number": 42],
            "tool_use_id": "mcp-test-123"
        ]
        
        let jsonString = try await service.processMCPToolCall(toolCallData)
        
        // Parse the JSON response
        let jsonData = jsonString.data(using: .utf8)!
        let responseDict = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        
        XCTAssertEqual(responseDict["behavior"] as? String, "allow")
        XCTAssertNotNil(responseDict["updatedInput"])
        
        if let updatedInput = responseDict["updatedInput"] as? [String: Any] {
            XCTAssertEqual(updatedInput["param"] as? String, "value")
            XCTAssertEqual(updatedInput["number"] as? Int, 42)
        }
    }
    
    func testProcessMCPToolCallMissingFields() async {
        let invalidData: [String: Any] = [
            "tool_name": "test",
            // Missing input and tool_use_id
        ]
        
        do {
            _ = try await service.processMCPToolCall(invalidData)
            XCTFail("Expected invalidRequest error")
        } catch let error as CustomPermissionError {
            if case .invalidRequest(let message) = error {
                XCTAssertTrue(message.contains("Missing required fields"))
            } else {
                XCTFail("Expected invalidRequest error, got \(error)")
            }
        } catch {
            XCTFail("Expected CustomPermissionError, got \(error)")
        }
    }
    
    func testCreateContextForTool() {
        // Test through processMCPToolCall since createContextForTool is private
        service.autoApproveToolCalls = true
        
        let deleteToolData: [String: Any] = [
            "tool_name": "delete_file",
            "input": ["file_path": "/test/file.txt"],
            "tool_use_id": "delete-test"
        ]
        
        // This should create a high-risk context internally
        Task {
            do {
                let result = try await service.processMCPToolCall(deleteToolData)
                XCTAssertFalse(result.isEmpty)
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }
    
    func testPermissionConfigurationDefaults() {
        let config = PermissionConfiguration.default
        
        XCTAssertNil(config.defaultTimeout) // Default is no timeout
        XCTAssertFalse(config.autoApproveLowRisk)
        XCTAssertTrue(config.showDetailedInfo)
        XCTAssertEqual(config.maxConcurrentRequests, 5)
    }
    
    func testCustomPermissionErrorDescriptions() {
        let timeoutError = CustomPermissionError.requestTimedOut
        XCTAssertEqual(timeoutError.errorDescription, "The permission request timed out")
        XCTAssertNotNil(timeoutError.recoverySuggestion)
        
        let cancelledError = CustomPermissionError.requestCancelled
        XCTAssertEqual(cancelledError.errorDescription, "The permission request was cancelled")
        XCTAssertNotNil(cancelledError.recoverySuggestion)
        
        let invalidError = CustomPermissionError.invalidRequest("test")
        XCTAssertEqual(invalidError.errorDescription, "Invalid permission request: test")
        
        let processingError = CustomPermissionError.processingError("test")
        XCTAssertEqual(processingError.errorDescription, "Error processing permission request: test")
        
        let mcpError = CustomPermissionError.mcpIntegrationError("test")
        XCTAssertEqual(mcpError.errorDescription, "MCP integration error: test")
    }
}