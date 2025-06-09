//
//  MessageFactoryTests.swift
//  ClaudeCodeUITests
//
//  Created by Assistant on 6/8/2025.
//

import Testing
import Foundation
@testable import ClaudeCodeUI

struct MessageFactoryTests {
  
  @Test func testCreateUserMessage() async throws {
    let content = "Hello, Claude!"
    let message = MessageFactory.userMessage(content: content)
    
    #expect(message.role == .user)
    #expect(message.content == content)
    #expect(message.isComplete)
    #expect(message.messageType == .text)
  }
  
  @Test func testCreateAssistantMessage() async throws {
    let id = UUID()
    let content = "Hello! How can I help?"
    let message = MessageFactory.assistantMessage(
      id: id,
      content: content,
      isComplete: false
    )
    
    #expect(message.id == id)
    #expect(message.role == .assistant)
    #expect(message.content == content)
    #expect(!message.isComplete)
    #expect(message.messageType == .text)
  }
  
  @Test func testCreateToolUseMessage() async throws {
    let toolName = "Bash"
    let input = "{ \"command\": \"ls -la\" }"
    let message = MessageFactory.toolUseMessage(
      toolName: toolName,
      input: input
    )
    
    #expect(message.role == .toolUse)
    #expect(message.content.contains(toolName))
    #expect(message.content.contains(input))
    #expect(message.isComplete)
    #expect(message.messageType == .toolUse)
    #expect(message.toolName == toolName)
  }
  
  // Skip tool result tests as they require SDK types
  /*
   @Test func testCreateToolResultMessage() async throws {
   // Requires MessageResponse.Content.ToolResultContent from SDK
   }
   
   @Test func testCreateToolResultErrorMessage() async throws {
   // Requires MessageResponse.Content.ToolResultContent from SDK
   }
   */
  
  @Test func testCreateThinkingMessage() async throws {
    let thought = "Analyzing the problem..."
    let message = MessageFactory.thinkingMessage(content: thought)
    
    #expect(message.role == .thinking)
    #expect(message.content == "THINKING: \(thought)")
    #expect(message.isComplete)
    #expect(message.messageType == .thinking)
  }
  
  @Test func testCreateWebSearchMessage() async throws {
    let resultCount = 5
    let message = MessageFactory.webSearchMessage(resultCount: resultCount)
    
    #expect(message.role == .assistant)
    #expect(message.content.contains("\(resultCount)"))
    #expect(message.isComplete)
    #expect(message.messageType == .webSearch)
  }
}
