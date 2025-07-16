//
//  ToolInputData+HeaderText.swift
//  ClaudeCodeUI
//
//  Created on 6/21/2025.
//

import Foundation

extension ToolInputData {
  /// Generates a formatted header text for collapsible message views
  /// - Parameter toolName: The name of the tool
  /// - Returns: A formatted string with tool name and key parameters
  func headerText(for toolName: String) -> String {
    var header = toolName
    
    let keyParams = self.keyParameters
    if !keyParams.isEmpty {
      let paramString = keyParams.map { param in
        let value = param.value
        // Truncate long values for display
        let displayValue = value.count > 30 ? "\(value.prefix(27))..." : value
        return displayValue
      }.joined(separator: ", ")
      header += "(\(paramString))"
    }
    
    return header
  }
}