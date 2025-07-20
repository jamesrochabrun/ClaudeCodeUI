import XCTest
@testable import CustomPermissionServiceInterface

@MainActor
final class MockCustomPermissionServiceTests: XCTestCase {
    private var service: MockCustomPermissionService!
    
    override func setUp() {
        super.setUp()
        service = MockCustomPermissionService()
    }
    
    override func tearDown() {
        service = nil
        super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertFalse(service.autoApproveToolCalls)
        XCTAssertEqual(service.requestApprovalCallCount, 0)
        XCTAssertNil(service.lastRequest)
        XCTAssertEqual(service.cancelAllRequestsCallCount, 0)
    }
    
    func testAutoApprovePublisher() async {
        var receivedValues: [Bool] = []
        let cancellable = service.autoApprovePublisher
            .sink { value in
                receivedValues.append(value)
            }
        
        service.autoApproveToolCalls = true
        service.autoApproveToolCalls = false
        service.autoApproveToolCalls = true
        
        // Allow some time for the publisher to emit
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        XCTAssertEqual(receivedValues, [true, false, true])
        cancellable.cancel()
    }
    
    func testRequestApprovalSuccess() async throws {
        service.shouldApprove = true
        
        let request = ApprovalRequest(
            toolName: "testTool",
            input: ["test": "value"],
            toolUseId: "test-123"
        )
        
        let response = try await service.requestApproval(for: request, timeout: 30)
        
        XCTAssertEqual(service.requestApprovalCallCount, 1)
        XCTAssertEqual(service.lastRequest?.toolUseId, "test-123")
        XCTAssertEqual(service.lastTimeout, 30)
        XCTAssertEqual(response.behavior, .allow)
        XCTAssertEqual(response.message, "Mock approval")
    }
    
    func testRequestApprovalDenial() async throws {
        service.shouldApprove = false
        
        let request = ApprovalRequest(
            toolName: "testTool",
            input: ["test": "value"],
            toolUseId: "test-456"
        )
        
        let response = try await service.requestApproval(for: request, timeout: 60)
        
        XCTAssertEqual(response.behavior, .deny)
        XCTAssertEqual(response.message, "Mock denial")
        XCTAssertNil(response.updatedInput)
    }
    
    func testRequestApprovalTimeout() async {
        service.shouldTimeout = true
        
        let request = ApprovalRequest(
            toolName: "testTool",
            input: ["test": "value"],
            toolUseId: "test-789"
        )
        
        do {
            _ = try await service.requestApproval(for: request, timeout: 30)
            XCTFail("Expected timeout error")
        } catch let error as CustomPermissionError {
            if case .requestTimedOut = error {
                // Expected
            } else {
                XCTFail("Expected requestTimedOut error, got \(error)")
            }
        } catch {
            XCTFail("Expected CustomPermissionError, got \(error)")
        }
    }
    
    func testRequestApprovalError() async {
        service.shouldThrowError = true
        
        let request = ApprovalRequest(
            toolName: "testTool",
            input: ["test": "value"],
            toolUseId: "test-error"
        )
        
        do {
            _ = try await service.requestApproval(for: request, timeout: 30)
            XCTFail("Expected processing error")
        } catch let error as CustomPermissionError {
            if case .processingError(let message) = error {
                XCTAssertEqual(message, "Mock error")
            } else {
                XCTFail("Expected processingError, got \(error)")
            }
        } catch {
            XCTFail("Expected CustomPermissionError, got \(error)")
        }
    }
    
    func testCustomResponse() async throws {
        let customResponse = ApprovalResponse(
            behavior: .allow,
            updatedInput: ["modified": "custom"],
            message: "Custom response"
        )
        service.customResponse = customResponse
        
        let request = ApprovalRequest(
            toolName: "testTool",
            input: ["test": "value"],
            toolUseId: "test-custom"
        )
        
        let response = try await service.requestApproval(for: request, timeout: 30)
        
        XCTAssertEqual(response.behavior, .allow)
        XCTAssertEqual(response.message, "Custom response")
        XCTAssertEqual(response.updatedInputAsAny?["modified"] as? String, "custom")
    }
    
    func testCancelAllRequests() {
        service.setApprovalStatus(for: "pending-1", status: .pending)
        service.setApprovalStatus(for: "approved-1", status: .approved(ApprovalResponse(behavior: .allow)))
        
        service.cancelAllRequests()
        
        XCTAssertEqual(service.cancelAllRequestsCallCount, 1)
        
        if case .cancelled = service.getApprovalStatus(for: "pending-1") {
            // Expected
        } else {
            XCTFail("Expected cancelled status for pending request")
        }
        
        if case .approved = service.getApprovalStatus(for: "approved-1") {
            // Expected - should remain approved
        } else {
            XCTFail("Approved request should not be cancelled")
        }
    }
    
    func testGetApprovalStatus() {
        let response = ApprovalResponse(behavior: .allow)
        service.setApprovalStatus(for: "test-123", status: .approved(response))
        
        let status = service.getApprovalStatus(for: "test-123")
        XCTAssertEqual(service.getApprovalStatusCallCount, 1)
        
        if case .approved(let approvalResponse) = status {
            XCTAssertEqual(approvalResponse.behavior, .allow)
        } else {
            XCTFail("Expected approved status")
        }
    }
    
    func testProcessMCPToolCall() async throws {
        let toolCallData: [String: Any] = [
            "tool_name": "approval_prompt",
            "input": ["param": "value"],
            "tool_use_id": "mcp-123"
        ]
        
        let jsonString = try await service.processMCPToolCall(toolCallData)
        
        XCTAssertEqual(service.processMCPToolCallCount, 1)
        XCTAssertEqual(service.requestApprovalCallCount, 1)
        
        // Verify JSON response format
        let jsonData = jsonString.data(using: .utf8)!
        let responseDict = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        
        XCTAssertEqual(responseDict["behavior"] as? String, "allow")
        XCTAssertNotNil(responseDict["updatedInput"])
    }
    
    func testProcessMCPToolCallInvalidData() async {
        let invalidData: [String: Any] = [
            "invalid": "data"
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
    
    func testReset() async throws {
        // Set some state
        service.autoApproveToolCalls = true
        service.shouldApprove = false
        service.shouldTimeout = true
        service.customResponse = ApprovalResponse(behavior: .deny)
        
        // Make some calls
        let request = ApprovalRequest(toolName: "test", input: [:], toolUseId: "test")
        try? await service.requestApproval(for: request, timeout: 1)
        service.cancelAllRequests()
        
        // Reset
        service.reset()
        
        // Verify everything is reset
        XCTAssertFalse(service.autoApproveToolCalls)
        XCTAssertTrue(service.shouldApprove)
        XCTAssertFalse(service.shouldTimeout)
        XCTAssertNil(service.customResponse)
        XCTAssertEqual(service.requestApprovalCallCount, 0)
        XCTAssertEqual(service.cancelAllRequestsCallCount, 0)
    }
}