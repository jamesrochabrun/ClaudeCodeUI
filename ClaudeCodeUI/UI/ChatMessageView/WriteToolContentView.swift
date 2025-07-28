import SwiftUI

/// A view that displays the content of a Write tool operation with markdown formatting
struct WriteToolContentView: View {
  let content: String
  let filePath: String
  let fontSize: Double
  let textFormatter: TextFormatter
  let maxWidth: CGFloat
  
  @Environment(\.colorScheme) private var colorScheme
  
  private var contentFormatter: TextFormatter {
    let formatter = TextFormatter(projectRoot: URL(fileURLWithPath: filePath).deletingLastPathComponent())
    let markdownContent = wrapInCodeBlockIfNeeded(content)
    formatter.ingest(delta: markdownContent)
    return formatter
  }
  
  private var formattedMessage: ChatMessage {
    let markdownContent = wrapInCodeBlockIfNeeded(content)
    return ChatMessage(
      role: .assistant,
      content: markdownContent,
      messageType: .text
    )
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Header with file info
      headerView
      
      // Content with markdown formatting
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          MessageTextFormatterView(
            textFormatter: contentFormatter,
            message: formattedMessage,
            fontSize: fontSize - 1,
            horizontalPadding: 12,
            maxWidth: maxWidth
          )
          .padding(.vertical, 8)
          .background(
            RoundedRectangle(cornerRadius: 8)
              .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.05))
          )
          .overlay(
            RoundedRectangle(cornerRadius: 8)
              .stroke(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
          )
        }
        .padding(.horizontal, 12)
      }
      .frame(maxHeight: 400) // Limit height for long files
    }
    .background(Color(NSColor.controlBackgroundColor))
    .cornerRadius(12)
  }
  
  private func wrapInCodeBlockIfNeeded(_ content: String) -> String {
    let fileExtension = URL(fileURLWithPath: filePath).pathExtension.lowercased()
    
    // Check if it's already wrapped in markdown code block
    if content.hasPrefix("```") {
      return content
    }
    
    // Get language identifier for syntax highlighting
    let language = languageIdentifier(for: fileExtension)
    
    // Wrap in code block with language identifier
    if !language.isEmpty {
      return "```\(language)\n\(content)\n```"
    } else {
      // For unknown file types, just wrap in plain code block
      return "```\n\(content)\n```"
    }
  }
  
  private func languageIdentifier(for fileExtension: String) -> String {
    switch fileExtension {
    case "swift":
      return "swift"
    case "js", "javascript":
      return "javascript"
    case "ts", "typescript":
      return "typescript"
    case "py", "python":
      return "python"
    case "rb", "ruby":
      return "ruby"
    case "go":
      return "go"
    case "rs", "rust":
      return "rust"
    case "java":
      return "java"
    case "cpp", "cc", "cxx":
      return "cpp"
    case "c":
      return "c"
    case "h", "hpp":
      return "cpp"
    case "cs":
      return "csharp"
    case "php":
      return "php"
    case "html", "htm":
      return "html"
    case "css":
      return "css"
    case "scss", "sass":
      return "scss"
    case "json":
      return "json"
    case "xml":
      return "xml"
    case "yaml", "yml":
      return "yaml"
    case "sh", "bash", "zsh":
      return "bash"
    case "sql":
      return "sql"
    case "md", "markdown":
      return "markdown"
    default:
      return ""
    }
  }
  
  private var headerView: some View {
    HStack {
      Image(systemName: "doc.text.fill")
        .foregroundStyle(.blue)
      
      VStack(alignment: .leading, spacing: 2) {
        Text(URL(fileURLWithPath: filePath).lastPathComponent)
          .font(.system(size: fontSize, weight: .medium))
        
        Text(URL(fileURLWithPath: filePath).deletingLastPathComponent().path)
          .font(.system(size: fontSize - 2))
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
      }
      
      Spacer()
      
      // File size indicator (if we had the actual size)
      Label("Write", systemImage: "square.and.pencil")
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.green.opacity(0.1))
        .cornerRadius(6)
    }
    .padding(12)
  }
}

// MARK: - Preview

#Preview {
  WriteToolContentView(
    content: """
    # Example File
    
    This is some example content with **markdown** formatting.
    
    ```swift
    func hello() {
        print("Hello, World!")
    }
    ```
    
    - Item 1
    - Item 2
    - Item 3
    """,
    filePath: "/Users/example/Documents/test.swift",
    fontSize: 13,
    textFormatter: TextFormatter(projectRoot: nil),
    maxWidth: 600
  )
  .frame(width: 600)
  .padding()
}
