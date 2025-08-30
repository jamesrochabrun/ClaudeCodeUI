//
//  FileDiff+applyLLMSuggestion.swift
//  ClaudeCodeUI
//
//  Created on 1/30/2025.
//

import Foundation
import os.log

// MARK: - LLM Integration

extension AdvancedDiff {
  
  private static let logger = Logger(subsystem: "com.ClaudeCodeUI.FileDiff", category: "LLM")
  
  /// Regular expression for parsing LLM search/replace patterns
  private static let llmDiffRegex = /<<<<<<< SEARCH\n(?<search>([\s\S]*?\n)?)=======\n(?<replace>([\s\S]*?\n)?)>>>>>>> REPLACE/
  
  /// Checks if a string contains LLM diff format
  public static func isLLMDiff(_ content: String) -> Bool {
    content.contains("<<<<<<< SEARCH") && content.contains(">>>>>>> REPLACE")
  }
  
  /// Parses LLM-generated search/replace patterns
  /// Format:
  /// ```
  /// <<<<<<< SEARCH
  /// old content here
  /// =======
  /// new content here
  /// >>>>>>> REPLACE
  /// ```
  public static func parse(
    searchReplacePattern: String,
    for fileContent: String
  ) throws -> [SearchReplace] {
    var results = [SearchReplace]()
    
    // Find all matches
    let matches = searchReplacePattern.matches(of: llmDiffRegex)
    
    guard !matches.isEmpty else {
      throw DiffError.notADiff(content: searchReplacePattern)
    }
    
    for match in matches {
      var searchContent = String(match.output.search ?? "")
      var replaceContent = String(match.output.replace ?? "")
      
      // Handle trailing newlines intelligently
      // If search ends with newline but replace doesn't, remove it from search
      if searchContent.hasSuffix("\n") && !replaceContent.hasSuffix("\n") {
        searchContent = String(searchContent.dropLast())
      }
      // If replace ends with newline but search doesn't, remove it from replace
      else if replaceContent.hasSuffix("\n") && !searchContent.hasSuffix("\n") {
        replaceContent = String(replaceContent.dropLast())
      }
      
      results.append(SearchReplace(
        search: searchContent,
        replace: replaceContent
      ))
    }
    
    return results
  }
  
  /// Applies search/replace operations to content
  public static func apply(
    changes: [SearchReplace],
    to fileContent: String
  ) throws -> String {
    var result = fileContent
    
    for change in changes {
      // Handle special cases
      if change.search.isEmpty {
        // Empty search means prepend to file
        if result.isEmpty {
          result = change.replace
        } else {
          result = change.replace + "\n" + result
        }
      } else {
        // Find and replace
        guard let range = result.range(of: change.search) else {
          logger.error("Search pattern not found: \(change.search)")
          throw DiffError.searchPatternNotFound(pattern: change.search)
        }
        
        result.replaceSubrange(range, with: change.replace)
      }
    }
    
    return result
  }
  
  /// Convenience method to apply LLM diff pattern directly
  public static func apply(
    searchReplacePattern: String,
    to fileContent: String
  ) throws -> String {
    let changes = try parse(searchReplacePattern: searchReplacePattern, for: fileContent)
    return try apply(changes: changes, to: fileContent)
  }
  
  /// Creates a FileChangeDiff by parsing and applying search/replace patterns
  public static func getFileChange(
    applying searchReplacePattern: String,
    to content: String
  ) throws -> FileChangeDiff {
    let newContent = try apply(searchReplacePattern: searchReplacePattern, to: content)
    
    // Generate diff
    // Note: This would need terminal service in real implementation
    // For now, return empty diff
    return FileChangeDiff(
      oldContent: content,
      newContent: newContent,
      diff: []
    )
  }
  
  /// Creates a FileChangeDiff from old and new content
  public static func getFileChange(
    changing oldContent: String,
    to newContent: String
  ) throws -> FileChangeDiff {
    // Generate diff
    // Note: This would need terminal service in real implementation
    // For now, return empty diff
    return FileChangeDiff(
      oldContent: oldContent,
      newContent: newContent,
      diff: []
    )
  }
}