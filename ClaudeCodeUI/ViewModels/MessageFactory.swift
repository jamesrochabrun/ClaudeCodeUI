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
  
  /// Creates a user message with the specified content
  /// - Parameters:
  ///   - content: The text content of the user's message
  ///   - codeSelections: Optional code selections to display with the message
  ///   - attachments: Optional file attachments to display with the message
  /// - Returns: A ChatMessage configured as a user message
  static func userMessage(content: String, codeSelections: [TextSelection]? = nil, attachments: [FileAttachment]? = nil) -> ChatMessage {
    ChatMessage(role: .user, content: content, codeSelections: codeSelections, attachments: attachments)
  }
  
  /// Creates an assistant message with streaming support
  /// - Parameters:
  ///   - id: Unique identifier for the message
  ///   - content: The text content of the assistant's response
  ///   - isComplete: Whether the message has finished streaming (default: true)
  /// - Returns: A ChatMessage configured as an assistant text message
  static func assistantMessage(id: UUID, content: String, isComplete: Bool) -> ChatMessage {
    ChatMessage(
      id: id,
      role: .assistant,
      content: content,
      isComplete: isComplete,
      messageType: .text
    )
  }
  
  /// Creates a tool use message showing which tool was invoked
  /// - Parameters:
  ///   - toolName: The name of the tool being used (e.g., "Bash", "TodoWrite")
  ///   - input: The formatted input parameters for the tool
  ///   - toolInputData: Optional structured data containing the tool's parameters
  ///   - taskGroupId: Optional group ID for Task tool execution tracking
  ///   - isTaskContainer: Whether this is a Task tool that contains other tools
  /// - Returns: A ChatMessage configured as a tool use message
  /// - Note: Empty inputs (like "[:] " or "{}") are handled gracefully by omitting the input display
  static func toolUseMessage(
    toolName: String, 
    input: String, 
    toolInputData: ToolInputData? = nil,
    taskGroupId: UUID? = nil,
    isTaskContainer: Bool = false
  ) -> ChatMessage {
    // For tools with no parameters, don't show empty input
    let content: String
    if input.isEmpty || input == "[:]" || input == "{}" {
      content = "TOOL USE: \(toolName)"
    } else {
      content = "TOOL USE: \(toolName). \n\(input)"
    }
    
    return ChatMessage(
      role: .toolUse,
      content: content,
      messageType: .toolUse,
      toolName: toolName,
      toolInputData: toolInputData,
      taskGroupId: taskGroupId,
      isTaskContainer: isTaskContainer
    )
  }
  
  /// Creates a tool result message showing the output of a tool execution
  /// - Parameters:
  ///   - content: The result content from the tool execution
  ///   - isError: Whether the tool execution resulted in an error
  ///   - taskGroupId: Optional group ID for Task tool execution tracking
  /// - Returns: A ChatMessage configured as either a tool result or tool error
  /// - Note: Handles both string results and structured item results
  static func toolResultMessage(content: MessageResponse.Content.ToolResultContent, isError: Bool, taskGroupId: UUID? = nil) -> ChatMessage {
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
      messageType: isError ? .toolError : .toolResult,
      isError: isError,
      taskGroupId: taskGroupId
    )
  }
  
  /// Creates a thinking message showing Claude's internal reasoning
  /// - Parameter content: The thinking content from Claude
  /// - Returns: A ChatMessage configured as a thinking message
  /// - Note: Thinking messages are prefixed with "THINKING:" for clarity
  static func thinkingMessage(content: String) -> ChatMessage {
    ChatMessage(
      role: .thinking,
      content: "THINKING: \(content)",
      messageType: .thinking
    )
  }
  
  /// Creates a web search result message
  /// - Parameter resultCount: The number of search results found
  /// - Returns: A ChatMessage configured as a web search result
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
