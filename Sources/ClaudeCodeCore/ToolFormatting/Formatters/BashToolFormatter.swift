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

  // MARK: - Compact Summary & Preview

  /// Returns a compact summary for bash output
  func compactSummary(_ result: String, tool: ToolType) -> String? {
    let lines = result.components(separatedBy: .newlines).filter { !$0.isEmpty }

    if lines.isEmpty {
      return "Completed"
    }

    // Check for error indicators
    let hasError = result.lowercased().contains("error") ||
                   result.lowercased().contains("failed") ||
                   result.lowercased().contains("fatal")

    if hasError {
      return "Error"
    }

    return nil  // Use preview content instead
  }

  /// Returns preview content with first few lines and remaining count
  func previewContent(_ result: String, tool: ToolType, maxLines: Int) -> (preview: String, remainingLines: Int)? {
    let lines = result.components(separatedBy: .newlines)
    guard !lines.isEmpty else { return nil }

    let previewLines = Array(lines.prefix(maxLines))
    let remainingCount = max(0, lines.count - maxLines)

    // Truncate long lines for cleaner display
    let truncatedPreview = previewLines.map { line -> String in
      if line.count > 100 {
        return String(line.prefix(97)) + "..."
      }
      return line
    }

    return (truncatedPreview.joined(separator: "\n"), remainingCount)
  }
}
