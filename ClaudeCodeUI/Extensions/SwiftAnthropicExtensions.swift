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
    // DynamicContent can contain different types of values
    // We'll use reflection to extract the actual value
    let mirror = Mirror(reflecting: content)
    logger.debug("Mirror children count: \(mirror.children.count)")
    
    // Try to find the actual value within the DynamicContent
    for child in mirror.children {
      logger.debug("Child label: \(child.label ?? "nil"), type: \(String(describing: type(of: child.value)))")
      return formatValue(child.value)
    }
    
    // If we can't extract a specific value, use string description
    logger.debug("No children found in mirror, using string description")
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
    case let array as [Any]:
      logger.debug("formatValue - Array with \(array.count) items")
      logger.debug("Array type: \(String(describing: type(of: array)))")
      logger.debug("First item type: \(array.first.map { String(describing: type(of: $0)) } ?? "empty")")
      
      // Special handling for todos array - check if we have DynamicContent dictionaries
      var todoDescriptions: [String] = []
      
      for item in array {
        // Check if this is a DynamicContent dictionary
        let description = String(describing: item)
        if description.hasPrefix("dictionary(") {
          logger.debug("Found DynamicContent dictionary: \(description)")
          
          // Parse the DynamicContent dictionary to extract todos
          if let dict = parseDynamicContentDictionary(description) {
            logger.debug("Parsed dictionary with keys: \(dict.keys.sorted())")
            
            // Try different key variations for content
            let contentValue = dict["content"] ?? 
                              dict["description"] ?? 
                              dict["task"]
            
            if let content = contentValue {
              logger.debug("Found content: '\(content)'")
              // Check status to determine checkbox
              let status = dict["status"] ?? "pending"
              logger.debug("Todo status: '\(status)'")
              let checkbox = status == "completed" ? "[✓]" : "[ ]"
              todoDescriptions.append("\(checkbox) \(content)")
            }
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
        logger.debug("Returning formatted todos")
        // Show all todos, each on a new line
        return todoDescriptions.joined(separator: "\n")
      }
      return "[\(array.count) items]"
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
  
  /// Parse DynamicContent dictionary description to extract key-value pairs
  private func parseDynamicContentDictionary(_ description: String) -> [String: String]? {
    // Format: dictionary(["key": DynamicContent.string("value"), ...])
    guard description.hasPrefix("dictionary("),
          let startIndex = description.firstIndex(of: "["),
          let endIndex = description.lastIndex(of: "]") else {
      return nil
    }
    
    let dictContent = String(description[description.index(after: startIndex)..<endIndex])
    var result: [String: String] = [:]
    
    // Split by commas carefully (handling nested structures)
    let pairs = splitDictionaryPairs(dictContent)
    
    for pair in pairs {
      if let colonIndex = pair.firstIndex(of: ":") {
        let key = pair[..<colonIndex]
          .trimmingCharacters(in: .whitespacesAndNewlines)
          .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        
        let valueStr = String(pair[pair.index(after: colonIndex)...])
          .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Extract string value from DynamicContent.string("value")
        if let value = extractStringFromDynamicContent(valueStr) {
          result[key] = value
        }
      }
    }
    
    return result.isEmpty ? nil : result
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
    if value.contains(".string("),
       let startIndex = value.firstIndex(of: "("),
       let endIndex = value.lastIndex(of: ")") {
      let content = value[value.index(after: startIndex)..<endIndex]
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
      return String(content)
    }
    return nil
  }
}

