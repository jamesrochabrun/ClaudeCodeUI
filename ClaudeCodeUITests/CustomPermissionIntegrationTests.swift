//
//  CustomPermissionIntegrationTests.swift
//  ClaudeCodeUITests
//
//  Tests for the integration of CustomPermissionService with ClaudeCodeSDK and MCP configuration
//

import ClaudeCodeSDK
import CustomPermissionService
import CustomPermissionServiceInterface
import SwiftUI
import XCTest
@testable import ClaudeCodeUI

// MARK: - CustomPermissionIntegrationTests

@MainActor
final class CustomPermissionIntegrationTests: XCTestCase {

  // MARK: Internal

  override func setUp() {
    super.setUp()
    globalPreferences = GlobalPreferencesStorage()
    dependencyContainer = DependencyContainer(globalPreferences: globalPreferences)
    customPermissionService = dependencyContainer.customPermissionService
  }

  override func tearDown() {
    customPermissionService = nil
    dependencyContainer = nil
    globalPreferences = nil
    super.tearDown()
  }

  func testCustomPermissionServiceIsIntegrated() {
    XCTAssertNotNil(dependencyContainer.customPermissionService)
    XCTAssertTrue(dependencyContainer.customPermissionService is DefaultCustomPermissionService)
  }

  func testGlobalPreferencesHasPermissionSettings() {
    // Test default values
    XCTAssertFalse(globalPreferences.autoApproveToolCalls)
    XCTAssertFalse(globalPreferences.autoApproveLowRisk)
    XCTAssertTrue(globalPreferences.showDetailedPermissionInfo)
    XCTAssertEqual(globalPreferences.permissionRequestTimeout, 240.0)
    XCTAssertEqual(globalPreferences.maxConcurrentPermissionRequests, 5)

    // Test setting values
    globalPreferences.autoApproveToolCalls = true
    globalPreferences.autoApproveLowRisk = true
    globalPreferences.showDetailedPermissionInfo = false
    globalPreferences.permissionRequestTimeout = 120.0
    globalPreferences.maxConcurrentPermissionRequests = 3

    XCTAssertTrue(globalPreferences.autoApproveToolCalls)
    XCTAssertTrue(globalPreferences.autoApproveLowRisk)
    XCTAssertFalse(globalPreferences.showDetailedPermissionInfo)
    XCTAssertEqual(globalPreferences.permissionRequestTimeout, 120.0)
    XCTAssertEqual(globalPreferences.maxConcurrentPermissionRequests, 3)
  }

  func testPermissionConfigurationCreation() {
    globalPreferences.autoApproveLowRisk = true
    globalPreferences.showDetailedPermissionInfo = false
    globalPreferences.permissionRequestTimeout = 180.0
    globalPreferences.maxConcurrentPermissionRequests = 2

    let config = globalPreferences.createPermissionConfiguration()

    XCTAssertTrue(config.autoApproveLowRisk)
    XCTAssertFalse(config.showDetailedInfo)
    XCTAssertEqual(config.defaultTimeout, 180.0)
    XCTAssertEqual(config.maxConcurrentRequests, 2)
  }

  func testPermissionConfigurationUpdate() {
    let config = PermissionConfiguration(
      defaultTimeout: 300.0,
      autoApproveLowRisk: true,
      showDetailedInfo: false,
      maxConcurrentRequests: 1
    )

    globalPreferences.updateFromPermissionConfiguration(config)

    XCTAssertEqual(globalPreferences.permissionRequestTimeout, 300.0)
    XCTAssertTrue(globalPreferences.autoApproveLowRisk)
    XCTAssertFalse(globalPreferences.showDetailedPermissionInfo)
    XCTAssertEqual(globalPreferences.maxConcurrentPermissionRequests, 1)
  }

  func testResetToDefaults() {
    // Change values
    globalPreferences.autoApproveToolCalls = true
    globalPreferences.autoApproveLowRisk = true
    globalPreferences.showDetailedPermissionInfo = false
    globalPreferences.permissionRequestTimeout = 60.0
    globalPreferences.maxConcurrentPermissionRequests = 1

    // Reset
    globalPreferences.resetToDefaults()

    // Verify defaults are restored
    XCTAssertFalse(globalPreferences.autoApproveToolCalls)
    XCTAssertFalse(globalPreferences.autoApproveLowRisk)
    XCTAssertTrue(globalPreferences.showDetailedPermissionInfo)
    XCTAssertEqual(globalPreferences.permissionRequestTimeout, 240.0)
    XCTAssertEqual(globalPreferences.maxConcurrentPermissionRequests, 5)
  }

  func testAutoApprovePublisher() async {
    var receivedValues: [Bool] = []
    let cancellable = customPermissionService.autoApprovePublisher
      .sink { value in
        receivedValues.append(value)
      }

    await customPermissionService.setAutoApprove(true)
    await customPermissionService.setAutoApprove(false)
    await customPermissionService.setAutoApprove(true)

    // Allow time for publisher to emit
    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

    XCTAssertEqual(receivedValues, [true, false, true])
    cancellable.cancel()
  }

  func testMCPIntegrationWithGlobalPreferences() {
    // Test that MCP configuration includes approval tool when permissions are configured
    let mcpHelper = ApprovalMCPHelper(permissionService: customPermissionService)
    let mcpConfig = mcpHelper.createCompleteMCPConfig()

    XCTAssertTrue(mcpConfig["mcpServers"] is [String: Any])

    if let servers = mcpConfig["mcpServers"] as? [String: Any] {
      XCTAssertTrue(servers.keys.contains("approval_server"))
    }
  }

  func testChatViewModelIntegration() {
    // Test that ChatViewModel can be created with CustomPermissionService
    let mockSessionStorage = MockSessionStorage()
    let mockSettingsStorage = SettingsStorageManager()
    let mockClaudeClient = ClaudeCodeClient()

    let chatViewModel = ChatViewModel(
      claudeClient: mockClaudeClient,
      sessionStorage: mockSessionStorage,
      settingsStorage: mockSettingsStorage,
      globalPreferences: globalPreferences,
      customPermissionService: customPermissionService
    )

    XCTAssertNotNil(chatViewModel)
    XCTAssertIdentical(chatViewModel.customPermissionService as AnyObject, customPermissionService as AnyObject)
  }

  // MARK: Private

  private var globalPreferences: GlobalPreferencesStorage!
  private var dependencyContainer: DependencyContainer!
  private var customPermissionService: CustomPermissionService!

}

// MARK: - Test Helpers

extension CustomPermissionService {
  fileprivate func setAutoApprove(_ value: Bool) async {
    await MainActor.run {
      self.autoApproveToolCalls = value
    }
  }
}

/// Mock implementations for testing
private class MockSessionStorage: SessionStorageProtocol {

  // MARK: Internal

  func saveSessions(_ sessions: [StoredSession]) async {
    for session in sessions {
      self.sessions[session.id] = session
    }
  }

  func loadSessions() async -> [StoredSession] {
    Array(sessions.values)
  }

  func deleteSession(withId id: String) async {
    sessions.removeValue(forKey: id)
  }

  // MARK: Private

  private var sessions: [String: StoredSession] = [:]

}

/// Integration test for the complete flow
@MainActor
final class CustomPermissionEndToEndTests: XCTestCase {

  func testCompletePermissionFlow() async throws {
    let globalPrefs = GlobalPreferencesStorage()
    let container = DependencyContainer(globalPreferences: globalPrefs)
    let permissionService = container.customPermissionService

    // Configure for auto-approval
    globalPrefs.autoApproveToolCalls = true

    // Create an approval request
    let request = ApprovalRequest(
      toolName: "Read",
      input: ["file_path": "/test/file.txt"],
      toolUseId: "test-integration-001"
    )

    // Request approval (should auto-approve)
    let response = try await permissionService.requestApproval(for: request, timeout: 5.0)

    XCTAssertEqual(response.behavior, .allow)
    XCTAssertEqual(response.message, "Auto-approved")
    XCTAssertNotNil(response.updatedInput)
  }

  func testMCPToolCallProcessing() async throws {
    let globalPrefs = GlobalPreferencesStorage()
    let container = DependencyContainer(globalPreferences: globalPrefs)
    let permissionService = container.customPermissionService

    // Enable auto-approval for testing
    globalPrefs.autoApproveToolCalls = true

    let toolCallData: [String: Any] = [
      "tool_name": "approval_prompt",
      "input": ["file_path": "/test/integration.txt", "operation": "read"],
      "tool_use_id": "mcp-integration-001",
    ]

    let jsonResponse = try await permissionService.processMCPToolCall(toolCallData)

    // Parse the JSON response
    let data = jsonResponse.data(using: .utf8)!
    let responseDict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

    XCTAssertEqual(responseDict["behavior"] as? String, "allow")
    XCTAssertNotNil(responseDict["updatedInput"])

    if let updatedInput = responseDict["updatedInput"] as? [String: Any] {
      XCTAssertEqual(updatedInput["file_path"] as? String, "/test/integration.txt")
      XCTAssertEqual(updatedInput["operation"] as? String, "read")
    }
  }
}
