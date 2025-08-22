//
//  MessageStore.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 6/8/2025.
//

import Foundation

/// Manages the chat message collection with thread-safe operations
/// 
/// MessageStore is the central repository for all chat messages in a conversation.
/// It provides methods to add, update, remove, and query messages while ensuring
/// thread safety through the @MainActor attribute.
///
/// - Note: This class is @Observable, allowing SwiftUI views to automatically
///         update when the messages array changes.
@MainActor
@Observable
final class MessageStore {
  /// The array of chat messages in chronological order
  /// - Note: This is private(set) to ensure all modifications go through the provided methods
  private(set) var messages: [ChatMessage] = []
  
  /// Adds a new message to the store
  /// - Parameter message: The ChatMessage to add to the collection
  /// - Note: Messages are appended to maintain chronological order
  func addMessage(_ message: ChatMessage) {
    messages.append(message)
  }
  
  /// Updates an existing message's content and completion status
  /// - Parameters:
  ///   - id: The UUID of the message to update
  ///   - content: The new content for the message
  ///   - isComplete: Whether the message has finished streaming
  ///   - isError: Whether the message represents an error state (default: false)
  /// - Note: Preserves all other message properties (role, type, toolName, etc.)
  ///         If the message ID is not found, the operation is silently ignored
  func updateMessage(id: UUID, content: String, isComplete: Bool, isError: Bool = false) {
    guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
    
    let updatedMessage = ChatMessage(
      id: id,
      role: messages[index].role,
      content: content,
      isComplete: isComplete,
      messageType: messages[index].messageType,
      toolName: messages[index].toolName,
      toolInputData: messages[index].toolInputData,
      isError: isError
    )
    messages[index] = updatedMessage
  }
  
  /// Removes a specific message from the store
  /// - Parameter id: The UUID of the message to remove
  /// - Note: If the message ID is not found, no action is taken
  func removeMessage(id: UUID) {
    messages.removeAll { $0.id == id }
  }
  
  /// Removes all incomplete messages from the store
  /// - Note: This is useful for cleaning up partial messages after streaming errors
  ///         or when starting a new conversation
  func removeIncompleteMessages() {
    messages.removeAll { !$0.isComplete }
  }
  
  /// Removes all messages from the store
  /// - Note: Use this when starting a new conversation or clearing the chat history
  func clear() {
    messages.removeAll()
  }
  
  /// Finds and returns a message by its ID
  /// - Parameter id: The UUID of the message to find
  /// - Returns: The ChatMessage if found, nil otherwise
  func findMessage(id: UUID) -> ChatMessage? {
    messages.first { $0.id == id }
  }
  
  /// Replaces all messages with a new array
  /// - Parameter newMessages: The array of messages to replace current messages with
  /// - Note: Used when loading session history
  func loadMessages(_ newMessages: [ChatMessage]) {
    messages = newMessages
  }
  
  /// Returns a copy of all messages
  /// - Returns: Array of all current messages
  /// - Note: Used for saving session state
  func getAllMessages() -> [ChatMessage] {
    messages
  }
  
  /// Marks a message as cancelled
  /// - Parameter id: The UUID of the message to mark as cancelled
  /// - Note: This sets wasCancelled to true and isComplete to true
  func markMessageAsCancelled(id: UUID) {
    guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
    
    var updatedMessage = messages[index]
    updatedMessage.wasCancelled = true
    updatedMessage.isComplete = true
    messages[index] = updatedMessage
  }
}
