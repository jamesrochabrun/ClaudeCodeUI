//
//  ChatScreen.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 5/25/25.
//

import ClaudeCodeSDK
import Foundation
import SwiftUI
import PermissionsServiceInterface
import TerminalServiceInterface
import KeyboardShortcuts

struct ChatScreen: View {
  
  init(viewModel: ChatViewModel, contextManager: ContextManager, xcodeObservationViewModel: XcodeObservationViewModel, permissionsService: PermissionsService, terminalService: TerminalService) {
    self.viewModel = viewModel
    self.contextManager = contextManager
    self.xcodeObservationViewModel = xcodeObservationViewModel
    self.permissionsService = permissionsService
    self.terminalService = terminalService
  }
  
  @State var viewModel: ChatViewModel
  @State var contextManager: ContextManager
  let xcodeObservationViewModel: XcodeObservationViewModel
  let permissionsService: PermissionsService
  let terminalService: TerminalService
  @State private var messageText: String = ""
  @State var showingSettings = false
  @State private var keyboardManager = KeyboardShortcutManager()
  @State var hasShownAutoDetectionAlert = false
  @State var detectedProjectPath: String?
  @State var showingPathDetectionAlert = false
  
  var body: some View {
    VStack {
      // Always show the messages list (WelcomeRow will handle empty state)
      messagesListView
      
      // Error message if present
      if let error = viewModel.error {
        HStack {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundColor(.red)
          Text(error.localizedDescription)
            .foregroundColor(.red)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
          Spacer()
          Button(action: {
            viewModel.error = nil
          }) {
            Image(systemName: "xmark.circle.fill")
              .foregroundColor(.secondary)
          }
          .buttonStyle(.plain)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.bottom, 8)
      }
      // Loading indicator
      if viewModel.isLoading, let startTime = viewModel.streamingStartTime {
        LoadingIndicator(
          startTime: startTime,
          inputTokens: viewModel.currentInputTokens,
          outputTokens: viewModel.currentOutputTokens,
          costUSD: viewModel.currentCostUSD
        )
        .padding(.horizontal)
        .padding(.bottom, 8)
        .transition(.asymmetric(
          insertion: .move(edge: .bottom).combined(with: .opacity),
          removal: .move(edge: .bottom).combined(with: .opacity)
        ))
      }
      
      ChatInputView(
        text: $messageText,
        chatViewModel: $viewModel,
        contextManager: contextManager,
        xcodeObservationViewModel: xcodeObservationViewModel,
        permissionsService: permissionsService,
        placeholder: "Type a message...")
    }
    .navigationTitle("Claude Code Chat")
    .toolbar {
      ToolbarItem(placement: .automatic) {
        Button(action: clearChat) {
          Image(systemName: "trash")
            .font(.title2)
        }
        .disabled(viewModel.messages.isEmpty)
      }
    }
    .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
    .sheet(isPresented: $showingSettings) {
      SettingsView(chatViewModel: viewModel, xcodeObservationViewModel: xcodeObservationViewModel, permissionsService: permissionsService)
    }
    .alert("Working Directory Detected", isPresented: $showingPathDetectionAlert) {
      Button("Accept") {
        if let detectedPath = detectedProjectPath {
          viewModel.claudeClient.configuration.workingDirectory = detectedPath
          viewModel.settingsStorage.setProjectPath(detectedPath)
          if let sessionId = viewModel.currentSessionId {
            viewModel.settingsStorage.setProjectPath(detectedPath, forSessionId: sessionId)
          }
          viewModel.refreshProjectPath()
        }
      }
      Button("Cancel", role: .cancel) {
        // User declined - will show the settings button
      }
    } message: {
      if let detectedPath = detectedProjectPath {
        Text("Claude Code UI has detected the following working directory:\n\n\(detectedPath)\n\nWould you like to use this as your working directory?")
      }
    }
    .onChange(of: keyboardManager.capturedText) { oldValue, newValue in
      if !newValue.isEmpty && newValue != oldValue {
        // First try to capture from Xcode if available
        if contextManager.captureCurrentSelection() != nil {
          // Successfully captured from Xcode, ignore clipboard text
        } else {
          // No Xcode selection, use clipboard text
          contextManager.addCapturedText(newValue)
        }
      }
    }
  }
  
  private func clearChat() {
    viewModel.clearConversation()
  }
  
  func checkForAutoDetection() {
    // Only check if we haven't shown the alert and don't have a manual path
    if !hasShownAutoDetectionAlert && viewModel.projectPath.isEmpty {
      if xcodeObservationViewModel.hasAccessibilityPermission,
         let projectRoot = xcodeObservationViewModel.getProjectRootPath() {
        detectedProjectPath = projectRoot
        hasShownAutoDetectionAlert = true
        showingPathDetectionAlert = true
      }
    }
  }
}
