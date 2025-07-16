//
//  ToolInputDataTests.swift
//  ClaudeCodeUITests
//
//  Created by Assistant on 6/20/2025.
//

import Testing
import Foundation
@testable import ClaudeCodeUI

struct ToolInputDataTests {
  
  @Test func testKeyParametersExtraction() async throws {
    // Test with priority parameters
    let toolInputData = ToolInputData(parameters: [
      "file_path": "/Users/test/document.txt",
      "limit": "100",
      "offset": "0",
      "extra_param": "value"
    ])
    
    let keyParams = toolInputData.keyParameters
    
    // Should prioritize file_path and include up to 3 parameters
    #expect(keyParams.count <= 3)
    #expect(keyParams[0].key == "file_path")
    #expect(keyParams[0].value == "/Users/test/document.txt")
  }
  
  @Test func testKeyParametersTruncation() async throws {
    // Test with long values
    let longPath = "/very/long/path/that/exceeds/thirty/characters/document.txt"
    let toolInputData = ToolInputData(parameters: [
      "file_path": longPath,
      "command": "ls -la"
    ])
    
    let keyParams = toolInputData.keyParameters
    
    #expect(keyParams.count == 2)
    #expect(keyParams[0].key == "file_path")
    #expect(keyParams[0].value == longPath) // Should not truncate in the data structure
  }
  
  @Test func testEmptyParameters() async throws {
    let toolInputData = ToolInputData(parameters: [:])
    let keyParams = toolInputData.keyParameters
    
    #expect(keyParams.isEmpty)
  }
  
  @Test func testNonPriorityParameters() async throws {
    // Test with only non-priority parameters
    let toolInputData = ToolInputData(parameters: [
      "custom_param1": "value1",
      "custom_param2": "value2",
      "custom_param3": "value3",
      "custom_param4": "value4"
    ])
    
    let keyParams = toolInputData.keyParameters
    
    // Should include up to 3 parameters
    #expect(keyParams.count == 3)
  }
  
  @Test func testTodosParameterHandling() async throws {
    // Test with todos parameter containing completed and pending items
    let todosValue = """
    [✓] Implement user authentication
    [ ] Add password reset functionality
    [✓] Set up database connection
    [ ] Create API endpoints
    [ ] Write unit tests
    """
    
    let toolInputData = ToolInputData(parameters: ["todos": todosValue])
    let keyParams = toolInputData.keyParameters
    
    #expect(keyParams.count == 1)
    #expect(keyParams[0].key == "todos")
    #expect(keyParams[0].value == "2/5 completed")
  }
  
  @Test func testTodosParameterEmpty() async throws {
    // Test with empty todos parameter
    let toolInputData = ToolInputData(parameters: ["todos": ""])
    let keyParams = toolInputData.keyParameters
    
    // Should not include todos if count is 0
    #expect(keyParams.isEmpty)
  }
  
  @Test func testTodosParameterAllCompleted() async throws {
    // Test with all todos completed
    let todosValue = """
    [✓] Task 1
    [✓] Task 2
    [✓] Task 3
    """
    
    let toolInputData = ToolInputData(parameters: ["todos": todosValue])
    let keyParams = toolInputData.keyParameters
    
    #expect(keyParams.count == 1)
    #expect(keyParams[0].key == "todos")
    #expect(keyParams[0].value == "3/3 completed")
  }
  
  @Test func testPriorityKeyOrdering() async throws {
    // Test that priority keys appear in the specified order
    let toolInputData = ToolInputData(parameters: [
      "name": "test-name",
      "url": "https://example.com",
      "file_path": "/Users/test/file.txt",
      "command": "ls -la",
      "extra": "value"
    ])
    
    let keyParams = toolInputData.keyParameters
    
    #expect(keyParams.count == 3)
    // file_path should come first as it's first in priorityKeys
    #expect(keyParams[0].key == "file_path")
    #expect(keyParams[1].key == "command")
    // url comes before name in priority order
    #expect(keyParams[2].key == "url")
  }
  
  @Test func testMixedPriorityAndNonPriorityParameters() async throws {
    // Test with a mix of priority and non-priority parameters
    let toolInputData = ToolInputData(parameters: [
      "custom_param": "custom_value",
      "pattern": "*.swift",
      "another_param": "another_value",
      "query": "search term"
    ])
    
    let keyParams = toolInputData.keyParameters
    
    #expect(keyParams.count == 3)
    // Priority parameters should come first
    #expect(keyParams[0].key == "pattern")
    #expect(keyParams[1].key == "query")
    // Then non-priority parameters
    #expect(keyParams[2].key == "custom_param")
  }
  
  @Test func testParameterLimitEnforcement() async throws {
    // Test that only 3 parameters are returned even with many inputs
    let toolInputData = ToolInputData(parameters: [
      "file_path": "/path/to/file",
      "command": "git status",
      "pattern": "test*",
      "query": "search",
      "path": "/another/path",
      "url": "https://example.com",
      "name": "test"
    ])
    
    let keyParams = toolInputData.keyParameters
    
    // Should only return 3 parameters maximum
    #expect(keyParams.count == 3)
    #expect(keyParams[0].key == "file_path")
    #expect(keyParams[1].key == "command")
    #expect(keyParams[2].key == "pattern")
  }
  
  @Test func testSpecialCharactersInValues() async throws {
    // Test handling of special characters in parameter values
    let toolInputData = ToolInputData(parameters: [
      "file_path": "/path/with spaces/and \"quotes\"/file.txt",
      "command": "echo 'hello\nworld'",
      "pattern": ".*\\.(swift|m)$"
    ])
    
    let keyParams = toolInputData.keyParameters
    
    #expect(keyParams.count == 3)
    #expect(keyParams[0].value == "/path/with spaces/and \"quotes\"/file.txt")
    #expect(keyParams[1].value == "echo 'hello\nworld'")
    #expect(keyParams[2].value == ".*\\.(swift|m)$")
  }
  
  @Test func testTodosWithMixedParameters() async throws {
    // Test todos parameter alongside other parameters
    let todosValue = """
    [✓] First task
    [ ] Second task
    """
    
    let toolInputData = ToolInputData(parameters: [
      "todos": todosValue,
      "file_path": "/test/path",
      "command": "npm test"
    ])
    
    let keyParams = toolInputData.keyParameters
    
    // todos should take precedence when present
    #expect(keyParams.count == 1)
    #expect(keyParams[0].key == "todos")
    #expect(keyParams[0].value == "1/2 completed")
  }
}