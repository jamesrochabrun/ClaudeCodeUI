//
//  ChatMessage.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 5/25/25.
//

import Foundation

public struct ChatMessage: Identifiable, Equatable {
  public var id: UUID
  public var role: MessageRole
  public var content: String
  public var timestamp: Date
  public var isComplete: Bool
  public var messageType: MessageType
  public var toolName: String?

  public init(
    id: UUID = UUID(),
    role: MessageRole,
    content: String,
    timestamp: Date = Date(),
    isComplete: Bool = true,
    messageType: MessageType = .text,
    toolName: String? = nil
  ) {
    self.id = id
    self.role = role
    self.content = content
    self.timestamp = timestamp
    self.isComplete = isComplete
    self.messageType = messageType
    self.toolName = toolName
  }

  public static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
    return lhs.content == rhs.content &&
           lhs.id == rhs.id &&
           lhs.isComplete == rhs.isComplete &&
           lhs.messageType == rhs.messageType &&
           lhs.toolName == rhs.toolName
  }
}

/// Message content types
public enum MessageType: String {
  case text
  case toolUse
  case toolResult
  case toolError
  case thinking
  case webSearch
}

/// Message role types
public enum MessageRole: String {
  case user
  case assistant
  case system
  case toolUse
  case toolResult
  case toolError
  case thinking
}
