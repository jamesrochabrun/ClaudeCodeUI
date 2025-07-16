//
//  BashToolFormatterTests.swift
//  ClaudeCodeUITests
//
//  Created on 1/10/2025.
//

import XCTest
@testable import ClaudeCodeUI

final class BashToolFormatterTests: XCTestCase {
  
  private var formatter: BashToolFormatter!
  private var bashTool: ToolType!
  
  override func setUp() {
    super.setUp()
    formatter = BashToolFormatter()
    bashTool = ClaudeCodeTool.bash
  }
  
  override func tearDown() {
    formatter = nil
    bashTool = nil
    super.tearDown()
  }
  
  func testFormatOutput() {
    // Given
    let output = """
    file1.txt
    file2.txt
    directory/
    """
    
    // When
    let (formatted, contentType) = formatter.formatOutput(output, tool: bashTool)
    
    // Then
    XCTAssertTrue(formatted.contains("```shell"))
    XCTAssertTrue(formatted.contains("file1.txt"))
    XCTAssertEqual(contentType, .)
  }
  
  func testFormatArguments() {
    // Given
    let arguments = """
    {
      "command": "ls -la /Users/test",
      "timeout": 5000,
      "quiet": true
    }
    """
    
    // When
    let formatted = formatter.formatArguments(arguments, tool: bashTool)
    
    // Then
    XCTAssertTrue(formatted.contains("command"))
    XCTAssertTrue(formatted.contains("ls -la /Users/test"))
    XCTAssertTrue(formatted.contains("timeout"))
  }
  
  func testExtractKeyParameters() {
    // Given
    let arguments = """
    {
      "command": "npm install react react-dom",
      "timeout": 30000
    }
    """
    
    // When
    let keyParams = formatter.extractKeyParameters(arguments, tool: bashTool)
    
    // Then
    XCTAssertNotNil(keyParams)
    XCTAssertEqual(keyParams, "npm install react react-dom")
  }
  
  func testDangerousCommandWarning() {
    // Given
    let arguments = """
    {
      "command": "sudo rm -rf /",
      "timeout": 1000
    }
    """
    
    // When
    let formatted = formatter.formatArguments(arguments, tool: bashTool)
    
    // Then
    XCTAssertTrue(formatted.contains("⚠️"))
    XCTAssertTrue(formatted.contains("sudo rm"))
  }
}
