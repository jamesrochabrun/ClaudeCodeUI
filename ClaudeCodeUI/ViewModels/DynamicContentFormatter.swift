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
    
    // Extract the array from DynamicContent
    let mirror = Mirror(reflecting: content)
    logger.debug("Mirror children count: \(mirror.children.count)")
    
    for child in mirror.children {
      logger.debug("Child label: \(child.label ?? "nil"), type: \(type(of: child.value))")
      
      if let array = child.value as? [Any] {
        logger.debug("Found array with \(array.count) items for todos")
        return formatTodosArray(array)
      }
    }
    
    // Fall back to regular formatting if not an array
    return format(content)
  }
  
  /// Formats any DynamicContent into a string
  /// - Parameter content: The DynamicContent to format
  /// - Returns: A formatted string representation
  func format(_ content: MessageResponse.Content.DynamicContent) -> String {
    let mirror = Mirror(reflecting: content)
    logger.debug("formatDynamicContent - Mirror children count: \(mirror.children.count)")
    
    // Try to find the actual value within the DynamicContent
    for child in mirror.children {
      logger.debug("Child label: \(child.label ?? "nil"), type: \(type(of: child.value))")
      
      if let value = child.value as? String {
        return value
      } else if let value = child.value as? Bool {
        return value ? "true" : "false"
      } else if let value = child.value as? NSNumber {
        return value.stringValue
      } else if let array = child.value as? [Any] {
        logger.debug("Found array with \(array.count) items")
        return formatParameterValue(array)
      } else if let dict = child.value as? [String: Any] {
        return formatParameterValue(dict)
      }
    }
    
    // If we can't extract a specific value, use string description
    return formatParameterValue(content)
  }
  
  // MARK: - Private Methods
  
  private func formatTodosArray(_ array: [Any]) -> String {
    logger.debug("formatTodosArray - Array with \(array.count) items")
    
    var todoDescriptions: [String] = []
    
    for item in array {
      // Try to extract dictionary from DynamicContent
      if let dynamicDict = extractDictionaryFromDynamicContent(item) {
        logger.debug("Extracted dictionary with keys: \(dynamicDict.keys.sorted())")
        
        // Try different key variations for content
        let contentValue = dynamicDict["content"] ?? 
                          dynamicDict["description"] ?? 
                          dynamicDict["task"]
        
        if let content = contentValue {
          logger.debug("Found content: '\(content)'")
          // Check status to determine checkbox
          let status = dynamicDict["status"] ?? "pending"
          logger.debug("Todo status: '\(status)'")
          let checkbox = status == "completed" ? "[✓]" : "[ ]"
          todoDescriptions.append("\(checkbox) \(content)")
        } else {
          logger.debug("No content found in todo dict")
        }
      } else if let regularDict = item as? [String: Any] {
        // Handle regular dictionaries
        logger.debug("Regular dict keys: \(regularDict.keys.sorted())")
        
        let contentValue = regularDict["content"] as? String ?? 
                          regularDict["description"] as? String ?? 
                          regularDict["task"] as? String
        
        if let content = contentValue {
          logger.debug("Found content: '\(content)'")
          let status = regularDict["status"] as? String ?? "pending"
          logger.debug("Todo status: '\(status)'")
          let checkbox = status == "completed" ? "[✓]" : "[ ]"
          todoDescriptions.append("\(checkbox) \(content)")
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
  
  private func extractDictionaryFromDynamicContent(_ item: Any) -> [String: String]? {
    logger.debug("Extracting from item of type: \(type(of: item))")
    
    let description = String(describing: item)
    
    // Check if it's a DynamicContent dictionary
    if description.hasPrefix("dictionary(") {
      logger.debug("Found DynamicContent dictionary")
      
      var result: [String: String] = [:]
      
      // Parse the description to extract key-value pairs
      if let startIndex = description.firstIndex(of: "["),
         let endIndex = description.lastIndex(of: "]") {
        let dictContent = String(description[description.index(after: startIndex)..<endIndex])
        logger.debug("Dictionary content: \(dictContent)")
        
        let pairs = splitDictionaryPairs(dictContent)
        
        for pair in pairs {
          if let colonIndex = pair.firstIndex(of: ":") {
            let key = pair[..<colonIndex]
              .trimmingCharacters(in: .whitespacesAndNewlines)
              .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            
            let valueStr = String(pair[pair.index(after: colonIndex)...])
              .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let value = extractStringFromDynamicContent(valueStr) {
              result[key] = value
            }
          }
        }
      }
      
      return result.isEmpty ? nil : result
    }
    
    return nil
  }
  
  private func splitDictionaryPairs(_ content: String) -> [String] {
    var pairs: [String] = []
    var currentPair = ""
    var parenDepth = 0
    var inQuotes = false
    var prevChar: Character?
    
    for char in content {
      if char == "\"" && prevChar != "\\" {
        inQuotes.toggle()
      } else if !inQuotes {
        if char == "(" {
          parenDepth += 1
        } else if char == ")" {
          parenDepth -= 1
        } else if char == "," && parenDepth == 0 {
          pairs.append(currentPair)
          currentPair = ""
          prevChar = char
          continue
        }
      }
      currentPair.append(char)
      prevChar = char
    }
    
    if !currentPair.isEmpty {
      pairs.append(currentPair)
    }
    
    return pairs
  }
  
  private func extractStringFromDynamicContent(_ value: String) -> String? {
    // Extract from patterns like: DynamicContent.string("value")
    if let startIndex = value.firstIndex(of: "("),
       let endIndex = value.lastIndex(of: ")") {
      let content = value[value.index(after: startIndex)..<endIndex]
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
      return String(content)
    }
    return nil
  }
  
  private func formatParameterValue(_ value: Any) -> String {
    switch value {
    case let string as String:
      return string
    case let bool as Bool:
      return bool ? "true" : "false"
    case let number as NSNumber:
      return number.stringValue
    case let array as [Any]:
      logger.debug("formatParameterValue - Array with \(array.count) items")
      logger.debug("Array type: \(type(of: array))")
      logger.debug("First item type: \(array.first.map { String(describing: type(of: $0)) } ?? "empty")")
      
      // Special handling for todos array
      if array.allSatisfy({ ($0 as? [String: Any]) != nil }) {
        logger.debug("Array contains all dictionaries - checking for todos")
        let todos = array.compactMap { $0 as? [String: Any] }
        logger.debug("Successfully cast \(todos.count) items to dictionaries")
        
        let todoDescriptions = todos.compactMap { todo -> String? in
          logger.debug("Todo dict keys: \(todo.keys.sorted())")
          logger.debug("Todo dict: \(todo)")
          
          // Try different key variations
          let contentValue = todo["content"] as? String ?? 
                           todo["description"] as? String ?? 
                           todo["task"] as? String
          
          if let content = contentValue {
            logger.debug("Found content: '\(content)'")
            // Check status to determine checkbox
            let status = todo["status"] as? String ?? "pending"
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
          logger.debug("First array item type detail: \(String(describing: type(of: firstItem)))")
        }
      }
      
      // For other arrays, join elements or show count
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