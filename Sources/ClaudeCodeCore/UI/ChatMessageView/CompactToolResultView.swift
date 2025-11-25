//
//  CompactToolResultView.swift
//  ClaudeCodeUI
//
//  Created on 2025.
//

import SwiftUI

/// A compact, minimal view for displaying tool calls and results
/// Mimics the Claude Code CLI style with colored dots and inline content
struct CompactToolResultView: View {

  let message: ChatMessage
  let fontSize: Double

  private let toolRegistry = ToolRegistry.shared
  private let formatter = ToolDisplayFormatter()

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      // Main tool line with dot indicator
      mainToolLine

      // Optional sub-line with preview content (for .preview style)
      previewLine
    }
  }

  // MARK: - Main Tool Line

  private var mainToolLine: some View {
    HStack(alignment: .center, spacing: 8) {
      // Colored dot indicator
      Circle()
        .fill(statusColor)
        .frame(width: 8, height: 8)

      // Tool name and parameters
      toolLabel

      Spacer()
    }
    .padding(.vertical, 2)
  }

  private var toolLabel: some View {
    HStack(spacing: 4) {
      // Tool name (bold)
      Text(toolName)
        .font(.system(size: fontSize, weight: .semibold, design: .monospaced))
        .foregroundStyle(.primary)

      // Key parameter or summary (regular)
      if let paramText = keyParameterText {
        Text(paramText)
          .font(.system(size: fontSize, design: .monospaced))
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      // Compact summary for results (e.g., "Read 100 lines")
      if message.messageType == .toolResult, let summary = compactSummary {
        Text(summary)
          .font(.system(size: fontSize - 1, design: .monospaced))
          .foregroundStyle(.tertiary)
      }
    }
  }

  // MARK: - Preview Line (for .preview display style)

  @ViewBuilder
  private var previewLine: some View {
    if let tool = tool,
       tool.displayStyle == .preview,
       message.messageType == .toolResult,
       let preview = previewContent {
      HStack(alignment: .top, spacing: 8) {
        // Connector line
        Text("└")
          .font(.system(size: fontSize, design: .monospaced))
          .foregroundStyle(.tertiary)
          .frame(width: 8)

        // Preview content
        VStack(alignment: .leading, spacing: 0) {
          Text(preview.preview)
            .font(.system(size: fontSize - 1, design: .monospaced))
            .foregroundStyle(.secondary)
            .lineLimit(3)

          // Remaining lines indicator
          if preview.remainingLines > 0 {
            Text("... +\(preview.remainingLines) lines")
              .font(.system(size: fontSize - 1, design: .monospaced))
              .foregroundStyle(.tertiary)
          }
        }
      }
      .padding(.leading, 0)
    }
  }

  // MARK: - Computed Properties

  private var tool: ToolType? {
    guard let toolName = message.toolName else { return nil }
    return toolRegistry.tool(for: toolName)
  }

  private var toolName: String {
    tool?.identifier ?? message.toolName ?? "Tool"
  }

  private var statusColor: Color {
    switch message.messageType {
    case .toolUse:
      return .brandPrimary
    case .toolResult:
      return .brandTertiary
    case .toolError:
      return .red
    case .toolDenied:
      return .orange
    default:
      return .secondary
    }
  }

  private var keyParameterText: String? {
    guard let toolName = message.toolName else { return nil }

    if let toolInputData = message.toolInputData {
      let header = formatter.toolRequestHeader(toolName: toolName, toolInputData: toolInputData)
      // Extract just the parameters part (after the tool name)
      let content = header.formattedContent
      if content.contains("(") {
        // Remove tool name prefix and parentheses
        let start = content.firstIndex(of: "(").map { content.index(after: $0) }
        let end = content.lastIndex(of: ")")
        if let start = start, let end = end {
          return String(content[start..<end])
        }
      }
    }

    return nil
  }

  private var compactSummary: String? {
    guard let tool = tool else { return nil }

    // Get the appropriate formatter for this tool
    let toolFormatter = formatterFor(tool: tool)
    return toolFormatter.compactSummary(message.content, tool: tool)
  }

  private var previewContent: (preview: String, remainingLines: Int)? {
    guard let tool = tool else { return nil }

    let toolFormatter = formatterFor(tool: tool)
    return toolFormatter.previewContent(message.content, tool: tool, maxLines: 2)
  }

  private func formatterFor(tool: ToolType) -> ToolFormatterProtocol {
    switch ClaudeCodeTool(rawValue: tool.identifier) {
    case .bash:
      return BashToolFormatter()
    case .read, .write, .ls:
      return FileToolFormatter()
    case .grep, .glob:
      return SearchFormatter()
    case .webFetch, .webSearch:
      return WebToolFormatter()
    default:
      return PlainTextToolFormatter()
    }
  }
}

// MARK: - Preview

#Preview {
  VStack(alignment: .leading, spacing: 8) {
    // Compact style (Grep)
    CompactToolResultView(
      message: ChatMessage(
        role: .assistant,
        content: "",
        messageType: .toolUse,
        toolName: "Grep",
        toolInputData: ToolInputData(parameters: ["pattern": "timeout|wait|delay"])
      ),
      fontSize: 13
    )

    // Preview style (Bash)
    CompactToolResultView(
      message: ChatMessage(
        role: .assistant,
        content: "/path/to/file1.swift\n/path/to/file2.swift\n/path/to/file3.swift\nmore output here\nand more\nand even more",
        messageType: .toolResult,
        toolName: "Bash",
        toolInputData: ToolInputData(parameters: ["command": "find . -name \"*.swift\""])
      ),
      fontSize: 13
    )

    // Preview style (Read)
    CompactToolResultView(
      message: ChatMessage(
        role: .assistant,
        content: String(repeating: "line\n", count: 100),
        messageType: .toolResult,
        toolName: "Read",
        toolInputData: ToolInputData(parameters: ["file_path": "/path/to/ConversationManager.swift"])
      ),
      fontSize: 13
    )
  }
  .padding()
  .frame(width: 600)
}
