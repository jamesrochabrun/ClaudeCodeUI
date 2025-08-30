//
//  FileDiffViewModel.swift
//  ClaudeCodeUI
//
//  Created on 1/30/2025.
//

import Foundation
import SwiftUI
import CCTerminalServiceInterface
import os.log

/// View model for managing file diffs with baseline tracking and error recovery
@MainActor
@Observable
public class FileDiffViewModel {
  
  // MARK: - Properties
  
  public var formattedDiff: FormattedFileChange?
  public var isLoading = false
  public var error: String?
  public var selectedSections: Set<String> = []
  
  public let filePath: String
  public let oldContent: String
  public private(set) var targetContent: String
  public private(set) var baselineContent: String?
  
  private let terminalService: TerminalService
  private let changes: [SearchReplace]
  private let logger = Logger(subsystem: "com.ClaudeCodeUI.FileDiffViewModel", category: "Diff")
  private var retryCount = 0
  private let maxRetries = 5
  
  // MARK: - Initialization
  
  /// Initialize with search/replace changes
  public init(
    filePath: String,
    changes: [SearchReplace],
    oldContent: String,
    terminalService: TerminalService
  ) throws {
    self.filePath = filePath
    self.changes = changes
    self.oldContent = oldContent
    self.terminalService = terminalService
    self.baselineContent = oldContent
    
    // Apply changes to get target content
    self.targetContent = try AdvancedDiff.apply(changes: changes, to: oldContent)
    
    Task {
      await generateDiff()
    }
  }
  
  /// Initialize with LLM diff pattern
  public init(
    filePath: String,
    llmDiff: String,
    terminalService: TerminalService
  ) throws {
    self.filePath = filePath
    
    // Read current file content
    let fileURL = URL(fileURLWithPath: filePath)
    self.oldContent = try String(contentsOf: fileURL)
    self.baselineContent = self.oldContent
    
    // Parse LLM diff
    self.changes = try AdvancedDiff.parse(searchReplacePattern: llmDiff, for: oldContent)
    self.terminalService = terminalService
    
    // Apply changes to get target content
    self.targetContent = try AdvancedDiff.apply(changes: changes, to: oldContent)
    
    Task {
      await generateDiff()
    }
  }
  
  // MARK: - Public Methods
  
  /// Apply all changes to the file
  public func handleApplyAllChanges() async throws {
    guard !targetContent.isEmpty else {
      throw DiffError.message("No changes to apply")
    }
    
    let fileURL = URL(fileURLWithPath: filePath)
    try targetContent.write(to: fileURL, atomically: true, encoding: .utf8)
    
    // Update baseline after successful apply
    baselineContent = targetContent
    
    logger.info("Applied all changes to \(self.filePath)")
  }
  
  /// Apply only selected sections
  public func handleApplySelectedSections() async throws {
    guard !selectedSections.isEmpty else {
      throw DiffError.message("No sections selected")
    }
    
    // This would require more complex logic to apply only selected changes
    // For now, apply all if any are selected
    try await handleApplyAllChanges()
  }
  
  /// Handle new changes (for streaming support)
  public func handle(newChanges: [SearchReplace]) {
    Task {
      do {
        // Apply new changes on top of current target
        let newTarget = try AdvancedDiff.apply(changes: newChanges, to: targetContent)
        self.targetContent = newTarget
        
        // Regenerate diff
        await generateDiff()
      } catch {
        self.error = error.localizedDescription
      }
    }
  }
  
  // MARK: - Private Methods
  
  private func generateDiff() async {
    isLoading = true
    error = nil
    
    logger.debug("Generating diff for \(self.filePath)")
    
    do {
      let diff = try await AdvancedDiff.getColoredDiff(
        oldContent: oldContent,
        newContent: targetContent,
        terminalService: terminalService
      )
      
      logger.debug("Diff generated successfully with \(diff.changes.count) changes")
      
      self.formattedDiff = diff
      self.isLoading = false
      
    } catch {
      logger.error("Error generating diff: \(error)")
      
      // Attempt error recovery
      if retryCount < maxRetries {
        await attemptErrorRecovery(error: error)
      } else {
        self.error = error.localizedDescription
        self.isLoading = false
      }
    }
  }
  
  private func attemptErrorRecovery(error: Error) async {
    retryCount += 1
    logger.info("Attempting error recovery (attempt \(self.retryCount)/\(self.maxRetries))")
    
    // Check if baseline has drifted
    if let baseline = baselineContent {
      do {
        // Try to read current file content
        let fileURL = URL(fileURLWithPath: filePath)
        if let currentContent = try? String(contentsOf: fileURL),
           currentContent != baseline {
          
          logger.info("Baseline drift detected, attempting three-way merge")
          
          // Attempt three-way merge
          let mergedContent = try await AdvancedDiff.rebaseChange(
            baselineContent: baseline,
            currentContent: currentContent,
            targetContent: targetContent,
            terminalService: terminalService
          )
          
          // Update target with merged content
          self.targetContent = mergedContent
          
          // Update baseline
          self.baselineContent = currentContent
          
          // Retry diff generation
          await generateDiff()
          return
        }
      } catch {
        logger.error("Error during recovery: \(error)")
      }
    }
    
    // Simple retry with delay
    try? await Task.sleep(nanoseconds: 100_000_000 * UInt64(retryCount))
    await generateDiff()
  }
  
  /// Check if baseline content has changed
  public func checkBaselineDrift() -> Bool {
    guard let baseline = baselineContent else { return false }
    
    let fileURL = URL(fileURLWithPath: filePath)
    guard let currentContent = try? String(contentsOf: fileURL) else {
      return false
    }
    
    return currentContent != baseline
  }
}