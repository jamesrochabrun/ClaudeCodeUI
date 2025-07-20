import XCTest
import SwiftUI
@testable import CustomPermissionService
@testable import CustomPermissionServiceInterface

@MainActor
final class ApprovalPromptViewTests: XCTestCase {
    
    @MainActor
    func testApprovalPromptStateCreation() {
        let request = ApprovalRequest(
            toolName: "testTool",
            input: ["param": .string("value")],
            toolUseId: "test-123"
        )
        
        var approvedCalled = false
        var deniedCalled = false
        var approvedInput: [String: Any]?
        var deniedReason: String?
        
        let state = ApprovalPromptState(
            request: request,
            onApprove: { input in
                approvedCalled = true
                approvedInput = input
            },
            onDeny: { reason in
                deniedCalled = true
                deniedReason = reason
            }
        )
        
        XCTAssertEqual(state.request.toolUseId, "test-123")
        XCTAssertEqual(state.modifiedInput["param"], .string("value"))
        XCTAssertFalse(state.isProcessing)
        XCTAssertEqual(state.denyReason, "")
        
        // Test approval
        state.approve()
        XCTAssertTrue(state.isProcessing)
        XCTAssertTrue(approvedCalled)
        XCTAssertNotNil(approvedInput)
        
        // Reset for denial test
        approvedCalled = false
        state.isProcessing = false
        
        // Test denial
        state.denyReason = "Test reason"
        state.deny()
        XCTAssertTrue(state.isProcessing)
        XCTAssertTrue(deniedCalled)
        XCTAssertEqual(deniedReason, "Test reason")
    }
    
    func testApprovalPromptStateModification() {
        let request = ApprovalRequest(
            toolName: "testTool",
            input: ["original": .string("value"), "number": .integer(42)],
            toolUseId: "test-123"
        )
        
        let state = ApprovalPromptState(
            request: request,
            onApprove: { _ in },
            onDeny: { _ in }
        )
        
        // Test modification
        state.modifiedInput["original"] = .string("modified")
        state.modifiedInput["new"] = .string("added")
        
        XCTAssertEqual(state.modifiedInput["original"], .string("modified"))
        XCTAssertEqual(state.modifiedInput["new"], .string("added"))
        XCTAssertEqual(state.modifiedInput["number"], .integer(42))
    }
    
    func testRiskLevelProperties() {
        XCTAssertEqual(RiskLevel.low.displayName, "Low Risk")
        XCTAssertEqual(RiskLevel.medium.displayName, "Medium Risk")  
        XCTAssertEqual(RiskLevel.high.displayName, "High Risk")
        XCTAssertEqual(RiskLevel.critical.displayName, "Critical Risk")
        
        XCTAssertEqual(RiskLevel.low.color, "green")
        XCTAssertEqual(RiskLevel.medium.color, "yellow")
        XCTAssertEqual(RiskLevel.high.color, "orange")
        XCTAssertEqual(RiskLevel.critical.color, "red")
    }
}

final class PermissionConfigurationTests: XCTestCase {
    
    func testDefaultConfiguration() {
        let config = PermissionConfiguration.default
        
        XCTAssertEqual(config.defaultTimeout, 240.0)
        XCTAssertFalse(config.autoApproveLowRisk)
        XCTAssertTrue(config.showDetailedInfo)
        XCTAssertEqual(config.maxConcurrentRequests, 5)
    }
    
    func testCustomConfiguration() {
        let config = PermissionConfiguration(
            defaultTimeout: 120.0,
            autoApproveLowRisk: true,
            showDetailedInfo: false,
            maxConcurrentRequests: 3
        )
        
        XCTAssertEqual(config.defaultTimeout, 120.0)
        XCTAssertTrue(config.autoApproveLowRisk)
        XCTAssertFalse(config.showDetailedInfo)
        XCTAssertEqual(config.maxConcurrentRequests, 3)
    }
}

final class ApprovalContextTests: XCTestCase {
    
    func testDefaultContext() {
        let context = ApprovalContext()
        
        XCTAssertNil(context.description)
        XCTAssertEqual(context.riskLevel, .medium)
        XCTAssertFalse(context.isSensitive)
        XCTAssertTrue(context.affectedResources.isEmpty)
    }
    
    func testCustomContext() {
        let context = ApprovalContext(
            description: "Test operation",
            riskLevel: .high,
            isSensitive: true,
            affectedResources: ["file1.txt", "file2.txt"]
        )
        
        XCTAssertEqual(context.description, "Test operation")
        XCTAssertEqual(context.riskLevel, .high)
        XCTAssertTrue(context.isSensitive)
        XCTAssertEqual(context.affectedResources, ["file1.txt", "file2.txt"])
    }
}