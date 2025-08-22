//
//  SwiftAnthropicExtensions.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 6/20/2025.
//

import Foundation
import SwiftAnthropic
import os.log

extension MessageResponse.Content.Input {
  /// Formats the tool input for display
  func formattedDescription() -> String {
    // Input is a type alias for [String: MessageResponse.Content.DynamicContent]
    var parameters: [String] = []
    
    // Sort keys for consistent output
    let sortedKeys = self.keys.sorted()
    
    for key in sortedKeys {
      if let dynamicContent = self[key] {
        let valueString = formatDynamicContent(dynamicContent)
        // Special handling for todos - don't include the key prefix
        if key == "todos" && (valueString.contains("[✓]") || valueString.contains("[ ]")) {
          parameters.append(valueString)
        } else {
          parameters.append("\(key): \(valueString)")
        }
      }
    }
    
    // Join parameters with newlines for readability
    let description = parameters.joined(separator: "\n")
    
    // If we couldn't extract any parameters, fall back to string description
    if description.isEmpty {
      return String(describing: self)
    }
    
    return description
  }
  
  /// Helper function to format DynamicContent values
  private func formatDynamicContent(_ content: MessageResponse.Content.DynamicContent) -> String {
    let logger = Logger(subsystem: "com.ClaudeCodeUI.Extensions", category: "SwiftAnthropicExtensions")
    logger.debug("formatDynamicContent called")
    
    // Use the built-in computed properties to extract values
    if let stringValue = content.stringValue {
      return formatValue(stringValue)
    } else if let intValue = content.intValue {
      return formatValue(intValue)
    } else if let boolValue = content.boolValue {
      return formatValue(boolValue)
    } else if let arrayValue = content.arrayValue {
      return formatValue(arrayValue)
    } else if let dictValue = content.dictionaryValue {
      return formatValue(dictValue)
    } else if case .null = content {
      return "null"
    } else if case .double(let doubleValue) = content {
      return formatValue(doubleValue)
    }
    
    // Fallback to string description
    logger.debug("Using string description as fallback")
    return String(describing: content)
  }
  
  /// Helper function to format values based on type
  private func formatValue(_ value: Any) -> String {
    let logger = Logger(subsystem: "com.ClaudeCodeUI.Extensions", category: "SwiftAnthropicExtensions")
    // Handle different types appropriately
    switch value {
    case let string as String:
      // For strings, show them with quotes if they're short, or truncate if long
      if string.count > 100 {
        return "\"\(string.prefix(100))...\""
      } else {
        return "\"\(string)\""
      }
    case let bool as Bool:
      return bool ? "true" : "false"
    case let number as NSNumber:
      return number.stringValue
    case let number as Int:
      return String(number)
    case let number as Double:
      return String(number)
    case let array as [MessageResponse.Content.DynamicContent]:
      logger.debug("formatValue - Array with \(array.count) items")
      
      // Special handling for todos array - check if array contains dictionaries
      var todoDescriptions: [String] = []
      
      for item in array {
        // Use the built-in dictionaryValue property
        if let dict = item.dictionaryValue {
          logger.debug("Found dictionary with keys: \(dict.keys.sorted())")
          
          // Try different key variations for content
          let contentValue = dict["content"]?.stringValue ??
          dict["description"]?.stringValue ??
          dict["task"]?.stringValue
          
          if let content = contentValue {
            logger.debug("Found content: '\(content)'")
            // Check status to determine checkbox
            let status = dict["status"]?.stringValue ?? "pending"
            logger.debug("Todo status: '\(status)'")
            let checkbox = status == "completed" ? "[✓]" : "[ ]"
            todoDescriptions.append("\(checkbox) \(content)")
          }
        }
      }
      
      logger.debug("Created \(todoDescriptions.count) todo descriptions")
      if !todoDescriptions.isEmpty {
        logger.debug("Returning formatted todos")
        // Show all todos, each on a new line
        return todoDescriptions.joined(separator: "\n")
      }
      return "[\(array.count) items]"
    case let dict as [String: MessageResponse.Content.DynamicContent]:
      return "{\(dict.count) properties}"
    case let dict as [String: Any]:
      return "{\(dict.count) properties}"
    default:
      // For other types, use string description
      let description = String(describing: value)
      // Truncate if too long
      if description.count > 100 {
        return String(description.prefix(100)) + "..."
      }
      return description
    }
  }
  
}

