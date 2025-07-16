//
//  PlainTextToolFormatter.swift
//  ClaudeCodeUI
//
//  Created on 1/10/2025.
//

import Foundation

/// Default formatter for tools that output plain text
struct PlainTextToolFormatter: ToolFormatterProtocol {
  
  func formatOutput(_ output: String, tool: ToolType) -> (String, ToolDisplayFormatter.ToolContentFormatter.ContentType) {
    // Check if it might be JSON and format accordingly
    if output.trimmingCharacters(in: .whitespacesAndNewlines).starts(with: "{") ||
        output.trimmingCharacters(in: .whitespacesAndNewlines).starts(with: "[") {
      let formattedJSON = output.formatJSON()
      let wrapped = """
      ```json
      \(formattedJSON)
      ```
      """
      return (wrapped, .markdown)
    }
    
    // Otherwise, return as plain text with line limiting
    let limited = output.limitToLines(50, maxCharacters: 2000)
    return (limited, .plainText)
  }
  
  // Uses default implementations for formatArguments and extractKeyParameters
}
