//
//  DiffTerminalService.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 9/3/25.
//

import CCTerminalServiceInterface
import Foundation

// MARK: - DiffTerminalService

final class DiffTerminalService {
  
  // MARK: - Constants
  
  private enum Constants {
    static let contextLines = 1
    static let tempFilePrefix = "diff_before_"
    static let tempFileAfterPrefix = "diff_after_"
    static let defaultExtension = "txt"
  }
  
  // MARK: - Lifecycle
  
  init(terminalService: TerminalService) {
    self.terminalService = terminalService
  }
  
  // MARK: - Internal
  
  /// Define the diff types
  enum DiffType {
    case unchanged
    case inserted
    case deleted
  }
  
  /// A model for a single diff line
  struct DiffLine {
    let text: String
    let type: DiffType
    let lineNumber: Int? // Line number (only for insertions and unchanged lines)
  }
  
  /// A model for a group of diff lines that can be applied together
  struct DiffGroup: Identifiable, Equatable {
    let id = UUID()
    let lines: [DiffLine]
    
    var hasChanges: Bool {
      lines.contains { $0.type != .unchanged }
    }
    
    static func ==(
      lhs: DiffTerminalService.DiffGroup,
      rhs: DiffTerminalService.DiffGroup
    ) -> Bool {
      lhs.id == rhs.id
    }
  }
  
  func createDiffGroup(
    for diff: CodeDiff,
    original: String,
    diffApplier: DiffApplyManager,
    fileExtension: String? = nil
  ) async -> DiffTerminalService.DiffGroup {
    // Create before/after states
    let beforeState = original
    let afterState = diffApplier.apply(diffs: [diff], to: original)
    
    if beforeState == afterState {
      AppLogger.error("ApplyChangesPreviewContentGenerator: before and after are equal")
    }
    
    // Get diff lines using Git diff
    if let diffLines = await createGitDiffLines(
      before: beforeState,
      after: afterState,
      fileExtension: fileExtension
    ) {
      return DiffTerminalService.DiffGroup(lines: diffLines)
    } else {
      AppLogger.error("ApplyChangesPreviewContentGenerator: Unable to create diffLines using terminal.")
    }
    
    // Even if Git diff fails, create a minimal representation using only the diff details
    // This avoids falling back to the problematic internal diff algorithm
    var lines = [DiffTerminalService.DiffLine]()
    
    // Add the search pattern lines (what will be replaced)
    let searchLines = diff.searchPattern.components(separatedBy: "\n")
    for line in searchLines {
      lines.append(DiffTerminalService.DiffLine(
        text: line,
        type: .deleted,
        lineNumber: nil
      ))
    }
    
    // Add the replacement lines
    let replacementLines = diff.replacement.components(separatedBy: "\n")
    for line in replacementLines {
      lines.append(DiffTerminalService.DiffLine(
        text: line,
        type: .inserted,
        lineNumber: nil
      ))
    }
    
    return DiffTerminalService.DiffGroup(lines: lines)
  }
  
  // MARK: Private
  
  private let terminalService: TerminalService
  
  /// Creates diff lines by comparing before and after states using Git diff.
  ///
  /// - Parameters:
  ///   - before: The original content before changes
  ///   - after: The content after applying changes
  ///   - fileExtension: Optional file extension to use for temp files (affects syntax in diff output)
  /// - Returns: Array of diff lines with type and line number information, or nil if diff generation fails
  private func createGitDiffLines(
    before: String,
    after: String,
    fileExtension: String? = nil
  ) async -> [DiffTerminalService.DiffLine]? {
    // Create temp file URLs with appropriate extension
    let (beforeURL, afterURL) = createTempFileURLs(fileExtension: fileExtension)
    
    defer {
      // Clean up temp files
      cleanupTempFiles(beforeURL, afterURL)
    }
    
    do {
      // Write content to temp files
      try before.write(to: beforeURL, atomically: true, encoding: .utf8)
      try after.write(to: afterURL, atomically: true, encoding: .utf8)
      
      // Execute git diff command
      let diffOutput = try await executeGitDiff(beforeURL: beforeURL, afterURL: afterURL)
      
      // Validate diff output
      guard !diffOutput.isEmpty, diffOutput.contains("@@") else {
        AppLogger.info("Git diff produced no meaningful output")
        return nil
      }
      
      return parseDiffOutput(diffOutput)
    } catch {
      AppLogger.error("Failed to create git diff: \(error.localizedDescription)")
      return nil
    }
  }
  
  /// Creates temporary file URLs for diff comparison.
  ///
  /// - Parameter fileExtension: Optional file extension to use
  /// - Returns: Tuple of URLs for before and after temp files
  private func createTempFileURLs(fileExtension: String?) -> (before: URL, after: URL) {
    let tempDir = FileManager.default.temporaryDirectory
    let uniqueID = UUID().uuidString
    let ext = fileExtension ?? Constants.defaultExtension
    
    let beforeURL = tempDir
      .appendingPathComponent("\(Constants.tempFilePrefix)\(uniqueID)")
      .appendingPathExtension(ext)
    
    let afterURL = tempDir
      .appendingPathComponent("\(Constants.tempFileAfterPrefix)\(uniqueID)")
      .appendingPathExtension(ext)
    
    return (beforeURL, afterURL)
  }
  
  /// Executes git diff command on the provided file URLs.
  ///
  /// - Parameters:
  ///   - beforeURL: URL of the file containing original content
  ///   - afterURL: URL of the file containing modified content
  /// - Returns: The diff output as a string
  private func executeGitDiff(beforeURL: URL, afterURL: URL) async throws -> String {
    let beforePath = beforeURL.path
    let afterPath = afterURL.path
    
    // Build git diff command with configurable context lines
    let diffCommand = "git diff --no-index -U\(Constants.contextLines) \"\(beforePath)\" \"\(afterPath)\""
    
    // Execute command and return output
    return try await terminalService.output(diffCommand) ?? ""
  }
  
  /// Cleans up temporary files created for diff comparison.
  ///
  /// - Parameters:
  ///   - beforeURL: URL of the before temp file
  ///   - afterURL: URL of the after temp file
  private func cleanupTempFiles(_ beforeURL: URL, _ afterURL: URL) {
    let fileManager = FileManager.default
    try? fileManager.removeItem(at: beforeURL)
    try? fileManager.removeItem(at: afterURL)
  }
  
  private func parseDiffOutput(_ diffOutput: String) -> [DiffTerminalService.DiffLine]? {
    let lines = diffOutput.components(separatedBy: "\n")
    
    // Find the first hunk header
    guard let firstHunkIndex = findFirstHunkHeader(in: lines) else {
      return nil
    }
    
    var diffLines = [DiffTerminalService.DiffLine]()
    var lineIndex = firstHunkIndex
    var currentLineNumber = extractLineNumber(from: lines[lineIndex])
    
    // Skip the first hunk header
    lineIndex += 1
    
    // Process all diff lines
    while lineIndex < lines.count {
      let line = lines[lineIndex]
      
      if line.starts(with: "@@") {
        // Handle new hunk header
        currentLineNumber = extractLineNumber(from: line)
        lineIndex += 1
        
        // Add separator between hunks
        diffLines.append(createSeparatorLine())
        continue
      }
      
      // Skip empty line at end of file
      if shouldSkipLine(line, at: lineIndex, totalLines: lines.count) {
        lineIndex += 1
        continue
      }
      
      // Process content line and update line number if needed
      if let diffLine = processContentLine(
        line,
        currentLineNumber: &currentLineNumber
      ) {
        diffLines.append(diffLine)
      }
      
      lineIndex += 1
    }
    
    return diffLines
  }
  
  /// Finds the index of the first hunk header in the diff output.
  ///
  /// - Parameter lines: Array of lines from the diff output
  /// - Returns: Index of the first hunk header, or nil if not found
  private func findFirstHunkHeader(in lines: [String]) -> Int? {
    for (index, line) in lines.enumerated() {
      if line.starts(with: "@@") {
        return index
      }
    }
    return nil
  }
  
  /// Extracts the line number from a hunk header.
  ///
  /// - Parameter hunkHeader: The hunk header line starting with @@
  /// - Returns: The starting line number, or nil if not found
  private func extractLineNumber(from hunkHeader: String) -> Int? {
    guard let match = hunkHeader.range(
      of: #"\+(\d+)"#,
      options: .regularExpression
    ) else {
      return nil
    }
    
    let startIndex = hunkHeader.index(match.lowerBound, offsetBy: 1)
    let numberString = String(hunkHeader[startIndex..<match.upperBound])
    return Int(numberString)
  }
  
  /// Creates a separator line for display between hunks.
  ///
  /// - Returns: A diff line representing a separator
  private func createSeparatorLine() -> DiffLine {
    DiffLine(
      text: "...",
      type: .unchanged,
      lineNumber: nil
    )
  }
  
  /// Determines if a line should be skipped during processing.
  ///
  /// - Parameters:
  ///   - line: The current line being processed
  ///   - index: Current index in the lines array
  ///   - totalLines: Total number of lines in the array
  /// - Returns: True if the line should be skipped, false otherwise
  private func shouldSkipLine(
    _ line: String,
    at index: Int,
    totalLines: Int
  ) -> Bool {
    // Skip empty line at the end of file
    line.isEmpty && index == totalLines - 1
  }
  
  /// Processes a single content line from the diff output.
  ///
  /// - Parameters:
  ///   - line: The line to process
  ///   - currentLineNumber: Reference to the current line number (will be updated for inserted/unchanged lines)
  /// - Returns: A DiffLine if the line should be included, nil otherwise
  private func processContentLine(
    _ line: String,
    currentLineNumber: inout Int?
  ) -> DiffLine? {
    guard !line.isEmpty else { return nil }
    
    let firstChar = line.first
    let content = String(line.dropFirst())
    
    switch firstChar {
    case "+":
      // Added line
      let diffLine = DiffLine(
        text: content,
        type: .inserted,
        lineNumber: currentLineNumber
      )
      currentLineNumber = (currentLineNumber ?? 0) + 1
      return diffLine
      
    case "-":
      // Removed line
      return DiffLine(
        text: content,
        type: .deleted,
        lineNumber: nil
      )
      
    case " ":
      // Context line (unchanged)
      let diffLine = DiffLine(
        text: content,
        type: .unchanged,
        lineNumber: currentLineNumber
      )
      currentLineNumber = (currentLineNumber ?? 0) + 1
      return diffLine
      
    default:
      return nil
    }
  }
}

extension DiffTerminalService.DiffGroup {
  /// Returns the first valid line number in this diff group, if any exists
  var firstLineNumber: Int? {
    lines.first { $0.lineNumber != nil }?.lineNumber
  }
  
  /// Returns all lines that are inserted or unchanged concatenated into a single string, separated by newlines
  var formattedString: String {
    lines
      .filter { $0.type == .inserted || $0.type == .unchanged }
      .map(\.text)
      .joined(separator: "\n")
  }
}
