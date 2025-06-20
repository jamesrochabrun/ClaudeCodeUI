//
//  SimpleMessageStoreTests.swift
//  ClaudeCodeUITests
//
//  Created by Assistant on 6/8/2025.
//

import Testing
import Foundation
@testable import ClaudeCodeUI

// Simple tests that don't require SDK types
struct SimpleMessageStoreTests {
  
  @Test
  @MainActor
  func testMessageStoreBasics() async throws {
    let store = MessageStore()
    
    // Test initial state
    #expect(store.messages.isEmpty)
    
    // Add a message
    let message = ChatMessage(
      role: .user,
      content: "Hello",
      isComplete: true
    )
    store.addMessage(message)
    
    #expect(store.messages.count == 1)
    #expect(store.messages[0].content == "Hello")
    
    // Update message
    store.updateMessage(
      id: message.id,
      content: "Updated Hello",
      isComplete: true
    )
    
    #expect(store.messages[0].content == "Updated Hello")
    
    // Clear
    store.clear()
    #expect(store.messages.isEmpty)
  }
  
  @Test
  @MainActor
  func testSessionManagerBasics() async throws {
    let sessionStorage = UserDefaultsSessionStorage()
    let manager = SessionManager(sessionStorage: sessionStorage)
    
    #expect(manager.currentSessionId == nil)
    
    manager.startNewSession(id: "test-123", firstMessage: "Test message")
    #expect(manager.currentSessionId == "test-123")
    
    manager.clearSession()
    #expect(manager.currentSessionId == nil)
  }
  
  @Test
  @MainActor
  func testMessageFactoryCreation() async throws {
    // User message
    let userMsg = MessageFactory.userMessage(content: "Test")
    #expect(userMsg.role == .user)
    #expect(userMsg.content == "Test")
    #expect(userMsg.isComplete)
    
    // Assistant message
    let assistantMsg = MessageFactory.assistantMessage(
      id: UUID(),
      content: "Response",
      isComplete: false
    )
    #expect(assistantMsg.role == .assistant)
    #expect(assistantMsg.content == "Response")
    #expect(!assistantMsg.isComplete)
    
    // Tool use message
    let toolMsg = MessageFactory.toolUseMessage(
      toolName: "Bash",
      input: "ls -la"
    )
    #expect(toolMsg.role == .toolUse)
    #expect(toolMsg.toolName == "Bash")
    
    // Skip tool result tests as they require SDK types
  }
  
  @Test
  @MainActor
  func testChatMessageTypes() async throws {
    let messages: [ChatMessage] = [
      ChatMessage(role: .user, content: "User", isComplete: true),
      ChatMessage(role: .assistant, content: "Assistant", isComplete: true),
      ChatMessage(role: .toolUse, content: "Tool", isComplete: true, messageType: .toolUse),
      ChatMessage(role: .toolResult, content: "Result", isComplete: true, messageType: .toolResult),
      ChatMessage(role: .thinking, content: "Thinking", isComplete: true, messageType: .thinking),
      ChatMessage(role: .assistant, content: "Search", isComplete: true, messageType: .webSearch)
    ]
    
    #expect(messages[0].messageType == .text)
    #expect(messages[1].messageType == .text)
    #expect(messages[2].messageType == .toolUse)
    #expect(messages[3].messageType == .toolResult)
    #expect(messages[4].messageType == .thinking)
    #expect(messages[5].messageType == .webSearch)
  }
}
