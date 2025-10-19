//
//  AskUserQuestionFormatter.swift
//  ClaudeCodeUI
//
//  Created for AskUserQuestion tool support
//

import Foundation

/// Formatter for AskUserQuestion tool display
struct AskUserQuestionFormatter: ToolFormatterProtocol {
  
  func formatOutput(_ output: String, tool: ToolType) -> (String, ToolDisplayFormatter.ToolContentFormatter.ContentType) {
    // Output is typically the user's answers
    return (output, .plainText)
  }
  
  func extractKeyParameters(_ arguments: String, tool: ToolType) -> String? {
    // Extract number of questions for header display
    if let jsonDict = arguments.toDictionary(),
       let questions = jsonDict["questions"] as? [[String: Any]] {
      let count = questions.count
      return "\(count) question\(count == 1 ? "" : "s")"
    }
    return nil
  }
}
