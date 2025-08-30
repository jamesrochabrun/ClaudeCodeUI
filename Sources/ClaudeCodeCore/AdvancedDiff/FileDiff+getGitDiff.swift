//
//  FileDiff+getGitDiff.swift
//  ClaudeCodeUI
//
//  Created on 1/30/2025.
//

import Foundation
import CCTerminalServiceInterface
import os.log

// MARK: - Git Diff Generation

extension AdvancedDiff {
  
  private static let logger = Logger(subsystem: "com.ClaudeCodeUI.FileDiff", category: "GitDiff")
  
  /// Generates a unified diff between two strings using git
  /// Handles empty lines using special token `<l>` for accurate representation
  public static func getGitDiff(
    oldContent: String,
    newContent: String,
    terminalService: TerminalService
  ) async throws -> String {
    let uuid = UUID().uuidString
    let tmpFileV0Path = "/tmp/file-0-\(uuid).txt"
    let tmpFileV1Path = "/tmp/file-1-\(uuid).txt"
    
    let fileManager = FileManager.default
    
    // Format content with special tokens for empty lines
    let formattedOldContent = oldContent.formattedToApplyGitDiff
    let formattedNewContent = newContent.formattedToApplyGitDiff
    
    fileManager.createFile(
      atPath: tmpFileV0Path,
      contents: formattedOldContent.data(using: .utf8),
      attributes: nil
    )
    fileManager.createFile(
      atPath: tmpFileV1Path,
      contents: formattedNewContent.data(using: .utf8),
      attributes: nil
    )
    
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
    
    // Remove special tokens from the output
    return diff.formatAppliedGitDiff
  }
}

// MARK: - String Extensions for Empty Line Handling

extension String {
  /// Formats string for git diff by adding special tokens to empty lines
  /// This ensures empty lines are properly represented in the diff
  var formattedToApplyGitDiff: String {
    replacingOccurrences(
      of: "(\n)(?=\n|$)",
      with: "$1<l>",
      options: .regularExpression
    )
  }
  
  /// Removes special tokens after git diff processing
  var unformattedFromApplyGitDiff: String {
    replacingOccurrences(of: "<l>", with: "")
  }
  
  /// Cleans up git diff output by removing special tokens
  var formatAppliedGitDiff: String {
    replacingOccurrences(of: "<l>", with: "")
  }
  
  /// Splits string into lines while preserving line endings
  func splitLines() -> [String.SubSequence] {
    var result = [String.SubSequence]()
    var lineStart = startIndex
    var index = startIndex
    
    while index < endIndex {
      if self[index] == "\n" {
        result.append(self[lineStart...index])
        lineStart = self.index(after: index)
      }
      index = self.index(after: index)
    }
    
    // Add the last line if it doesn't end with newline
    if lineStart != endIndex {
      result.append(self[lineStart...])
    }
    
    return result
  }
  
  /// Convert to UTF8 data
  var utf8Data: Data {
    data(using: .utf8) ?? Data()
  }
}