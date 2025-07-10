//
//  ToolDisplayView.swift
//  ClaudeCodeUI
//
//  Created on 1/9/2025.
//

import SwiftUI

/// Enhanced view for displaying tool interactions with sophisticated formatting
struct ToolDisplayView: View {
  let message: ChatMessage
  let fontSize: Double
  let textFormatter: TextFormatter
  @State private var isCopied = false
  @Environment(\.colorScheme) private var colorScheme
  
  private let formatter = ToolDisplayFormatter()
  private let todoFormatter = TodoFormatter()
  private let shellFormatter = ShellFormatter()
  private let codeFormatter = CodeFormatter()
  private let searchFormatter = SearchFormatter()
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if let formattedContent = formatContent() {
        contentView(for: formattedContent)
      } else {
        fallbackView
      }
    }
  }
  
  @ViewBuilder
  private func contentView(for content: ToolDisplayFormatter.ToolContentFormatter) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      // Tool header with icon
      HStack {
        toolIcon(for: content.toolType)
          .font(.system(size: 14))
          .foregroundStyle(iconColor(for: content))
        
        Text(content.toolType?.friendlyName ?? content.toolName)
          .font(.system(size: fontSize - 1, weight: .medium))
          .foregroundStyle(.primary)
        
        Spacer()
        
        // Copy button for non-error content
        if !content.isError && !content.formattedContent.isEmpty {
          copyButton(for: content.formattedContent)
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(headerBackground(for: content))
      .clipShape(RoundedRectangle(cornerRadius: 6))
      
      // Formatted content
      formattedContentView(for: content)
        .padding(.horizontal, 4)
    }
  }
  
  @ViewBuilder
  private func formattedContentView(for content: ToolDisplayFormatter.ToolContentFormatter) -> some View {
    switch content.contentType {
    case .markdown:
      // Use the existing markdown formatter view
      // Markdown content is rendered using MessageTextFormatterView
      MessageTextFormatterView(
        textFormatter: createMarkdownTextFormatter(for: content.formattedContent),
        message: ChatMessage(
          role: .assistant,
          content: content.formattedContent,
          messageType: .text
        ),
        fontSize: fontSize,
        horizontalPadding: 0,
        maxWidth: .infinity
      )
      
    // Code, shell, and JSON are now handled by markdown renderer
      
    case .todos:
      todoListView(content.formattedContent)
      
    case .searchResults:
      searchResultsView(content.formattedContent)
      
    case .diff:
      // Diff view is handled separately in MessageContentView
      formattedTextView(content.formattedContent)
      
    case .error:
      errorView(content.formattedContent)
      
    case .plainText:
      formattedTextView(content.formattedContent)
    }
  }
  
  // MARK: - Content Type Views
  
  // Code, shell, and JSON views removed - now handled by markdown renderer
  
  @ViewBuilder
  private func todoListView(_ content: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      ForEach(content.components(separatedBy: .newlines), id: \.self) { line in
        if !line.isEmpty {
          HStack(spacing: 8) {
            if line.contains("[x]") || line.contains("[✓]") {
              Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 12))
            } else if line.contains("[ ]") {
              Image(systemName: "circle")
                .foregroundStyle(.secondary)
                .font(.system(size: 12))
            }
            
            Text(line.replacingOccurrences(of: "- [x]", with: "")
              .replacingOccurrences(of: "- [ ]", with: "")
              .replacingOccurrences(of: "- [✓]", with: "")
              .trimmingCharacters(in: .whitespaces))
              .font(.system(size: fontSize - 1))
              .strikethrough(line.contains("[x]") || line.contains("[✓]"))
              .foregroundStyle(line.contains("[x]") || line.contains("[✓]") ? .secondary : .primary)
          }
        }
      }
    }
    .padding(12)
    .background(Color.secondary.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
  
  @ViewBuilder
  private func searchResultsView(_ content: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(content)
        .font(.system(size: fontSize - 1))
        .foregroundStyle(contentTextColor)
        .textSelection(.enabled)
    }
    .padding(12)
    .background(Color.secondary.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
  
  @ViewBuilder
  private func errorView(_ content: String) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 16))
        .foregroundStyle(.red)
      
      Text(content)
        .font(.system(size: fontSize - 1))
        .foregroundStyle(.red)
        .textSelection(.enabled)
    }
    .padding(12)
    .background(Color.red.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
    )
  }
  
  @ViewBuilder
  private func formattedTextView(_ content: String) -> some View {
    Text(content)
      .font(.system(size: fontSize - 1, design: .monospaced))
      .foregroundStyle(contentTextColor)
      .textSelection(.enabled)
      .padding(12)
      .background(Color.secondary.opacity(0.1))
      .clipShape(RoundedRectangle(cornerRadius: 8))
  }
  
  // MARK: - Fallback View
  
  @ViewBuilder
  private var fallbackView: some View {
    Text(message.content)
      .font(.system(size: fontSize - 1, design: .monospaced))
      .foregroundStyle(contentTextColor)
      .padding(12)
      .background(Color.secondary.opacity(0.1))
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .textSelection(.enabled)
  }
  
  // MARK: - Helper Methods
  
  private func formatContent() -> ToolDisplayFormatter.ToolContentFormatter? {
    switch message.messageType {
    case .toolUse:
      guard let toolName = message.toolName else { return nil }
      
      // Extract arguments from content or toolInputData
      let arguments = extractArguments()
      
      return formatter.toolResponseMessage(
        toolName: toolName,
        arguments: arguments,
        result: message.content,
        isError: false
      )
      
    case .toolResult:
      guard let toolName = message.toolName else { return nil }
      
      let result = formatter.toolResponseMessage(
        toolName: toolName,
        arguments: "",
        result: message.content,
        isError: false
      )
      
      return result
      
    case .toolError:
      guard let toolName = message.toolName else { return nil }
      
      return formatter.toolResponseMessage(
        toolName: toolName,
        arguments: "",
        result: message.content,
        isError: true
      )
      
    default:
      return nil
    }
  }
  
  private func extractArguments() -> String {
    if let toolInputData = message.toolInputData {
      // Convert parameters to JSON
      if let data = try? JSONSerialization.data(withJSONObject: toolInputData.parameters, options: .prettyPrinted),
               let json = String(data: data, encoding: .utf8) {
        return json
      }
    }
    
    // Try to extract from content
    if let startIndex = message.content.firstIndex(of: "{"),
           let endIndex = message.content.lastIndex(of: "}") {
      return String(message.content[startIndex...endIndex])
    }
    
    return ""
  }
  
  private func toolIcon(for toolType: ToolType?) -> some View {
    Image(systemName: toolType?.icon ?? "hammer")
  }
  
  private func iconColor(for content: ToolDisplayFormatter.ToolContentFormatter) -> Color {
    if content.isError {
      return .red
    }
    
    switch message.messageType {
    case .toolUse:
      return .bookCloth
    case .toolResult:
      return .manilla
    case .toolError:
      return .red
    default:
      return .secondary
    }
  }
  
  private func headerBackground(for content: ToolDisplayFormatter.ToolContentFormatter) -> some View {
    Group {
      if content.isError {
        Color.red.opacity(0.1)
      } else {
        Color.secondary.opacity(0.1)
      }
    }
  }
  
  @ViewBuilder
  private func copyButton(for content: String) -> some View {
    Button(action: {
      copyToClipboard(content)
    }) {
      Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
        .font(.system(size: 12))
        .foregroundStyle(isCopied ? .green : .secondary)
    }
    .buttonStyle(.plain)
  }
  
  private func copyToClipboard(_ text: String) {
    #if os(macOS)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    #endif
    
    isCopied = true
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      isCopied = false
    }
  }
  
  private var contentTextColor: Color {
    colorScheme == .dark ? .white : Color.black.opacity(0.85)
  }
  
  private var codeBackground: Color {
    colorScheme == .dark ? Color.black.opacity(0.3) : Color.secondary.opacity(0.1)
  }
  
  private func createMarkdownTextFormatter(for content: String) -> TextFormatter {
    let formatter = TextFormatter(projectRoot: nil)
    formatter.ingest(delta: content)
    return formatter
  }
}