//
//  XcodeObserverViewModel.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 6/21/25.
//

import Foundation
import SwiftUI
import XcodeObserverServiceInterface

// MARK: - SourceCodeViewModel

extension XcodeObserverViewModel {
  static func ==(lhs: XcodeObserverViewModel, rhs: XcodeObserverViewModel) -> Bool {
    lhs.workSpaceDocumentURL?.absoluteString == rhs.workSpaceDocumentURL?.absoluteString &&
      lhs.workspaceURL?.absoluteString == rhs.workspaceURL?.absoluteString &&
      lhs.selectionSources == rhs.selectionSources &&
      lhs.activeEditorSource == rhs.activeEditorSource &&
      lhs.editorsSources == rhs.editorsSources
  }
}

// MARK: - SourceCodeViewModel

/// Represents the source code information for a given workspace, including file selection and active file for example.
struct XcodeObserverViewModel: Equatable {

  // MARK: Lifecycle

  /// Initializes the SourceCodeViewModel with the given XcodeObserver.State.
  init(state: XcodeObserver.State) {
    /// The state of one Xcode instance.
    let instance = state.knownState?.first
    /// The first window that belong to the instance, ordered from when they were most recently were active.
    let window = instance?.windows.first
    /// A workspace is the instance that contains all your open files. (editors)
    let workspace = window?.workspace
    /// An editor represents a file opened inside Xcode.
    let editors = workspace?.editors ?? []

    // Important: Currently each editor will contain only the last selection.
    // This means that if user selects different sections of a file, only the last one
    // will be available as `selectedContent`.
    var selections: [SourceCode] = []

    var editorsSources: [SourceCode] = []

    var activeEditorSource: SourceCode? = nil

    // Iterate through the editors and extract information to construct respective `SourceCode` instances.
    for editor in editors {
      if let activeTab = editor.activeTab {
        // selection sources
        if
          let selectedContent = editor.content.selectedContent,
          // If user selects a lines of code that are empty, the selectedContent will return the `\n` value for each line.
          // We don't want to use empty lines as selection.
          !selectedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          let rangeDisplayText = editor.content.selection?.rangeDisplayText
        {
          selections.append(.init(
            content: selectedContent,
            rangeDisplayText: rangeDisplayText,
            activeTab: activeTab,
            activeTabFilePath: editor.activeTabURL?.absoluteString ?? "",
            tabs: editor.tabs))
        }

        // Active editor Source
        if editor.isFocussed {
          activeEditorSource = .init(
            content: editor.content.lines.formatWithLineNumbers(),
            rangeDisplayText: nil,
            activeTab: activeTab,
            activeTabFilePath: editor.activeTabURL?.absoluteString ?? "",
            tabs: editor.tabs)
        }

        // Editors sources
        editorsSources.append(.init(
          content: editor.content.lines.formatWithLineNumbers(),
          rangeDisplayText: nil,
          activeTab: activeTab,
          activeTabFilePath: editor.activeTabURL?.absoluteString ?? "",
          tabs: editor.tabs))
      }
    }

    selectionSources = selections
    self.editorsSources = editorsSources
    self.activeEditorSource = activeEditorSource

    self.editors = editors
    workSpaceDocumentURL = workspace?.documentURL
    workspaceURL = workspace?.workspaceURL
  }

  // MARK: Internal

  struct SourceCode: Equatable, Hashable, Identifiable {
    /// The content of the selected source code
    let content: String
    /// The display text for the selected range, if available
    let rangeDisplayText: String?
    /// The active tab for the selected source code
    let activeTab: String
    /// The path of the file's active tab
    let activeTabFilePath: String
    /// The current editor's open tabs.
    let tabs: [String]

    var id: String {
      activeTab
    }

    /// Returns the concatenated content of the current sources if any, else nil.
    /// This is used as part of the users prompt.
    var contentPrompt: String {
      """
      ### File Name: \(activeTab)

      \(content)
      """
    }

    static func ==(lhs: SourceCode, rhs: SourceCode) -> Bool {
      lhs.activeTab == rhs.activeTab && lhs.tabs == rhs.tabs && lhs.rangeDisplayText == rhs.rangeDisplayText
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(activeTab)
      hasher.combine(tabs)
      hasher.combine(rangeDisplayText)
    }
  }

  /// The workspace Document URL.
  let workSpaceDocumentURL: URL?
  /// The workspace URL.
  let workspaceURL: URL?
  /// The array of opened editors. An editor represents a file opened inside Xcode.
  let editors: [EditorState]
  /// The array of selections across different editors.
  let selectionSources: [SourceCode]
  /// The source code for the active editor.
  let activeEditorSource: SourceCode?
  /// The array of source code for different editors.
  let editorsSources: [SourceCode]
}

// MARK: - SourceCodeScope

/// Represents the scope of source code that XA has access to using the accessibility APIs.
enum SourceCodeScope: String {

  /// Represents access to all open active editors in the IDE.
  /// This includes only the active files, not all open tabs.
  case editors
  /// Represents access to the currently active editor.
  /// This refers to the file that is currently in focus, not including other open tabs.
  case activeEditor
  /// Represents access to the currently selected code in the active editor.
  case selection
}

// MARK: SourceCodeViewModel + SourceCodeScopeAction

extension XcodeObserverViewModel {

  // MARK: Internal

  /// Returns the available sources for a given Scope action.
  func sourcesForAction(
    _ scope: SourceCodeScope)
    -> [SourceCode]
  {
    switch scope {
    case .editors:
      removeDuplicatesKeepingOrder(from: editorsSources)
    case .activeEditor:
      activeEditorSource.map { [$0] } ?? []
    case .selection:
      removeDuplicatesKeepingOrder(from: selectionSources)
    }
  }

  /// Returns the concatenated content of the current sources if any, else nil.
  /// This is used as part of the users prompt.
  func contentForAction(
    _ scope: SourceCodeScope)
    -> String?
  {
    let sources = sourcesForAction(scope)
    guard !sources.isEmpty else { return nil }
    return sources.map { source in
      source.contentPrompt
    }.joined(separator: "\n")
  }

  // MARK: Private

  private func removeDuplicatesKeepingOrder(
    from array: [SourceCode])
    -> [SourceCode]
  {
    var seen: Set<SourceCode> = []
    return array.filter { element in
      if seen.contains(element) {
        return false
      } else {
        seen.insert(element)
        return true
      }
    }
  }
}

extension XcodeObserverViewModel.SourceCode {

  var fileExtension: String {
    let components = activeTab.split(separator: ".")
    return components.last.map(String.init) ?? ""
  }

  var fileExtensionImageName: String {
    switch fileExtension {
    case "swift": "swift"
    case "md": "book"
    default: "doc"
    }
  }

  var imageForegroundColorForFileExtension: Color {
    switch fileExtension {
    case "swift": .orange
    default: .primary
    }
  }

  var displayCode: String {
    """
    ```\(fileExtension)
    \(content)
    ```
    """
  }
}

extension [String] {

  func formatWithLineNumbers() -> String {
    let maxLineNumberWidth = String(count).count

    return enumerated().map { index, line in
      let lineNumber = index + 1 // Normalize to start from 1
      // Remove the newline character at the end if it exists
      let trimmedLine = line.hasSuffix("\n") ? String(line.dropLast()) : line
      return String(format: "%\(maxLineNumberWidth)d  %@", lineNumber, trimmedLine)
    }.joined(separator: "\n")
  }
}
