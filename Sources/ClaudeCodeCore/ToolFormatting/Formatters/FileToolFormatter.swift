//
//  FileToolFormatter.swift
//  ClaudeCodeUI
//
//  Created on 1/10/2025.
//

import Foundation

/// Formatter for file-related tools (Read, Write, LS)
struct FileToolFormatter: ToolFormatterProtocol {
  private let codeFormatter = CodeFormatter()
  
  func formatOutput(_ output: String, tool: ToolType) -> (String, ToolDisplayFormatter.ToolContentFormatter.ContentType) {
    switch tool.identifier {
    case "Read":
      // Try to detect language from content
      let language = output.detectLanguage()
      let formatted = codeFormatter.formatCode(
        output,
        language: language,
        filePath: nil,
        maxLines: 50
      )
      return (formatted, .markdown)
      
    case "Write":
      // Write operations typically return a success message
      let success = !output.lowercased().contains("error") && !output.lowercased().contains("failed")
      let formatted = success ? "✅ File written successfully" : "❌ \(output)"
      return (formatted, .plainText)
      
    case "LS":
      // Directory listings
      let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
      if lines.count > 20 {
        let formatted = """
        \(lines.prefix(20).joined(separator: "\n"))
        ... and \(lines.count - 20) more items
        """
        return (formatted, .plainText)
      }
      return (output, .plainText)
      
    default:
      // Generic file operation
      return (output, .plainText)
    }
  }
  
  func formatArguments(_ arguments: String, tool: ToolType) -> String {
    if let jsonDict = arguments.toDictionary() {
      var filtered: [String: Any] = [:]
      
      // Always show file path first
      if let filePath = jsonDict["file_path"] as? String {
        filtered["file_path"] = URL(fileURLWithPath: filePath).lastPathComponent
      }
      
      // Add other relevant parameters
      switch tool.identifier {
      case "Read":
        if let offset = jsonDict["offset"] {
          filtered["offset"] = offset
        }
        if let limit = jsonDict["limit"] {
          filtered["limit"] = limit
        }
        
      case "Write":
        if let content = jsonDict["content"] as? String {
          filtered["content"] = content.truncateIntelligently(to: 100) + "..."
        }
        
      case "LS":
        if let ignore = jsonDict["ignore"] {
          filtered["ignore"] = ignore
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
    guard let jsonDict = arguments.toDictionary(),
              let filePath = jsonDict["file_path"] as? String else {
      return nil
    }
    
    let filename = URL(fileURLWithPath: filePath).lastPathComponent
    
    switch tool.identifier {
    case "Read":
      if let offset = jsonDict["offset"], let limit = jsonDict["limit"] {
        return "\(filename) lines \(offset)-\(limit)"
      }
      return filename
      
    case "Write":
      return filename
      
    case "LS":
      return filename.isEmpty ? "current directory" : filename
      
    default:
      return filename
    }
  }
}