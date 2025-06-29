//
//  ChatViewModelSimplifiedTests.swift
//  ClaudeCodeUITests
//
//

import XCTest
import Combine
import ClaudeCodeSDK
@testable import ClaudeCodeUI

final class ChatViewModelSimplifiedTests: XCTestCase {
  var chatViewModel: ChatViewModel!
  var mockStorage: MockSessionStorage!
  var cancellables = Set<AnyCancellable>()
  
  @MainActor
  override func setUp() {
    super.setUp()
    
    // Create mock dependencies
    mockStorage = MockSessionStorage()
    let settingsStorage = SettingsStorageManager()
    let globalPreferences = GlobalPreferencesStorage()
    
    // Create a minimal mock ClaudeClient
    let mockClient = MockMinimalClaudeClient()
    
    // Create view model
    chatViewModel = ChatViewModel(
      claudeClient: mockClient,
      sessionStorage: mockStorage,
      settingsStorage: settingsStorage,
      globalPreferences: globalPreferences,
      onSessionChange: nil
    )
  }
  
  override func tearDown() {
    chatViewModel = nil
    mockStorage = nil
    cancellables.removeAll()
    super.tearDown()
  }
  
  // MARK: - Basic Tests
  
  @MainActor
  func testSendMessage_CreatesUserMessage() {
    // Given
    let messageContent = "Test message"
    
    // When
    chatViewModel.sendMessage(messageContent)
    
    // Then - Should have at least the user message
    XCTAssertGreaterThan(chatViewModel.messages.count, 0)
    XCTAssertEqual(chatViewModel.messages[0].role, .user)
    XCTAssertEqual(chatViewModel.messages[0].content, messageContent)
  }
  
  @MainActor
  func testClearConversation() {
    // Given - Add some messages
    chatViewModel.sendMessage("Test 1")
    chatViewModel.sendMessage("Test 2")
    XCTAssertGreaterThan(chatViewModel.messages.count, 0)
    
    // When
    chatViewModel.clearConversation()
    
    // Then
    XCTAssertEqual(chatViewModel.messages.count, 0)
    XCTAssertNil(chatViewModel.error)
  }
  
  @MainActor
  func testSessionManagement() async {
    // Given - No initial session
    XCTAssertTrue(chatViewModel.sessions.isEmpty)
    
    // When - Load sessions
    await chatViewModel.loadSessions()
    
    // Add a test session to storage
    try? await mockStorage.saveSession(id: "test-session", firstMessage: "Hello")
    
    // Reload
    await chatViewModel.loadSessions()
    
    // Then
    XCTAssertEqual(chatViewModel.sessions.count, 1)
    XCTAssertEqual(chatViewModel.sessions[0].id, "test-session")
  }
  
  @MainActor
  func testMessageWithContext() {
    // Given
    let message = "Explain this"
    let context = "Selected code"
    let codeSelection = TextSelection(
      filePath: "/test/file.swift",
      selectedText: "func example() {}",
      lineRange: 1...5
    )
    
    // When
    chatViewModel.sendMessage(
      message,
      context: context,
      hiddenContext: nil,
      codeSelections: [codeSelection]
    )
    
    // Then
    XCTAssertGreaterThan(chatViewModel.messages.count, 0)
    let userMessage = chatViewModel.messages[0]
    XCTAssertEqual(userMessage.content, message)
    XCTAssertEqual(userMessage.codeSelections?.count, 1)
    XCTAssertEqual(userMessage.codeSelections?.first?.filePath, "/test/file.swift")
  }
  
  @MainActor
  func testErrorHandling() {
    // Given
    let testError = NSError(domain: "TestError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Test error"])
    
    // When
    chatViewModel.handleError(testError)
    
    // Then
    XCTAssertNotNil(chatViewModel.error)
    XCTAssertFalse(chatViewModel.isLoading)
  }
}

// MARK: - Minimal Mock Claude Client

private class MockMinimalClaudeClient: ClaudeCode {
  var configuration = ClaudeCodeConfiguration(workingDirectory: "/test")
  
  func runWithStdin(
    stdinContent: String,
    outputFormat: ClaudeCodeOutputFormat,
    options: ClaudeCodeOptions?
  ) async throws -> ClaudeCodeResult {
    // Return simple text result
    return .text("Mock response")
  }
  
  func runSinglePrompt(
    prompt: String,
    outputFormat: ClaudeCodeOutputFormat,
    options: ClaudeCodeOptions?
  ) async throws -> ClaudeCodeResult {
    // For stream output, create a simple publisher
    if outputFormat == .streamJson {
      let subject = PassthroughSubject<ResponseChunk, Error>()
      
      // Send completion immediately
      Task {
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        subject.send(completion: .finished)
      }
      
      return .stream(subject.eraseToAnyPublisher())
    }
    
    return .text("Mock response")
  }
  
  func continueConversation(
    prompt: String?,
    outputFormat: ClaudeCodeOutputFormat,
    options: ClaudeCodeOptions?
  ) async throws -> ClaudeCodeResult {
    return .text("Continued conversation")
  }
  
  func resumeConversation(
    sessionId: String,
    prompt: String?,
    outputFormat: ClaudeCodeOutputFormat,
    options: ClaudeCodeOptions?
  ) async throws -> ClaudeCodeResult {
    return .text("Resumed conversation")
  }
  
  func listSessions() async throws -> [SessionInfo] {
    return []
  }
  
  func cancel() {
    // No-op
  }
}
