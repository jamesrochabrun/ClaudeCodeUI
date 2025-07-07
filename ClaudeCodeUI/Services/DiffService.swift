//
//  DiffService.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 7/7/2025.
//

import Foundation
import TerminalServiceInterface
import os.log

/// Service for generating diffs between text content
@MainActor
final class DiffService {
  
  // MARK: - Properties
  
  private let terminalService: TerminalService
  private let logger = Logger(subsystem: "com.ClaudeCodeUI.DiffService", category: "Diff")
  private let fileManager = FileManager.default
  
  // MARK: - Initialization
  
  init(terminalService: TerminalService) {
    self.terminalService = terminalService
  }
  
  // MARK: - Public Methods
  
  /// Generates a unified diff between old and new content
  /// - Parameters:
  ///   - oldContent: The original content
  ///   - newContent: The modified content
  ///   - fileName: Optional file name for display in diff header
  /// - Returns: The diff output as a string
  func generateDiff(oldContent: String, newContent: String, fileName: String? = nil) async throws -> String {
    // Create temporary files
    let tempDir = fileManager.temporaryDirectory
    let oldFileURL = tempDir.appendingPathComponent("old_\(UUID().uuidString).txt")
    let newFileURL = tempDir.appendingPathComponent("new_\(UUID().uuidString).txt")
    
    do {
      // Write content to temporary files
      try oldContent.write(to: oldFileURL, atomically: true, encoding: .utf8)
      try newContent.write(to: newFileURL, atomically: true, encoding: .utf8)
      
      // Try git diff first for better formatting
      let gitDiffCommand = "git diff --no-index --no-prefix --unified=3 '\(oldFileURL.path)' '\(newFileURL.path)'"
      
      do {
        let result = try await terminalService.runTerminal(gitDiffCommand, quiet: true)
        
        // Git diff returns exit code 1 when there are differences, which is expected
        if result.exitCode == 0 || result.exitCode == 1 {
          if let output = result.output {
            // Clean up the diff output to use the provided filename
            return cleanDiffOutput(output, fileName: fileName)
          }
        }
      } catch {
        logger.debug("Git diff failed, falling back to standard diff: \(error)")
      }
      
      // Fall back to standard diff if git is not available
      let diffCommand = "diff -u '\(oldFileURL.path)' '\(newFileURL.path)'"
      let result = try await terminalService.runTerminal(diffCommand, quiet: true)
      
      // diff returns exit code 1 when there are differences, which is expected
      if result.exitCode == 0 || result.exitCode == 1 {
        if let output = result.output {
          return cleanDiffOutput(output, fileName: fileName)
        }
      }
      
      throw DiffError.diffGenerationFailed(result.errorOutput ?? "Unknown error")
      
    } catch {
      // Clean up temporary files
      try? fileManager.removeItem(at: oldFileURL)
      try? fileManager.removeItem(at: newFileURL)
      throw error
    }
  }
  
  /// Generates a colored diff suitable for terminal display
  func generateColoredDiff(oldContent: String, newContent: String, fileName: String? = nil) async throws -> String {
    // Create temporary files
    let tempDir = fileManager.temporaryDirectory
    let oldFileURL = tempDir.appendingPathComponent("old_\(UUID().uuidString).txt")
    let newFileURL = tempDir.appendingPathComponent("new_\(UUID().uuidString).txt")
    
    do {
      // Write content to temporary files
      try oldContent.write(to: oldFileURL, atomically: true, encoding: .utf8)
      try newContent.write(to: newFileURL, atomically: true, encoding: .utf8)
      
      // Use git diff with color for better formatting
      let gitDiffCommand = "git diff --no-index --no-prefix --unified=3 --color=always '\(oldFileURL.path)' '\(newFileURL.path)'"
      
      let result = try await terminalService.runTerminal(gitDiffCommand, quiet: true)
      
      // Git diff returns exit code 1 when there are differences, which is expected
      if result.exitCode == 0 || result.exitCode == 1 {
        if let output = result.output {
          // Clean up the diff output to use the provided filename
          return cleanDiffOutput(output, fileName: fileName, preserveColors: true)
        }
      }
      
      throw DiffError.diffGenerationFailed(result.errorOutput ?? "Git diff failed")
      
    } catch {
      // Clean up temporary files
      try? fileManager.removeItem(at: oldFileURL)
      try? fileManager.removeItem(at: newFileURL)
      throw error
    }
  }
  
  // MARK: - Private Methods
  
  private func cleanDiffOutput(_ output: String, fileName: String?, preserveColors: Bool = false) -> String {
    var lines = output.components(separatedBy: .newlines)
    
    // Replace temporary file paths with the provided filename in the header
    if let fileName = fileName, lines.count > 2 {
      // Update the --- and +++ lines with the filename
      for (index, line) in lines.enumerated() {
        if line.hasPrefix("---") {
          lines[index] = "--- \(fileName)"
        } else if line.hasPrefix("+++") {
          lines[index] = "+++ \(fileName)"
          break
        }
      }
    }
    
    // Remove the diff command line if present
    if let firstLine = lines.first, firstLine.contains("diff ") {
      lines.removeFirst()
    }
    
    return lines.joined(separator: "\n")
  }
}

// MARK: - DiffError

enum DiffError: LocalizedError {
  case diffGenerationFailed(String)
  
  var errorDescription: String? {
    switch self {
    case .diffGenerationFailed(let message):
      return "Failed to generate diff: \(message)"
    }
  }
}