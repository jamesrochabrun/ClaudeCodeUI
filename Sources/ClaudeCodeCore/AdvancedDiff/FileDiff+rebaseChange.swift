//
//  FileDiff+rebaseChange.swift
//  ClaudeCodeUI
//
//  Created on 1/30/2025.
//

import Foundation
import CCTerminalServiceInterface
import os.log

// MARK: - Three-way Merge

extension AdvancedDiff {
  
  private static let logger = Logger(subsystem: "com.ClaudeCodeUI.FileDiff", category: "Rebase")
  
  /// Performs a three-way merge for conflict resolution using git
  /// This is useful when the baseline content has changed since the diff was generated
  ///
  /// - Parameters:
  ///   - baselineContent: Original baseline content when the changes were created
  ///   - currentContent: Current content in the file (may have been modified)
  ///   - targetContent: Target content we want to apply
  ///   - terminalService: Service for executing git commands
  ///
  /// - Returns: Merged content (may contain conflict markers if automatic merge fails)
  /// - Throws: Error if merge setup fails
  public static func rebaseChange(
    baselineContent: String,
    currentContent: String,
    targetContent: String,
    terminalService: TerminalService
  ) async throws -> String {
    let uuid = UUID().uuidString
    let tmpDir = "/tmp/git-merge-\(uuid)"
    
    // Create temporary directory and initialize git repo
    let setupCommands = """
      mkdir -p \(tmpDir) && \
      cd \(tmpDir) && \
      git init --quiet && \
      git config user.email "diff@claudecode.ai" && \
      git config user.name "ClaudeCode Diff"
      """
    
    var result = try await terminalService.runTerminal(setupCommands, quiet: true)
    guard result.exitCode == 0 else {
      throw DiffError.gitDiffFailed("Failed to initialize git repository: \(result.errorOutput ?? "")")
    }
    
    defer {
      // Cleanup
      Task {
        _ = try? await terminalService.runTerminal("rm -rf \(tmpDir)", quiet: true)
      }
    }
    
    let filePath = "\(tmpDir)/file.txt"
    
    // Create baseline branch
    try baselineContent.write(toFile: filePath, atomically: true, encoding: .utf8)
    result = try await terminalService.runTerminal(
      "cd \(tmpDir) && git add file.txt && git commit -m 'baseline' --quiet",
      quiet: true
    )
    guard result.exitCode == 0 else {
      throw DiffError.gitDiffFailed("Failed to commit baseline: \(result.errorOutput ?? "")")
    }
    
    // Create current branch
    result = try await terminalService.runTerminal(
      "cd \(tmpDir) && git checkout -b current --quiet",
      quiet: true
    )
    try currentContent.write(toFile: filePath, atomically: true, encoding: .utf8)
    result = try await terminalService.runTerminal(
      "cd \(tmpDir) && git add file.txt && git commit -m 'current' --quiet",
      quiet: true
    )
    
    // Create target branch from baseline
    result = try await terminalService.runTerminal(
      "cd \(tmpDir) && git checkout main --quiet && git checkout -b target --quiet",
      quiet: true
    )
    try targetContent.write(toFile: filePath, atomically: true, encoding: .utf8)
    result = try await terminalService.runTerminal(
      "cd \(tmpDir) && git add file.txt && git commit -m 'target' --quiet",
      quiet: true
    )
    
    // Attempt three-way merge
    result = try await terminalService.runTerminal(
      "cd \(tmpDir) && git checkout current --quiet && git merge target --no-edit --quiet",
      quiet: true
    )
    
    // Read the result (may contain conflict markers)
    let mergedContent = try String(contentsOfFile: filePath, encoding: .utf8)
    
    // Check if merge had conflicts
    if result.exitCode != 0 {
      logger.info("Three-way merge resulted in conflicts that need manual resolution")
    }
    
    return mergedContent
  }
}