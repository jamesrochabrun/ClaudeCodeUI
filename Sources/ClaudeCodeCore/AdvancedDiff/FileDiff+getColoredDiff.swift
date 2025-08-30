//
//  FileDiff+getColoredDiff.swift
//  ClaudeCodeUI
//
//  Created on 1/30/2025.
//

import Foundation
import SwiftUI
import CCTerminalServiceInterface
import os.log

// MARK: - Colored Diff Generation

extension AdvancedDiff {
  
  private static let logger = Logger(subsystem: "com.ClaudeCodeUI.FileDiff", category: "ColoredDiff")
  
  /// Generates a formatted diff with line-by-line change tracking between two versions of content.
  /// Uses your existing AttributedString approach for formatting instead of external highlighting libraries.
  ///
  /// This method performs the following steps:
  /// 1. Generates or uses a provided git diff to identify changes
  /// 2. Parses the diff to extract line-level changes (added, removed, unchanged)
  /// 3. Creates formatted line changes with attributed strings for UI rendering
  ///
  /// - Parameters:
  ///   - oldContent: The original content to compare from
  ///   - newContent: The new content to compare to
  ///   - terminalService: Service for executing git commands to generate diffs
  ///   - gitDiff: Optional pre-computed git diff string. If nil, a new diff will be generated
  ///
  /// - Returns: A `FormattedFileChange` containing all line changes with attributed strings
  ///
  /// - Throws: `DiffError.gitDiffFailed` if git diff generation fails
  public static func getColoredDiff(
    oldContent: String,
    newContent: String,
    terminalService: TerminalService,
    gitDiff: String? = nil
  ) async throws -> FormattedFileChange {
    let diff: String
    if let gitDiff = gitDiff {
      diff = gitDiff
    } else {
      diff = try await getGitDiff(
        oldContent: oldContent,
        newContent: newContent,
        terminalService: terminalService
      )
    }
    
    let diffRanges = gitDiffToChangedRanges(
      oldContent: oldContent,
      newContent: newContent,
      diffText: diff
    )
    
    // Create attributed strings using your existing approach
    let oldContentFormatted = AttributedString(oldContent)
    let newContentFormatted = AttributedString(newContent)
    
    var formattedLineChanges: [FormattedLineChange] = []
    
    for lineChange in diffRanges {
      let formattedContent = lineChange.type == .removed ? oldContentFormatted : newContentFormatted
      guard let range = formattedContent.range(lineChange.characterRange) else {
        continue
      }
      var line = AttributedString(formattedContent[range])
      
      // Remove trailing newlines from the attributed string
      if let lastChar = line.characters.last, lastChar.isNewline {
        let endIndex = line.characters.index(before: line.characters.endIndex)
        line = AttributedString(line.characters[line.characters.startIndex..<endIndex])
      }
      
      // Apply diff-specific formatting
      switch lineChange.type {
      case .added:
        line.backgroundColor = Color.green.opacity(0.2)
      case .removed:
        line.backgroundColor = Color.red.opacity(0.2)
      case .unchanged:
        break
      }
      
      formattedLineChanges.append(FormattedLineChange(formattedContent: line, change: lineChange))
    }
    
    return FormattedFileChange(changes: formattedLineChanges)
  }
}

// MARK: - AttributedString Extensions

extension AttributedString {
  /// Get range from integer character positions
  func range(_ range: Range<Int>) -> Range<AttributedString.Index>? {
    guard range.lowerBound >= 0 else { return nil }
    
    var currentOffset = 0
    var startIndex: AttributedString.Index?
    var endIndex: AttributedString.Index?
    
    for index in characters.indices {
      if currentOffset == range.lowerBound {
        startIndex = index
      }
      if currentOffset == range.upperBound {
        endIndex = index
        break
      }
      currentOffset += 1
    }
    
    // Handle end of string
    if currentOffset == range.upperBound && endIndex == nil {
      endIndex = characters.endIndex
    }
    
    guard let start = startIndex, let end = endIndex else {
      return nil
    }
    
    return start..<end
  }
}