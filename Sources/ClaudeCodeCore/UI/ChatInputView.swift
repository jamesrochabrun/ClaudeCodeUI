//
//  ChatInputView.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 6/7/2025.
//

import SwiftUI
import ClaudeCodeSDK
import CCPermissionsServiceInterface
import CCXcodeObserverServiceInterface
import CCAccessibilityFoundation
import Combine
import UniformTypeIdentifiers
import CodeWhisper

struct ChatInputView: View {
  
  // MARK: - Properties
  
  @Binding var text: String
  @Binding var viewModel: ChatViewModel
  let contextManager: ContextManager
  let xcodeObservationViewModel: XcodeObservationViewModel
  let permissionsService: PermissionsService
  let uiConfiguration: UIConfiguration
  
  @Environment(GlobalPreferencesStorage.self) private var globalPreferences
  
  @FocusState private var isFocused: Bool
  let placeholder: String
  @State private var shouldSubmit = false
  @Binding var triggerFocus: Bool
  @State private var showingProjectPathAlert = false
  @State private var showingSettings = false
  @State private var attachments: [FileAttachment] = []
  @State private var isDragging = false
  @State private var showingFilePicker = false

  // Voice mode adapter for CodeWhisperButton
  @State private var voiceModeAdapter: ChatViewModelVoiceModeAdapter?
  @State private var isRealtimeSessionActive = false
  
  // File search properties
  @State private var showingFileSearch = false
  @State private var fileSearchRange: NSRange? = nil
  @State private var fileSearchViewModel: FileSearchViewModel? = nil
  @State private var fileSearchAnchor: CGPoint = .zero
  @State private var isUpdatingFileSearch = false
  
  // Command search properties
  @State private var showingCommandSearch = false
  @State private var commandSearchRange: NSRange? = nil
  @State private var commandSearchViewModel: CommandSearchViewModel? = nil
  @State private var isUpdatingCommandSearch = false
  
  // Tip preferences
  @StateObject private var tipManager = TipPreferencesManager()
  
  private let processor = AttachmentProcessor()
  
  // MARK: - Constants
  
  private let textAreaEdgeInsets = EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 15)
  private let textAreaCornerRadius = 24.0
  
  // MARK: - Initialization
  
  init(
    text: Binding<String>,
    chatViewModel: Binding<ChatViewModel>,
    contextManager: ContextManager,
    xcodeObservationViewModel: XcodeObservationViewModel,
    permissionsService: PermissionsService,
    uiConfiguration: UIConfiguration = .default,
    placeholder: String = "↵ send new message, ⇧↵ new line",
    triggerFocus: Binding<Bool> = .constant(false))
  {
    _text = text
    _viewModel = chatViewModel
    self.contextManager = contextManager
    self.xcodeObservationViewModel = xcodeObservationViewModel
    self.permissionsService = permissionsService
    self.uiConfiguration = uiConfiguration
    self.placeholder = placeholder
    _triggerFocus = triggerFocus
  }
  // MARK: - Body
  var body: some View {
    VStack(spacing: 0) {
      // File search UI - shown when @ is typed
      if showingFileSearch {
        if let viewModel = fileSearchViewModel {
          InlineFileSearchView(
            viewModel: viewModel,
            onSelect: { result in
              insertFileReference(result)
            },
            onDismiss: {
              dismissFileSearch()
            }
          )
          .background(Color(NSColor.controlBackgroundColor))
          .clipShape(RoundedRectangle(cornerRadius: 12))
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(Color(NSColor.separatorColor), lineWidth: 1)
          )
          .padding(.horizontal, 12)
          .padding(.bottom, 8)
          .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
          ))
        }
      }
      
      // Command search UI - shown when / is typed at start of message
      if showingCommandSearch {
        if let viewModel = commandSearchViewModel {
          CommandSearchView(
            viewModel: viewModel,
            onSelect: { result in
              insertCommand(result)
            },
            onDismiss: {
              dismissCommandSearch()
            }
          )
          .background(Color(NSColor.controlBackgroundColor))
          .clipShape(RoundedRectangle(cornerRadius: 12))
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(Color(NSColor.separatorColor), lineWidth: 1)
          )
          .padding(.horizontal, 12)
          .padding(.bottom, 8)
          .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
          ))
        }
      }
      
      // Main input area
      VStack(alignment: .leading, spacing: 8) {
        VStack(alignment: .leading, spacing: 2) {
          if shouldShowContextBar {
            contextBar
          }
          if !attachments.isEmpty {
            AttachmentListView(attachments: $attachments)
              .padding(.horizontal, 8)
              .padding(.top, 4)
          }
          HStack(alignment: .center) {
            attachmentButton
            textEditor
            // Show CodeWhisperButton when voice mode is enabled and text is empty
            // Keep button visible during loading only when realtime session is active (to prevent sheet dismissal)
            // For STT/STT+TTS modes, show action button during loading so user can cancel
            if uiConfiguration.showVoiceModeButton && globalPreferences.enableVoiceMode && text.isEmpty && (!viewModel.isLoading || isRealtimeSessionActive) {
              codeWhisperButton
            } else {
              actionButton
            }
          }
          .animation(.easeInOut, value: text.isEmpty)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(inputBorder)
        PermissionModeButton(mode: $viewModel.permissionMode)
        
        // Dismissable tip about cmd+i functionality
        if !tipManager.isDismissed(.cmdITipV1) {
          TipBannerView(
            message: TipPreferencesManager.TipID.cmdITipV1.displayMessage,
            icon: TipPreferencesManager.TipID.cmdITipV1.iconName,
            onDismiss: {
              withAnimation(.easeInOut(duration: 0.2)) {
                tipManager.dismiss(.cmdITipV1)
              }
            }
          )
          .padding(.top, 4)
          .transition(.move(edge: .top).combined(with: .opacity))
        }
      }
      .padding(.horizontal, 12)
      .padding(.bottom, 12)
    }
    .animation(.easeInOut(duration: 0.2), value: showingFileSearch)
    .animation(.easeInOut(duration: 0.2), value: xcodeObservationViewModel.workspaceModel.activeFile?.name)
    .animation(.easeInOut(duration: 0.2), value: contextManager.context.codeSelections.count)
    .animation(.easeInOut(duration: 0.15), value: viewModel.permissionMode)
    .animation(.easeInOut(duration: 0.2), value: tipManager.isDismissed(.cmdITipV1))
    .onChange(of: viewModel.projectPath) { oldValue, newValue in
      if !newValue.isEmpty && newValue != oldValue {
        fileSearchViewModel?.updateProjectPath(newValue)
      }
    }
    .onAppear {
      xcodeObservationViewModel.refresh()
      // Only initialize file search if we don't have one already
      if fileSearchViewModel == nil {
        fileSearchViewModel = FileSearchViewModel(xcodeObservationViewModel: xcodeObservationViewModel, projectPath: viewModel.projectPath)
      }
      // Update project path if it changed
      if !viewModel.projectPath.isEmpty {
        fileSearchViewModel?.updateProjectPath(viewModel.projectPath)
      }
      // Initialize voice mode adapter for CodeWhisperButton
      if voiceModeAdapter == nil {
        voiceModeAdapter = ChatViewModelVoiceModeAdapter(chatViewModel: viewModel)
      }
    }
    .alert("No Working Directory Selected", isPresented: $showingProjectPathAlert) {
      workingDirectoryAlertButtons
    } message: {
      Text("Please select a working directory before starting a conversation. This helps Claude understand the context of your project.")
    }
    .sheet(isPresented: $showingSettings) {
      settingsSheet
    }
    .fileImporter(
      isPresented: $showingFilePicker,
      allowedContentTypes: allowedFileTypes,
      allowsMultipleSelection: true
    ) { result in
      handleFileImport(result)
    }
  }
  
  // MARK: - Computed Properties
}

// MARK: - Main UI Components

extension ChatInputView {
  
  /// Attachment button
  private var attachmentButton: some View {
    Button(action: {
      showingFilePicker = true
    }) {
      Image(systemName: "paperclip")
        .foregroundColor(.gray)
    }
    .buttonStyle(.plain)
    .padding(.leading, 8)
    .help("Attach files")
  }
  
  /// CodeWhisper button - tap to start voice mode, long-press to open settings
  private var codeWhisperButton: some View {
    CodeWhisperButton(
      chatInterface: voiceModeAdapter,
      executor: ChatViewModelAdapter(chatViewModel: viewModel),
      configuration: uiConfiguration.availableVoiceModes.toCodeWhisperConfiguration,
      isRealtimeSessionActive: $isRealtimeSessionActive
    )
    .padding(.trailing, 2)
  }
  
  /// Action button (send/cancel)
  private var actionButton: some View {
    Group {
      if viewModel.isLoading {
        cancelButton
      } else {
        sendButton
      }
    }
  }
  
  /// Cancel request button
  private var cancelButton: some View {
    Button(action: {
      viewModel.cancelRequest()
    }) {
      Image(systemName: "stop.fill")
    }
    .padding(10)
    .buttonStyle(.plain)
  }
  
  /// Send message button
  private var sendButton: some View {
    Button(action: {
      sendMessage()
    }) {
      Image(systemName: "arrow.up.circle.fill")
        .foregroundColor(.brandSecondary)
        .font(.title2)
    }
    .padding(10)
    .buttonStyle(.plain)
    .disabled(isTextEmpty)
  }
  
  /// Input area border
  private var inputBorder: some View {
    RoundedRectangle(cornerRadius: 12)
      .stroke(isDragging ? Color.accentColor : Color(NSColor.separatorColor), lineWidth: isDragging ? 2 : 1)
      .animation(.easeInOut(duration: 0.2), value: isDragging)
  }
  
  /// Working directory alert buttons
  private var workingDirectoryAlertButtons: some View {
    Group {
      Button("Open Settings") {
        showingSettings = true
      }
      Button("Cancel", role: .cancel) {}
    }
  }
  
  /// Settings sheet
  private var settingsSheet: some View {
    SettingsView(chatViewModel: viewModel)
      .frame(width: 700, height: 550)
  }
  
  /// Placeholder view
  private var placeholderView: some View {
    Text(placeholder)
      .font(.body)
      .foregroundColor(.gray)
      .frame(maxWidth: .infinity, alignment: .leading)
      .onTapGesture {
        isFocused = true
      }
  }
}

// MARK: - Text Editor

extension ChatInputView {
  
  /// Main text editor component
  private var textEditor: some View {
    ZStack(alignment: .center) {
      TextEditor(text: $text)
        .scrollContentBackground(.hidden)
        .focused($isFocused)
        .font(.body)
        .frame(minHeight: 20, maxHeight: 200)
        .fixedSize(horizontal: false, vertical: true)
        .padding(textAreaEdgeInsets)
        .onAppear {
          isFocused = true
        }
        .onChange(of: triggerFocus) { _, shouldFocus in
          if shouldFocus {
            isFocused = true
            triggerFocus = false
          }
        }
        .onChange(of: text) { oldValue, newValue in
          // Simple check to avoid freezing
          if newValue.count > 1000 {
            print("[ChatInputView] Text too long, skipping @ and / detection")
            return
          }
          detectAtMention(oldText: oldValue, newText: newValue)
          detectSlashCommand(oldText: oldValue, newText: newValue)
        }
        .onKeyPress { key in
          handleKeyPress(key)
        }
        .overlay {
          textEditorOverlay
        }
      
      if text.isEmpty {
        placeholderView
          .padding(textAreaEdgeInsets)
          .padding(.leading, 4)
      }
    }
  }
  
  /// Text editor overlay for drag and drop
  private var textEditorOverlay: some View {
    Color.clear
      .allowsHitTesting(true)
      .onDrop(of: [.fileURL, .png, .tiff, .image], isTargeted: $isDragging) { providers in
        handleDroppedProviders(providers)
        return true
      }
  }
  
  /// Handle keyboard events
  private func handleKeyPress(_ key: KeyPress) -> KeyPress.Result {
    // When command search is showing, handle navigation keys
    if showingCommandSearch {
      switch key.key {
      case .return:
        if let result = commandSearchViewModel?.getSelectedResult() {
          insertCommand(result)
        }
        return .handled
      case .escape:
        dismissCommandSearch()
        return .handled
      case .downArrow:
        commandSearchViewModel?.selectNext()
        return .handled
      case .upArrow:
        commandSearchViewModel?.selectPrevious()
        return .handled
      default:
        return .ignored
      }
    }
    // When file search is showing, handle navigation keys
    else if showingFileSearch {
      switch key.key {
      case .return:
        if let result = fileSearchViewModel?.getSelectedResult() {
          insertFileReference(result)
        }
        return .handled
      case .escape:
        dismissFileSearch()
        return .handled
      case .downArrow:
        fileSearchViewModel?.selectNext()
        return .handled
      case .upArrow:
        fileSearchViewModel?.selectPrevious()
        return .handled
      default:
        return .ignored
      }
    } else {
      // Normal text editor behavior
      switch key.key {
      case .return:
        // Check if shift is pressed - if so, allow new line
        if key.modifiers.contains(.shift) {
          // Return .ignored to let TextEditor handle the newline insertion naturally
          return .ignored
        } else {
          // Don't send message if already loading/streaming
          if viewModel.isLoading {
            return .handled  // Prevent any action including new line
          }
          // Send message on regular return (without shift)
          sendMessage()
          return .handled
        }
      case .escape:
        if viewModel.isLoading {
          viewModel.cancelRequest()
          return .handled
        }
        return .ignored
      default:
        return .ignored
      }
    }
  }
}

// MARK: - Context Bar

extension ChatInputView {
  
  /// Context bar showing active file and selections
  private var contextBar: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        activeFileChip
        contextDivider
        codeSelectionChips
      }
      .padding(.horizontal, 4)
    }
    .padding(.top, 6)
    .padding(.horizontal, 4)
    .transition(.asymmetric(
      insertion: .move(edge: .top).combined(with: .opacity),
      removal: .move(edge: .top).combined(with: .opacity)
    ))
  }
  
  /// Active file chip
  @ViewBuilder
  private var activeFileChip: some View {
    // If there's a pinned file, show it instead of the active file
    if contextManager.isPinnedActiveFile, let pinnedFile = contextManager.pinnedActiveFile {
      ActiveFileView(
        model: FileDisplayModel(
          fileName: pinnedFile.name,
          filePath: pinnedFile.path,
          lineRange: nil,
          isRemovable: true
        ),
        onRemove: {
          // Unpin and clear the pinned file
          contextManager.unpinActiveFile()
        },
        isPinned: true,
        onTogglePin: {
          contextManager.togglePinActiveFile()
        }
      )
    } else if let activeFile = xcodeObservationViewModel.workspaceModel.activeFile {
      // Show the current active file with option to pin it
      ActiveFileView(
        model: FileDisplayModel(
          fileName: activeFile.name,
          filePath: activeFile.path,
          lineRange: nil,
          isRemovable: true
        ),
        onRemove: {
          // Dismiss the active file and prevent re-observation
          xcodeObservationViewModel.dismissActiveFile()
        },
        isPinned: false,
        onTogglePin: {
          contextManager.togglePinActiveFile()
        }
      )
    }
  }
  
  /// Divider between active file and selections
  @ViewBuilder
  private var contextDivider: some View {
    if xcodeObservationViewModel.workspaceModel.activeFile != nil && !contextManager.context.codeSelections.isEmpty {
      Divider()
        .frame(height: 16)
    }
  }
  
  /// Code selection chips
  private var codeSelectionChips: some View {
    ForEach(contextManager.context.codeSelections) { selection in
      ActiveFileView(
        model: .selection(selection),
        onRemove: {
          contextManager.removeSelection(id: selection.id)
        }
      )
    }
  }
}

// MARK: - Helper Properties

extension ChatInputView {
  
  /// Check if text is empty
  private var isTextEmpty: Bool {
    text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
  
  /// Check if context bar should be shown
  private var shouldShowContextBar: Bool {
    xcodeObservationViewModel.workspaceModel.activeFile != nil || !contextManager.context.codeSelections.isEmpty
  }
  
  /// Allowed file types for import
  private var allowedFileTypes: [UTType] {
    [.folder, .image, .pdf, .text, .plainText, .sourceCode, .data, .item]
  }
  
  /// Trimmed text without whitespace
  private var trimmedText: String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
  }
  
  /// Formatted context from context manager
  private var formattedContext: String? {
    contextManager.hasContext ? contextManager.getFormattedContext() : nil
  }
  
  /// Hidden context with active file info
  private var hiddenContext: String? {
    guard let activeFile = xcodeObservationViewModel.workspaceModel.activeFile else { return nil }
    return "Currently viewing: \(activeFile.path)"
  }
}

// MARK: - Actions

extension ChatInputView {
  
  /// Send message to the chat
  private func sendMessage() {
    guard !trimmedText.isEmpty else { return }
    
    if viewModel.projectPath.isEmpty {
      showingProjectPathAlert = true
      return
    }
    
    // Get current code selections from context manager
    var allSelections = contextManager.context.codeSelections
    
    // Add active file as a selection if present
    if let activeFile = xcodeObservationViewModel.workspaceModel.activeFile {
      // Create a TextSelection for the active file to display as a pill
      let activeFileSelection = TextSelection(
        filePath: activeFile.path,
        selectedText: "", // Empty since we're just showing the file, not a selection
        lineRange: 0...0,  // No specific line range
        columnRange: nil
      )
      allSelections.append(activeFileSelection)
    }
    
    let codeSelections = allSelections.isEmpty ? nil : allSelections
    
    // Include attachments if any
    let messageAttachments = attachments.isEmpty ? nil : attachments
    
    viewModel.sendMessage(trimmedText, context: formattedContext, hiddenContext: hiddenContext, codeSelections: codeSelections, attachments: messageAttachments)
    DispatchQueue.main.async {
      self.text = ""
      // Clear context and attachments after sending
      contextManager.clearAll()
      self.attachments.removeAll()
    }
  }
}

// MARK: - File Handling

extension ChatInputView {
  
  /// Handle file import from file picker
  private func handleFileImport(_ result: Result<[URL], Error>) {
    switch result {
    case .success(let urls):
      Task {
        for url in urls {
          var isDirectory: ObjCBool = false
          if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
              await handleDroppedFolder(url)
            } else {
              let attachment = FileAttachment(url: url)
              attachments.append(attachment)
              await processor.process(attachment)
            }
          }
        }
      }
    case .failure(let error):
      print("Failed to import files: \(error)")
    }
  }
  
  /// Handle dropped item providers
  private func handleDroppedProviders(_ providers: [NSItemProvider]) {
    Task {
      for provider in providers {
        // Try to load as file URL first (this handles both files and folders)
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
          _ = provider.loadObject(ofClass: URL.self) { url, error in
            guard let url = url, error == nil else { return }
            
            Task { @MainActor in
              // Check if it's a directory
              var isDirectory: ObjCBool = false
              if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                  // Handle folder
                  await handleDroppedFolder(url)
                } else {
                  // Handle single file
                  // Check if it's a screenshot from temporary directory
                  let isScreenshot = url.path.contains("TemporaryItems") || url.path.contains("screencaptureui")
                  let attachment = FileAttachment(url: url, isTemporary: isScreenshot)
                  attachments.append(attachment)
                  await processor.process(attachment)
                }
              }
            }
          }
        }
        // If not a file URL, try to load as PNG data (for screenshots)
        else if provider.hasItemConformingToTypeIdentifier(UTType.png.identifier) {
          _ = provider.loadDataRepresentation(for: .png) { data, error in
            guard let data = data, error == nil else { return }
            
            Task { @MainActor in
              // Save PNG data to temporary file
              let tempDirectory = FileManager.default.temporaryDirectory
              let fileName = "screenshot_\(UUID().uuidString).png"
              let tempURL = tempDirectory.appendingPathComponent(fileName)
              
              do {
                try data.write(to: tempURL)
                let attachment = FileAttachment(url: tempURL, isTemporary: true)
                attachments.append(attachment)
                await processor.process(attachment)
              } catch {
                print("Failed to save dropped screenshot: \(error)")
              }
            }
          }
        }
        // Try TIFF data (another common screenshot format)
        else if provider.hasItemConformingToTypeIdentifier(UTType.tiff.identifier) {
          _ = provider.loadDataRepresentation(for: .tiff) { data, error in
            guard let data = data, error == nil else { return }
            
            Task { @MainActor in
              // Save TIFF data to temporary file
              let tempDirectory = FileManager.default.temporaryDirectory
              let fileName = "screenshot_\(UUID().uuidString).tiff"
              let tempURL = tempDirectory.appendingPathComponent(fileName)
              
              do {
                try data.write(to: tempURL)
                let attachment = FileAttachment(url: tempURL, isTemporary: true)
                attachments.append(attachment)
                await processor.process(attachment)
              } catch {
                print("Failed to save dropped screenshot: \(error)")
              }
            }
          }
        }
        // Finally, try generic image data
        else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
          _ = provider.loadDataRepresentation(for: .image) { data, error in
            guard let data = data, error == nil else { return }
            
            Task { @MainActor in
              // Save image data to temporary file
              let tempDirectory = FileManager.default.temporaryDirectory
              let fileName = "dropped_image_\(UUID().uuidString).png"
              let tempURL = tempDirectory.appendingPathComponent(fileName)
              
              do {
                try data.write(to: tempURL)
                let attachment = FileAttachment(url: tempURL, isTemporary: true)
                attachments.append(attachment)
                await processor.process(attachment)
              } catch {
                print("Failed to save dropped image: \(error)")
              }
            }
          }
        }
      }
    }
  }
  
  /// Handle dropped folder
  @MainActor
  private func handleDroppedFolder(_ folderURL: URL) async {
    // Collect files synchronously first
    let filesToAdd = collectFilesFromFolder(folderURL)
    
    // Add files to attachments asynchronously
    for fileURL in filesToAdd {
      let attachment = FileAttachment(url: fileURL)
      attachments.append(attachment)
      await processor.process(attachment)
    }
  }
  
  /// Collect files from folder recursively
  private func collectFilesFromFolder(_ folderURL: URL) -> [URL] {
    let fileManager = FileManager.default
    
    // Get all files in the folder recursively
    guard let enumerator = fileManager.enumerator(
      at: folderURL,
      includingPropertiesForKeys: [.isRegularFileKey, .isHiddenKey],
      options: [.skipsHiddenFiles, .skipsPackageDescendants]
    ) else { return [] }
    
    var filesToAdd: [URL] = []
    
    for case let fileURL as URL in enumerator {
      do {
        let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .isHiddenKey])
        
        // Only add regular files (not directories or special files)
        if let isRegularFile = resourceValues.isRegularFile, isRegularFile,
           let isHidden = resourceValues.isHidden, !isHidden {
          
          // Skip system files
          let fileName = fileURL.lastPathComponent
          if !isSystemFile(fileName) {
            filesToAdd.append(fileURL)
          }
        }
      } catch {
        print("Error checking file properties: \(error)")
      }
    }
    
    return filesToAdd
  }
  
  /// Check if file is a system file
  private func isSystemFile(_ fileName: String) -> Bool {
    let systemFiles = [".DS_Store", ".localized", "Thumbs.db", "desktop.ini", ".git", ".svn"]
    return systemFiles.contains(fileName) || fileName.hasPrefix("~$")
  }
}

// MARK: - File Search

extension ChatInputView {
  
  /// Detect @ mention in text and trigger file search
  private func detectAtMention(oldText: String, newText: String) {
    // Prevent recursive updates
    guard !isUpdatingFileSearch else {
      return
    }
    
    // If text was deleted and we're showing search, check if @ was deleted
    if showingFileSearch && newText.count < oldText.count {
      // Check if the @ character is still present at the search location
      if let searchRange = fileSearchRange {
        let nsString = newText as NSString
        if searchRange.location >= nsString.length ||
            (searchRange.location < nsString.length && nsString.character(at: searchRange.location) != 64) { // 64 is @
          dismissFileSearch()
          return
        }
      }
    }
    
    // Check if @ was just typed
    let oldCount = oldText.filter { $0 == "@" }.count
    let newCount = newText.filter { $0 == "@" }.count
    
    if newCount > oldCount {
      // Find the position of the newly typed @
      if let atIndex = findNewAtPosition(oldText: oldText, newText: newText) {
        // Start file search
        fileSearchRange = NSRange(location: atIndex, length: 1)
        showingFileSearch = true
        fileSearchViewModel?.startSearch(query: "")
      }
    } else if showingFileSearch && !newText.isEmpty {
      // Update search query if we're already searching
      updateFileSearchQuery()
    } else if newText.isEmpty && showingFileSearch {
      // All text deleted, dismiss search
      dismissFileSearch()
    }
  }
  
  /// Find position of newly typed @ character
  private func findNewAtPosition(oldText: String, newText: String) -> Int? {
    let oldChars = Array(oldText)
    let newChars = Array(newText)
    
    // Find where the texts differ
    var i = 0
    while i < oldChars.count && i < newChars.count && oldChars[i] == newChars[i] {
      i += 1
    }
    
    // Check if @ was inserted at position i
    if i < newChars.count && newChars[i] == "@" {
      return i
    }
    
    return nil
  }
  
  /// Update file search query based on text after @
  private func updateFileSearchQuery() {
    guard let searchRange = fileSearchRange else { return }
    
    // Validate search range
    let nsString = text as NSString
    guard searchRange.location < nsString.length else {
      dismissFileSearch()
      return
    }
    
    // The search range starts at @ character
    let atLocation = searchRange.location
    
    // Find the end of the search query (until space, newline, or end of text)
    var queryEnd = atLocation + 1 // Start after the @ symbol
    while queryEnd < nsString.length {
      let char = nsString.character(at: queryEnd)
      if char == 32 || char == 10 { // space or newline
        break
      }
      queryEnd += 1
    }
    
    // Extract the full query after @ (not including @)
    let queryStart = atLocation + 1
    let queryLength = queryEnd - queryStart
    
    if queryStart <= nsString.length && queryLength >= 0 && queryStart + queryLength <= nsString.length {
      let query = nsString.substring(with: NSRange(location: queryStart, length: queryLength))
      fileSearchViewModel?.searchQuery = query
      
      // Update the search range to include @ and the query
      fileSearchRange = NSRange(location: atLocation, length: queryEnd - atLocation)
    }
  }
  
  /// Insert selected file reference into text
  private func insertFileReference(_ result: FileResult) {
    guard let searchRange = fileSearchRange else { return }
    
    // Validate that the range is still valid
    let nsString = text as NSString
    guard searchRange.location >= 0,
          searchRange.location + searchRange.length <= nsString.length else {
      dismissFileSearch()
      return
    }
    
    // Set flag to prevent onChange from triggering file search
    isUpdatingFileSearch = true
    
    // Replace the @query with @filename
    let replacement = "@\(result.fileName) "
    let newText = nsString.replacingCharacters(in: searchRange, with: replacement)
    text = newText
    
    // Add file to context
    contextManager.addFile(result.fileInfo)
    
    // Dismiss search
    dismissFileSearch()
    
    // Reset flag after a short delay
    DispatchQueue.main.async {
      self.isUpdatingFileSearch = false
    }
  }
  
  /// Dismiss file search and clear state
  private func dismissFileSearch() {
    showingFileSearch = false
    fileSearchRange = nil
    fileSearchViewModel?.clearSearch()
  }
}

// MARK: - Command Search

extension ChatInputView {
  
  /// Detect / at start of message and trigger command search
  private func detectSlashCommand(oldText: String, newText: String) {
    // Prevent recursive updates
    guard !isUpdatingCommandSearch else {
      return
    }
    
    // If text was deleted and we're showing search, check if / was deleted
    if showingCommandSearch && newText.count < oldText.count {
      // Check if the / character is still present at the search location
      if let searchRange = commandSearchRange {
        let nsString = newText as NSString
        if searchRange.location >= nsString.length ||
            (searchRange.location < nsString.length && nsString.character(at: searchRange.location) != 47) { // 47 is /
          dismissCommandSearch()
          return
        }
      }
    }
    
    // Check if / was just typed at the start of the message
    let oldCount = oldText.filter { $0 == "/" }.count
    let newCount = newText.filter { $0 == "/" }.count
    
    if newCount > oldCount {
      // Find the position of the newly typed /
      if let slashIndex = findNewSlashPosition(oldText: oldText, newText: newText) {
        // Only trigger if / is at the start (position 0) or after a newline
        if slashIndex == 0 || (slashIndex > 0 && newText[newText.index(newText.startIndex, offsetBy: slashIndex - 1)] == "\n") {
          // Initialize command search view model if needed
          if commandSearchViewModel == nil {
            commandSearchViewModel = CommandSearchViewModel(projectPath: viewModel.projectPath)
          }
          
          // Start command search
          commandSearchRange = NSRange(location: slashIndex, length: 1)
          showingCommandSearch = true
          commandSearchViewModel?.startSearch(query: "")
        }
      }
    } else if showingCommandSearch && !newText.isEmpty {
      // Update search query if we're already searching
      updateCommandSearchQuery()
    } else if newText.isEmpty && showingCommandSearch {
      // All text deleted, dismiss search
      dismissCommandSearch()
    }
  }
  
  /// Find position of newly typed / character
  private func findNewSlashPosition(oldText: String, newText: String) -> Int? {
    let oldChars = Array(oldText)
    let newChars = Array(newText)
    
    // Find where the texts differ
    var i = 0
    while i < oldChars.count && i < newChars.count && oldChars[i] == newChars[i] {
      i += 1
    }
    
    // Check if / was inserted at position i
    if i < newChars.count && newChars[i] == "/" {
      return i
    }
    
    return nil
  }
  
  /// Update command search query based on text after /
  private func updateCommandSearchQuery() {
    guard let searchRange = commandSearchRange else { return }
    
    // Validate search range
    let nsString = text as NSString
    guard searchRange.location < nsString.length else {
      dismissCommandSearch()
      return
    }
    
    // The search range starts at / character
    let slashLocation = searchRange.location
    
    // Find the end of the search query (until space, newline, or end of text)
    var queryEnd = slashLocation + 1 // Start after the / symbol
    while queryEnd < nsString.length {
      let char = nsString.character(at: queryEnd)
      if char == 32 || char == 10 { // space or newline
        break
      }
      queryEnd += 1
    }
    
    // Extract the full query after / (not including /)
    let queryStart = slashLocation + 1
    let queryLength = queryEnd - queryStart
    
    if queryStart <= nsString.length && queryLength >= 0 && queryStart + queryLength <= nsString.length {
      let query = nsString.substring(with: NSRange(location: queryStart, length: queryLength))
      commandSearchViewModel?.searchQuery = query
      
      // Update the search range to include / and the query
      commandSearchRange = NSRange(location: slashLocation, length: queryEnd - slashLocation)
    }
  }
  
  /// Insert selected command into text
  private func insertCommand(_ result: CommandResult) {
    guard let searchRange = commandSearchRange else { return }
    
    // Validate that the range is still valid
    let nsString = text as NSString
    guard searchRange.location >= 0,
          searchRange.location + searchRange.length <= nsString.length else {
      dismissCommandSearch()
      return
    }
    
    // Set flag to prevent onChange from triggering command search
    isUpdatingCommandSearch = true
    
    // Replace the /query with /command-name followed by space
    let replacement = result.displayName + " "
    let newText = nsString.replacingCharacters(in: searchRange, with: replacement)
    text = newText
    
    // Dismiss search
    dismissCommandSearch()
    
    // Reset flag after a short delay
    DispatchQueue.main.async {
      self.isUpdatingCommandSearch = false
    }
  }
  
  /// Dismiss command search and clear state
  private func dismissCommandSearch() {
    showingCommandSearch = false
    commandSearchRange = nil
    commandSearchViewModel?.clearSearch()
  }

}

// MARK: - VoiceModeOption to CodeWhisperConfiguration Mapping

extension Array where Element == VoiceModeOption {
  /// Converts an array of VoiceModeOption to CodeWhisperConfiguration
  var toCodeWhisperConfiguration: CodeWhisperConfiguration {
    let voiceModes = self.map { option -> VoiceMode in
      switch option {
      case .stt: return .stt
      case .sttWithTTS: return .sttWithTTS
      case .realtime: return .realtime
      }
    }
    return CodeWhisperConfiguration(availableVoiceModes: voiceModes)
  }
}

