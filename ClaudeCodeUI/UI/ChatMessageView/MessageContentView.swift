import SwiftUI
import TerminalServiceInterface

/// A view that renders the content of a chat message with appropriate formatting based on the message type.
///
/// This view handles different message types including:
/// - Plain text messages from users and assistants
/// - Tool usage messages (Edit, MultiEdit, etc.) with specialized diff views
/// - Tool results and errors
/// - Thinking messages
/// - Web search results
///
/// The view automatically selects the appropriate rendering strategy:
/// - Collapsible content for tool-related messages
/// - Formatted text for assistant responses
/// - Plain text for user messages
/// - Specialized diff views for Edit and MultiEdit tools
///
/// ## Usage Example
/// ```swift
/// MessageContentView(
///     message: chatMessage,
///     textFormatter: TextFormatter(),
///     fontSize: 14.0,
///     horizontalPadding: 16.0,
///     maxWidth: 600.0,
///     terminalService: terminalService
/// )
/// ```
struct MessageContentView: View {
  /// The chat message to display.
  /// Contains the message content, role (user/assistant/system), type (text/toolUse/toolResult/etc),
  /// and associated metadata such as tool parameters and results.
  let message: ChatMessage
  
  /// Text formatter for rendering markdown and code blocks.
  /// Handles syntax highlighting, code block formatting, inline code,
  /// links, emphasis, and other markdown elements in assistant messages.
  let textFormatter: TextFormatter
  
  /// Base font size for message content in points.
  /// This value is used as the foundation for all text rendering,
  /// with relative adjustments made for headers, code blocks, etc.
  let fontSize: Double
  
  /// Horizontal padding applied to message content.
  /// Creates consistent spacing between the message content and container edges.
  /// Typically ranges from 12-20 points depending on the UI design.
  let horizontalPadding: CGFloat
  
  /// Optional callback to show artifacts like Mermaid diagrams
  let showArtifact: ((Artifact) -> Void)?
  
  /// Maximum width constraint for the message content.
  /// Prevents messages from becoming too wide on large screens,
  /// ensuring optimal readability. Usually set based on the container width.
  let maxWidth: CGFloat
  
  /// Terminal service for executing commands in diff views.
  /// Used by EditToolDiffView and MultiEditToolDiffView to apply changes
  /// when users click "Apply" buttons in the diff interface.
  let terminalService: TerminalService
  
  /// Current color scheme for adaptive styling.
  /// Used to adjust text colors and font weights for optimal readability
  /// in both light and dark modes.
  @Environment(\.colorScheme) private var colorScheme
  
  /// Parses the edits string from MultiEdit tool parameters
  private func parseMultiEditEdits(from editsString: String) -> [[String: String]]? {
    guard let editsData = editsString.data(using: .utf8) else { return nil }
    
    do {
      if let parsed = try JSONSerialization.jsonObject(with: editsData) as? [[String: Any]] {
        // Convert to [[String: String]]
        return parsed.compactMap { dict in
          var stringDict: [String: String] = [:]
          for (key, value) in dict {
            if let stringValue = value as? String {
              stringDict[key] = stringValue
            }
          }
          return stringDict.isEmpty ? nil : stringDict
        }
      }
    } catch {
      print("DEBUG: Failed to parse edits as JSON:", error)
    }
    
    return nil
  }
  
  /// Determines if the message type should be displayed in a collapsible format.
  /// Tool-related messages (toolUse, toolResult, toolError, thinking, webSearch) are collapsible,
  /// while plain text messages are not.
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
        maxWidth: maxWidth,
        showArtifact: showArtifact
      )
    } else {
      // Use plain text for other messages
      plainTextContent
    }
  }
  
  @ViewBuilder
  private var collapsibleContent: some View {
    // Check if this is an Edit or MultiEdit tool message with diff data
    if message.messageType == .toolUse,
       let rawParams = message.toolInputData?.rawParameters {
      
      switch message.toolName {
      case "Edit":
        // Extract Edit tool parameters for diff view
        if let oldString = rawParams["old_string"],
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
          defaultToolDisplay
        }
        
      case "MultiEdit":
        // Extract MultiEdit tool parameters
        if let filePath = rawParams["file_path"],
           let editsString = rawParams["edits"] {
          
          let _ = print("DEBUG: MultiEdit rawParams:", rawParams)
          let _ =  print("DEBUG: edits string:", editsString)
          
          // Parse the edits array from JSON string
          if let editsArray = parseMultiEditEdits(from: editsString), !editsArray.isEmpty {
            // Show diff view for MultiEdit tool
            MultiEditToolDiffView(
              edits: editsArray,
              filePath: filePath,
              fontSize: fontSize,
              contentTextColor: contentTextColor,
              terminalService: terminalService
            )
          } else {
            let _ =  print("DEBUG: Failed to parse edits or empty array, falling back to default display")
            defaultToolDisplay
          }
        } else {
          defaultToolDisplay
        }
        
      case "Write":
        // Extract Write tool parameters
        if let filePath = rawParams["file_path"],
           let content = rawParams["content"] {
          // Show formatted content view for Write tool
          WriteToolContentView(
            content: content,
            filePath: filePath,
            fontSize: fontSize,
            textFormatter: textFormatter,
            maxWidth: maxWidth
          )
        } else {
          defaultToolDisplay
        }
        
      default:
        defaultToolDisplay
      }
    } else {
      defaultToolDisplay
    }
  }
  
  /// Default display for tool messages that don't have specialized views.
  /// Uses ToolDisplayView for consistent formatting of tool parameters and results.
  @ViewBuilder
  private var defaultToolDisplay: some View {
    // Use the new ToolDisplayView for sophisticated formatting
    ToolDisplayView(
      message: message,
      fontSize: fontSize,
      textFormatter: textFormatter
    )
  }
  
  @ViewBuilder
  private var plainTextContent: some View {
    VStack(alignment: .leading, spacing: 0) {
      let displayContent = message.role == .user && !message.content.isEmpty ? "> \(message.content)" : message.content
      Text(displayContent)
        .textSelection(.enabled)
        .font(messageFont)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, 8)
      
      // Show cancelled indicator if message was cancelled
      if message.wasCancelled {
        HStack {
          Text("Interrupted by user")
            .font(.system(size: fontSize - 1))
            .foregroundColor(.red)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 8)
        }
      }
    }
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
