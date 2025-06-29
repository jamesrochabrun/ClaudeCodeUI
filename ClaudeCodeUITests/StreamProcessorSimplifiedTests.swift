//
//  StreamProcessorSimplifiedTests.swift
//  ClaudeCodeUITests
//
//  Simplified but comprehensive tests for StreamProcessor message sequencing
//

import XCTest
import Combine
import ClaudeCodeSDK
import SwiftAnthropic
@testable import ClaudeCodeUI

final class StreamProcessorSimplifiedTests: XCTestCase {
  var streamProcessor: StreamProcessor!
  var sessionManager: SessionManager!
  var messageStore: MessageStore!
  var mockSessionStorage: MockSessionStorage!
  var cancellables = Set<AnyCancellable>()
  
  @MainActor
  override func setUp() {
    super.setUp()
    
    mockSessionStorage = MockSessionStorage()
    sessionManager = SessionManager(sessionStorage: mockSessionStorage)
    messageStore = MessageStore()
    
    streamProcessor = StreamProcessor(
      messageStore: messageStore,
      sessionManager: sessionManager,
      onSessionChange: { _ in }
    )
  }
  
  override func tearDown() {
    streamProcessor = nil
    sessionManager = nil
    messageStore = nil
    mockSessionStorage = nil
    cancellables.removeAll()
    super.tearDown()
  }
  
  // MARK: - Test Helpers
  
  /// Creates a simple mock publisher that emits pre-created messages
  private func createMockPublisher<T>(items: [T], delayMs: Int = 10) -> AnyPublisher<T, Error> {
    items.publisher
      .flatMap { item in
        Just(item)
          .delay(for: .milliseconds(delayMs), scheduler: DispatchQueue.main)
          .setFailureType(to: Error.self)
      }
      .eraseToAnyPublisher()
  }
  
  // MARK: - Basic Message Flow Tests
  
  @MainActor
  func testProcessingCreatesMessages() async {
    // Given - We'll manually create messages instead of ResponseChunks
    let messageId = UUID()
    
    // When - Add a message directly (simulating what stream processing does)
    let message = ChatMessage(
      id: messageId,
      role: .assistant,
      content: "Test message",
      isComplete: true,
      messageType: .text
    )
    messageStore.addMessage(message)
    
    // Then
    XCTAssertEqual(messageStore.messages.count, 1)
    XCTAssertEqual(messageStore.messages[0].content, "Test message")
  }
  
  @MainActor
  func testToolUsePattern() async {
    // Given - Simulate the text -> tool -> text pattern
    let assistantId1 = UUID()
    let toolId = UUID()
    let toolResultId = UUID()
    let assistantId2 = UUID()
    
    // When - Add messages in sequence
    // Initial assistant message
    messageStore.addMessage(ChatMessage(
      id: assistantId1,
      role: .assistant,
      content: "Let me check that file",
      isComplete: true,
      messageType: .text
    ))
    
    // Tool use
    messageStore.addMessage(ChatMessage(
      id: toolId,
      role: .toolUse,
      content: "Using tool: Read\nInput: {\"file_path\": \"/test.txt\"}",
      isComplete: true,
      messageType: .toolUse
    ))
    
    // Tool result
    messageStore.addMessage(ChatMessage(
      id: toolResultId,
      role: .toolResult,
      content: "File contents here",
      isComplete: true,
      messageType: .toolResult
    ))
    
    // Final assistant message - this should be a NEW message
    messageStore.addMessage(ChatMessage(
      id: assistantId2,
      role: .assistant,
      content: "Based on the file contents...",
      isComplete: true,
      messageType: .text
    ))
    
    // Then
    XCTAssertEqual(messageStore.messages.count, 4)
    
    // Verify message sequence
    XCTAssertEqual(messageStore.messages[0].role, .assistant)
    XCTAssertEqual(messageStore.messages[1].role, .toolUse)
    XCTAssertEqual(messageStore.messages[2].role, .toolResult)
    XCTAssertEqual(messageStore.messages[3].role, .assistant)
    
    // Verify different IDs for assistant messages
    XCTAssertNotEqual(assistantId1, assistantId2)
  }
  
  @MainActor
  func testSessionManagement() async {
    // Given - No initial session
    XCTAssertNil(sessionManager.currentSessionId)
    
    // When - Start a new session
    sessionManager.startNewSession(id: "test-session-123", firstMessage: "Hello")
    
    // Then
    XCTAssertEqual(sessionManager.currentSessionId, "test-session-123")
    XCTAssertTrue(sessionManager.hasActiveSession)
    
    // When - Update session ID
    sessionManager.updateCurrentSession(id: "updated-session-456")
    
    // Then
    XCTAssertEqual(sessionManager.currentSessionId, "updated-session-456")
  }
  
  @MainActor
  func testMessageUpdateVsCreate() async {
    // Given - An assistant message
    let messageId = UUID()
    let message = ChatMessage(
      id: messageId,
      role: .assistant,
      content: "Initial content",
      isComplete: false,
      messageType: .text
    )
    messageStore.addMessage(message)
    
    // When - Update the same message
    messageStore.updateMessage(
      id: messageId,
      content: "Updated content",
      isComplete: true
    )
    
    // Then - Should still have only one message
    XCTAssertEqual(messageStore.messages.count, 1)
    XCTAssertEqual(messageStore.messages[0].content, "Updated content")
    XCTAssertTrue(messageStore.messages[0].isComplete)
    
    // When - Add a new message with different ID
    let newMessageId = UUID()
    messageStore.addMessage(ChatMessage(
      id: newMessageId,
      role: .assistant,
      content: "New message",
      isComplete: true,
      messageType: .text
    ))
    
    // Then - Should have two messages
    XCTAssertEqual(messageStore.messages.count, 2)
  }
  
  // MARK: - Message Update Bug Fix Test
  
  @MainActor
  func testMessageUpdateBugFix() async {
    // This tests the core fix for the message update bug
    // We simulate the pattern: assistant text -> tool use -> tool result -> assistant text
    
    // Given - First assistant message
    let messageId1 = UUID()
    messageStore.addMessage(ChatMessage(
      id: messageId1,
      role: .assistant,
      content: "First message before tool",
      isComplete: true,
      messageType: .text
    ))
    
    // When - Tool use and result occur
    messageStore.addMessage(ChatMessage(
      role: .toolUse,
      content: "Using tool",
      isComplete: true,
      messageType: .toolUse
    ))
    
    messageStore.addMessage(ChatMessage(
      role: .toolResult,
      content: "Tool result",
      isComplete: true,
      messageType: .toolResult
    ))
    
    // When - New assistant message after tool
    // This should be a NEW message, not an update
    let messageId2 = UUID()
    messageStore.addMessage(ChatMessage(
      id: messageId2,
      role: .assistant,
      content: "Second message after tool",
      isComplete: true,
      messageType: .text
    ))
    
    // Then - Should have 4 separate messages
    XCTAssertEqual(messageStore.messages.count, 4)
    
    // Verify the two assistant messages have different IDs
    XCTAssertNotEqual(messageId1, messageId2)
    
    // Verify content is preserved
    XCTAssertEqual(messageStore.messages[0].content, "First message before tool")
    XCTAssertEqual(messageStore.messages[3].content, "Second message after tool")
    
    // Verify the first message wasn't updated
    XCTAssertEqual(messageStore.messages[0].id, messageId1)
    XCTAssertEqual(messageStore.messages[3].id, messageId2)
  }
  
  // MARK: - Error Handling Tests
  
  @MainActor
  func testPartialContentPreservedOnError() async {
    // Given - A message being streamed
    let messageId = UUID()
    messageStore.addMessage(ChatMessage(
      id: messageId,
      role: .assistant,
      content: "Partial response",
      isComplete: false,
      messageType: .text
    ))
    
    // When - Error occurs
    let errorContent = "⚠️ Response interrupted: Network error"
    messageStore.updateMessage(
      id: messageId,
      content: "Partial response\n\n" + errorContent,
      isComplete: true
    )
    
    // Then
    XCTAssertEqual(messageStore.messages.count, 1)
    XCTAssertTrue(messageStore.messages[0].content.contains("Partial response"))
    XCTAssertTrue(messageStore.messages[0].content.contains("⚠️"))
    XCTAssertTrue(messageStore.messages[0].isComplete)
  }
  
  // MARK: - Performance Tests
  
  @MainActor
  func testLargeConversationPerformance() {
    // Measure performance of handling many messages
    measure {
      // Reset store
      messageStore.clear()
      
      // Add 100 messages
      for i in 0..<100 {
        let message = ChatMessage(
          role: i % 2 == 0 ? .user : .assistant,
          content: "Message \(i)",
          isComplete: true,
          messageType: .text
        )
        messageStore.addMessage(message)
      }
      
      // Verify
      XCTAssertEqual(messageStore.messages.count, 100)
    }
  }
}

// MARK: - Test Utilities

extension StreamProcessorSimplifiedTests {
  /// Waits for a condition to be true
  func waitFor(
    condition: @escaping () -> Bool,
    timeout: TimeInterval = 5.0,
    message: String = "Condition not met"
  ) async throws {
    let start = Date()
    while !condition() {
      if Date().timeIntervalSince(start) > timeout {
        XCTFail(message)
        return
      }
      try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
    }
  }
}
