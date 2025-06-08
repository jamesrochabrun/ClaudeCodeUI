//
//  MessageFactory.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 6/8/2025.
//

import Foundation
import SwiftAnthropic

/// Factory for creating different types of chat messages
struct MessageFactory {
  
  static func userMessage(content: String) -> ChatMessage {
    ChatMessage(role: .user, content: content)
  }
  
  static func assistantMessage(id: UUID, content: String, isComplete: Bool) -> ChatMessage {
    ChatMessage(
      id: id,
      role: .assistant,
      content: content,
      isComplete: isComplete,
      messageType: .text
    )
  }
  
  static func toolUseMessage(toolName: String, input: String) -> ChatMessage {
    let content = "TOOL USE: \(toolName). \n\(input)"
    return ChatMessage(
      role: .toolUse,
      content: content,
      messageType: .toolUse,
      toolName: toolName
    )
  }
  
  static func toolResultMessage(content: MessageResponse.Content.ToolResultContent, isError: Bool) -> ChatMessage {
    var contentString = ""
    switch content {
    case .string(let stringValue):
      contentString = stringValue
    case .items(let items):
      for index in items.indices {
        contentString += "Item \(index) \n \(items[index].temporaryDescription)\n\n "
      }
    }
    
    return ChatMessage(
      role: isError ? .toolError : .toolResult,
      content: contentString,
      messageType: isError ? .toolError : .toolResult
    )
  }
  
  static func thinkingMessage(content: String) -> ChatMessage {
    ChatMessage(
      role: .thinking,
      content: "THINKING: \(content)",
      messageType: .thinking
    )
  }
  
  static func webSearchMessage(resultCount: Int) -> ChatMessage {
    ChatMessage(
      role: .assistant,
      content: "WEB SEARCH RESULT: Found \(resultCount) results",
      messageType: .webSearch
    )
  }
}

extension ContentItem {
  var temporaryDescription: String {
    var result = "ContentItem:\n"
    
    if let title = self.title {
      result += "  Title: \"\(title)\"\n"
    }
    
    if let url = self.url {
      result += "  URL: \(url)\n"
    }
    
    if let type = self.type {
      result += "  Type: \(type)\n"
    }
    
    if let pageAge = self.pageAge {
      result += "  Age: \(pageAge)\n"
    }
    
    if let text = self.text {
      // Limit text length for readability
      let truncatedText = text.count > 100 ? "\(text.prefix(100))..." : text
      result += "  Text: \"\(truncatedText)\"\n"
    }
    
    if let _ = self.encryptedContent {
      // Just indicate presence rather than showing the whole encrypted content
      result += "  Encrypted Content: [Present]\n"
    }
    
    return result
  }
}
