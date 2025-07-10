//
//  BashToolFormatter.swift
//  ClaudeCodeUI
//
//  Created on 1/10/2025.
//

import Foundation

/// Formatter for Bash/Shell tool output
struct BashToolFormatter: ToolFormatterProtocol {
  private let shellFormatter = ShellFormatter()
  
  func formatOutput(_ output: String, tool: ToolType) -> (String, ToolDisplayFormatter.ToolContentFormatter.ContentType) {
    let formattedOutput = shellFormatter.formatOutput(output)
    
    let formatted = """
    ```shell
    \(formattedOutput)
    ```
    """
    
    return (formatted, .markdown)
  }
  
  func formatArguments(_ arguments: String, tool: ToolType) -> String {
    // For bash, we want to show the command prominently
    if let jsonDict = arguments.toDictionary(),
       let command = jsonDict["command"] as? String {
      
      // Format the command with danger warnings if needed
      let formattedCommand = shellFormatter.formatCommand(command)
      
      // Create a simplified view showing just the command
      let simplified: [String: Any] = [
        "command": formattedCommand,
        "timeout": jsonDict["timeout"] ?? "default"
      ]
      
      if let data = try? JSONSerialization.data(withJSONObject: simplified, options: .prettyPrinted),
         let formatted = String(data: data, encoding: .utf8) {
        return formatted
      }
    }
    
    // Fallback to default implementation
    return arguments.formatJSON()
  }
  
  func extractKeyParameters(_ arguments: String, tool: ToolType) -> String? {
    if let jsonDict = arguments.toDictionary(),
       let command = jsonDict["command"] as? String {
      // Show a truncated version of the command
      return command.truncateIntelligently(to: 50)
    }
    
    return nil
  }
}
