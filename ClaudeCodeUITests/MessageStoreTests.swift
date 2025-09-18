//
//  MessageStoreTests.swift
//  ClaudeCodeUITests
//
//  Created by Assistant on 6/8/2025.
//

import Testing
import Foundation
@testable import ClaudeCodeCore

@MainActor
struct MessageStoreTests {
  
  @Test func testAddMessage() async throws {
    let store = MessageStore()
    
    #expect(store.messages.isEmpty)
    
    let message = ChatMessage(
      role: .user,
      content: "Test message",
      isComplete: true
    )
    
    store.addMessage(message)
    
    #expect(store.messages.count == 1)
    #expect(store.messages[0].content == "Test message")
    #expect(store.messages[0].role == .user)
  }
  
  @Test func testUpdateMessage() async throws {
    let store = MessageStore()
    let messageId = UUID()
    
    let message = ChatMessage(
      id: messageId,
      role: .assistant,
      content: "Initial",
      isComplete: false
    )
    
    store.addMessage(message)
    store.updateMessage(id: messageId, content: "Updated content", isComplete: true)
    
    #expect(store.messages.count == 1)
    #expect(store.messages[0].content == "Updated content")
    #expect(store.messages[0].isComplete)
  }
  
  @Test func testUpdateNonExistentMessage() async throws {
    let store = MessageStore()
    let randomId = UUID()
    
    // Should not crash when updating non-existent message
    store.updateMessage(id: randomId, content: "Test", isComplete: true)
    
    #expect(store.messages.isEmpty)
  }
  
  @Test func testRemoveMessage() async throws {
    let store = MessageStore()
    let messageId = UUID()
    
    let message = ChatMessage(
      id: messageId,
      role: .user,
      content: "To be removed",
      isComplete: true
    )
    
    store.addMessage(message)
    #expect(store.messages.count == 1)
    
    store.removeMessage(id: messageId)
    #expect(store.messages.isEmpty)
  }
  
  @Test func testClear() async throws {
    let store = MessageStore()
    
    // Add multiple messages
    for i in 0..<5 {
      let message = ChatMessage(
        role: i % 2 == 0 ? .user : .assistant,
        content: "Message \(i)",
        isComplete: true
      )
      store.addMessage(message)
    }
    
    #expect(store.messages.count == 5)
    
    store.clear()
    #expect(store.messages.isEmpty)
  }
  
  @Test func testMessageOrdering() async throws {
    let store = MessageStore()
    
    let message1 = ChatMessage(role: .user, content: "First", isComplete: true)
    let message2 = ChatMessage(role: .assistant, content: "Second", isComplete: true)
    let message3 = ChatMessage(role: .user, content: "Third", isComplete: true)
    
    store.addMessage(message1)
    store.addMessage(message2)
    store.addMessage(message3)
    
    #expect(store.messages[0].content == "First")
    #expect(store.messages[1].content == "Second")
    #expect(store.messages[2].content == "Third")
  }
}
