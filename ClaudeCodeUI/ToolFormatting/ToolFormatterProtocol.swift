//
//  ToolFormatterProtocol.swift
//  ClaudeCodeUI
//
//  Created on 1/10/2025.
//

import Foundation

/// Protocol that defines the interface for all tool formatters
public protocol ToolFormatterProtocol {
  /// Formats the tool's output/response for display
  /// - Parameters:
  ///   - output: The raw output from the tool
  ///   - tool: The tool type information
  /// - Returns: A tuple containing the formatted string and content type
  func formatOutput(_ output: String, tool: ToolType) -> (String, ToolDisplayFormatter.ToolContentFormatter.ContentType)
  
  /// Formats the tool's input arguments for display
  /// - Parameters:
  ///   - arguments: The raw arguments as a string (usually JSON)
  ///   - tool: The tool type information
  /// - Returns: The formatted arguments string
  func formatArguments(_ arguments: String, tool: ToolType) -> String
  
  /// Extracts key parameters from arguments for compact header display
  /// - Parameters:
  ///   - arguments: The raw arguments as a string (usually JSON)
  ///   - tool: The tool type information
  /// - Returns: A formatted string of key parameters, or nil if none
  func extractKeyParameters(_ arguments: String, tool: ToolType) -> String?
}

/// Base implementation with default behavior
public extension ToolFormatterProtocol {
  /// Default implementation for formatting arguments
  func formatArguments(_ arguments: String, tool: ToolType) -> String {
    // Try to parse as JSON first
    if let jsonDict = arguments.toDictionary() {
      var filtered: [String: Any] = [:]
      
      // Use priority parameters from tool
      for key in tool.priorityParameters {
        if let value = jsonDict[key] {
          filtered[key] = formatArgumentValue(key: key, value: value)
        }
      }
      
      // Add remaining parameters if space allows
      for (key, value) in jsonDict {
        if !tool.priorityParameters.contains(key) && filtered.count < 5 {
          filtered[key] = formatArgumentValue(key: key, value: value)
        }
      }
      
      // Convert back to formatted JSON
      if let data = try? JSONSerialization.data(withJSONObject: filtered, options: .prettyPrinted),
         let formatted = String(data: data, encoding: .utf8) {
        return formatted
      }
    }
    
    return arguments.formatJSON()
  }
  
  /// Default implementation for extracting key parameters
  func extractKeyParameters(_ arguments: String, tool: ToolType) -> String? {
    guard let params = arguments.toDictionary() else {
      return nil
    }
    
    var keyParams: [String] = []
    
    // Extract priority parameters
    for paramName in tool.priorityParameters {
      if let value = params[paramName] {
        let formattedValue = formatParameterForHeader(key: paramName, value: value)
        if !formattedValue.isEmpty {
          keyParams.append(formattedValue)
        }
      }
      
      if keyParams.count >= 2 {
        break
      }
    }
    
    return keyParams.isEmpty ? nil : keyParams.joined(separator: ", ")
  }
  
  /// Helper method to format individual argument values
  private func formatArgumentValue(key: String, value: Any) -> Any {
    switch key {
    case "content", "old_string", "new_string", "prompt", "plan":
      if let stringValue = value as? String {
        return stringValue.truncateIntelligently(to: 100)
      }
      
    case "todos":
      if let todosArray = value as? [[String: Any]] {
        return "[\(todosArray.count) todos]"
      }
      
    case "edits":
      if let editsArray = value as? [[String: Any]] {
        return "[\(editsArray.count) edits]"
      }
      
    default:
      break
    }
    
    return value
  }
  
  /// Helper method to format parameters for header display
  private func formatParameterForHeader(key: String, value: Any) -> String {
    switch value {
    case let string as String:
      // Extract filename from path
      if key.contains("path") || key.contains("file") {
        return URL(fileURLWithPath: string).lastPathComponent
      }
      return string.truncateIntelligently(to: 30)
      
    case let array as [Any]:
      // Special handling for todos array
      if key == "todos", let todos = array as? [[String: Any]] {
        let completed = todos.filter { $0["status"] as? String == "completed" }.count
        return "\(completed)/\(todos.count) completed"
      }
      return "[\(array.count) items]"
      
    case let dict as [String: Any]:
      return "{\(dict.count) properties}"
      
    default:
      return String(describing: value).truncateIntelligently(to: 30)
    }
  }
}
