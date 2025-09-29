import SwiftUI
import AppKit
import Down
import CCTerminalServiceInterface

struct ChatMessageView: View {
  
  enum Constants {
    static let cornerRadius: CGFloat = 5
    static let userTextHorizontalPadding: CGFloat = 8
    static let textVerticalPadding: CGFloat = 8
    static let toolPadding: CGFloat = 8
    static let checkpointPadding: CGFloat = 8
  }
  
  let message: ChatMessage
  let settingsStorage: SettingsStorage
  let fontSize: Double
  let terminalService: TerminalService
  let viewModel: ChatViewModel
  let showArtifact: ((Artifact) -> Void)?
  
  @State private var size = CGSize.zero
  @State private var isHovered = false
  @State private var showTimestamp = false
  @State private var isExpanded = false
  @State private var textFormatter: TextFormatter
  /// Tracks whether the initial message content has been processed by the TextFormatter.
  /// This prevents duplicate processing of pre-existing content while allowing incremental
  /// updates for streaming messages. Set to true after the first content ingestion.
  @State private var hasProcessedInitialContent = false
  
  @Environment(\.colorScheme) private var colorScheme
  
  init(
    message: ChatMessage,
    settingsStorage: SettingsStorage,
    terminalService: TerminalService,
    fontSize: Double = 13.0,
    viewModel: ChatViewModel,
    showArtifact: ((Artifact) -> Void)? = nil)
  {
    self.message = message
    self.settingsStorage = settingsStorage
    self.terminalService = terminalService
    self.fontSize = fontSize
    self.viewModel = viewModel
    self.showArtifact = showArtifact
    
    // Initialize text formatter with project root if available
    let projectRoot = settingsStorage.projectPath.isEmpty ? nil : URL(fileURLWithPath: settingsStorage.projectPath)
    let formatter = TextFormatter(projectRoot: projectRoot)
    
    // Process initial content for assistant messages
    if message.role == .assistant && message.messageType == .text && !message.content.isEmpty {
      formatter.ingest(delta: message.content)
      _hasProcessedInitialContent = State(initialValue: true)
    } else {
      _hasProcessedInitialContent = State(initialValue: false)
    }
    
    _textFormatter = State(initialValue: formatter)
    
    // Check if we have a persisted expansion state for this message
    let initialExpanded: Bool
    if let persistedState = viewModel.messageExpansionStates[message.id] {
      initialExpanded = persistedState
    } else {
      // Set default expanded state based on tool type or message type
      var defaultExpanded = false
      
      // Check if it's a tool that should be expanded by default
      if let toolName = message.toolName,
         let tool = ToolRegistry.shared.tool(for: toolName) {
        defaultExpanded = tool.defaultExpandedState

        // Special case for ExitPlanMode - always expand
        if toolName.lowercased() == "exitplanmode" || toolName == "exit_plan_mode" {
          defaultExpanded = true
        }
      }
      
      // Thinking messages should also be expanded by default
      if message.messageType == .thinking {
        defaultExpanded = true
      }
      
      initialExpanded = defaultExpanded
    }
    
    _isExpanded = State(initialValue: initialExpanded)
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      userMessageAttachments
      sizeReader
      messageContent
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 4)
    .onHover { hovering in
      withAnimation(.easeInOut(duration: 0.2)) {
        isHovered = hovering
      }
    }
    .contextMenu {
      contextMenuItems
    }
    .onChange(of: message.content) { oldContent, newContent in
      handleContentChange(oldContent: oldContent, newContent: newContent)
    }
    .onChange(of: viewModel.messageExpansionStates[message.id]) { _, newValue in
      if let newValue, newValue != isExpanded {
        withAnimation(.easeInOut(duration: 0.3)) {
          isExpanded = newValue
        }
      }
    }
  }
  
  @ViewBuilder
  private var userMessageAttachments: some View {
    if message.role == .user {
      if let codeSelections = message.codeSelections, !codeSelections.isEmpty {
        CodeSelectionsSectionView(selections: codeSelections)
          .padding(.top, 6)
      }
      
      if let attachments = message.attachments, !attachments.isEmpty {
        AttachmentsSectionView(attachments: attachments)
          .padding(.top, 6)
      }
    }
  }
  
  private var sizeReader: some View {
    GeometryReader { geometry in
      Color.clear
        .onAppear { size = geometry.size }
        .onChange(of: geometry.size) { _, newSize in
          size = newSize
        }
    }.frame(height: 0)
  }
  
  @ViewBuilder
  private var messageContent: some View {
    VStack(alignment: .leading, spacing: 0) {
      if isCollapsible {
        collapsibleContent
      } else {
        standardMessageContent
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
  
  private var collapsibleContent: some View {
    VStack {
      CollapsibleHeaderView(
        messageType: message.messageType,
        toolName: message.toolName,
        toolInputData: message.toolInputData,
        isExpanded: expansionBinding,
        fontSize: fontSize
      )
      if isExpanded {
        expandedContent
      }
    }
    .animation(.easeInOut, value: isExpanded)
  }
  
  private var expandedContent: some View {
    VStack(alignment: .leading, spacing: 0) {
      if !isEditTool {
        connectionLine
      }
      contentArea
    }
  }
  
  private var connectionLine: some View {
    HStack(spacing: 0) {
      Color.clear
        .frame(width: 20)
      
      Rectangle()
        .fill(borderColor)
        .frame(width: 2)
        .padding(.vertical, -1)
    }
    .frame(height: 8)
  }
  
  private var contentArea: some View {
    HStack(alignment: .top, spacing: 0) {
      if !isEditTool {
        Color.clear
          .frame(width: 20)
      }
      
      VStack(alignment: .leading, spacing: 0) {
        if !isEditTool {
          Rectangle()
            .fill(borderColor)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
        }
        
        // For ExitPlanMode, don't use ScrollView to show full content with action buttons
        if message.toolName == "ExitPlanMode" || message.toolName == "exit_plan_mode" {
          messageContentView
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(contentBackgroundColor)
        } else {
          ScrollView {
            messageContentView
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .frame(maxHeight: 400)
          .background(contentBackgroundColor)
        }
      }
    }
  }
  
  private var standardMessageContent: some View {
    messageContentView
  }
  
  private var messageContentView: some View {
    MessageContentView(
      message: message,
      textFormatter: textFormatter,
      fontSize: fontSize,
      horizontalPadding: horizontalPadding,
      showArtifact: showArtifact,
      maxWidth: size.width,
      terminalService: terminalService,
      projectPath: settingsStorage.projectPath,
      onApprovalAction: onApprovalAction,
      viewModel: viewModel
    )
  }
  
  private var expansionBinding: Binding<Bool> {
    Binding(
      get: { isExpanded },
      set: { newValue in
        isExpanded = newValue
        viewModel.messageExpansionStates[message.id] = newValue
      }
    )
  }
  
  private func onApprovalAction() {
    isExpanded = false
    viewModel.messageExpansionStates[message.id] = false
  }
  
  // MARK: - Helper Properties
  
  private var horizontalPadding: CGFloat {
    message.role == .user ? Constants.userTextHorizontalPadding : 0
  }
  
  private var isCollapsible: Bool {
    switch message.messageType {
    case .toolUse, .toolResult, .toolError, .toolDenied, .thinking, .webSearch:
      return true
    case .text:
      return false
    }
  }
  
  private var isEditTool: Bool {
    guard let toolName = message.toolName else { return false }
    return EditTool(rawValue: toolName) != nil
  }
  
  private var contentBackgroundColor: SwiftUI.Color {
    colorScheme == .dark
    ? Color.expandedContentBackgroundDark
    : .expandedContentBackgroundLight
  }
  
  private var borderColor: SwiftUI.Color {
    colorScheme == .dark
    ? SwiftUI.Color(white: 0.25)
    : SwiftUI.Color(white: 0.85)
  }
  
  // MARK: - Context Menu
  
  @ViewBuilder
  private var contextMenuItems: some View {
    Button(action: copyMessage) {
      Label("Copy", systemImage: "doc.on.doc")
    }
    
    if message.role == .assistant {
      Button(action: { showTimestamp.toggle() }) {
        Label(showTimestamp ? "Hide Timestamp" : "Show Timestamp",
              systemImage: "clock")
      }
    }
  }
  
  // MARK: - Helper Functions
  
  private func copyMessage() {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(message.content, forType: .string)
  }
  
  private func handleContentChange(oldContent: String, newContent: String) {
    // Handle content changes for assistant messages
    if message.role == .assistant && message.messageType == .text {
      if !hasProcessedInitialContent && !newContent.isEmpty {
        // First time seeing content
        textFormatter.ingest(delta: newContent)
        hasProcessedInitialContent = true
      } else if !message.isComplete && hasProcessedInitialContent {
        // Streaming updates - calculate the actual delta
        let currentLength = textFormatter.deltas.joined().count
        if newContent.count > currentLength {
          let newDelta = String(newContent.dropFirst(currentLength))
          if !newDelta.isEmpty {
            textFormatter.ingest(delta: newDelta)
          }
        }
      }
    }
  }
  
}
