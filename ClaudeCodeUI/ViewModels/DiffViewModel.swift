//
//  DiffViewModel.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 7/7/2025.
//

import Foundation
import SwiftUI
import os.log

/// Represents a single line in a diff
struct DiffLine: Identifiable {
  let id = UUID()
  let content: String
  let type: DiffLineType
  let oldLineNumber: Int?
  let newLineNumber: Int?
  
  enum DiffLineType {
    case header
    case context
    case addition
    case deletion
    case lineInfo  // @@ -1,4 +1,4 @@ style markers
  }
}

/// View model for handling diff display
@MainActor
@Observable
final class DiffViewModel {
  
  // MARK: - Properties
  
  private(set) var diffLines: [DiffLine] = []
  private(set) var isLoading = false
  private(set) var error: String?
  
  private let diffService: DiffService
  private let logger = Logger(subsystem: "com.ClaudeCodeUI.DiffViewModel", category: "Diff")
  
  // Statistics
  private(set) var additions = 0
  private(set) var deletions = 0
  
  // MARK: - Initialization
  
  init(diffService: DiffService) {
    self.diffService = diffService
  }
  
  // MARK: - Public Methods
  
  /// Generate diff from old and new content
  func generateDiff(oldContent: String, newContent: String, fileName: String? = nil) async {
    isLoading = true
    error = nil
    diffLines = []
    additions = 0
    deletions = 0
    
    do {
      let diffOutput = try await diffService.generateDiff(
        oldContent: oldContent,
        newContent: newContent,
        fileName: fileName
      )
      
      parseDiffOutput(diffOutput)
      
    } catch {
      logger.error("Failed to generate diff: \(error)")
      self.error = error.localizedDescription
    }
    
    isLoading = false
  }
  
  // MARK: - Private Methods
  
  private func parseDiffOutput(_ output: String) {
    let lines = output.components(separatedBy: .newlines)
    var oldLineNumber = 0
    var newLineNumber = 0
    var parsedLines: [DiffLine] = []
    
    for line in lines {
      // Skip empty lines at the end
      if line.isEmpty && parsedLines.last?.content.isEmpty == true {
        continue
      }
      
      // Parse line type and content
      if line.hasPrefix("---") || line.hasPrefix("+++") {
        // File header
        parsedLines.append(DiffLine(
          content: line,
          type: .header,
          oldLineNumber: nil,
          newLineNumber: nil
        ))
      } else if line.hasPrefix("@@") {
        // Line info (e.g., @@ -1,4 +1,4 @@)
        parsedLines.append(DiffLine(
          content: line,
          type: .lineInfo,
          oldLineNumber: nil,
          newLineNumber: nil
        ))
        
        // Parse line numbers from the @@ marker
        let numbers = parseLineNumbers(from: line)
        oldLineNumber = numbers.old
        newLineNumber = numbers.new
        
      } else if line.hasPrefix("+") {
        // Addition
        additions += 1
        parsedLines.append(DiffLine(
          content: String(line.dropFirst()),  // Remove the + prefix
          type: .addition,
          oldLineNumber: nil,
          newLineNumber: newLineNumber
        ))
        newLineNumber += 1
        
      } else if line.hasPrefix("-") {
        // Deletion
        deletions += 1
        parsedLines.append(DiffLine(
          content: String(line.dropFirst()),  // Remove the - prefix
          type: .deletion,
          oldLineNumber: oldLineNumber,
          newLineNumber: nil
        ))
        oldLineNumber += 1
        
      } else if !line.isEmpty || parsedLines.last?.content.isEmpty == false {
        // Context line (unchanged)
        parsedLines.append(DiffLine(
          content: line.hasPrefix(" ") ? String(line.dropFirst()) : line,
          type: .context,
          oldLineNumber: oldLineNumber,
          newLineNumber: newLineNumber
        ))
        oldLineNumber += 1
        newLineNumber += 1
      }
    }
    
    diffLines = parsedLines
  }
  
  private func parseLineNumbers(from lineInfo: String) -> (old: Int, new: Int) {
    // Parse @@ -old,count +new,count @@ format
    let pattern = #"@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@"#
    
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(
            in: lineInfo,
            range: NSRange(location: 0, length: lineInfo.utf16.count)
          ) else {
      return (1, 1)
    }
    
    let oldStart = (lineInfo as NSString).substring(with: match.range(at: 1))
    let newStart = (lineInfo as NSString).substring(with: match.range(at: 2))
    
    return (
      Int(oldStart) ?? 1,
      Int(newStart) ?? 1
    )
  }
}

// MARK: - DiffColors

extension DiffLine.DiffLineType {
  var backgroundColor: Color {
    switch self {
    case .addition:
      return Color.green.opacity(0.2)
    case .deletion:
      return Color.red.opacity(0.2)
    case .header, .lineInfo:
      return Color.gray.opacity(0.1)
    case .context:
      return Color.clear
    }
  }
  
  var foregroundColor: Color {
    switch self {
    case .addition:
      return Color.green.mix(with: .primary, by: 0.3)
    case .deletion:
      return Color.red.mix(with: .primary, by: 0.3)
    case .header, .lineInfo:
      return Color.secondary
    case .context:
      return Color.primary
    }
  }
  
  var prefixSymbol: String {
    switch self {
    case .addition:
      return "+"
    case .deletion:
      return "-"
    case .context, .header, .lineInfo:
      return " "
    }
  }
}

extension Color {
  func mix(with color: Color, by amount: Double) -> Color {
    // Simple color mixing by adjusting opacity
    // This creates a blend effect by overlaying the colors
    let clampedAmount = max(0, min(1, amount))
    return self.opacity(1 - clampedAmount)
  }
}