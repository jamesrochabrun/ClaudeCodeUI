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
  let showArtifact: ((Artifact) -> Void)?
  
  @State private var size = CGSize.zero
  @State private var isHovered = false
  @State private var showTimestamp = false
  @State private var isExpanded = false
  @State private var textFormatter: TextFormatter
  @State private var hasProcessedInitialContent = false
  
  @Environment(\.colorScheme) private var colorScheme
  
  init(
    message: ChatMessage,
    settingsStorage: SettingsStorage,
    terminalService: TerminalService,
    fontSize: Double = 13.0,
    showArtifact: ((Artifact) -> Void)? = nil)
  {
    self.message = message
    self.settingsStorage = settingsStorage
    self.terminalService = terminalService
    self.fontSize = fontSize
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
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Code selections for user messages
      if message.role == .user, let codeSelections = message.codeSelections, !codeSelections.isEmpty {
        CodeSelectionsSectionView(selections: codeSelections)
          .padding(.top, 6)
      }
      
      // File attachments for user messages
      if message.role == .user, let attachments = message.attachments, !attachments.isEmpty {
        AttachmentsSectionView(attachments: attachments)
          .padding(.top, 6)
      }
      
      GeometryReader { geometry in
        Color.clear
          .onAppear { size = geometry.size }
          .onChange(of: geometry.size) { _, newSize in
            size = newSize
          }
      }.frame(height: 0)
      
      VStack(alignment: .leading, spacing: 0) {
        if isCollapsible {
          CollapsibleHeaderView(
            messageType: message.messageType,
            toolName: message.toolName,
            toolInputData: message.toolInputData,
            isExpanded: $isExpanded,
            fontSize: fontSize
          )
          
          // Expandable content with indentation
          if isExpanded {
            VStack(alignment: .leading, spacing: 0) {
              // Connection line
              HStack(spacing: 0) {
                Color.clear
                  .frame(width: 20)
                
                Rectangle()
                  .fill(borderColor)
                  .frame(width: 2)
                  .padding(.vertical, -1)
              }
              .frame(height: 8)
              
              // Content area
              HStack(alignment: .top, spacing: 0) {
                Color.clear
                  .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 0) {
                  Rectangle()
                    .fill(borderColor)
                    .frame(height: 1)
                    .frame(maxWidth: .infinity)
                  
                  // Message content
                  ScrollView {
                    MessageContentView(
                      message: message,
                      textFormatter: textFormatter,
                      fontSize: fontSize,
                      horizontalPadding: horizontalPadding,
                      showArtifact: showArtifact,
                      maxWidth: size.width,
                      terminalService: terminalService
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                  }
                  .frame(maxHeight: 400)
                  .background(contentBackgroundColor)
                }
              }
            }
            .transition(.asymmetric(
              insertion: .push(from: .top).combined(with: .opacity),
              removal: .push(from: .bottom).combined(with: .opacity)
            ))
          }
        } else {
          MessageContentView(
            message: message,
            textFormatter: textFormatter,
            fontSize: fontSize,
            horizontalPadding: horizontalPadding,
            showArtifact: showArtifact,
            maxWidth: size.width,
            terminalService: terminalService
          )
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      
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
  }
  
  // MARK: - Helper Properties
  
  private var horizontalPadding: CGFloat {
    message.role == .user ? Constants.userTextHorizontalPadding : 0
  }
  
  private var isCollapsible: Bool {
    switch message.messageType {
    case .toolUse, .toolResult, .toolError, .thinking, .webSearch:
      return true
    case .text:
      return false
    }
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