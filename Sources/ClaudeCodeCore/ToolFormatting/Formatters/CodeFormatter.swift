//
//  CodeFormatter.swift
//  ClaudeCodeUI
//
//  Created on 1/9/2025.
//

import Foundation

/// Specialized formatter for code content
public struct CodeFormatter {
  
  public init() {}
  
  /// Formats code with language detection and smart truncation
  public func formatCode(
    _ code: String,
    language: String? = nil,
    filePath: String? = nil,
    maxLines: Int = 50
  ) -> String {
    let detectedLanguage = language ?? code.detectLanguage(fromPath: filePath) ?? "text"
    
    // Add line numbers for long code
    let lines = code.components(separatedBy: .newlines)
    let formattedCode: String
    
    if lines.count > 10 {
      formattedCode = addLineNumbers(to: code, maxLines: maxLines)
    } else {
      formattedCode = code.limitToLines(maxLines, maxCharacters: 2000)
    }
    
    return """
    ```\(detectedLanguage)
    \(formattedCode)
    ```
    """
  }
  
  /// Formats a file read operation result
  public func formatFileContent(
    content: String,
    filePath: String,
    offset: Int? = nil,
    limit: Int? = nil
  ) -> String {
    let filename = URL(fileURLWithPath: filePath).lastPathComponent
    let language = content.detectLanguage(fromPath: filePath) ?? "text"
    
    var header = "📄 **\(filename)**"
    
    if let offset = offset, let limit = limit {
      header += " (lines \(offset)-\(offset + limit))"
    }
    
    let formattedContent = """
    \(header)
    
    ```\(language)
    \(content.limitToLines(100, maxCharacters: 5000))
    ```
    """
    
    return formattedContent
  }
  
  /// Formats write operation result
  public func formatWriteResult(filePath: String, success: Bool) -> String {
    let filename = URL(fileURLWithPath: filePath).lastPathComponent
    
    if success {
      return "✅ Successfully wrote to **\(filename)**"
    } else {
      return "❌ Failed to write to **\(filename)**"
    }
  }
  
  /// Creates a summary of code content for headers
  public func createCodeSummary(content: String, filePath: String? = nil) -> String {
    let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
    
    if let path = filePath {
      let filename = URL(fileURLWithPath: path).lastPathComponent
      return "\(filename) (\(lines.count) lines)"
    }
    
    return "\(lines.count) lines"
  }
  
  /// Extracts and formats code structure (classes, functions, etc.)
  public func extractCodeStructure(_ code: String, language: String? = nil) -> String? {
    let lang = language ?? code.detectLanguage()
    
    guard let lang = lang else { return nil }
    
    switch lang {
    case "swift":
      return extractSwiftStructure(code)
    case "javascript", "typescript":
      return extractJavaScriptStructure(code)
    case "python":
      return extractPythonStructure(code)
    default:
      return nil
    }
  }
  
  // MARK: - Private Helpers
  
  private func addLineNumbers(to code: String, maxLines: Int) -> String {
    let lines = code.components(separatedBy: .newlines)
    let digitCount = String(min(lines.count, maxLines)).count
    
    var numberedLines: [String] = []
    
    for (index, line) in lines.prefix(maxLines).enumerated() {
      let lineNumber = String(format: "%\(digitCount)d", index + 1)
      numberedLines.append("\(lineNumber) │ \(line)")
    }
    
    if lines.count > maxLines {
      numberedLines.append("     │ ... \(lines.count - maxLines) more lines")
    }
    
    return numberedLines.joined(separator: "\n")
  }
  
  private func extractSwiftStructure(_ code: String) -> String? {
    var structure: [String] = []
    let lines = code.components(separatedBy: .newlines)
    
    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      
      if trimmed.starts(with: "class ") ||
          trimmed.starts(with: "struct ") ||
          trimmed.starts(with: "enum ") ||
          trimmed.starts(with: "protocol ") ||
          trimmed.starts(with: "func ") ||
          trimmed.starts(with: "var ") ||
          trimmed.starts(with: "let ") {
        
        // Extract the declaration
        if let firstBrace = trimmed.firstIndex(of: "{") {
          let declaration = String(trimmed[..<firstBrace]).trimmingCharacters(in: .whitespaces)
          structure.append("• \(declaration)")
        } else if trimmed.contains("=") {
          if let equals = trimmed.firstIndex(of: "=") {
            let declaration = String(trimmed[..<equals]).trimmingCharacters(in: .whitespaces)
            structure.append("• \(declaration)")
          }
        } else {
          structure.append("• \(trimmed)")
        }
      }
    }
    
    return structure.isEmpty ? nil : "**Structure:**\n" + structure.joined(separator: "\n")
  }
  
  private func extractJavaScriptStructure(_ code: String) -> String? {
    var structure: [String] = []
    let lines = code.components(separatedBy: .newlines)
    
    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      
      if trimmed.starts(with: "function ") ||
          trimmed.starts(with: "const ") && trimmed.contains("=>") ||
          trimmed.starts(with: "class ") ||
          trimmed.starts(with: "export ") {
        
        if let firstBrace = trimmed.firstIndex(of: "{") {
          let declaration = String(trimmed[..<firstBrace]).trimmingCharacters(in: .whitespaces)
          structure.append("• \(declaration)")
        } else {
          structure.append("• \(trimmed)")
        }
      }
    }
    
    return structure.isEmpty ? nil : "**Structure:**\n" + structure.joined(separator: "\n")
  }
  
  private func extractPythonStructure(_ code: String) -> String? {
    var structure: [String] = []
    let lines = code.components(separatedBy: .newlines)
    
    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      
      if trimmed.starts(with: "def ") ||
          trimmed.starts(with: "class ") ||
          trimmed.starts(with: "async def ") {
        
        if let colon = trimmed.firstIndex(of: ":") {
          let declaration = String(trimmed[..<colon]).trimmingCharacters(in: .whitespaces)
          structure.append("• \(declaration)")
        }
      }
    }
    
    return structure.isEmpty ? nil : "**Structure:**\n" + structure.joined(separator: "\n")
  }
}
