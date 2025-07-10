//
//  String+ToolFormatting.swift
//  ClaudeCodeUI
//
//  Created on 1/9/2025.
//

import Foundation

/// MARK: String+ToolFormatting
///
extension String {
  
  // MARK: Public
  /// Formats a JSON string with proper indentation and sorted keys
  ///
  /// This method takes a JSON string and returns a properly formatted version with
  /// consistent indentation and alphabetically sorted keys. This improves readability
  /// and consistency when displaying or logging JSON data.
  ///
  /// The method attempts to:
  /// 1. Convert the string to data using UTF-8 encoding
  /// 2. Parse the data into a JSON object
  /// 3. Re-serialize the object with pretty printing and sorted keys
  /// 4. Convert the formatted data back to a string
  ///
  /// If any step in the process fails, the original string is returned unchanged.
  ///
  /// @return A formatted JSON string with proper indentation and sorted keys,
  ///         or the original string if formatting fails
  func formatJSON() -> String {
    guard
      let jsonData = data(using: .utf8),
      let jsonObject = try? JSONSerialization.jsonObject(with: jsonData),
      let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys])
    else {
      return self // Return original if formatting fails
    }
    
    return String(data: prettyData, encoding: .utf8) ?? self
  }
  
  /// Limits text to specified number of lines with smart truncation
  func limitToLines(_ count: Int, maxCharacters: Int = 300) -> String {
    let lines = components(separatedBy: .newlines).filter { !$0.isEmpty }
    
    if lines.count > 1 {
      if lines.count <= count {
        if self.count > maxCharacters {
          return """
  \(String(prefix(maxCharacters)))...
  Truncated to \(maxCharacters) characters
  """
        }
        return self
      }
      
      let firstLines = lines.prefix(count).joined(separator: "\n")
      
      if firstLines.count > maxCharacters {
        return """
  \(String(firstLines.prefix(maxCharacters)))...
  Truncated to \(maxCharacters) characters (was showing \(count) of \(lines.count) lines)
  """
      }
      return """
  \(firstLines)
  ...
  Showing \(count) of \(lines.count) lines
  """
    }
    
    // Single line handling
    if self.count <= maxCharacters {
      return self
    }
    
    return """
  \(String(prefix(maxCharacters)))...
  Showing first \(maxCharacters) of \(self.count) characters
  """
  }
  
  /// Adds a blockquote marker (>) to each line of a string
  ///
  /// @return A string with blockquote markers at the beginning of each line
  func addBlockquoteToEachLine() -> String {
    let lines = components(separatedBy: .newlines)
    return lines.map { "> \($0)" }.joined(separator: "\n")
  }
  
  /// Converts a JSON string into a formatted key-value pair representation
  ///
  /// This method transforms a JSON string into a simple key-value format where each
  /// property is displayed on its own line. The output format is:
  /// ```
  /// key1: value1
  /// key2: value2
  /// key3: value3
  /// ```
  ///
  /// The method:
  /// 1. Parses the string into a dictionary
  /// 2. Sorts the keys alphabetically
  /// 3. Converts each key-value pair to a string representation
  /// 4. Joins the pairs with newlines
  ///
  /// @return A formatted string of key-value pairs, or nil if parsing fails
  func jsonAsFormattedKeysAndValues() -> String? {
    guard let data = self.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return nil
    }
    
    var result: [String] = []
    for (key, value) in json.sorted(by: { $0.key < $1.key }) {
      let formattedValue = formatValue(value)
      result.append("\(key): \(formattedValue)")
    }
    
    return result.joined(separator: "\n")
  }
  
  /// Extracts code from markdown code blocks
  func extractCodeOnly() -> String {
    // Pattern to match code blocks with optional language
    let pattern = "```(?:\\w+)?\\n([\\s\\S]*?)```"
    
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
      return self
    }
    
    let matches = regex.matches(in: self, options: [], range: NSRange(location: 0, length: self.count))
    
    if !matches.isEmpty {
      var extractedCode: [String] = []
      
      for match in matches {
        if let range = Range(match.range(at: 1), in: self) {
          extractedCode.append(String(self[range]))
        }
      }
      
      return extractedCode.joined(separator: "\n\n")
    }
    
    // If no code blocks found, return original string
    return self
  }
  
  /// Extracts file paths from various formats (including XML tags)
  func extractFilePaths() -> [String] {
    var paths: [String] = []
    
    // Pattern for file paths
    let filePathPattern = #"(?:/[\w\-. /]+\.[\w]+)|(?:[A-Za-z]:\\[\w\-. \\]+\.[\w]+)"#
    
    // Pattern for XML file_path tags
    let xmlPattern = #"<file_path>([^<]+)</file_path>"#
    
    // Extract from XML tags first
    if let xmlRegex = try? NSRegularExpression(pattern: xmlPattern, options: []) {
      let xmlMatches = xmlRegex.matches(in: self, options: [], range: NSRange(location: 0, length: self.count))
      for match in xmlMatches {
        if let range = Range(match.range(at: 1), in: self) {
          paths.append(String(self[range]))
        }
      }
    }
    
    // Extract general file paths
    if let pathRegex = try? NSRegularExpression(pattern: filePathPattern, options: []) {
      let pathMatches = pathRegex.matches(in: self, options: [], range: NSRange(location: 0, length: self.count))
      for match in pathMatches {
        if let range = Range(match.range, in: self) {
          let path = String(self[range])
          if !paths.contains(path) {
            paths.append(path)
          }
        }
      }
    }
    
    return paths
  }
  
  /// Converts a JSON-formatted string into a dictionary
  ///
  /// This utility method transforms a JSON string into a Swift dictionary for easier
  /// data access and manipulation. It's particularly useful for processing JSON responses
  /// from LLMs in tool call implementations, allowing for straightforward access to
  /// argument values by their keys.
  ///
  /// The method attempts to:
  /// 1. Convert the string to data using UTF-8 encoding
  /// 2. Deserialize the data into a dictionary using JSONSerialization
  ///
  /// If the string is not valid JSON or cannot be converted to a dictionary,
  /// the method returns nil.
  ///
  /// @return A dictionary representation of the JSON string, or nil if conversion fails
  public func toDictionary() -> [String: Any]? {
    guard let data = data(using: .utf8) else { return nil }
    return try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
  }
  
  /// Detects the programming language from content or file extension
  func detectLanguage(fromPath path: String? = nil) -> String? {
    if let path = path {
      let ext = (path as NSString).pathExtension.lowercased()
      return languageFromExtension(ext)
    }
    
    // Try to detect from content patterns
    if self.contains("import SwiftUI") || self.contains("import Foundation") {
      return "swift"
    } else if self.contains("import React") || self.contains("const ") || self.contains("function ") {
      return "javascript"
    } else if self.contains("def ") || self.contains("import ") || self.contains("class ") {
      return "python"
    } else if self.contains("#include") || self.contains("int main") {
      return "cpp"
    }
    
    return nil
  }
  
  /// Formats shell output with ANSI color code removal
  func formatShellOutput() -> String {
    // Remove ANSI escape codes
    let ansiPattern = #"\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])"#
    let cleanedOutput = self.replacingOccurrences(
      of: ansiPattern,
      with: "",
      options: .regularExpression
    )
    
    return cleanedOutput
  }
  
  /// Truncates string intelligently at word boundaries
  ///
  /// @param length The maximum length of the truncated string
  /// @param suffix The suffix to append when truncating (default: "...")
  /// @return A truncated string that breaks at word boundaries when possible
  func truncateIntelligently(to length: Int, suffix: String = "...") -> String {
    if self.count <= length {
      return self
    }
    
    let endIndex = self.index(self.startIndex, offsetBy: length)
    let truncated = String(self[..<endIndex])
    
    // Try to break at word boundary
    if let lastSpace = truncated.lastIndex(of: " ") {
      return String(truncated[..<lastSpace]) + suffix
    }
    
    return truncated + suffix
  }
  
  /// Extracts content from between triple backticks
  ///
  /// This method removes markdown code block delimiters (```) and optional language
  /// identifiers from a string. It's useful for extracting clean code from markdown
  /// formatted text.
  ///
  /// The method handles:
  /// - Opening triple backticks with optional language identifier
  /// - Closing triple backticks
  /// - Leading/trailing newlines
  ///
  /// @return The content between the backticks, or the original string if no backticks found
  func getSubstringBetweenBackticks() -> String {
    var result = self
    
    // Remove opening backticks and optional language identifier
    if result.hasPrefix("```") {
      result = String(result.dropFirst(3)) // Remove ```
      
      // Remove language identifier if present
      if let firstNewlineIndex = result.firstIndex(of: "\n") {
        let potentialLanguage = String(result[..<firstNewlineIndex])
        
        // Check if it looks like a language identifier
        let languagePattern = "^[a-zA-Z0-9+#-]+$"
        if potentialLanguage.range(of: languagePattern, options: .regularExpression) != nil {
          // Remove the language identifier and the newline
          result = String(result[result.index(after: firstNewlineIndex)...])
        }
      } else if result.hasPrefix("\n") {
        result = String(result.dropFirst(1)) // Remove leading newline
      }
    }
    
    // Remove closing backticks
    if result.hasSuffix("```") {
      result = String(result.dropLast(3))
      
      // Remove trailing newline before closing backticks if present
      if result.hasSuffix("\n") {
        result = String(result.dropLast(1))
      }
    }
    
    return result
  }
  
  // MARK: - Private Helpers
  
  private func formatValue(_ value: Any) -> String {
    switch value {
    case let string as String:
      return "\"\(string)\""
    case let number as NSNumber:
      return number.stringValue
    case let bool as Bool:
      return bool ? "true" : "false"
    case let array as [Any]:
      return "[\(array.count) items]"
    case let dict as [String: Any]:
      return "{\(dict.count) properties}"
    default:
      return String(describing: value)
    }
  }
  
  private func languageFromExtension(_ ext: String) -> String? {
    let languageMap: [String: String] = [
      "swift": "swift",
      "js": "javascript",
      "jsx": "javascript",
      "ts": "typescript",
      "tsx": "typescript",
      "py": "python",
      "rb": "ruby",
      "go": "go",
      "rs": "rust",
      "java": "java",
      "kt": "kotlin",
      "cpp": "cpp",
      "c": "c",
      "h": "c",
      "hpp": "cpp",
      "cs": "csharp",
      "php": "php",
      "sh": "bash",
      "bash": "bash",
      "zsh": "bash",
      "json": "json",
      "xml": "xml",
      "yaml": "yaml",
      "yml": "yaml",
      "md": "markdown",
      "html": "html",
      "css": "css",
      "scss": "scss",
      "sql": "sql"
    ]
    
    return languageMap[ext]
  }
}
