//
//  DiffRenderViewModel.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 7/7/2025.
//

import Foundation
import SwiftUI
import CCTerminalServiceInterface
import os.log

@MainActor
@Observable
public class DiffRenderViewModel {
  public var formattedDiff: FormattedFileChange?
  public var isLoading = false
  public var error: String?
  
  public let oldContent: String
  public let newContent: String
  private let terminalService: TerminalService
  private let logger = Logger(subsystem: "com.ClaudeCodeUI.FileDiffViewModel", category: "Diff")
  
  public init(oldContent: String, newContent: String, terminalService: TerminalService) {
    self.oldContent = oldContent
    self.newContent = newContent
    self.terminalService = terminalService
    
    Task {
      await generateDiff()
    }
  }
  
  private func generateDiff() async {
    isLoading = true
    error = nil
    
    logger.debug("Starting diff generation for content lengths: old=\(self.oldContent.count), new=\(self.newContent.count)")
    
    do {
      let diff = try await FileDiff.getColoredDiff(
        oldContent: oldContent,
        newContent: newContent,
        terminalService: terminalService
      )
      
      logger.debug("Diff generated successfully with \(diff.changes.count) changes")
      
      await MainActor.run {
        self.formattedDiff = diff
        self.isLoading = false
      }
    } catch {
      logger.error("Error generating diff: \(error)")
      await MainActor.run {
        self.error = error.localizedDescription
        self.isLoading = false
      }
    }
  }
}
