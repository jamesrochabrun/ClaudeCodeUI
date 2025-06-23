//
//  ChatInputView.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 6/7/2025.
//

import SwiftUI
import ClaudeCodeSDK
import PermissionsServiceInterface

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
      HStack {
        sessionsButton
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
    .alert("No Working Directory Selected", isPresented: $showingProjectPathAlert) {
      workingDirectoryAlertButtons
    } message: {
      Text("Please select a working directory before starting a conversation. This helps Claude understand the context of your project.")
    }
    .sheet(isPresented: $showingSettings) {
      settingsSheet
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
      .stroke(Color(NSColor.separatorColor), lineWidth: 1)
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
    
    viewModel.sendMessage(trimmedText, context: formattedContext, hiddenContext: hiddenContext)
    DispatchQueue.main.async {
      self.text = ""
    }
  }
}

