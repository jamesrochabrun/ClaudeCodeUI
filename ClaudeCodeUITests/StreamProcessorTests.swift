//
//  StreamProcessorTests.swift
//  ClaudeCodeUITests
//
//  Unit tests for StreamProcessor sequence of messages fix
//

import XCTest
import Combine
import ClaudeCodeSDK
import SwiftAnthropic
@testable import ClaudeCodeUI

final class StreamProcessorTests: XCTestCase {
  var streamProcessor: StreamProcessor!
  var sessionManager: SessionManager!
  var messageStore: MessageStore!
  var mockSessionStorage: MockSessionStorage!
  var onSessionChangeCalled = false
  var onSessionChangeId: String?
  
  @MainActor
  override func setUp() {
    super.setUp()
    
    // Create mock session storage
    mockSessionStorage = MockSessionStorage()
    
    // Initialize real instances with mock storage
    sessionManager = SessionManager(sessionStorage: mockSessionStorage)
    messageStore = MessageStore()
    
    // Create stream processor
    streamProcessor = StreamProcessor(
      messageStore: messageStore,
      sessionManager: sessionManager,
      onSessionChange: { [weak self] sessionId in
        self?.onSessionChangeCalled = true
        self?.onSessionChangeId = sessionId
      }
    )
    
    // Reset test state
    onSessionChangeCalled = false
    onSessionChangeId = nil
  }
  
  override func tearDown() {
    streamProcessor = nil
    sessionManager = nil
    messageStore = nil
    mockSessionStorage = nil
    super.tearDown()
  }
  
  // MARK: - Session ID Update Tests
  
  /// Tests basic session management functionality
  @MainActor
  func testSessionManager_StartNewSession() async {
    // Given
    XCTAssertNil(sessionManager.currentSessionId)
    
    // When
    sessionManager.startNewSession(id: "test-session-123", firstMessage: "Test message")
    
    // Then
    XCTAssertEqual(sessionManager.currentSessionId, "test-session-123")
    XCTAssertTrue(sessionManager.hasActiveSession)
    
    // Allow async save operation to complete
    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    
    // Verify session was saved
    let sessions = try? await mockSessionStorage.getAllSessions()
    XCTAssertEqual(sessions?.count, 1)
    XCTAssertEqual(sessions?.first?.id, "test-session-123")
    XCTAssertEqual(sessions?.first?.firstUserMessage, "Test message")
  }
  
  /// Tests that session ID can be updated
  @MainActor
  func testSessionManager_UpdateCurrentSession() async {
    // Given
    sessionManager.startNewSession(id: "original-session", firstMessage: "Original message")
    XCTAssertEqual(sessionManager.currentSessionId, "original-session")
    
    // When
    sessionManager.updateCurrentSession(id: "updated-session")
    
    // Then
    XCTAssertEqual(sessionManager.currentSessionId, "updated-session")
  }
  
  /// Tests message store functionality
  @MainActor
  func testMessageStore_AddAndUpdateMessages() async {
    // Given
    XCTAssertEqual(messageStore.messages.count, 0)
    
    // When - Add a message
    let messageId = UUID()
    let message = ChatMessage(
      id: messageId,
      role: .assistant,
      content: "Initial content",
      isComplete: false,
      messageType: .text
    )
    messageStore.addMessage(message)
    
    // Then
    XCTAssertEqual(messageStore.messages.count, 1)
    XCTAssertEqual(messageStore.messages.first?.content, "Initial content")
    XCTAssertFalse(messageStore.messages.first?.isComplete ?? true)
    
    // When - Update the message
    messageStore.updateMessage(
      id: messageId,
      content: "Updated content",
      isComplete: true
    )
    
    // Then
    XCTAssertEqual(messageStore.messages.count, 1)
    XCTAssertEqual(messageStore.messages.first?.content, "Updated content")
    XCTAssertTrue(messageStore.messages.first?.isComplete ?? false)
  }
  
  /// Tests the session change callback
  @MainActor
  func testStreamProcessor_SessionChangeCallback() async {
    // Given
    XCTAssertFalse(onSessionChangeCalled)
    XCTAssertNil(onSessionChangeId)
    
    // When - Start a new session
    sessionManager.startNewSession(id: "callback-test-session", firstMessage: "Test")
    
    // Then - Callback should not be triggered for startNewSession
    XCTAssertFalse(onSessionChangeCalled)
    XCTAssertNil(onSessionChangeId)
    
    // The actual stream processing would trigger the callback
    // This would happen when processing ResponseChunk.initSystem messages
  }
}

// MARK: - Mock Session Storage

class MockSessionStorage: SessionStorageProtocol {
  var sessions: [StoredSession] = []
  
  func saveSession(id: String, firstMessage: String) async throws {
    let session = StoredSession(
      id: id,
      createdAt: Date(),
      firstUserMessage: firstMessage,
      lastAccessedAt: Date()
    )
    sessions.append(session)
  }
  
  func getAllSessions() async throws -> [StoredSession] {
    return sessions
  }
  
  func getSession(id: String) async throws -> StoredSession? {
    return sessions.first { $0.id == id }
  }
  
  func deleteSession(id: String) async throws {
    sessions.removeAll { $0.id == id }
  }
  
  func deleteAllSessions() async throws {
    sessions.removeAll()
  }
  
  func updateLastAccessed(id: String) async throws {
    if let index = sessions.firstIndex(where: { $0.id == id }) {
      var session = sessions[index]
      session.lastAccessedAt = Date()
      sessions[index] = session
    }
  }
}