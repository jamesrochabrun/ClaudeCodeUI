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

/// A view that displays code edits using the @pierre/diffs JavaScript library.
///
/// This view renders diffs in a WebView with rich syntax highlighting,
/// split/unified view modes, and inline word-level change highlighting.
public struct ClaudeCodeEditsView: View {

  // MARK: - Properties

  let messageID: UUID
  let editTool: EditTool
  let toolParameters: [String: String]
  let terminalService: TerminalService
  let projectPath: String?

  /// Optional callback for when user wants to expand to full-screen
  var onExpandRequest: (() -> Void)?

  /// Shared diff store from parent - required to avoid duplicate processing
  let diffStore: DiffStateManager?

  /// Diff lifecycle state for showing compact views for applied/rejected diffs
  let diffLifecycleState: DiffLifecycleState?

  @State private var isProcessing = false
  @State private var processingError: String?
  @State private var diffStyle: DiffStyle = .unified

  /// Get the active diff store - prefer shared, create local only if necessary
  private var activeDiffStore: DiffStateManager {
    if let shared = diffStore {
      return shared
    }
    // This should rarely happen since parent should provide store
    return DiffStateManager(terminalService: terminalService)
  }

  // MARK: - Initialization

  public init(
    messageID: UUID,
    editTool: EditTool,
    toolParameters: [String: String],
    terminalService: TerminalService,
    projectPath: String? = nil,
    onExpandRequest: (() -> Void)? = nil,
    diffStore: DiffStateManager? = nil,
    diffLifecycleState: DiffLifecycleState? = nil
  ) {
    self.messageID = messageID
    self.editTool = editTool
    self.toolParameters = toolParameters
    self.terminalService = terminalService
    self.projectPath = projectPath
    self.onExpandRequest = onExpandRequest
    self.diffStore = diffStore
    self.diffLifecycleState = diffLifecycleState
  }

  // MARK: - Body

  public var body: some View {
    Group {
      if isProcessing {
        LoadingView()
          .transition(.opacity)
      } else if let error = processingError {
        ErrorView(error: error)
          .transition(.opacity)
      } else {
        let state = activeDiffStore.getState(for: messageID)
        if state == .empty {
          EmptyStateView()
        } else {
          PierreDiffContentView(
            state: state,
            diffStyle: $diffStyle,
            filePath: toolParameters[ParameterKeys.filePath],
            onExpandRequest: onExpandRequest,
            diffLifecycleState: diffLifecycleState
          )
          .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity
          ))
        }
      }
    }
    .animation(.easeInOut(duration: 0.25), value: isProcessing)
    .animation(.easeInOut(duration: 0.25), value: processingError)
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
    VStack(spacing: 12) {
      ProgressView()
        .controlSize(.small)
        .frame(width: 20, height: 20)
      Text("Processing diff...")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, minHeight: 100, idealHeight: 120)
    .fixedSize(horizontal: false, vertical: true)
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

private struct EmptyStateView: View {
  var body: some View {
    Text("No changes to display")
      .foregroundStyle(.secondary)
      .padding()
      .frame(maxWidth: .infinity, minHeight: 100)
  }
}

/// Content view that renders diffs using PierreDiffView (WKWebView + @pierre/diffs)
private struct PierreDiffContentView: View {
  let state: DiffState
  @Binding var diffStyle: DiffStyle
  @State private var overflowMode: OverflowMode = .wrap
  let filePath: String?
  let onExpandRequest: (() -> Void)?
  let diffLifecycleState: DiffLifecycleState?

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header with file info and controls
      headerView

      // Check if diff has been reviewed (collapsed state)
      if let lifecycle = diffLifecycleState,
         !lifecycle.appliedDiffGroupIDs.isEmpty {
        CompactDiffStatusView(
          fileName: filePath ?? "Unknown file",
          timestamp: lifecycle.appliedTimestamps.values.first,
          onTapToExpand: {
            onExpandRequest?()
          }
        )
        .padding()
      } else {
        // Render diff using WebView
        PierreDiffView(
          oldContent: state.diffResult.original,
          newContent: state.diffResult.updated,
          fileName: state.diffResult.fileName,
          diffStyle: $diffStyle,
          overflowMode: $overflowMode,
          onLineClick: { lineNumber, side in
            AppLogger.info("Line clicked: \(lineNumber) on \(side)")
          },
          onExpandRequest: onExpandRequest
        )
        .frame(minHeight: 200)
      }
    }
  }

  private var headerView: some View {
    VStack(alignment: .leading) {
      HStack {
        if let filePath {
          HStack {
            Image(systemName: "doc.text.fill")
              .foregroundStyle(.blue)
            Text(URL(fileURLWithPath: filePath).lastPathComponent)
              .font(.headline)
          }
        }
        Spacer()

        HStack(spacing: 8) {
          // Split/Unified toggle button
          Button {
            diffStyle = diffStyle == .split ? .unified : .split
          } label: {
            Image(systemName: diffStyle == .split ? "rectangle.split.2x1" : "rectangle.stack")
              .font(.system(size: 14))
          }
          .buttonStyle(.plain)
          .help(diffStyle == .split ? "Switch to unified view" : "Switch to split view")

          // Wrap toggle button
          Button {
            overflowMode = overflowMode == .scroll ? .wrap : .scroll
          } label: {
            Image(systemName: overflowMode == .wrap ? "text.justify" : "arrow.left.and.right")
              .font(.system(size: 14))
          }
          .buttonStyle(.plain)
          .help(overflowMode == .wrap ? "Disable word wrap" : "Enable word wrap")

          // Expand button
          if let onExpandRequest {
            Button(action: onExpandRequest) {
              Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            .help("Expand to full screen")
          }
        }
      }
      if let filePath {
        Text(filePath)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.horizontal)
    .padding(.vertical, 12)
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
  private func parseMultiEditEdits(from editsString: String) -> [[String: String]]? {
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
