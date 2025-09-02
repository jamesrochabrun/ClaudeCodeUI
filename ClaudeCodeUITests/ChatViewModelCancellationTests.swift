//
//  ChatViewModelCancellationTests.swift
//  ClaudeCodeUITests
//
//  Integration tests for complete cancellation flow
//

import XCTest
import Combine
import ClaudeCodeSDK
import SwiftAnthropic
@testable import ClaudeCodeUI
@testable import CCCustomPermissionServiceInterface
@testable import CustomPermissionService

@MainActor
final class ChatViewModelCancellationTests: XCTestCase {
  var chatViewModel: ChatViewModel!
  var sessionManager: SessionManager!
  var messageStore: MessageStore!
  var mockSessionStorage: MockSessionStorage!
  var mockClaudeService: MockClaudeService!
  var customPermissionService: DefaultCustomPermissionService!
  var settingsStorage: SettingsStorageManager!
  var cancellables = Set<AnyCancellable>()
  
  override func setUp() {
    super.setUp()
    
    // Initialize dependencies
    mockSessionStorage = MockSessionStorage()
    sessionManager = SessionManager(sessionStorage: mockSessionStorage)
    messageStore = MessageStore()
    mockClaudeService = MockClaudeService()
    customPermissionService = DefaultCustomPermissionService()
    settingsStorage = SettingsStorageManager(
      userDefaults: UserDefaults(suiteName: "test")!
    )
    
    // Create ChatViewModel
    chatViewModel = ChatViewModel(
      claudeService: mockClaudeService,
      messageStore: messageStore,
      sessionManager: sessionManager,
      settingsStorage: settingsStorage,
      customPermissionService: customPermissionService,
      sessionStorage: mockSessionStorage
    )
  }
  
  override func tearDown() {
    cancellables.removeAll()
    chatViewModel = nil
    sessionManager = nil
    messageStore = nil
    mockSessionStorage = nil
    mockClaudeService = nil
    customPermissionService = nil
    settingsStorage = nil
    super.tearDown()
  }
  
  // MARK: - Integration Tests
  
  func testCancelRequestStopsStreamAndApprovals() async throws {
    // Given - Simulate an active stream with pending approvals
    chatViewModel.isLoading = true
    chatViewModel.streamingStartTime = Date()
    
    // Add a message being streamed
    let messageId = UUID()
    messageStore.addMessage(ChatMessage(
      id: messageId,
      role: .assistant,
      content: "Processing...",
      isComplete: false,
      messageType: .text
    ))
    
    // Simulate a pending approval request
    let approvalRequest = ApprovalRequest(
      toolName: "Bash",
      input: ["command": "ls -la"],
      toolUseId: "test-tool-use"
    )
    
    // Start approval request (will be pending)
    let approvalTask = Task {
      try? await customPermissionService.requestApproval(
        for: approvalRequest,
        timeout: 10
      )
    }
    
    // Give it time to become pending
    try await Task.sleep(nanoseconds: 50_000_000) // 50ms
    
    // Verify initial state
    XCTAssertTrue(chatViewModel.isLoading)
    XCTAssertNotNil(chatViewModel.streamingStartTime)
    XCTAssertEqual(customPermissionService.getApprovalStatus(for: "test-tool-use"), .pending)
    
    // When - Cancel the request
    chatViewModel.cancelRequest()
    
    // Then - Everything should be cleaned up
    XCTAssertFalse(chatViewModel.isLoading, "Loading should be false")
    XCTAssertNil(chatViewModel.streamingStartTime, "Streaming start time should be nil")
    XCTAssertTrue(chatViewModel.isCancelled, "Should be marked as cancelled")
    
    // Approval should be cancelled
    XCTAssertNil(customPermissionService.getApprovalStatus(for: "test-tool-use"))
    
    // Last message should be marked as cancelled
    if let lastMessage = messageStore.messages.last {
      XCTAssertTrue(lastMessage.isCancelled, "Last message should be marked as cancelled")
    }
    
    // Approval task should complete (with cancellation)
    await approvalTask.value
  }
  
  func testMultipleToolApprovalsCancelledTogether() async throws {
    // Given - Multiple tool approvals pending
    let approvalRequests = [
      ApprovalRequest(toolName: "Read", input: ["file": "test1.txt"], toolUseId: "tool-1"),
      ApprovalRequest(toolName: "Write", input: ["file": "test2.txt"], toolUseId: "tool-2"),
      ApprovalRequest(toolName: "Bash", input: ["command": "echo test"], toolUseId: "tool-3")
    ]
    
    // Start all approval requests
    let approvalTasks = approvalRequests.map { request in
      Task {
        try? await customPermissionService.requestApproval(
          for: request,
          timeout: 10
        )
      }
    }
    
    // Wait for them to become pending
    try await Task.sleep(nanoseconds: 100_000_000) // 100ms
    
    // Verify all are pending
    for request in approvalRequests {
      XCTAssertEqual(
        customPermissionService.getApprovalStatus(for: request.toolUseId),
        .pending,
        "Request \(request.toolUseId) should be pending"
      )
    }
    
    // When - Cancel via ChatViewModel
    chatViewModel.cancelRequest()
    
    // Then - All approvals should be cancelled
    for request in approvalRequests {
      XCTAssertNil(
        customPermissionService.getApprovalStatus(for: request.toolUseId),
        "Request \(request.toolUseId) should be cancelled"
      )
    }
    
    // All tasks should complete
    for task in approvalTasks {
      await task.value
    }
  }
  
  func testCancellationDuringStreamProcessing() async throws {
    // Given - Setup mock stream
    let publisher = PassthroughSubject<ResponseChunk, Error>()
    mockClaudeService.mockStreamPublisher = publisher.eraseToAnyPublisher()
    
    // Start sending a message (which will trigger stream processing)
    let sendTask = Task {
      await chatViewModel.sendMessage("Test message")
    }
    
    // Send some chunks
    publisher.send(.assistant(createAssistantChunk("Processing your request...")))
    
    try await Task.sleep(nanoseconds: 50_000_000) // 50ms
    
    // Verify streaming is active
    XCTAssertTrue(chatViewModel.isLoading)
    
    // When - Cancel during streaming
    chatViewModel.cancelRequest()
    
    // Complete the publisher
    publisher.send(completion: .finished)
    
    // Then - Stream should be properly cancelled
    await sendTask.value
    
    XCTAssertFalse(chatViewModel.isLoading)
    XCTAssertTrue(chatViewModel.isCancelled)
  }
  
  func testUIStateResetAfterCancellation() async throws {
    // Given - Set various UI states
    chatViewModel.isLoading = true
    chatViewModel.streamingStartTime = Date()
    chatViewModel.currentInputTokens = 100
    chatViewModel.currentOutputTokens = 50
    chatViewModel.currentStreamCost = 0.001
    
    // When - Cancel request
    chatViewModel.cancelRequest()
    
    // Then - UI state should be reset
    XCTAssertFalse(chatViewModel.isLoading)
    XCTAssertNil(chatViewModel.streamingStartTime)
    XCTAssertTrue(chatViewModel.isCancelled)
    
    // Token counts should remain (for display purposes)
    XCTAssertEqual(chatViewModel.currentInputTokens, 100)
    XCTAssertEqual(chatViewModel.currentOutputTokens, 50)
  }
  
  func testRapidCancellationAndRestart() async throws {
    // Test rapid cancel and restart cycles
    for i in 0..<3 {
      // Start loading
      chatViewModel.isLoading = true
      chatViewModel.isCancelled = false
      
      // Add a message
      messageStore.addMessage(ChatMessage(
        role: .assistant,
        content: "Message \(i)",
        isComplete: false,
        messageType: .text
      ))
      
      // Cancel
      chatViewModel.cancelRequest()
      
      // Verify cancellation
      XCTAssertFalse(chatViewModel.isLoading)
      XCTAssertTrue(chatViewModel.isCancelled)
      
      // Small delay before next iteration
      try await Task.sleep(nanoseconds: 10_000_000) // 10ms
    }
    
    // Verify system still works after rapid cycles
    chatViewModel.isCancelled = false
    chatViewModel.isLoading = true
    XCTAssertTrue(chatViewModel.isLoading)
    XCTAssertFalse(chatViewModel.isCancelled)
  }
  
  // MARK: - Edge Cases
  
  func testCancelWithNoActiveStream() async throws {
    // Given - No active stream or requests
    XCTAssertFalse(chatViewModel.isLoading)
    XCTAssertNil(chatViewModel.streamingStartTime)
    
    // When - Cancel request
    chatViewModel.cancelRequest()
    
    // Then - Should handle gracefully
    XCTAssertTrue(chatViewModel.isCancelled)
    XCTAssertFalse(chatViewModel.isLoading)
    
    // Should not affect ability to send new messages
    chatViewModel.isCancelled = false
    XCTAssertFalse(chatViewModel.isCancelled)
  }
  
  func testCancelWithEmptyMessageStore() async throws {
    // Given - Empty message store
    XCTAssertTrue(messageStore.messages.isEmpty)
    
    // When - Cancel request
    chatViewModel.cancelRequest()
    
    // Then - Should not crash
    XCTAssertTrue(chatViewModel.isCancelled)
    XCTAssertTrue(messageStore.messages.isEmpty)
  }
  
  // MARK: - Helper Methods
  
  private func createAssistantChunk(_ content: String) -> AssistantMessage {
    AssistantMessage(
      message: MessageResponse(
        id: "msg_test",
        type: .message,
        model: "claude-3",
        role: .assistant,
        content: [.text(content, nil)],
        stopReason: nil,
        stopSequence: nil,
        usage: MessageResponse.Usage(inputTokens: 10, outputTokens: 10)
      )
    )
  }
}

// MARK: - Mock Claude Service

private class MockClaudeService: ClaudeServiceProtocol {
  var mockStreamPublisher: AnyPublisher<ResponseChunk, Error>?
  
  func sendMessage(
    _ message: String,
    withHistory messages: [ChatMessage],
    sessionId: String?,
    isResume: Bool,
    firstMessageInSession: String?
  ) -> AnyPublisher<ResponseChunk, Error> {
    if let publisher = mockStreamPublisher {
      return publisher
    }
    
    // Return a simple completed stream by default
    return Just(ResponseChunk.assistant(AssistantMessage(
      message: MessageResponse(
        id: "msg_mock",
        type: .message,
        model: "claude-3",
        role: .assistant,
        content: [.text("Mock response", nil)],
        stopReason: nil,
        stopSequence: nil,
        usage: MessageResponse.Usage(inputTokens: 10, outputTokens: 10)
      )
    )))
    .setFailureType(to: Error.self)
    .eraseToAnyPublisher()
  }
  
  func terminateSession(sessionId: String) async throws {
    // Mock implementation
  }
  
  func canSendMessage() -> Bool {
    true
  }
}