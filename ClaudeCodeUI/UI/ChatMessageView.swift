import SwiftUI
import AppKit
import Down
import TerminalServiceInterface

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
  
  @State private var size = CGSize.zero
  @State private var isHovered = false
  @State private var showTimestamp = false
  @State private var isExpanded = false
  @State private var textFormatter: TextFormatter
  @State private var hasProcessedInitialContent = false
  @State private var diffViewModel: DiffRenderViewModel?
  
  init(
    message: ChatMessage,
    settingsStorage: SettingsStorage,
    terminalService: TerminalService,
    fontSize: Double = 13.0)
  {
    self.message = message
    self.settingsStorage = settingsStorage
    self.terminalService = terminalService
    self.fontSize = fontSize
    
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
        codeSelectionsView(selections: codeSelections)
          .padding(.top, 6)
      }
      
      // File attachments for user messages
      if message.role == .user, let attachments = message.attachments, !attachments.isEmpty {
        attachmentsView(attachments: attachments)
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
          collapsibleHeader
          
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
                    messageContentView
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
          messageContentView
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      
      Spacer(minLength: 0)
      
        .background(Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
      
      if message.isError {
        Text("Error occurred")
          .textSelection(.enabled)
          .font(.system(size: 11))
          .foregroundColor(.red)
      }
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
  
  var style: MarkdownStyle {
    MarkdownStyle(colorScheme: colorScheme)
  }
  
  @Environment(\.colorScheme) private var colorScheme
  
  private var horizontalPadding: CGFloat {
    message.role == .user ? Constants.userTextHorizontalPadding : 0
  }
  
  // Determine if this message type should be collapsible
  private var isCollapsible: Bool {
    switch message.messageType {
    case .toolUse, .toolResult, .toolError, .thinking, .webSearch:
      return true
    case .text:
      return false
    }
  }
  
  // Check if this is a user or assistant text message
  private var isUserOrAssistantTextMessage: Bool {
    return (message.role == .user || message.role == .assistant) && message.messageType == .text
  }
  
  // Message prefix based on role
  private var messagePrefix: String {
    switch message.role {
    case .user:
      return "> "
    default:
      return ""
    }
  }
  
  @ViewBuilder
  private var collapsibleHeader: some View {
    HStack(spacing: 12) {
      // Checkmark indicator
      Image(systemName: isExpanded ? "checkmark.circle.fill" : "checkmark.circle")
        .font(.system(size: 14))
        .foregroundStyle(statusColor)
        .frame(width: 20, height: 20)
      
      // Message type label
      Text(collapsibleHeaderText)
        .font(.system(size: fontSize - 1, design: .monospaced))
        .foregroundStyle(.primary)
      
      Spacer()
      
      // Expand/collapse chevron
      Image(systemName: "chevron.right")
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.secondary)
        .rotationEffect(.degrees(isExpanded ? 90 : 0))
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(
      RoundedRectangle(cornerRadius: Constants.cornerRadius, style: .continuous)
        .fill(.ultraThinMaterial)
        .overlay(
          RoundedRectangle(cornerRadius: Constants.cornerRadius, style: .continuous)
            .strokeBorder(
              LinearGradient(
                colors: [
                  Color(red: 147/255, green: 51/255, blue: 234/255).opacity(0.3),
                  Color(red: 147/255, green: 51/255, blue: 234/255).opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ),
              lineWidth: 1
            )
        )
    )
    .contentShape(Rectangle())
    .onTapGesture {
      withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
        isExpanded.toggle()
      }
    }
  }
  
  @ViewBuilder
  private var messageContentView: some View {
    if isCollapsible {
      // Check if this is an Edit tool message with diff data
      if message.messageType == .toolUse && 
         message.toolName == "Edit",
         let rawParams = message.toolInputData?.rawParameters,
         let oldString = rawParams["old_string"],
         let newString = rawParams["new_string"],
         let filePath = rawParams["file_path"] {
        // Show diff view for Edit tool
        if let viewModel = diffViewModel {
          DiffView(
            formattedDiff: viewModel.formattedDiff,
            fileName: URL(fileURLWithPath: filePath).lastPathComponent
          )
          .padding(8)
        } else {
          ProgressView()
            .frame(maxWidth: .infinity, minHeight: 100)
            .onAppear {
              // Create diff view model when the view appears
              diffViewModel = DiffRenderViewModel(
                oldContent: oldString,
                newContent: newString,
                terminalService: terminalService
              )
            }
        }
      } else {
        // For other collapsible messages (tool use, thinking, etc.), show plain text with appropriate styling
        Text(message.content)
          .font(.system(size: fontSize - 1, design: .monospaced))
          .foregroundColor(contentTextColor)
          .padding(16)
          .frame(maxWidth: .infinity, alignment: .leading)
          .textSelection(.enabled)
      }
    } else if message.role == .assistant && message.messageType == .text {
      // Use formatted text for assistant messages
      ForEach(textFormatter.elements) { element in
        textElementView(element)
      }
      
      // Show loading indicator if still streaming
      if !message.isComplete && textFormatter.elements.isEmpty {
        loadingView
      }
    } else {
      // Use plain text for other messages
      let displayContent = message.role == .user && !message.content.isEmpty ? "\(messagePrefix)\(message.content)" : message.content
      Text(displayContent)
        .textSelection(.enabled)
        .font(messageFont)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, Constants.textVerticalPadding)
    }
  }
  
  @ViewBuilder
  private func textElementView(_ element: TextFormatter.Element) -> some View {
    switch element {
    case .text(let text):
      let attributedText = message.role == .user ? plainText(for: text) : markdown(for: text)
      LongText(attributedText, maxWidth: size.width - 2 * horizontalPadding)
        .textSelection(.enabled)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, Constants.textVerticalPadding)
      
    case .codeBlock(let code):
      CodeBlockContentView(code: code, role: message.role)
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }
  }
  
  private func markdown(for text: TextFormatter.Element.TextElement) -> AttributedString {
    let markDown = Down(markdownString: text.text)
    do {
      let attributedString = try markDown.toAttributedString(using: style)
      return AttributedString(attributedString.trimmedAttributedString())
    } catch {
      print("Error parsing markdown: \(error)")
      return AttributedString(text.text)
    }
  }
  
  private func plainText(for text: TextFormatter.Element.TextElement) -> AttributedString {
    var attrs = AttributedString(text.text)
    attrs.foregroundColor = SwiftUI.Color(style.baseFontColor)
    // NSFont can be used directly with Font initializer
    attrs.font = Font(style.baseFont as CTFont)
    return attrs
  }
  
  @ViewBuilder
  private var loadingView: some View {
    HStack(spacing: 8) {
      ForEach(0..<3) { index in
        Circle()
          .fill(
            LinearGradient(
              colors: [messageTint, messageTint.opacity(0.6)],
              startPoint: .top,
              endPoint: .bottom
            )
          )
          .frame(width: 8, height: 8)
          .scaleEffect(animationValues[index] ? 1.2 : 0.8)
          .animation(
            Animation.easeInOut(duration: 0.6)
              .repeatForever(autoreverses: true)
              .delay(Double(index) * 0.15),
            value: animationValues[index]
          )
          .onAppear {
            animationValues[index].toggle()
          }
      }
    }
    .padding(.vertical, 4)
  }
  
  @State private var animationValues: [Bool] = [false, false, false]
  
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
  
  // MARK: - Computed Properties
  private var collapsibleHeaderText: String {
    switch message.messageType {
    case .toolUse:
      let toolName = message.toolName ?? "Tool Use"
      return message.toolInputData?.headerText(for: toolName) ?? toolName
    case .toolResult:
      return "Processing result"
    case .toolError:
      return "Error occurred"
    case .thinking:
      return "Thinking..."
    case .webSearch:
      return "Searching the web"
    default:
      return "Processing"
    }
  }
  
  private var statusColor: SwiftUI.Color {
    switch message.messageType {
    case .toolUse, .thinking, .webSearch:
      return .bookCloth
    case .toolResult:
      return .manilla
    case .toolError:
      return .red
    default:
      return .secondary
    }
  }
  
  private var messageTint: SwiftUI.Color {
    switch message.messageType {
    case .text:
      return message.role == .assistant ? SwiftUI.Color(red: 147/255, green: 51/255, blue: 234/255) : .primary
    case .toolUse:
      return SwiftUI.Color(red: 255/255, green: 149/255, blue: 0/255)
    case .toolResult:
      return SwiftUI.Color(red: 52/255, green: 199/255, blue: 89/255)
    case .toolError:
      return SwiftUI.Color(red: 255/255, green: 59/255, blue: 48/255)
    case .thinking:
      return SwiftUI.Color(red: 90/255, green: 200/255, blue: 250/255)
    case .webSearch:
      return SwiftUI.Color(red: 0/255, green: 199/255, blue: 190/255)
    }
  }
  
  private var messageFont: SwiftUI.Font {
    guard (message.role == .user || message.role == .assistant) else {
      return .system(size: fontSize, weight: colorScheme == .dark ? .ultraLight : .light, design: .monospaced)
    }
    return SwiftUI.Font.system(.body)
  }
  
  private var collapsibleBackgroundColor: SwiftUI.Color {
    colorScheme == .dark
    ? SwiftUI.Color(white: 0.15)
    : SwiftUI.Color(white: 0.95)
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
  
  private var contentTextColor: SwiftUI.Color {
    colorScheme == .dark ? .white : SwiftUI.Color.black.opacity(0.85)
  }
  
  // MARK: - Code Selections View
  @ViewBuilder
  private func codeSelectionsView(selections: [TextSelection]) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(selections) { selection in
        ActiveFileView(model: .selection(selection))
          .transition(.asymmetric(
            insertion: .scale(scale: 0.95).combined(with: .opacity),
            removal: .scale(scale: 0.95).combined(with: .opacity)
          ))
      }
    }
  }
  
  private func attachmentsView(attachments: [FileAttachment]) -> some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 12) {
        ForEach(attachments) { attachment in
          AttachmentPreviewView(attachment: attachment, onRemove: {})
            .allowsHitTesting(false) // Disable interaction in message view
        }
      }
      .padding(.horizontal, 12)
    }
  }
}

// Helper to trim whitespace from attributed strings
extension NSAttributedString {
  public func trimmedAttributedString() -> NSAttributedString {
    let nonWhiteSpace = CharacterSet.whitespacesAndNewlines.inverted
    let startRange = string.rangeOfCharacter(from: nonWhiteSpace)
    let endRange = string.rangeOfCharacter(from: nonWhiteSpace, options: .backwards)
    
    guard let startLocation = startRange?.lowerBound, let endLocation = endRange?.lowerBound else {
      return NSAttributedString(string: "")
    }
    
    if startLocation == string.startIndex, endLocation == string.index(before: string.endIndex) {
      return self
    }
    
    let trimmedRange = startLocation...endLocation
    return attributedSubstring(from: NSRange(trimmedRange, in: string))
  }
}

