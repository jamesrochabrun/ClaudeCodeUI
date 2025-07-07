//
//  DynamicContentFormatter.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 6/21/2025.
//

import Foundation
import SwiftAnthropic
import os.log

/// Handles formatting of DynamicContent from Claude's API into user-friendly strings
///
/// This formatter is responsible for extracting and formatting values from the complex
/// DynamicContent structures returned by Claude's API, with special handling for
/// different data types like todos, arrays, and dictionaries.
final class DynamicContentFormatter {
  private let logger = Logger(subsystem: "com.ClaudeCodeUI.Formatting", category: "DynamicContentFormatter")
  
  /// Formats DynamicContent for todos with special handling
  /// - Parameter content: The DynamicContent to format
  /// - Returns: A formatted string with todo items including checkboxes
  func formatForTodos(_ content: MessageResponse.Content.DynamicContent) -> String {
    logger.debug("formatForTodos - special handling for todos")
    
    // Use the built-in arrayValue property to extract the array
    if let array = content.arrayValue {
      logger.debug("Found array with \(array.count) items for todos")
      return formatTodosArray(array)
    }
    
    // Fall back to regular formatting if not an array
    return format(content)
  }
  
  /// Formats any DynamicContent into a string
  /// - Parameter content: The DynamicContent to format
  /// - Returns: A formatted string representation
  func format(_ content: MessageResponse.Content.DynamicContent) -> String {
    logger.debug("formatDynamicContent called")
    
    // Use the built-in computed properties to extract values
    if let stringValue = content.stringValue {
      return stringValue
    } else if let intValue = content.intValue {
      return String(intValue)
    } else if let boolValue = content.boolValue {
      return boolValue ? "true" : "false"
    } else if let arrayValue = content.arrayValue {
      logger.debug("Found array with \(arrayValue.count) items")
      return formatParameterValue(arrayValue)
    } else if let dictValue = content.dictionaryValue {
      return formatParameterValue(dictValue)
    } else if case .null = content {
      return "null"
    } else if case .double(let doubleValue) = content {
      return String(doubleValue)
    }
    
    // If we can't extract a specific value, use string description
    return formatParameterValue(content)
  }
  
  // MARK: - Private Methods
  
  private func formatTodosArray(_ array: [MessageResponse.Content.DynamicContent]) -> String {
    logger.debug("formatTodosArray - Array with \(array.count) items")
    
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
        } else {
          logger.debug("No content found in todo dict")
        }
      }
    }
    
    logger.debug("Created \(todoDescriptions.count) todo descriptions")
    if !todoDescriptions.isEmpty {
      logger.debug("Returning formatted todos with checkboxes")
      return todoDescriptions.joined(separator: "\n")
    }
    
    // If we can't format as todos, return a simple count
    return "[\(array.count) items]"
  }
  
  
  private func formatParameterValue(_ value: Any) -> String {
    switch value {
    case let string as String:
      return string
    case let bool as Bool:
      return bool ? "true" : "false"
    case let number as NSNumber:
      return number.stringValue
    case let array as [MessageResponse.Content.DynamicContent]:
      logger.debug("formatParameterValue - Array with \(array.count) items")
      logger.debug("Array type: \(type(of: array))")
      logger.debug("First item type: \(array.first.map { String(describing: type(of: $0)) } ?? "empty")")
      
      // Special handling for todos array - check if all items have dictionary values
      if array.allSatisfy({ $0.dictionaryValue != nil }) {
        logger.debug("Array contains all dictionaries - checking for todos")
        
        let todoDescriptions = array.compactMap { item -> String? in
          guard let todo = item.dictionaryValue else { return nil }
          logger.debug("Todo dict keys: \(todo.keys.sorted())")
          
          // Try different key variations
          let contentValue = todo["content"]?.stringValue ??
          todo["description"]?.stringValue ??
          todo["task"]?.stringValue
          
          if let content = contentValue {
            logger.debug("Found content: '\(content)'")
            // Check status to determine checkbox
            let status = todo["status"]?.stringValue ?? "pending"
            logger.debug("Todo status: '\(status)'")
            let checkbox = status == "completed" ? "[✓]" : "[ ]"
            return "\(checkbox) \(content)"
          } else {
            logger.debug("No content found in todo dict")
          }
          return nil
        }
        
        logger.debug("Created \(todoDescriptions.count) todo descriptions")
        if !todoDescriptions.isEmpty {
          logger.debug("Returning formatted todos with checkboxes")
          return todoDescriptions.joined(separator: "\n")
        } else {
          logger.debug("No todo descriptions created, falling through")
        }
      } else {
        logger.debug("Array does NOT contain all dictionaries")
        if let firstItem = array.first {
          logger.debug("First array item: \(String(describing: firstItem))")
        }
      }
      
      // For other arrays, join elements or show count
      if array.count <= 3 {
        return array.map { String(describing: $0) }.joined(separator: ", ")
      } else {
        return "[\(array.count) items]"
      }
    case let dict as [String: MessageResponse.Content.DynamicContent]:
      // For dictionaries, show key count
      return "{\(dict.count) properties}"
    case let array as [Any]:
      // Generic array handling
      if array.count <= 3 {
        return array.map { String(describing: $0) }.joined(separator: ", ")
      } else {
        return "[\(array.count) items]"
      }
    case let dict as [String: Any]:
      // For dictionaries, show key count
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
