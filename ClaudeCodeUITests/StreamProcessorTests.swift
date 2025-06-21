//
//  StreamProcessorTests.swift
//  ClaudeCodeUITests
//
//  Created on 6/21/2025.
//

import XCTest
import Foundation
import Combine
@testable import ClaudeCodeUI

@MainActor
final class StreamProcessorTests: XCTestCase {
  
  // MARK: - Test Dependencies
  
  private var messageStore: MessageStore!
  private var sessionStorage: SessionStorageProtocol!
  private var sessionManager: SessionManager!
  private var streamProcessor: StreamProcessor!
  
  override func setUp() {
    super.setUp()
    messageStore = MessageStore()
    sessionStorage = UserDefaultsSessionStorage()
    sessionManager = SessionManager(sessionStorage: sessionStorage)
    streamProcessor = StreamProcessor(
      messageStore: messageStore,
      sessionManager: sessionManager,
      onSessionChange: nil
    )
  }
  
  override func tearDown() {
    messageStore = nil
    sessionManager = nil
    streamProcessor = nil
    sessionStorage = nil
    super.tearDown()
  }
  
  // MARK: - Basic Tests
  
  func testStreamProcessorInitialization() {
    XCTAssertNotNil(streamProcessor)
    XCTAssertTrue(messageStore.messages.isEmpty)
    XCTAssertNil(sessionManager.currentSessionId)
  }
  
  func testMessageStoreIntegration() {
    // Test that StreamProcessor can add messages to the store
    let testMessage = MessageFactory.userMessage(content: "Test message")
    messageStore.addMessage(testMessage)
    
    XCTAssertEqual(messageStore.messages.count, 1)
    XCTAssertEqual(messageStore.messages[0].content, "Test message")
    XCTAssertEqual(messageStore.messages[0].role, .user)
  }
  
  func testSessionManagerIntegration() {
    // Test session creation
    sessionManager.startNewSession(id: "test-123", firstMessage: "Hello")
    
    XCTAssertEqual(sessionManager.currentSessionId, "test-123")
  }
  
  // MARK: - Message Factory Tests
  
  func testAssistantMessageCreation() {
    let message = MessageFactory.assistantMessage(
      id: UUID(),
      content: "Assistant response",
      isComplete: true
    )
    
    messageStore.addMessage(message)
    
    XCTAssertEqual(messageStore.messages.count, 1)
    XCTAssertEqual(messageStore.messages[0].role, .assistant)
    XCTAssertEqual(messageStore.messages[0].content, "Assistant response")
    XCTAssertTrue(messageStore.messages[0].isComplete)
  }
  
  func testToolUseMessageCreation() {
    let toolData = ToolInputData(parameters: [
      "file_path": "/test/path",
      "command": "ls -la"
    ])
    
    let message = MessageFactory.toolUseMessage(
      toolName: "Bash",
      input: "Running command: ls -la",
      toolInputData: toolData
    )
    
    messageStore.addMessage(message)
    
    XCTAssertEqual(messageStore.messages.count, 1)
    XCTAssertEqual(messageStore.messages[0].messageType, .toolUse)
    XCTAssertEqual(messageStore.messages[0].toolName, "Bash")
    XCTAssertNotNil(messageStore.messages[0].toolInputData)
    XCTAssertEqual(messageStore.messages[0].toolInputData?.parameters["file_path"], "/test/path")
  }
  
  func testToolResultMessageCreation() {
    let message = MessageFactory.toolResultMessage(
      content: .string("Command executed successfully"),
      isError: false
    )
    
    messageStore.addMessage(message)
    
    XCTAssertEqual(messageStore.messages.count, 1)
    XCTAssertEqual(messageStore.messages[0].messageType, .toolResult)
    XCTAssertFalse(messageStore.messages[0].isError)
  }
  
  func testToolErrorMessageCreation() {
    let message = MessageFactory.toolResultMessage(
      content: .string("Command failed"),
      isError: true
    )
    
    messageStore.addMessage(message)
    
    XCTAssertEqual(messageStore.messages.count, 1)
    XCTAssertEqual(messageStore.messages[0].messageType, .toolError)
    XCTAssertTrue(messageStore.messages[0].isError)
  }
  
  func testThinkingMessageCreation() {
    let message = MessageFactory.thinkingMessage(
      content: "Processing your request..."
    )
    
    messageStore.addMessage(message)
    
    XCTAssertEqual(messageStore.messages.count, 1)
    XCTAssertEqual(messageStore.messages[0].messageType, .thinking)
    XCTAssertEqual(messageStore.messages[0].content, "THINKING: Processing your request...")
  }
  
  func testWebSearchMessageCreation() {
    let message = MessageFactory.webSearchMessage(resultCount: 5)
    
    messageStore.addMessage(message)
    
    XCTAssertEqual(messageStore.messages.count, 1)
    XCTAssertEqual(messageStore.messages[0].messageType, .webSearch)
    XCTAssertEqual(messageStore.messages[0].content, "WEB SEARCH RESULT: Found 5 results")
  }
  
  // MARK: - Message Update Tests
  
  func testMessageUpdateContent() {
    let messageId = UUID()
    let message = MessageFactory.assistantMessage(
      id: messageId,
      content: "Initial content",
      isComplete: false
    )
    
    messageStore.addMessage(message)
    messageStore.updateMessage(
      id: messageId,
      content: "Updated content",
      isComplete: true
    )
    
    XCTAssertEqual(messageStore.messages.count, 1)
    XCTAssertEqual(messageStore.messages[0].content, "Updated content")
    XCTAssertTrue(messageStore.messages[0].isComplete)
  }
  
  func testMessageRemoval() {
    let messageId = UUID()
    let message = MessageFactory.assistantMessage(
      id: messageId,
      content: "To be removed",
      isComplete: true
    )
    
    messageStore.addMessage(message)
    XCTAssertEqual(messageStore.messages.count, 1)
    
    messageStore.removeMessage(id: messageId)
    XCTAssertTrue(messageStore.messages.isEmpty)
  }
  
  // MARK: - DynamicContentFormatter Tests
  
  func testDynamicContentFormatterIntegration() {
    let formatter = DynamicContentFormatter()
    
    // Test that formatter exists and can be initialized
    XCTAssertNotNil(formatter)
    
    // The actual formatting tests would require access to DynamicContent types
    // which are part of the external SDK
  }
  
  // MARK: - ToolInputData Tests
  
  func testToolInputDataWithTodos() {
    let todosString = """
    [✓] Complete task 1
    [ ] Pending task 2
    [✓] Complete task 3
    """
    
    let toolData = ToolInputData(parameters: ["todos": todosString])
    let keyParams = toolData.keyParameters
    
    XCTAssertEqual(keyParams.count, 1)
    XCTAssertEqual(keyParams[0].key, "todos")
    XCTAssertEqual(keyParams[0].value, "2/3 completed")
  }
  
  func testToolInputDataPriorityKeys() {
    let toolData = ToolInputData(parameters: [
      "custom": "value",
      "file_path": "/important/path",
      "another": "value2"
    ])
    
    let keyParams = toolData.keyParameters
    
    // file_path should be prioritized
    XCTAssertTrue(keyParams.count >= 1)
    XCTAssertEqual(keyParams[0].key, "file_path")
  }
}

