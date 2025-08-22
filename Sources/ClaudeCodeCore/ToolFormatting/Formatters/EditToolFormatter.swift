//
//  EditToolFormatter.swift
//  ClaudeCodeUI
//
//  Created on 1/10/2025.
//

import Foundation

/// Formatter for Edit and MultiEdit tools
struct EditToolFormatter: ToolFormatterProtocol {
  
  func formatOutput(_ output: String, tool: ToolType) -> (String, ToolDisplayFormatter.ToolContentFormatter.ContentType) {
    // Edit tool output is typically a success/failure message
    // The actual diff display is handled by EditToolDiffView
    return (output, .diff)
  }
  
  func formatArguments(_ arguments: String, tool: ToolType) -> String {
    if let jsonDict = arguments.toDictionary() {
      var filtered: [String: Any] = [:]
      
      // Always show file path
      if let filePath = jsonDict["file_path"] as? String {
        filtered["file_path"] = URL(fileURLWithPath: filePath).lastPathComponent
      }
      
      switch tool.identifier {
      case "Edit":
        // For single edit, show truncated old/new strings
        if let oldString = jsonDict["old_string"] as? String {
          filtered["old_string"] = oldString.truncateIntelligently(to: 50) + "..."
        }
        if let newString = jsonDict["new_string"] as? String {
          filtered["new_string"] = newString.truncateIntelligently(to: 50) + "..."
        }
        if let replaceAll = jsonDict["replace_all"] as? Bool, replaceAll {
          filtered["replace_all"] = true
        }
        
      case "MultiEdit":
        // For multi-edit, show number of edits
        if let edits = jsonDict["edits"] as? [[String: Any]] {
          filtered["edits"] = "[\(edits.count) edits]"
          
          // Show summary of edit types
          var replaceAllCount = 0
          for edit in edits {
            if let replaceAll = edit["replace_all"] as? Bool, replaceAll {
              replaceAllCount += 1
            }
          }
          if replaceAllCount > 0 {
            filtered["replace_all_count"] = "\(replaceAllCount) global replacements"
          }
        }
        
      default:
        break
      }
      
      if let data = try? JSONSerialization.data(withJSONObject: filtered, options: .prettyPrinted),
         let formatted = String(data: data, encoding: .utf8) {
        return formatted
      }
    }
    
    return arguments.formatJSON()
  }
  
  func extractKeyParameters(_ arguments: String, tool: ToolType) -> String? {
    guard let jsonDict = arguments.toDictionary() else {
      return nil
    }
    
    var params: [String] = []
    
    // Add filename
    if let filePath = jsonDict["file_path"] as? String {
      params.append(URL(fileURLWithPath: filePath).lastPathComponent)
    }
    
    // Add edit count for MultiEdit
    if tool.identifier == "MultiEdit",
       let edits = jsonDict["edits"] as? [[String: Any]] {
      params.append("\(edits.count) edits")
    }
    
    // Add replace_all indicator
    if let replaceAll = jsonDict["replace_all"] as? Bool, replaceAll {
      params.append("replace all")
    }
    
    return params.isEmpty ? nil : params.joined(separator: ", ")
  }
}
