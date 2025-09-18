//
//  MessageFactoryTests.swift
//  ClaudeCodeUITests
//
//  Created by Assistant on 6/8/2025.
//

import Testing
import Foundation
@testable import ClaudeCodeCore

struct MessageFactoryTests {
  
  @Test func testCreateUserMessage() async throws {
    let content = "Hello, Claude!"
    let message = MessageFactory.userMessage(content: content)
    
    #expect(message.role == .user)
    #expect(message.content == content)
    #expect(message.isComplete)
    #expect(message.messageType == .text)
    #expect(!message.isError)
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
    #expect(!message.isError)
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
  
  @Test func testCreateToolUseMessageWithInputData() async throws {
    let toolName = "Read"
    let input = "file_path: /path/to/file.txt\nlimit: 100"
    let toolInputData = ToolInputData(parameters: [
      "file_path": "/path/to/file.txt",
      "limit": "100"
    ])
    
    let message = MessageFactory.toolUseMessage(
      toolName: toolName,
      input: input,
      toolInputData: toolInputData
    )
    
    #expect(message.role == .toolUse)
    #expect(message.content.contains(toolName))
    #expect(message.content.contains(input))
    #expect(message.isComplete)
    #expect(message.messageType == .toolUse)
    #expect(message.toolName == toolName)
    #expect(message.toolInputData == toolInputData)
    
    // Test key parameters extraction
    let keyParams = toolInputData.keyParameters
    #expect(keyParams.count == 2)
    #expect(keyParams[0].key == "file_path")
    #expect(keyParams[0].value == "/path/to/file.txt")
  }
  
  @Test func testCreateToolUseMessageWithEmptyInput() async throws {
    let toolName = "TodoRead"
    
    // Test with empty string
    let message1 = MessageFactory.toolUseMessage(
      toolName: toolName,
      input: ""
    )
    #expect(message1.content == "TOOL USE: TodoRead")
    #expect(!message1.content.contains("\n"))
    
    // Test with empty dictionary notation
    let message2 = MessageFactory.toolUseMessage(
      toolName: toolName,
      input: "[:]"
    )
    #expect(message2.content == "TOOL USE: TodoRead")
    #expect(!message2.content.contains("[:]"))
    
    // Test with empty JSON object
    let message3 = MessageFactory.toolUseMessage(
      toolName: toolName,
      input: "{}"
    )
    #expect(message3.content == "TOOL USE: TodoRead")
    #expect(!message3.content.contains("{}"))
  }
  
  @Test func testCreateToolUseMessageWithTodos() async throws {
    let toolName = "TodoWrite"
    let input = "[✓] Set up development environment\n[✓] Review project requirements\n[ ] Implement user authentication\n[ ] Create database schema"
    let toolInputData = ToolInputData(parameters: [
      "todos": "[✓] Set up development environment\n[✓] Review project requirements\n[ ] Implement user authentication\n[ ] Create database schema"
    ])
    
    let message = MessageFactory.toolUseMessage(
      toolName: toolName,
      input: input,
      toolInputData: toolInputData
    )
    
    #expect(message.role == .toolUse)
    #expect(message.content.contains(toolName))
    #expect(message.content.contains(input))
    #expect(message.toolInputData == toolInputData)
    
    // Test todos key parameters extraction
    let keyParams = toolInputData.keyParameters
    #expect(keyParams.count == 1)
    #expect(keyParams[0].key == "todos")
    #expect(keyParams[0].value == "2/4 completed")
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
