import SwiftUI
import CCTerminalServiceInterface

// MARK: - JSON Keys
private enum JSONKeys {
  static let filePath = "file_path"
  static let oldString = "old_string"
  static let newString = "new_string"
  static let edits = "edits"
  static let content = "content"
}

/// Data for presenting the diff modal
struct DiffModalData: Identifiable {
  let id = UUID()
  let messageID: UUID
  let tool: EditTool
  let params: [String: String]
}

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
/// A loading view specifically for diff tools with consistent styling
private struct DiffLoadingView: View {
  var body: some View {
    VStack(spacing: 12) {
      ProgressView()
      Text("Preparing diff view...")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding()
  }
}

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
  
  /// The project path for file operations
  let projectPath: String?
  
  /// Optional callback when approval/denial action occurs
  let onApprovalAction: (() -> Void)?
  
  /// Current color scheme for adaptive styling.
  /// Used to adjust text colors and font weights for optimal readability
  /// in both light and dark modes.
  @Environment(\.colorScheme) private var colorScheme
  
  /// Data for the modal diff view - when non-nil, shows the modal
  @State private var modalDiffData: DiffModalData?
  
  /// Single diff state manager for this message
  @State private var diffStateManager: DiffStateManager?
  
  /// Tracks whether the diff manager is ready for use
  @State private var isDiffManagerReady = false
  
  /// Creates a new message content view with the specified configuration.
  ///
  /// - Parameters:
  ///   - message: The chat message to display, containing content, role, and metadata
  ///   - textFormatter: Formatter for rendering markdown and code blocks with syntax highlighting
  ///   - fontSize: Base font size in points for message text
  ///   - horizontalPadding: Padding between message content and container edges
  ///   - showArtifact: Optional callback to display artifacts like Mermaid diagrams
  ///   - maxWidth: Maximum width constraint to ensure readable line lengths
  ///   - terminalService: Service for executing terminal commands in diff views
  ///   - projectPath: Optional path to the project root for file operations
  ///   - onApprovalAction: Optional callback invoked when approval/denial actions occur
  init(
    message: ChatMessage,
    textFormatter: TextFormatter,
    fontSize: Double,
    horizontalPadding: CGFloat,
    showArtifact: ((Artifact) -> Void)?,
    maxWidth: CGFloat,
    terminalService: TerminalService,
    projectPath: String?,
    onApprovalAction: (() -> Void)? = nil
  ) {
    self.message = message
    self.textFormatter = textFormatter
    self.fontSize = fontSize
    self.horizontalPadding = horizontalPadding
    self.showArtifact = showArtifact
    self.maxWidth = maxWidth
    self.terminalService = terminalService
    self.projectPath = projectPath
    self.onApprovalAction = onApprovalAction
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
      .sheet(item: $modalDiffData) { data in
        DiffModalView(
          messageID: data.messageID,
          editTool: data.tool,
          toolParameters: data.params,
          terminalService: terminalService,
          projectPath: projectPath,
          diffStore: diffStateManager ?? DiffStateManager(terminalService: terminalService),
          onDismiss: {
            modalDiffData = nil
          }
        )
        .task {
          if diffStateManager == nil {
            diffStateManager = DiffStateManager(terminalService: terminalService)
            withAnimation(.easeInOut(duration: 0.3)) {
              isDiffManagerReady = true
            }
          }
        }
      }
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
    Group {
      // Check if this is an Edit or MultiEdit tool message with diff data
      if message.messageType == .toolUse,
         let rawParams = message.toolInputData?.rawParameters {
        
        switch EditTool(rawValue: message.toolName ?? "") {
        case .edit:
          editToolContent(rawParams: rawParams)
        case .multiEdit:
          multiEditToolContent(rawParams: rawParams)
        case .write:
          writeToolContent(rawParams: rawParams)
        default:
          defaultToolDisplay
        }
      } else {
        defaultToolDisplay
      }
    }
    .task {
      // Initialize DiffStateManager if needed for diff tools
      if message.messageType == .toolUse,
         let toolName = message.toolName,
         [EditTool.edit.rawValue, EditTool.multiEdit.rawValue, EditTool.write.rawValue].contains(toolName),
         diffStateManager == nil {
        diffStateManager = DiffStateManager(terminalService: terminalService)
        withAnimation(.easeInOut(duration: 0.3)) {
          isDiffManagerReady = true
        }
      }
    }
  }
  
  // MARK: - Tool Content Views
  
  @ViewBuilder
  private func editToolContent(rawParams: [String: String]) -> some View {
    if let filePath = rawParams[JSONKeys.filePath],
       rawParams[JSONKeys.oldString] != nil,
       rawParams[JSONKeys.newString] != nil {
      diffView(editTool: .edit, rawParams: rawParams)
    } else {
      defaultToolDisplay
    }
  }
  
  @ViewBuilder
  private func multiEditToolContent(rawParams: [String: String]) -> some View {
    if let filePath = rawParams[JSONKeys.filePath],
       rawParams[JSONKeys.edits] != nil {
      diffView(editTool: .multiEdit, rawParams: rawParams)
    } else {
      defaultToolDisplay
    }
  }
  
  @ViewBuilder
  private func writeToolContent(rawParams: [String: String]) -> some View {
    if let filePath = rawParams[JSONKeys.filePath],
       rawParams[JSONKeys.content] != nil {
      diffView(editTool: .write, rawParams: rawParams)
    } else {
      defaultToolDisplay
    }
  }
  
  @ViewBuilder
  private func diffView(editTool: EditTool, rawParams: [String: String]) -> some View {
    Group {
      if isDiffManagerReady && diffStateManager != nil {
        ClaudeCodeEditsView(
          messageID: message.id,
          editTool: editTool,
          toolParameters: rawParams,
          terminalService: terminalService,
          projectPath: projectPath,
          onExpandRequest: {
            modalDiffData = DiffModalData(messageID: message.id, tool: editTool, params: rawParams)
          },
          diffStore: diffStateManager
        )
        .transition(.asymmetric(
          insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
          removal: .opacity
        ))
      } else {
        DiffLoadingView()
          .transition(.opacity.combined(with: .scale))
      }
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
      let displayContent = message.role == .user && !message.content.isEmpty ? "\(message.content)" : message.content
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
}
