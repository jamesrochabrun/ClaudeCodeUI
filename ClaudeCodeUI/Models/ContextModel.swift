//
//  ContextModel.swift
//  ClaudeCodeUI
//
//  Created on 12/27/24.
//

import Foundation

/// Manages the context that will be included in chat messages
struct ContextModel: Equatable {
  /// Code selections from Xcode
  var codeSelections: [TextSelection]
  
  /// Files actively being worked on
  var activeFiles: [FileInfo]
  
  /// Current workspace name
  var workspace: String?
  
  /// Additional context notes
  var notes: String?
  
  /// Maximum number of selections to keep
  private let maxSelections = 10
  
  /// Maximum number of files to keep
  private let maxFiles = 5
  
  init(
    codeSelections: [TextSelection] = [],
    activeFiles: [FileInfo] = [],
    workspace: String? = nil,
    notes: String? = nil
  ) {
    self.codeSelections = codeSelections
    self.activeFiles = activeFiles
    self.workspace = workspace
    self.notes = notes
  }
  
  /// Builds a formatted string representation of the context for the prompt
  func buildPromptContext() -> String {
    var contextParts: [String] = []
    
    // Add workspace info
    if let workspace = workspace {
      contextParts.append("Workspace: \(workspace)")
    }
    
    // Add code selections
    if !codeSelections.isEmpty {
      contextParts.append("Code Selections:")
      for selection in codeSelections {
        let language = FileInfo(path: selection.filePath).language ?? "plaintext"
        contextParts.append("""
                
                File: \(selection.fileName) (\(selection.lineRangeDescription))
                ```\(language)
                \(selection.selectedText)
                ```
                """)
      }
    }
    
    // Add active files info
    if !activeFiles.isEmpty {
      contextParts.append("\nActive Files:")
      for file in activeFiles {
        contextParts.append("- \(file.name)")
        if let content = file.content, !content.isEmpty {
          let preview = String(content.prefix(500))
          let language = file.language ?? "plaintext"
          contextParts.append("""
                    ```\(language)
                    \(preview)\(content.count > 500 ? "\n... (truncated)" : "")
                    ```
                    """)
        }
      }
    }
    
    // Add notes if any
    if let notes = notes, !notes.isEmpty {
      contextParts.append("\nAdditional Context: \(notes)")
    }
    
    return contextParts.joined(separator: "\n\n")
  }
  
  /// Clears all context
  mutating func clear() {
    codeSelections.removeAll()
    activeFiles.removeAll()
    workspace = nil
    notes = nil
  }
  
  /// Checks if the context is empty
  func isEmpty() -> Bool {
    codeSelections.isEmpty && activeFiles.isEmpty && workspace == nil && (notes?.isEmpty ?? true)
  }
  
  /// Adds a code selection, maintaining the maximum limit
  mutating func addSelection(_ selection: TextSelection) {
    // Remove duplicate selections from the same file/line range
    codeSelections.removeAll { existing in
      existing.filePath == selection.filePath && existing.lineRange == selection.lineRange
    }
    
    codeSelections.insert(selection, at: 0)
    
    // Keep only the most recent selections
    if codeSelections.count > maxSelections {
      codeSelections = Array(codeSelections.prefix(maxSelections))
    }
  }
  
  /// Adds a file, maintaining the maximum limit
  mutating func addFile(_ file: FileInfo) {
    // Remove duplicate files
    activeFiles.removeAll { $0.path == file.path }
    
    activeFiles.insert(file, at: 0)
    
    // Keep only the most recent files
    if activeFiles.count > maxFiles {
      activeFiles = Array(activeFiles.prefix(maxFiles))
    }
  }
  
  /// Sets the active file (replaces current active files)
  mutating func setActiveFile(_ file: FileInfo) {
    activeFiles = [file]
  }
  
  /// Removes a specific selection
  mutating func removeSelection(id: UUID) {
    codeSelections.removeAll { $0.id == id }
  }
  
  /// Removes a specific file
  mutating func removeFile(id: UUID) {
    activeFiles.removeAll { $0.id == id }
  }
  
  /// Updates from XcodeWorkspaceModel
  mutating func updateFromWorkspace(_ workspace: XcodeWorkspaceModel) {
    self.workspace = workspace.workspaceName
    
    // Add new selections
    for selection in workspace.selectedText {
      addSelection(selection)
    }
    
    // Update active file if present
    if let activeFile = workspace.activeFile {
      addFile(activeFile)
    }
  }
  
  /// Summary description for UI display
  var summary: String {
    var parts: [String] = []
    
    if let workspace = workspace {
      parts.append(workspace)
    }
    
    if !codeSelections.isEmpty {
      parts.append("\(codeSelections.count) selection\(codeSelections.count == 1 ? "" : "s")")
    }
    
    if !activeFiles.isEmpty {
      parts.append("\(activeFiles.count) file\(activeFiles.count == 1 ? "" : "s")")
    }
    
    return parts.isEmpty ? "No context" : parts.joined(separator: " • ")
  }
}
