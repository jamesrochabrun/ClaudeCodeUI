//
//  ContextManager.swift
//  ClaudeCodeUI
//
//  Created on 12/27/24.
//

import Foundation
import SwiftUI

/// Manages the code context that will be included in chat messages
@Observable
@MainActor
public final class ContextManager {
  
  // MARK: - Observable Properties
  
  /// The current context model
  private(set) var context: ContextModel = ContextModel()
  
  /// Whether context capture is enabled
  var isCaptureEnabled: Bool = true
  
  /// Visual feedback when context is captured
  var showCaptureAnimation: Bool = false
  
  /// Whether the active file is pinned (won't change when switching files in Xcode)
  var isPinnedActiveFile: Bool = false
  
  /// The pinned active file (if any)
  private(set) var pinnedActiveFile: FileInfo?
  
  // MARK: - Private Properties
  
  private let xcodeObservationViewModel: XcodeObservationViewModel
  
  // MARK: - Initialization
  
  init(xcodeObservationViewModel: XcodeObservationViewModel) {
    self.xcodeObservationViewModel = xcodeObservationViewModel
    setupSubscriptions()
  }
  
  // MARK: - Public Methods
  
  /// Captures the current selection from Xcode (triggered by cmd+8)
  func captureCurrentSelection() -> TextSelection? {
    guard isCaptureEnabled else { return nil }
    
    if let selection = xcodeObservationViewModel.captureCurrentSelection() {
      context.addSelection(selection)
      triggerCaptureAnimation()
      print("[ContextManager] Captured selection from \(selection.fileName)")
      return selection
    } else {
      print("[ContextManager] No selection available to capture")
      return nil
    }
  }
  
  /// Manually adds a file to the context
  func addFile(_ file: FileInfo) {
    context.addFile(file)
  }
  
  /// Manually adds a selection to the context
  func addSelection(_ selection: TextSelection) {
    context.addSelection(selection)
  }
  
  /// Adds captured text when Xcode selection is not available
  func addCapturedText(_ text: String) {
    guard isCaptureEnabled else { return }
    
    // Create a text selection with minimal info
    let selection = TextSelection(
      filePath: "Clipboard",
      selectedText: text,
      lineRange: 0...0,
      columnRange: 0..<0
    )
    
    context.addSelection(selection)
    triggerCaptureAnimation()
    print("[ContextManager] Captured text from clipboard")
  }
  
  /// Removes a specific selection by ID
  func removeSelection(id: UUID) {
    context.removeSelection(id: id)
  }
  
  /// Removes a specific file by ID
  func removeFile(id: UUID) {
    // If removing the pinned file, unpin it
    if let pinned = pinnedActiveFile, pinned.id == id {
      isPinnedActiveFile = false
      pinnedActiveFile = nil
    }
    context.removeFile(id: id)
  }
  
  /// Clears all context
  func clearAll() {
    context.clear()
    isPinnedActiveFile = false
    pinnedActiveFile = nil
  }
  
  /// Toggles the pin state of the active file
  func togglePinActiveFile() {
    if isPinnedActiveFile {
      // Unpin
      isPinnedActiveFile = false
      pinnedActiveFile = nil
    } else {
      // Pin the current active file from Xcode
      if let activeFile = xcodeObservationViewModel.workspaceModel.activeFile {
        isPinnedActiveFile = true
        pinnedActiveFile = activeFile
      }
    }
  }
  
  /// Unpins the active file
  func unpinActiveFile() {
    isPinnedActiveFile = false
    pinnedActiveFile = nil
  }
  
  /// Sets additional notes for the context
  func setNotes(_ notes: String?) {
    context.notes = notes
  }
  
  /// Gets the formatted context for inclusion in a prompt
  func getFormattedContext() -> String {
    context.buildPromptContext()
  }
  
  /// Checks if there's any context available
  var hasContext: Bool {
    !context.isEmpty()
  }
  
  /// Gets the context summary for UI display
  var contextSummary: String {
    context.summary
  }
  
  /// Updates the context from the current workspace state
  func updateFromCurrentWorkspace() {
    handleWorkspaceUpdate(xcodeObservationViewModel.workspaceModel)
  }
  
  // MARK: - Private Methods
  
  private func setupSubscriptions() {
    // Observe workspace changes from XcodeObservationViewModel
    // We'll use a timer to periodically check for updates
    Task { @MainActor in
      while true {
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        handleWorkspaceUpdate(xcodeObservationViewModel.workspaceModel)
      }
    }
  }
  
  private func handleWorkspaceUpdate(_ workspace: XcodeWorkspaceModel) {
    // Update workspace name
    if workspace.workspaceName != context.workspace {
      context.workspace = workspace.workspaceName
    }
    
    // Don't update context active files when pinned - the pinned file stays in view
    // The actual Xcode active file changes are tracked in XcodeObservationViewModel
    
    // Optionally auto-capture selections if enabled
    if isCaptureEnabled && !workspace.selectedText.isEmpty {
      // Only add new selections that aren't already in context
      for selection in workspace.selectedText {
        if !context.codeSelections.contains(where: {
          $0.filePath == selection.filePath &&
          $0.lineRange == selection.lineRange
        }) {
          // This is a new selection, you might want to auto-add it
          // For now, we'll let the user explicitly capture with cmd+8
        }
      }
    }
  }
  
  private func triggerCaptureAnimation() {
    withAnimation(.easeInOut(duration: 0.3)) {
      showCaptureAnimation = true
    }
    
    // Hide animation after delay
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
      withAnimation(.easeInOut(duration: 0.3)) {
        self?.showCaptureAnimation = false
      }
    }
  }
}

// MARK: - Context Presets

extension ContextManager {
  /// Predefined context configurations
  enum ContextPreset {
    case activeFile
    case allOpenFiles
    case selectionsOnly
    case workspaceOnly
    
    var name: String {
      switch self {
      case .activeFile: return "Active File"
      case .allOpenFiles: return "All Open Files"
      case .selectionsOnly: return "Selections Only"
      case .workspaceOnly: return "Workspace Info"
      }
    }
  }
  
  /// Applies a preset configuration to the context
  func applyPreset(_ preset: ContextPreset) {
    context.clear()
    
    let workspace = xcodeObservationViewModel.workspaceModel
    
    switch preset {
    case .activeFile:
      if let activeFile = workspace.activeFile {
        context.addFile(activeFile)
      }
      context.workspace = workspace.workspaceName
      
    case .allOpenFiles:
      for file in workspace.openFiles {
        context.addFile(file)
      }
      context.workspace = workspace.workspaceName
      
    case .selectionsOnly:
      for selection in workspace.selectedText {
        context.addSelection(selection)
      }
      
    case .workspaceOnly:
      context.workspace = workspace.workspaceName
    }
  }
}
