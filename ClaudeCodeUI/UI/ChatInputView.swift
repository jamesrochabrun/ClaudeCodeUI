//
//  ChatInputView.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 6/7/2025.
//

import SwiftUI
import ClaudeCodeSDK
import PermissionsServiceInterface
import UniformTypeIdentifiers

struct ChatInputView: View {
  
  // MARK: - Properties
  
  @Binding var text: String
  @Binding var viewModel: ChatViewModel
  let contextManager: ContextManager
  let xcodeObservationViewModel: XcodeObservationViewModel
  let permissionsService: PermissionsService
  
  @FocusState private var isFocused: Bool
  let placeholder: String
  @State private var shouldSubmit = false
  @State private var showingSessionsList = false
  @State private var showingProjectPathAlert = false
  @State private var showingSettings = false
  @State private var attachments: [FileAttachment] = []
  @State private var isDragging = false
  @State private var showingFilePicker = false
  
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
    placeholder: String = "Type a message...")
  {
    _text = text
    _viewModel = chatViewModel
    self.contextManager = contextManager
    self.xcodeObservationViewModel = xcodeObservationViewModel
    self.permissionsService = permissionsService
    self.placeholder = placeholder
  }
  // MARK: - Body
  
  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      if shouldShowContextBar {
        contextBar
      }
      if !attachments.isEmpty {
        AttachmentListView(attachments: $attachments)
          .padding(.horizontal, 8)
          .padding(.top, 4)
      }
      HStack {
        sessionsButton
        attachmentButton
        textEditor
        actionButton
      }
    }
    .background(Color(NSColor.controlBackgroundColor))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .overlay(inputBorder)
    .padding(.horizontal, 12)
    .padding(.bottom, 12)
    .animation(.easeInOut(duration: 0.2), value: xcodeObservationViewModel.workspaceModel.activeFile?.name)
    .animation(.easeInOut(duration: 0.2), value: contextManager.context.codeSelections.count)
    .onAppear {
      xcodeObservationViewModel.refresh()
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
  
  private var sessionsButton: some View {
    Button(action: {
      showingSessionsList = true
    }) {
      Image(systemName: "list.bullet")
        .foregroundColor(.gray)
    }
    .buttonStyle(.plain)
    .padding(.leading, 8)
    .popover(isPresented: $showingSessionsList) {
      SessionsListView(viewModel: $viewModel)
        .frame(width: 300, height: 400)
    }
  }
  
  private var attachmentButton: some View {
    Button(action: {
      showingFilePicker = true
    }) {
      Image(systemName: "paperclip")
        .foregroundColor(.gray)
    }
    .buttonStyle(.plain)
    .help("Attach files")
  }
  
  private var actionButton: some View {
    Group {
      if viewModel.isLoading {
        cancelButton
      } else {
        sendButton
      }
    }
  }
  
  private var cancelButton: some View {
    Button(action: {
      viewModel.cancelRequest()
    }) {
      Image(systemName: "stop.fill")
    }
    .padding(10)
    .buttonStyle(.plain)
  }
  
  private var sendButton: some View {
    Button(action: {
      sendMessage()
    }) {
      Image(systemName: "arrow.up.circle.fill")
        .foregroundColor(.kraft)
        .font(.title2)
    }
    .padding(10)
    .buttonStyle(.plain)
    .disabled(isTextEmpty)
  }
  
  private var inputBorder: some View {
    RoundedRectangle(cornerRadius: 12)
      .stroke(isDragging ? Color.accentColor : Color(NSColor.separatorColor), lineWidth: isDragging ? 2 : 1)
      .animation(.easeInOut(duration: 0.2), value: isDragging)
  }
  
  private var workingDirectoryAlertButtons: some View {
    Group {
      Button("Open Settings") {
        showingSettings = true
      }
      Button("Cancel", role: .cancel) {}
    }
  }
  
  private var settingsSheet: some View {
    SettingsView(
      chatViewModel: viewModel,
      xcodeObservationViewModel: xcodeObservationViewModel,
      permissionsService: permissionsService
    )
    .frame(width: 700, height: 550)
  }
  
  private var isTextEmpty: Bool {
    text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
  
  private var shouldShowContextBar: Bool {
    xcodeObservationViewModel.workspaceModel.activeFile != nil || !contextManager.context.codeSelections.isEmpty
  }
  
  private var allowedFileTypes: [UTType] {
    [.folder, .image, .pdf, .text, .plainText, .sourceCode, .data, .item]
  }
  
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
  
  @ViewBuilder
  private var activeFileChip: some View {
    if let activeFile = xcodeObservationViewModel.workspaceModel.activeFile {
      ActiveFileView(model: .activeFile(activeFile))
        .onTapGesture {
          contextManager.addFile(activeFile)
        }
    }
  }
  
  @ViewBuilder
  private var contextDivider: some View {
    if xcodeObservationViewModel.workspaceModel.activeFile != nil && !contextManager.context.codeSelections.isEmpty {
      Divider()
        .frame(height: 16)
    }
  }
  
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
        .onKeyPress(.return) {
          sendMessage()
          return .handled
        }
        .onKeyPress(.escape) {
          if viewModel.isLoading {
            viewModel.cancelRequest()
            return .handled
          }
          return .ignored
        }
        .overlay {
          Color.clear
            .allowsHitTesting(true)
            .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
              handleDroppedProviders(providers)
              return true
            }
            .dropDestination(for: Data.self) { items, _ in
              // Handle raw data drops (e.g., images from web browsers)
              Task { @MainActor in
                for data in items {
                  // Save data to temporary file
                  let tempDirectory = FileManager.default.temporaryDirectory
                  let fileName = "dropped_file_\(UUID().uuidString)"
                  let tempURL = tempDirectory.appendingPathComponent(fileName)
                  
                  do {
                    try data.write(to: tempURL)
                    let attachment = FileAttachment(url: tempURL, isTemporary: true)
                    attachments.append(attachment)
                    await processor.process(attachment)
                  } catch {
                    print("Failed to save dropped data: \(error)")
                  }
                }
              }
              return true
            }
        }
      
      if text.isEmpty {
        placeholderView
          .padding(textAreaEdgeInsets)
          .padding(.leading, 4)
      }
    }
  }
  
  // MARK: - Private Views
  
  private var placeholderView: some View {
    Text(placeholder)
      .font(.body)
      .foregroundColor(.gray)
      .frame(maxWidth: .infinity, alignment: .leading)
      .onTapGesture {
        isFocused = true
      }
  }
  
  // MARK: - Helper Computed Properties
  
  private var trimmedText: String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
  }
  
  private var formattedContext: String? {
    contextManager.hasContext ? contextManager.getFormattedContext() : nil
  }
  
  private var hiddenContext: String? {
    guard let activeFile = xcodeObservationViewModel.workspaceModel.activeFile else { return nil }
    return "Currently viewing: \(activeFile.path)"
  }
  
  // MARK: - Actions
  
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
  
  // MARK: - File Handling
  
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
  
  
  private func handleDroppedProviders(_ providers: [NSItemProvider]) {
    Task {
      for provider in providers {
        // Try to load as file URL (this should handle both files and folders)
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
                  let attachment = FileAttachment(url: url)
                  attachments.append(attachment)
                  await processor.process(attachment)
                }
              }
            }
          }
        }
        // Try to load as image data
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
  
  private func isSystemFile(_ fileName: String) -> Bool {
    let systemFiles = [".DS_Store", ".localized", "Thumbs.db", "desktop.ini", ".git", ".svn"]
    return systemFiles.contains(fileName) || fileName.hasPrefix("~$")
  }
}

