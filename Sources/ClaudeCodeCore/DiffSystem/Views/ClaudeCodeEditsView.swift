//
//  ClaudeCodeEditsView.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 9/2/25.
//

import CCTerminalServiceInterface
import Foundation
import SwiftUI

/// Tool parameter keys used throughout the view
private enum ParameterKeys {
  static let filePath = "file_path"
  static let oldString = "old_string"
  static let newString = "new_string"
  static let replaceAll = "replace_all"
  static let edits = "edits"
  static let content = "content"
}

public struct ClaudeCodeEditsView: View {
  
  // MARK: - Constants

  let messageID: UUID
  let editTool: EditTool
  let toolParameters: [String: String]
  let terminalService: TerminalService
  let projectPath: String?
  
  /// Optional callback for when user wants to expand to full-screen
  var onExpandRequest: (() -> Void)?
  
  /// Optional shared diff store to avoid reprocessing
  let diffStore: DiffStateManager?
  
  @State private var ownDiffStore: DiffStateManager?
  @State private var isProcessing = false
  @State private var processingError: String?
  @State private var viewMode: DiffViewMode = .grouped
  
  /// Get the active diff store (shared or owned)
  private var activeDiffStore: DiffStateManager {
    diffStore ?? ownDiffStore ?? DiffStateManager(terminalService: terminalService)
  }
  
  /// Display modes for presenting code differences.
  enum DiffViewMode {
    /// Shows changes in grouped sections with context
    case grouped
    /// Shows old and new versions side by side
    case split
  }
  
  public init(
    messageID: UUID,
    editTool: EditTool,
    toolParameters: [String: String],
    terminalService: TerminalService,
    projectPath: String? = nil,
    onExpandRequest: (() -> Void)? = nil,
    diffStore: DiffStateManager? = nil
  ) {
    self.messageID = messageID
    self.editTool = editTool
    self.toolParameters = toolParameters
    self.terminalService = terminalService
    self.projectPath = projectPath
    self.onExpandRequest = onExpandRequest
    self.diffStore = diffStore
    
    // Only create own store if no shared one provided
    if diffStore == nil {
      _ownDiffStore = State(initialValue: DiffStateManager(terminalService: terminalService))
    }
  }
  
  public var body: some View {
    Group {
      if isProcessing {
        LoadingView()
      } else if let error = processingError {
        ErrorView(error: error)
      } else {
        DiffContentView(
          state: activeDiffStore.getState(for: messageID),
          viewMode: $viewMode,
          toolParameters: toolParameters,
          onExpandRequest: onExpandRequest)
      }
    }
    .onAppear {
      let currentState = activeDiffStore.getState(for: messageID)
      let isEmpty = currentState == .empty
      
      // Only process if we don't have a shared store or if the state is empty
      if diffStore == nil || isEmpty {
        Task {
          await processTool()
        }
      }
    }
  }
}

// MARK: - Component Views

private struct LoadingView: View {
  var body: some View {
    VStack {
      ProgressView()
      Text("Processing diff...")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, minHeight: 100)
  }
}

private struct ErrorView: View {
  let error: String
  
  var body: some View {
    VStack {
      Image(systemName: "exclamationmark.triangle")
        .foregroundStyle(.red)
      Text("Error: \(error)")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding()
    .frame(maxWidth: .infinity)
  }
}

private struct DiffContentView: View {
  let state: DiffState
  @Binding var viewMode: ClaudeCodeEditsView.DiffViewMode
  let toolParameters: [String: String]
  let onExpandRequest: (() -> Void)?
  
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HeaderView(
        filePath: toolParameters[ParameterKeys.filePath],
        viewMode: $viewMode,
        onExpandRequest: onExpandRequest
      )
      
      if state.diffGroups.isEmpty {
        Text("No changes to display")
          .foregroundStyle(.secondary)
          .padding()
      } else {
        ScrollView {
          VStack(spacing: 16) {
            ForEach(state.diffGroups) { group in
              DiffGroupView(
                group: group,
                state: state,
                viewMode: viewMode,
                toolParameters: toolParameters
              )
              .padding(.horizontal)
            }
          }
        }
      }
    }
  }
}

private struct HeaderView: View {
  let filePath: String?
  @Binding var viewMode: ClaudeCodeEditsView.DiffViewMode
  let onExpandRequest: (() -> Void)?
  
  var body: some View {
    VStack {
      HStack {
        if let filePath = filePath {
          HStack {
            Image(systemName: "doc.text.fill")
              .foregroundStyle(.blue)
            Text(URL(fileURLWithPath: filePath).lastPathComponent)
              .font(.headline)
          }
        }
        Spacer()
        
        HStack(spacing: 12) {
          // Expand button
          if let onExpandRequest = onExpandRequest {
            Button(action: {
              onExpandRequest()
            }) {
              Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            .help("Expand to full screen")
          }
          
          // View mode picker
          Picker("", selection: $viewMode) {
            Text("Grouped").tag(ClaudeCodeEditsView.DiffViewMode.grouped)
            Text("Split").tag(ClaudeCodeEditsView.DiffViewMode.split)
          }
          .pickerStyle(.segmented)
          .frame(width: 200)
        }
      }
      if let filePath = filePath {
        Text(filePath)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.horizontal)
    .padding(.vertical, 12)
  }
}

private struct DiffGroupView: View {
  let group: DiffTerminalService.DiffGroup
  let state: DiffState
  let viewMode: ClaudeCodeEditsView.DiffViewMode
  let toolParameters: [String: String]
  
  private var isApplied: Bool {
    state.appliedDiffGroupIDs.contains(group.id)
  }
  
  @ViewBuilder
  var body: some View {
    switch viewMode {
    case .split:
      TwoSideReviewPanel(
        group: group,
        isApplied: isApplied)
      
    case .grouped:
      DiffContainerView(
        group: group,
        filePath: toolParameters[ParameterKeys.filePath] ?? "",
        isApplied: isApplied,
        slotContent: {
          VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(group.lines.enumerated()), id: \.offset) { _, line in
              LineView(line: line)
            }
          }
        }
      )
    }
  }
}

// MARK: - Processing

extension ClaudeCodeEditsView {
  
  /// Processes the tool response based on the tool type (edit, multiEdit, or write).
  /// 
  /// This method coordinates the processing of different tool types, creating diff results
  /// and updating the diff store with the processed changes.
  private func processTool() async {
    isProcessing = true
    defer {
      isProcessing = false
    }
    
    let processor = DiffResultProcessor(
      fileDataReader: DefaultFileDataReader(projectPath: projectPath)
    )
    
    let diffResults: [DiffResult]?
    
    switch editTool {
    case .edit:
      diffResults = await processEditTool(processor: processor)
      
    case .multiEdit:
      diffResults = await processMultiEditTool(processor: processor)
      
    case .write:
      diffResults = await processWriteTool(processor: processor)
    }
    
    if let diffResults {
      await activeDiffStore.process(diffs: diffResults, for: messageID)
    } else if processingError == nil {
      processingError = "Failed to process tool response"
    }
  }
  
  /// Processes an Edit tool response to generate diff results.
  ///
  /// Extracts the required parameters (file_path, old_string, new_string) from the tool
  /// parameters and creates a FileEdit object for processing.
  ///
  /// - Parameter processor: The DiffResultProcessor used to process the edit.
  /// - Returns: An array of DiffResult objects if successful, nil if parameters are missing or invalid.
  private func processEditTool(processor: DiffResultProcessor) async -> [DiffResult]? {
    guard
      let filePath = toolParameters[ParameterKeys.filePath],
      let oldString = toolParameters[ParameterKeys.oldString],
      let newString = toolParameters[ParameterKeys.newString]
    else {
      processingError = "Missing required parameters for Edit tool"
      return nil
    }
    
    let fileEdit = FileEdit(
      filePath: filePath,
      edits: nil,
      newString: newString,
      oldString: oldString,
      replaceAll: toolParameters[ParameterKeys.replaceAll] == "true"
    )
    
    guard
      let jsonData = try? JSONEncoder().encode(fileEdit),
      let jsonString = String(data: jsonData, encoding: .utf8)
    else {
      processingError = "Failed to encode Edit parameters"
      return nil
    }
    
    return await processor.processEditTool(
      response: jsonString,
      tool: .edit
    )
  }
  
  /// Processes a MultiEdit tool response to generate diff results.
  ///
  /// Extracts the file path and edits array from the tool parameters, parses the edits
  /// into structured Edit objects, and creates a FileEdit object for processing.
  ///
  /// - Parameter processor: The DiffResultProcessor used to process the edits.
  /// - Returns: An array of DiffResult objects if successful, nil if parameters are missing or invalid.
  private func processMultiEditTool(processor: DiffResultProcessor) async -> [DiffResult]? {
    guard
      let filePath = toolParameters[ParameterKeys.filePath],
      let editsString = toolParameters[ParameterKeys.edits],
      let editsArray = parseMultiEditEdits(from: editsString)
    else {
      processingError = "Missing or invalid parameters for MultiEdit tool"
      return nil
    }
    
    let edits = editsArray.map { dict in
      Edit(
        newString: dict[ParameterKeys.newString] ?? "",
        oldString: dict[ParameterKeys.oldString] ?? "",
        replaceAll: dict[ParameterKeys.replaceAll] == "true"
      )
    }
    
    let fileEdit = FileEdit(
      filePath: filePath,
      edits: edits,
      newString: nil,
      oldString: nil,
      replaceAll: nil
    )
    
    guard
      let jsonData = try? JSONEncoder().encode(fileEdit),
      let jsonString = String(data: jsonData, encoding: .utf8)
    else {
      processingError = "Failed to encode MultiEdit parameters"
      return nil
    }
    
    return await processor.processEditTool(
      response: jsonString,
      tool: .multiEdit
    )
  }
  
  /// Processes a Write tool response to generate diff results.
  ///
  /// Extracts the file path and content from the tool parameters and creates
  /// a FileContent object for processing. This handles creating or overwriting files.
  ///
  /// - Parameter processor: The DiffResultProcessor used to process the write operation.
  /// - Returns: An array of DiffResult objects if successful, nil if parameters are missing or invalid.
  private func processWriteTool(processor: DiffResultProcessor) async -> [DiffResult]? {
    guard
      let filePath = toolParameters[ParameterKeys.filePath],
      let content = toolParameters[ParameterKeys.content]
    else {
      processingError = "Missing required parameters for Write tool"
      return nil
    }
    
    let fileContent = FileContent(content: content, filePath: filePath)
    
    guard
      let jsonData = try? JSONEncoder().encode(fileContent),
      let jsonString = String(data: jsonData, encoding: .utf8)
    else {
      processingError = "Failed to encode Write parameters"
      return nil
    }
    
    return await processor.processEditTool(
      response: jsonString,
      tool: .write
    )
  }
  
  /// Parses a JSON string containing multiple edit operations into a dictionary array.
  ///
  /// Converts a JSON string representing an array of edit objects into a Swift array
  /// of dictionaries. Handles both string and boolean values, converting booleans to
  /// string representations ("true"/"false").
  ///
  /// - Parameter editsString: A JSON string containing an array of edit objects.
  /// - Returns: An array of dictionaries with string keys and values, or nil if parsing fails.
  private func parseMultiEditEdits(from editsString: String) -> [[String: String]]? {
    // Try to parse as JSON array first
    if let data = editsString.data(using: .utf8),
       let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
      return json.compactMap { dict in
        var result = [String: String]()
        for (key, value) in dict {
          if let stringValue = value as? String {
            result[key] = stringValue
          } else if let boolValue = value as? Bool {
            result[key] = boolValue ? "true" : "false"
          }
        }
        return result.isEmpty ? nil : result
      }
    }
    
    return nil
  }
}

