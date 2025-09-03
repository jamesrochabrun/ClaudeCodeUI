//
//  ClaudeCodeEditsView.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 9/2/25.
//

import CCTerminalServiceInterface
import Foundation
import SwiftUI

public struct ClaudeCodeEditsView: View {
  let messageID: UUID
  let editTool: EditTool
  let toolParameters: [String: String]
  let terminalService: TerminalService
  let projectPath: String?
  
  @State private var diffStore: DiffStateManager
  @State private var isProcessing = false
  @State private var processingError: String?
  @State private var viewMode: DiffViewMode = .grouped
  
  enum DiffViewMode {
    case grouped
    case split
    case inline
  }
  
  public init(
    messageID: UUID,
    editTool: EditTool,
    toolParameters: [String: String],
    terminalService: TerminalService,
    projectPath: String? = nil
  ) {
    self.messageID = messageID
    self.editTool = editTool
    self.toolParameters = toolParameters
    self.terminalService = terminalService
    self.projectPath = projectPath
    _diffStore = State(initialValue: DiffStateManager(terminalService: terminalService))
  }
  
  public var body: some View {
    Group {
      if isProcessing {
        LoadingView()
      } else if let error = processingError {
        ErrorView(error: error)
      } else {
        DiffContentView(
          state: diffStore.getState(for: messageID),
          viewMode: $viewMode,
          toolParameters: toolParameters)
      }
    }
    .onAppear {
      Task {
        await processTool()
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
  
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HeaderView(
        filePath: toolParameters["file_path"],
        viewMode: $viewMode
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
        Picker("", selection: $viewMode) {
          Text("Grouped").tag(ClaudeCodeEditsView.DiffViewMode.grouped)
          Text("Split").tag(ClaudeCodeEditsView.DiffViewMode.split)
          Text("Inline").tag(ClaudeCodeEditsView.DiffViewMode.inline)
        }
        .pickerStyle(.segmented)
        .frame(width: 200)
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
        filePath: toolParameters["file_path"] ?? "",
        isApplied: isApplied,
        slotContent: {
          VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(group.lines.enumerated()), id: \.offset) { _, line in
              LineView(line: line)
            }
          }
        }
      )
      
    case .inline:
      VStack(alignment: .leading, spacing: 0) {
        ForEach(Array(group.lines.enumerated()), id: \.offset) { _, line in
          LineView(line: line)
        }
      }
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(isApplied ? Color.green.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 1)
      )
    }
  }
}

// MARK: - Processing

extension ClaudeCodeEditsView {
  
  private func processTool() async {
    isProcessing = true
    defer { isProcessing = false }
    
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
      await diffStore.process(diffs: diffResults, for: messageID)
    } else if processingError == nil {
      processingError = "Failed to process tool response"
    }
  }
  
  private func processEditTool(processor: DiffResultProcessor) async -> [DiffResult]? {
    guard
      let filePath = toolParameters["file_path"],
      let oldString = toolParameters["old_string"],
      let newString = toolParameters["new_string"]
    else {
      processingError = "Missing required parameters for Edit tool"
      return nil
    }
    
    let fileEdit = FileEdit(
      filePath: filePath,
      edits: nil,
      newString: newString,
      oldString: oldString,
      replaceAll: toolParameters["replace_all"] == "true"
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
  
  private func processMultiEditTool(processor: DiffResultProcessor) async -> [DiffResult]? {
    guard
      let filePath = toolParameters["file_path"],
      let editsString = toolParameters["edits"],
      let editsArray = parseMultiEditEdits(from: editsString)
    else {
      processingError = "Missing or invalid parameters for MultiEdit tool"
      return nil
    }
    
    let edits = editsArray.map { dict in
      Edit(
        newString: dict["new_string"] ?? "",
        oldString: dict["old_string"] ?? "",
        replaceAll: dict["replace_all"] == "true"
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
  
  private func processWriteTool(processor: DiffResultProcessor) async -> [DiffResult]? {
    guard
      let filePath = toolParameters["file_path"],
      let content = toolParameters["content"]
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

