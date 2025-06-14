//
//  MessageStore.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 6/8/2025.
//

import Foundation

/// Manages the message collection with thread-safe operations
@MainActor
@Observable
final class MessageStore {
  private(set) var messages: [ChatMessage] = []
  
  func addMessage(_ message: ChatMessage) {
    messages.append(message)
  }
  
  func updateMessage(id: UUID, content: String, isComplete: Bool) {
    guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
    
    let updatedMessage = ChatMessage(
      id: id,
      role: messages[index].role,
      content: content,
      isComplete: isComplete,
      messageType: messages[index].messageType,
      toolName: messages[index].toolName
    )
    messages[index] = updatedMessage
  }
  
  func removeMessage(id: UUID) {
    messages.removeAll { $0.id == id }
  }
  
  func removeIncompleteMessages() {
    messages.removeAll { !$0.isComplete }
  }
  
  func clear() {
    messages.removeAll()
  }
  
  func findMessage(id: UUID) -> ChatMessage? {
    messages.first { $0.id == id }
  }
}
