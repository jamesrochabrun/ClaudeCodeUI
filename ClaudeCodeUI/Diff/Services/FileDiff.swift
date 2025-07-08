//
//  FileDiff.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 7/7/2025.
//

import Foundation
import SwiftUI
import TerminalServiceInterface
import os.log

// MARK: - Git Diff Generation

extension FileDiff {
  
  public static func getGitDiff(oldContent: String, newContent: String, terminalService: TerminalService) async throws -> String {
    let uuid = UUID().uuidString
    let tmpFileV0Path = "/tmp/file-0-\(uuid).txt"
    let tmpFileV1Path = "/tmp/file-1-\(uuid).txt"
    
    let fileManager = FileManager.default
    fileManager.createFile(
      atPath: tmpFileV0Path,
      contents: oldContent.formattedToApplyGitDiff.utf8Data,
      attributes: nil)
    fileManager.createFile(
      atPath: tmpFileV1Path,
      contents: newContent.formattedToApplyGitDiff.utf8Data,
      attributes: nil)
    
    defer {
      try? fileManager.removeItem(atPath: tmpFileV0Path)
      try? fileManager.removeItem(atPath: tmpFileV1Path)
    }
    
    let command = "git diff --no-index --no-color \(tmpFileV0Path) \(tmpFileV1Path)"
    let result = try await terminalService.runTerminal(command, quiet: true)
    
    // Git diff returns exit code 1 when there are differences, which is expected
    guard result.exitCode == 0 || result.exitCode == 1 else {
      throw DiffError.gitDiffFailed(result.errorOutput ?? "Unknown error")
    }
    
    let diff = (result.output ?? "")
      .split(separator: "\n", omittingEmptySubsequences: false)
      .dropFirst(4)  // Remove the file path headers
      .joined(separator: "\n")
    
    return diff.formatAppliedGitDiff
  }
}

// MARK: - Git Diff Parsing

extension FileDiff {
  static func gitDiffToChangedRanges(oldContent: String, newContent: String, diffText: String) -> [LineChange] {
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

// MARK: - Colored Diff Generation

extension FileDiff {
  public static func getColoredDiff(
    oldContent: String,
    newContent: String,
    terminalService: TerminalService,
    gitDiff: String? = nil) async throws -> FormattedFileChange
  {
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
    
    // For now, create attributed strings without syntax highlighting
    let oldContentFormatted = AttributedString(oldContent)
    let newContentFormatted = AttributedString(newContent)
    
    var formattedLineChanges: [FormattedLineChange] = []
    
    for lineChange in diffRanges {
      let formattedContent = lineChange.type == .removed ? oldContentFormatted : newContentFormatted
      guard let range = formattedContent.range(lineChange.characterRange) else {
        continue
      }
      let line = AttributedString(formattedContent[range])
      formattedLineChanges.append(FormattedLineChange(formattedContent: line, change: lineChange))
    }
    
    return FormattedFileChange(changes: formattedLineChanges)
  }
}

// MARK: - DiffError

enum DiffError: LocalizedError {
  case gitDiffFailed(String)
  
  var errorDescription: String? {
    switch self {
    case .gitDiffFailed(let message):
      return "Git diff failed: \(message)"
    }
  }
}
