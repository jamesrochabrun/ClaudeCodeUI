//
//  JSONToolFormatter.swift
//  ClaudeCodeUI
//
//  Created on 1/10/2025.
//

import Foundation

/// Formatter for tools that output JSON data
struct JSONToolFormatter: ToolFormatterProtocol {
  
  func formatOutput(_ output: String, tool: ToolType) -> (String, ToolDisplayFormatter.ToolContentFormatter.ContentType) {
    let formattedJSON = output.formatJSON()
    let formatted = """
    ```json
    \(formattedJSON)
    ```
    """
    return (formatted, .markdown)
  }
  
  // Uses default implementations for formatArguments and extractKeyParameters
}