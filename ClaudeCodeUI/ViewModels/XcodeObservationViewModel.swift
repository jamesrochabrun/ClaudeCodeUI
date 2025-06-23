//
//  XcodeObservationViewModel.swift
//  ClaudeCodeUI
//
//  Created on 12/27/24.
//

import Foundation
import SwiftUI
import Combine
import XcodeObserverServiceInterface
import AppKit
import ApplicationServices

/// Manages the XcodeObserver lifecycle and provides workspace state updates
@Observable
@MainActor
final class XcodeObservationViewModel {
  
  // MARK: - Observable Properties
  
  /// Current Xcode workspace state
  private(set) var workspaceModel: XcodeWorkspaceModel = XcodeWorkspaceModel()
  
  /// Whether Xcode observation is active
  private(set) var isObserving: Bool = false
  
  /// Error state if observation fails
  private(set) var observationError: Error?
  
  /// Whether we have permission to observe Xcode
  private(set) var hasAccessibilityPermission: Bool = false
  
  // MARK: - Private Properties
  
  private let xcodeObserver: XcodeObserver
  private var stateSubscription: AnyCancellable?
  private var permissionCheckTimer: Timer?
  
  // MARK: - Initialization
  
  init(xcodeObserver: XcodeObserver) {
    self.xcodeObserver = xcodeObserver
    setupObservation()
    startPermissionCheck()
  }
  
  // MARK: - Public Methods
  
  /// Cleans up resources (should be called before deallocation)
  func cleanup() {
    permissionCheckTimer?.invalidate()
    permissionCheckTimer = nil
  }
  
  /// Starts observing Xcode if not already observing
  func startObserving() {
    guard !isObserving else { return }
    
    // XcodeObserver starts automatically when permissions are granted
    isObserving = hasAccessibilityPermission
    observationError = nil
  }
  
  /// Stops observing Xcode
  func stopObserving() {
    // XcodeObserver doesn't have a stop method - it's managed automatically
    isObserving = false
  }
  
  /// Refreshes the current state
  func refresh() {
    // Force update from current state
    updateWorkspaceModel(from: xcodeObserver.state)
  }
  
  /// Gets the current selection from Xcode
  func captureCurrentSelection() -> TextSelection? {
    guard let state = xcodeObserver.state.knownState?.first,
          let window = state.windows.first,
          let workspace = window.workspace,
          let editor = workspace.editors.first(where: { $0.isFocussed }),
          let selectedContent = editor.content.selectedContent,
          !selectedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          let selection = editor.content.selection,
          let fileURL = editor.activeTabURL else {
      return nil
    }
    
    // Handle potentially reversed selection (right to left)
    let startLine = min(selection.start.line, selection.end.line)
    let endLine = max(selection.start.line, selection.end.line)
    let lineRange = startLine...endLine
    
    // For column range, since selectedContent already has the correct text,
    // we'll just store a valid range. For multi-line selections, the column
    // range is less meaningful anyway.
    let columnRange: Range<Int>
    if selection.start.line == selection.end.line {
      // Same line - ensure proper ordering
      let startChar = min(selection.start.character, selection.end.character)
      let endChar = max(selection.start.character, selection.end.character)
      columnRange = startChar..<endChar
    } else {
      // Multi-line selection - just use 0..<0 as a placeholder
      // The actual selection is preserved in selectedText
      columnRange = 0..<0
    }
    
    return TextSelection(
      filePath: fileURL.path,
      selectedText: selectedContent,
      lineRange: lineRange,
      columnRange: columnRange
    )
  }
  
  // MARK: - Private Methods
  
  private func setupObservation() {
    // Subscribe to state changes
    stateSubscription = xcodeObserver.statePublisher
      .receive(on: DispatchQueue.main)
      .sink { [weak self] state in
        self?.updateWorkspaceModel(from: state)
      }
  }
  
  private func updateWorkspaceModel(from state: XcodeObserver.State) {
    guard let instance = state.knownState?.first,
          let window = instance.windows.first,
          let workspace = window.workspace else {
      // Clear the model if no workspace is available
      workspaceModel = XcodeWorkspaceModel()
      return
    }
    
    // Extract workspace name
    let workspaceName = workspace.documentURL?.deletingPathExtension().lastPathComponent
    
    // Extract active file
    let activeFile: FileInfo? = workspace.editors
      .first(where: { $0.isFocussed })
      .flatMap { editor in
        guard let url = editor.activeTabURL,
              let activeTab = editor.activeTab else { return nil }
        
        return FileInfo(
          path: url.path,
          name: activeTab,
          content: editor.content.lines.joined()
        )
      }
    
    // Extract open files
    let openFiles: [FileInfo] = workspace.editors.compactMap { editor in
      guard let url = editor.activeTabURL,
            let activeTab = editor.activeTab else { return nil }
      
      return FileInfo(
        path: url.path,
        name: activeTab,
        content: nil // Don't load content for all files to save memory
      )
    }
    
    // Extract text selections
    let selections: [TextSelection] = workspace.editors.compactMap { editor in
      guard let selectedContent = editor.content.selectedContent,
            !selectedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            let selection = editor.content.selection,
            let fileURL = editor.activeTabURL else { return nil }
      
      // Handle potentially reversed selection (right to left)
      let startLine = min(selection.start.line, selection.end.line)
      let endLine = max(selection.start.line, selection.end.line)
      let lineRange = startLine...endLine
      
      // For column range, since selectedContent already has the correct text,
      // we'll just store a valid range. For multi-line selections, the column
      // range is less meaningful anyway.
      let columnRange: Range<Int>
      if selection.start.line == selection.end.line {
        // Same line - ensure proper ordering
        let startChar = min(selection.start.character, selection.end.character)
        let endChar = max(selection.start.character, selection.end.character)
        columnRange = startChar..<endChar
      } else {
        // Multi-line selection - just use 0..<0 as a placeholder
        // The actual selection is preserved in selectedText
        columnRange = 0..<0
      }
      
      return TextSelection(
        filePath: fileURL.path,
        selectedText: selectedContent,
        lineRange: lineRange,
        columnRange: columnRange
      )
    }
    
    // Update the model
    workspaceModel = XcodeWorkspaceModel(
      workspaceName: workspaceName,
      activeFile: activeFile,
      openFiles: openFiles,
      selectedText: selections
    )
  }
  
  private func startPermissionCheck() {
    checkAccessibilityPermission()
    
    // Check permission every 2 seconds
    permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
      Task { @MainActor in
        self?.checkAccessibilityPermission()
      }
    }
  }
  
  private func checkAccessibilityPermission() {
    // This is a simplified check - you should use the actual permission service
    hasAccessibilityPermission = AXIsProcessTrusted()
    
    // Auto-start observation when permission is granted
    if hasAccessibilityPermission && !isObserving {
      startObserving()
    }
  }
}

// MARK: - Convenience Extensions

extension XcodeObservationViewModel {
  /// Simple summary of the current state
  var stateSummary: String {
    if !hasAccessibilityPermission {
      return "Accessibility permission required"
    }
    
    if !isObserving {
      return "Not observing"
    }
    
    if let error = observationError {
      return "Error: \(error.localizedDescription)"
    }
    
    if let workspace = workspaceModel.workspaceName {
      return "Observing: \(workspace)"
    }
    
    return "Observing Xcode"
  }
  
  /// Whether there's any active content
  var hasContent: Bool {
    workspaceModel.workspaceName != nil ||
    !workspaceModel.openFiles.isEmpty ||
    !workspaceModel.selectedText.isEmpty
  }
}
