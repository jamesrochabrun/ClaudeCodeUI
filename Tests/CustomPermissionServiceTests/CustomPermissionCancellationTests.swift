//
//  CustomPermissionCancellationTests.swift
//  CustomPermissionServiceTests
//
//  Tests for approval cancellation functionality
//

import XCTest
import SwiftUI
@testable import CustomPermissionService
@testable import CCCustomPermissionServiceInterface

@MainActor
final class CustomPermissionCancellationTests: XCTestCase {
  private var service: DefaultCustomPermissionService!
  
  override func setUp() {
    super.setUp()
    service = DefaultCustomPermissionService()
    // Ensure auto-approve is off for testing
    service.autoApproveToolCalls = false
  }
  
  override func tearDown() {
    // Clean up any pending requests
    service.cancelAllRequests()
    service = nil
    super.tearDown()
  }
  
  // MARK: - Cancel All Requests Tests
  
  func testCancelAllRequestsTerminatesPendingApprovals() async throws {
    // Given - Multiple pending approval requests
    let request1 = ApprovalRequest(
      toolName: "tool1",
      input: ["test": "value1"],
      toolUseId: "cancel-test-1"
    )
    
    let request2 = ApprovalRequest(
      toolName: "tool2",
      input: ["test": "value2"],
      toolUseId: "cancel-test-2"
    )
    
    // Start both requests (they will be pending)
    let task1 = Task<ApprovalResponse?, Error> {
      do {
        return try await service.requestApproval(for: request1, timeout: 10)
      } catch CustomPermissionError.requestCancelled {
        return nil // Expected cancellation
      }
    }
    
    let task2 = Task<ApprovalResponse?, Error> {
      do {
        return try await service.requestApproval(for: request2, timeout: 10)
      } catch CustomPermissionError.requestCancelled {
        return nil // Expected cancellation
      }
    }
    
    // Give them time to become pending
    try await Task.sleep(nanoseconds: 50_000_000) // 50ms
    
    // When - Cancel all requests
    service.cancelAllRequests()
    
    // Then - Both tasks should complete with cancellation
    let result1 = try await task1.value
    let result2 = try await task2.value
    
    XCTAssertNil(result1, "Request 1 should have been cancelled")
    XCTAssertNil(result2, "Request 2 should have been cancelled")
    
    // Verify no pending requests remain
    XCTAssertNil(service.getApprovalStatus(for: "cancel-test-1"))
    XCTAssertNil(service.getApprovalStatus(for: "cancel-test-2"))
  }
  
  func testCancelAllRequestsHidesActiveToast() async throws {
    // Given - A pending request with visible toast
    let request = ApprovalRequest(
      toolName: "testTool",
      input: ["test": "value"],
      toolUseId: "toast-cancel-test"
    )
    
    // Start request (will show toast)
    let _ = Task {
      try? await service.requestApproval(for: request, timeout: 10)
    }
    
    // Wait for toast to appear
    try await Task.sleep(nanoseconds: 100_000_000) // 100ms
    
    // Verify toast is visible
    XCTAssertNotNil(service.currentToastRequest, "Toast should be visible")
    XCTAssertTrue(service.isToastVisible, "Toast should be visible")
    
    // When - Cancel all requests
    service.cancelAllRequests()
    
    // Give animation time to complete
    try await Task.sleep(nanoseconds: 600_000_000) // 600ms for animation
    
    // Then - Toast should be hidden
    XCTAssertFalse(service.isToastVisible, "Toast should be hidden after cancellation")
    XCTAssertNil(service.currentToastRequest, "Toast request should be cleared")
  }
  
  func testTimeoutTasksCancelledProperly() async throws {
    // Given - A request with a timeout
    let request = ApprovalRequest(
      toolName: "timeoutTest",
      input: ["test": "value"],
      toolUseId: "timeout-cancel-test"
    )
    
    // Start request with 2 second timeout
    let task = Task<ApprovalResponse?, Error> {
      do {
        return try await service.requestApproval(for: request, timeout: 2.0)
      } catch {
        // Check if it's cancellation (expected) or timeout (unexpected)
        if error is CustomPermissionError {
          switch error as! CustomPermissionError {
          case .requestCancelled:
            return nil // Expected
          case .requestTimedOut:
            XCTFail("Should not timeout, should be cancelled")
            return nil
          default:
            XCTFail("Unexpected error: \(error)")
            return nil
          }
        }
        return nil
      }
    }
    
    // Wait briefly
    try await Task.sleep(nanoseconds: 100_000_000) // 100ms
    
    // When - Cancel before timeout
    service.cancelAllRequests()
    
    // Then - Should get cancellation, not timeout
    let result = try await task.value
    XCTAssertNil(result, "Request should have been cancelled, not timed out")
  }
  
  func testCancelAllRequestsIdempotent() async throws {
    // Given - Some pending requests
    let request = ApprovalRequest(
      toolName: "idempotentTest",
      input: ["test": "value"],
      toolUseId: "idempotent-test"
    )
    
    let _ = Task {
      try? await service.requestApproval(for: request, timeout: 10)
    }
    
    try await Task.sleep(nanoseconds: 50_000_000) // 50ms
    
    // When - Cancel multiple times
    service.cancelAllRequests()
    service.cancelAllRequests()
    service.cancelAllRequests()
    
    // Then - Should not crash or cause issues
    XCTAssertNil(service.getApprovalStatus(for: "idempotent-test"))
    
    // Verify service still works after multiple cancellations
    service.autoApproveToolCalls = true
    let newRequest = ApprovalRequest(
      toolName: "afterCancel",
      input: ["test": "value"],
      toolUseId: "after-cancel-test"
    )
    
    let response = try await service.requestApproval(for: newRequest, timeout: 1)
    XCTAssertEqual(response.behavior, .allow, "Service should still work after multiple cancellations")
  }
  
  // MARK: - Integration with Stream Cancellation
  
  func testApprovalCancellationDuringActiveToastInteraction() async throws {
    // Given - A request with toast showing
    let request = ApprovalRequest(
      toolName: "interactionTest",
      input: ["file": "/test.txt"],
      toolUseId: "interaction-test"
    )
    
    let requestTask = Task<ApprovalResponse?, Error> {
      do {
        return try await service.requestApproval(for: request, timeout: 5)
      } catch CustomPermissionError.requestCancelled {
        return nil
      }
    }
    
    // Wait for toast to appear
    try await Task.sleep(nanoseconds: 100_000_000) // 100ms
    
    // Simulate user about to interact but stream gets cancelled
    XCTAssertTrue(service.isToastVisible, "Toast should be visible")
    
    // When - Stream cancellation triggers cancelAllRequests
    service.cancelAllRequests()
    
    // Then - Request should be cancelled even if user was about to approve
    let result = try await requestTask.value
    XCTAssertNil(result, "Request should be cancelled")
    
    // Toast should be hidden
    try await Task.sleep(nanoseconds: 600_000_000) // Wait for animation
    XCTAssertFalse(service.isToastVisible, "Toast should be hidden")
  }
  
  func testRapidRequestAndCancelCycles() async throws {
    // Test rapid cycles of requests and cancellations
    for i in 0..<5 {
      // Create a request
      let request = ApprovalRequest(
        toolName: "rapidTest\(i)",
        input: ["index": "\(i)"],
        toolUseId: "rapid-test-\(i)"
      )
      
      // Start request
      let _ = Task {
        try? await service.requestApproval(for: request, timeout: 10)
      }
      
      // Small delay
      try await Task.sleep(nanoseconds: 10_000_000) // 10ms
      
      // Cancel it
      service.cancelAllRequests()
      
      // Verify cleanup
      XCTAssertNil(service.getApprovalStatus(for: "rapid-test-\(i)"))
    }
    
    // Service should still be functional
    service.autoApproveToolCalls = true
    let finalRequest = ApprovalRequest(
      toolName: "finalTest",
      input: ["test": "final"],
      toolUseId: "final-test"
    )
    
    let response = try await service.requestApproval(for: finalRequest, timeout: 1)
    XCTAssertEqual(response.behavior, .allow, "Service should work after rapid cycles")
  }
  
  // MARK: - Edge Cases
  
  func testCancelWithNoActiveRequests() async throws {
    // Given - No active requests
    XCTAssertNil(service.currentToastRequest)
    
    // When - Cancel all requests
    service.cancelAllRequests()
    
    // Then - Should not crash or cause issues
    XCTAssertNil(service.currentToastRequest)
    XCTAssertFalse(service.isToastVisible)
    
    // Service should still work
    service.autoApproveToolCalls = true
    let request = ApprovalRequest(
      toolName: "afterEmpty",
      input: ["test": "value"],
      toolUseId: "after-empty"
    )
    
    let response = try await service.requestApproval(for: request, timeout: 1)
    XCTAssertEqual(response.behavior, .allow)
  }
  
  func testCancelDuringAutoApproval() async throws {
    // Given - Auto-approve is enabled
    service.autoApproveToolCalls = true
    
    let request = ApprovalRequest(
      toolName: "autoTest",
      input: ["test": "value"],
      toolUseId: "auto-test"
    )
    
    // When - Request with auto-approval and immediate cancel
    let task = Task {
      try await service.requestApproval(for: request, timeout: 1)
    }
    
    service.cancelAllRequests() // This should have no effect on auto-approved
    
    // Then - Auto-approved request should complete normally
    let response = try await task.value
    XCTAssertEqual(response.behavior, .allow)
    XCTAssertEqual(response.message, "Auto-approved")
  }
}