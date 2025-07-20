import XCTest
@testable import CustomPermissionServiceInterface

final class ApprovalRequestTests: XCTestCase {
    
    func testApprovalRequestCreation() {
        let context = ApprovalContext(
            description: "Test operation",
            riskLevel: .medium,
            isSensitive: true,
            affectedResources: ["file1.txt", "file2.txt"]
        )
        
        let request = ApprovalRequest(
            toolName: "testTool",
            input: ["param1": "value1", "param2": 42],
            toolUseId: "test-123",
            context: context
        )
        
        XCTAssertEqual(request.toolName, "testTool")
        XCTAssertEqual(request.toolUseId, "test-123")
        XCTAssertEqual(request.inputAsAny["param1"] as? String, "value1")
        XCTAssertEqual(request.inputAsAny["param2"] as? Int, 42)
        XCTAssertNotNil(request.context)
        XCTAssertEqual(request.context?.riskLevel, .medium)
        XCTAssertTrue(request.context?.isSensitive == true)
    }
    
    func testApprovalRequestCodable() throws {
        let request = ApprovalRequest(
            toolName: "testTool",
            input: ["param1": "value1", "param2": 42, "param3": true],
            toolUseId: "test-123"
        )
        
        let encoded = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(ApprovalRequest.self, from: encoded)
        
        XCTAssertEqual(decoded.toolName, request.toolName)
        XCTAssertEqual(decoded.toolUseId, request.toolUseId)
        XCTAssertEqual(decoded.inputAsAny["param1"] as? String, "value1")
        XCTAssertEqual(decoded.inputAsAny["param2"] as? Int, 42)
        XCTAssertEqual(decoded.inputAsAny["param3"] as? Bool, true)
    }
    
    func testApprovalResponseCreation() {
        let response = ApprovalResponse(
            behavior: .allow,
            updatedInput: ["modified": "value"],
            message: "Approved with modifications"
        )
        
        XCTAssertEqual(response.behavior, .allow)
        XCTAssertEqual(response.updatedInputAsAny?["modified"] as? String, "value")
        XCTAssertEqual(response.message, "Approved with modifications")
    }
    
    func testApprovalResponseCodable() throws {
        let response = ApprovalResponse(
            behavior: .deny,
            updatedInput: nil,
            message: "Access denied"
        )
        
        let encoded = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(ApprovalResponse.self, from: encoded)
        
        XCTAssertEqual(decoded.behavior, .deny)
        XCTAssertNil(decoded.updatedInputAsAny)
        XCTAssertEqual(decoded.message, "Access denied")
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
    
    func testApprovalContextDefaults() {
        let context = ApprovalContext()
        
        XCTAssertNil(context.description)
        XCTAssertEqual(context.riskLevel, .medium)
        XCTAssertFalse(context.isSensitive)
        XCTAssertTrue(context.affectedResources.isEmpty)
    }
}