import SwiftUI
import TerminalServiceInterface

struct MessageContentView: View {
  let message: ChatMessage
  let textFormatter: TextFormatter
  let fontSize: Double
  let horizontalPadding: CGFloat
  let maxWidth: CGFloat
  let terminalService: TerminalService
  
  @Environment(\.colorScheme) private var colorScheme
  
  private var isCollapsible: Bool {
    switch message.messageType {
    case .toolUse, .toolResult, .toolError, .thinking, .webSearch:
      return true
    case .text:
      return false
    }
  }
  
  var body: some View {
    contentView
  }
  
  @ViewBuilder
  private var contentView: some View {
    if isCollapsible {
      collapsibleContent
    } else if message.role == .assistant && message.messageType == .text {
      // Use formatted text for assistant messages
      MessageTextFormatterView(
        textFormatter: textFormatter,
        message: message,
        fontSize: fontSize,
        horizontalPadding: horizontalPadding,
        maxWidth: maxWidth
      )
    } else {
      // Use plain text for other messages
      plainTextContent
    }
  }
  
  @ViewBuilder
  private var collapsibleContent: some View {
    // Check if this is an Edit tool message with diff data
    if message.messageType == .toolUse &&
        message.toolName == "Edit",
       let rawParams = message.toolInputData?.rawParameters,
       let oldString = rawParams["old_string"],
       let newString = rawParams["new_string"],
       let filePath = rawParams["file_path"] {
      // Show diff view for Edit tool
      EditToolDiffView(
        oldString: oldString,
        newString: newString,
        filePath: filePath,
        fontSize: fontSize,
        contentTextColor: contentTextColor,
        terminalService: terminalService
      )
    } else {
      // For other collapsible messages (tool use, thinking, etc.), show plain text
      Text(message.content)
        .font(.system(size: fontSize - 1, design: .monospaced))
        .foregroundColor(contentTextColor)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }
  }
  
  @ViewBuilder
  private var plainTextContent: some View {
    let displayContent = message.role == .user && !message.content.isEmpty ? "> \(message.content)" : message.content
    Text(displayContent)
      .textSelection(.enabled)
      .font(messageFont)
      .padding(.horizontal, horizontalPadding)
      .padding(.vertical, 8)
  }
  
  private var messageFont: SwiftUI.Font {
    guard (message.role == .user || message.role == .assistant) else {
      return .system(size: fontSize, weight: colorScheme == .dark ? .ultraLight : .light, design: .monospaced)
    }
    return SwiftUI.Font.system(.body)
  }
  
  private var contentTextColor: SwiftUI.Color {
    colorScheme == .dark ? .white : SwiftUI.Color.black.opacity(0.85)
  }
}
