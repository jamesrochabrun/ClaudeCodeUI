//
//  SearchFormatter.swift
//  ClaudeCodeUI
//
//  Created on 1/9/2025.
//

import Foundation

/// Specialized formatter for search results (Grep, Glob, LS, WebSearch)
public struct SearchFormatter: ToolFormatterProtocol {
  
  public init() {}
  
  // MARK: - ToolFormatterProtocol
  
  public func formatOutput(_ output: String, tool: ToolType) -> (String, ToolDisplayFormatter.ToolContentFormatter.ContentType) {
    let formatted: String
    
    switch tool.identifier {
    case "Grep":
      formatted = formatGrepResults(output)
    case "Glob":
      formatted = formatGlobResults(output)
    case "LS":
      formatted = formatLSResults(output)
    default:
      formatted = output
    }
    
    return (formatted, .searchResults)
  }
  
  // Uses default implementations for formatArguments and extractKeyParameters
  
  /// Formats grep search results
  public func formatGrepResults(_ results: String, pattern: String? = nil) -> String {
    let lines = results.components(separatedBy: .newlines).filter { !$0.isEmpty }
    
    guard !lines.isEmpty else {
      return "No matches found" + (pattern != nil ? " for pattern: `\(pattern!)`" : "")
    }
    
    var formatted = "🔍 **Search Results**"
    if let pattern = pattern {
      formatted += " for `\(pattern)`"
    }
    formatted += "\n\n"
    
    // Group results by file
    var fileGroups: [String: [String]] = [:]
    
    for line in lines {
      // Try to extract file path and match
      if let colonIndex = line.firstIndex(of: ":") {
        let filePath = String(line[..<colonIndex])
        let match = String(line[line.index(after: colonIndex)...])
        
        if fileGroups[filePath] != nil {
          fileGroups[filePath]?.append(match)
        } else {
          fileGroups[filePath] = [match]
        }
      } else {
        // If no file path, just add the line
        if fileGroups[""] != nil {
          fileGroups[""]?.append(line)
        } else {
          fileGroups[""] = [line]
        }
      }
    }
    
    // Format grouped results
    for (file, matches) in fileGroups.sorted(by: { $0.key < $1.key }) {
      if !file.isEmpty {
        let filename = URL(fileURLWithPath: file).lastPathComponent
        formatted += "**\(filename)**\n"
      }
      
      for match in matches.prefix(5) {
        formatted += "  • \(match.trimmingCharacters(in: .whitespaces))\n"
      }
      
      if matches.count > 5 {
        formatted += "  • ... and \(matches.count - 5) more matches\n"
      }
      
      formatted += "\n"
    }
    
    // Add summary
    let totalMatches = fileGroups.values.reduce(0) { $0 + $1.count }
    formatted += "---\n"
    formatted += "Found **\(totalMatches) matches** in **\(fileGroups.count) files**"
    
    return formatted
  }
  
  /// Formats glob file pattern results
  public func formatGlobResults(_ results: String, pattern: String? = nil) -> String {
    let files = results.components(separatedBy: .newlines).filter { !$0.isEmpty }
    
    guard !files.isEmpty else {
      return "No files found" + (pattern != nil ? " matching pattern: `\(pattern!)`" : "")
    }
    
    var formatted = "📁 **Files Found**"
    if let pattern = pattern {
      formatted += " matching `\(pattern)`"
    }
    formatted += "\n\n"
    
    // Group files by directory
    var dirGroups: [String: [String]] = [:]
    
    for file in files {
      let url = URL(fileURLWithPath: file)
      let dir = url.deletingLastPathComponent().path
      let filename = url.lastPathComponent
      
      if dirGroups[dir] != nil {
        dirGroups[dir]?.append(filename)
      } else {
        dirGroups[dir] = [filename]
      }
    }
    
    // Format grouped files
    if dirGroups.count == 1 {
      // All files in same directory
      for file in files.prefix(20) {
        formatted += "• \(URL(fileURLWithPath: file).lastPathComponent)\n"
      }
      
      if files.count > 20 {
        formatted += "• ... and \(files.count - 20) more files\n"
      }
    } else {
      // Multiple directories
      for (dir, fileList) in dirGroups.sorted(by: { $0.key < $1.key }).prefix(10) {
        let dirName = URL(fileURLWithPath: dir).lastPathComponent
        formatted += "**\(dirName.isEmpty ? "." : dirName)/**\n"
        
        for file in fileList.prefix(5) {
          formatted += "  • \(file)\n"
        }
        
        if fileList.count > 5 {
          formatted += "  • ... and \(fileList.count - 5) more\n"
        }
        
        formatted += "\n"
      }
    }
    
    formatted += "---\n"
    formatted += "Total: **\(files.count) files**"
    
    return formatted
  }
  
  /// Formats directory listing results
  public func formatLSResults(_ results: String, path: String? = nil) -> String {
    let items = results.components(separatedBy: .newlines).filter { !$0.isEmpty }
    
    guard !items.isEmpty else {
      return "📁 Empty directory" + (path != nil ? ": \(path!)" : "")
    }
    
    var formatted = "📁 **Directory Contents**"
    if let path = path {
      formatted += " of `\(URL(fileURLWithPath: path).lastPathComponent)`"
    }
    formatted += "\n\n"
    
    var directories: [String] = []
    var files: [String] = []
    
    // Separate directories and files
    for item in items {
      if item.hasSuffix("/") {
        directories.append(item)
      } else {
        files.append(item)
      }
    }
    
    // Show directories first
    if !directories.isEmpty {
      formatted += "**Directories:**\n"
      for dir in directories.sorted().prefix(10) {
        formatted += "📁 \(dir)\n"
      }
      if directories.count > 10 {
        formatted += "... and \(directories.count - 10) more directories\n"
      }
      formatted += "\n"
    }
    
    // Show files
    if !files.isEmpty {
      formatted += "**Files:**\n"
      
      // Group by extension
      var extensionGroups: [String: [String]] = [:]
      
      for file in files {
        let ext = (file as NSString).pathExtension
        let key = ext.isEmpty ? "no extension" : ".\(ext)"
        
        if extensionGroups[key] != nil {
          extensionGroups[key]?.append(file)
        } else {
          extensionGroups[key] = [file]
        }
      }
      
      for (ext, fileList) in extensionGroups.sorted(by: { $0.key < $1.key }) {
        formatted += "\n*\(ext) files:*\n"
        for file in fileList.sorted().prefix(5) {
          formatted += "• \(file)\n"
        }
        if fileList.count > 5 {
          formatted += "• ... and \(fileList.count - 5) more\n"
        }
      }
    }
    
    formatted += "\n---\n"
    formatted += "Total: **\(directories.count) directories**, **\(files.count) files**"
    
    return formatted
  }
  
  /// Formats web search results
  public func formatWebSearchResults(_ results: String) -> String {
    // Web search results are usually already formatted by the tool
    // Add some light formatting
    var formatted = "🌐 **Web Search Results**\n\n"
    formatted += results
    
    // Extract URLs if present
    let urls = extractURLs(from: results)
    if !urls.isEmpty {
      formatted += "\n\n---\n**Links found:**\n"
      for url in urls.prefix(5) {
        formatted += "• [\(url)](\(url))\n"
      }
    }
    
    return formatted
  }
  
  /// Creates a summary for search results
  public func createSearchSummary(results: String, type: String) -> String {
    let lines = results.components(separatedBy: .newlines).filter { !$0.isEmpty }
    
    if lines.isEmpty {
      return "no results"
    }
    
    switch type.lowercased() {
    case "grep":
      return "\(lines.count) matches"
    case "glob":
      return "\(lines.count) files"
    case "ls":
      return "\(lines.count) items"
    case "websearch":
      return "results found"
    default:
      return "\(lines.count) results"
    }
  }
  
  // MARK: - Private Helpers
  
  private func extractURLs(from text: String) -> [String] {
    let pattern = #"https?://[^\s<>"{}|\\^`\[\]]+"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
      return []
    }
    
    let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
    
    return matches.compactMap { match in
      guard let range = Range(match.range, in: text) else { return nil }
      return String(text[range])
    }
  }
}