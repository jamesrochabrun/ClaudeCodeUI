//
//  FileDiff+gitDiffToChangedRanges.swift
//  ClaudeCodeUI
//
//  Created on 1/30/2025.
//

import Foundation
import os.log

// MARK: - Git Diff Parsing

extension AdvancedDiff {
  
  private static let logger = Logger(subsystem: "com.ClaudeCodeUI.FileDiff", category: "Parser")
  
  /// Converts unified diff text into structured LineChange objects
  /// Parses git diff output and maps it to line-by-line changes with proper tracking
  static func gitDiffToChangedRanges(
    oldContent: String,
    newContent: String,
    diffText: String
  ) -> [LineChange] {
    let newLines = newContent.splitLines()
    let newLinesOffset = offsetFor(lines: newLines)
    let oldLines = oldContent.splitLines()
    let oldLinesOffset = offsetFor(lines: oldLines)
    
    var result = [LineChange]()
    
    // Current line numbers in old and new files (1-based)
    var currentOldLine = 1
    var currentNewLine = 1
    
    // Parse diff hunks
    let lines = diffText.split(separator: "\n", omittingEmptySubsequences: false)
    var i = 0
    
    while i < lines.count {
      let line = lines[i]
      
      // Check for hunk header
      if line.starts(with: "@@") {
        // Parse hunk header to get line numbers
        // Format: @@ -oldStart,oldCount +newStart,newCount @@
        let hunkPattern = #/@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@/#
        if let match = try? hunkPattern.firstMatch(in: String(line)) {
          let oldStart = Int(match.output.1) ?? 1
          let newStart = Int(match.output.3) ?? 1
          
          // Add unchanged lines before this hunk
          while currentNewLine < newStart {
            let idx = currentNewLine - 1
            if idx < newLines.count {
              let range = newLinesOffset[idx]..<newLinesOffset[idx + 1]
              result.append(LineChange(
                oldLineNumber: currentOldLine,
                newLineNumber: currentNewLine,
                characterRange: range,
                content: String(newLines[idx]),
                type: .unchanged
              ))
            }
            currentOldLine += 1
            currentNewLine += 1
          }
          
          // Update current positions to hunk start
          currentOldLine = oldStart
          currentNewLine = newStart
        }
        i += 1
        continue
      }
      
      // Process diff lines
      if line.starts(with: "+") && !line.starts(with: "+++") {
        // Added line - get content from new file
        let idx = currentNewLine - 1
        if idx < newLines.count {
          let content = String(newLines[idx])
          let range = newLinesOffset[idx]..<newLinesOffset[idx + 1]
          
          result.append(LineChange(
            oldLineNumber: nil,
            newLineNumber: currentNewLine,
            characterRange: range,
            content: content,
            type: .added
          ))
        }
        currentNewLine += 1
        
      } else if line.starts(with: "-") && !line.starts(with: "---") {
        // Removed line - get content from old file
        let idx = currentOldLine - 1
        if idx < oldLines.count {
          let content = String(oldLines[idx])
          let range = oldLinesOffset[idx]..<oldLinesOffset[idx + 1]
          
          result.append(LineChange(
            oldLineNumber: currentOldLine,
            newLineNumber: nil,
            characterRange: range,
            content: content,
            type: .removed
          ))
        }
        currentOldLine += 1
        
      } else if line.starts(with: " ") {
        // Context line (unchanged) - get content from new file
        let idx = currentNewLine - 1
        if idx < newLines.count {
          let content = String(newLines[idx])
          let range = newLinesOffset[idx]..<newLinesOffset[idx + 1]
          
          result.append(LineChange(
            oldLineNumber: currentOldLine,
            newLineNumber: currentNewLine,
            characterRange: range,
            content: content,
            type: .unchanged
          ))
        }
        currentOldLine += 1
        currentNewLine += 1
      }
      
      i += 1
    }
    
    // Add any remaining unchanged lines
    while currentNewLine <= newLines.count {
      let idx = currentNewLine - 1
      if idx < newLines.count {
        let range = newLinesOffset[idx]..<newLinesOffset[idx + 1]
        result.append(LineChange(
          oldLineNumber: currentOldLine,
          newLineNumber: currentNewLine,
          characterRange: range,
          content: String(newLines[idx]),
          type: .unchanged
        ))
      }
      currentOldLine += 1
      currentNewLine += 1
    }
    
    return result
  }
  
  /// Calculates character offsets for each line in the content
  private static func offsetFor(lines: [String.SubSequence]) -> [Int] {
    var result: [Int] = []
    result.reserveCapacity(lines.count + 1)
    var offset = 0
    for (index, line) in lines.enumerated() {
      result.append(offset)
      offset += line.count
      // Add 1 for the newline character that was removed during splitting
      // except for the last line
      if index < lines.count - 1 {
        offset += 1
      }
    }
    result.append(offset)
    return result
  }
}