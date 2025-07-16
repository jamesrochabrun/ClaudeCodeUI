//
//  TaskToolFormatter.swift
//  ClaudeCodeUI
//
//  Created on 1/10/2025.
//

import Foundation

/// Formatter for Task tool output (typically markdown)
struct TaskToolFormatter: ToolFormatterProtocol {
  
  func formatOutput(_ output: String, tool: ToolType) -> (String, ToolDisplayFormatter.ToolContentFormatter.ContentType) {
    // Task output is usually already well-formatted markdown
    return (output, .markdown)
  }
  
  func extractKeyParameters(_ arguments: String, tool: ToolType) -> String? {
    if let jsonDict = arguments.toDictionary(),
       let description = jsonDict["description"] as? String {
      return description
    }
    return nil
  }
}
