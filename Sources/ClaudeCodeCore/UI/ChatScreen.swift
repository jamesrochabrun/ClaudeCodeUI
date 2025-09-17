//
//  ChatScreen.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 5/25/25.
//

import ClaudeCodeSDK
import Foundation
import SwiftUI
import AppKit
import CCPermissionsServiceInterface
import CCTerminalServiceInterface
import KeyboardShortcuts
import CCCustomPermissionServiceInterface
import CCCustomPermissionService

/// Main chat interface view that displays the conversation and input controls.
/// 
/// `ChatScreen` serves as the primary user interface for chat interactions with Claude.
/// It manages the display of messages, handles user input, coordinates with various services,
/// and provides a complete chat experience including:
/// - Message history with support for different message types (user, assistant, tool use)
/// - Real-time streaming of responses with token counting
/// - Context management from Xcode and other sources
/// - Permission approval workflows for sensitive operations
/// - Settings management (both session and global)
/// - Artifact viewing for generated content
/// 
/// This view can be used directly for custom UI implementations without requiring RootView.
/// It's designed to be flexible and configurable through the `UIConfiguration` parameter.
public struct ChatScreen: View {
  
  /// Defines the type of settings to display in the settings sheet
  public enum SettingsType {
    /// Session-specific settings (project path, model, etc.)
    case session
    /// Global application settings
    case global
  }
  
  /// Creates a new ChatScreen instance.
  /// - Parameters:
  ///   - viewModel: The chat view model managing conversation state
  ///   - contextManager: Manages context information from various sources
  ///   - xcodeObservationViewModel: View model for Xcode observation data
  ///   - permissionsService: Service managing app permissions
  ///   - terminalService: Service for terminal operations
  ///   - customPermissionService: Service for custom permission management
  ///   - columnVisibility: Binding to control navigation split view visibility
  ///   - uiConfiguration: UI configuration settings
  public init(viewModel: ChatViewModel, contextManager: ContextManager, xcodeObservationViewModel: XcodeObservationViewModel, permissionsService: PermissionsService, terminalService: TerminalService, customPermissionService: CustomPermissionService, columnVisibility: Binding<NavigationSplitViewVisibility>, uiConfiguration: UIConfiguration = .default) {
    self.viewModel = viewModel
    self.contextManager = contextManager
    self.xcodeObservationViewModel = xcodeObservationViewModel
    self.permissionsService = permissionsService
    self.terminalService = terminalService
    _customPermissionService = State(initialValue: customPermissionService)
    _columnVisibility = columnVisibility
    self.uiConfiguration = uiConfiguration
  }
  
  /// The view model managing the chat conversation state, messages, and streaming
  /// Handles all chat-related business logic including API interactions
  @State var viewModel: ChatViewModel
  
  /// Manages context information from various sources (Xcode, clipboard, etc.)
  /// Responsible for capturing and providing contextual data to enhance chat interactions
  @State var contextManager: ContextManager
  
  /// View model that observes and tracks Xcode state and active projects
  /// Provides integration with Xcode IDE for context-aware assistance
  let xcodeObservationViewModel: XcodeObservationViewModel
  
  /// Service managing system-level permissions (file system, network, etc.)
  /// Ensures safe execution of operations requiring elevated privileges
  let permissionsService: PermissionsService
  
  /// Service for executing terminal commands and managing shell operations
  /// Provides interface for running shell scripts and terminal commands
  let terminalService: TerminalService
  
  /// Service managing custom permission requests with approval UI
  /// Handles user approval flow for potentially risky operations
  @State var customPermissionService: CustomPermissionService
  
  /// Configuration object defining UI appearance and behavior
  /// Includes settings like app name, theme, and feature toggles
  let uiConfiguration: UIConfiguration
  
  /// Binding controlling the visibility of navigation split view columns
  /// Used to toggle sidebar visibility in the navigation interface
  @Binding var columnVisibility: NavigationSplitViewVisibility
  
  /// The current text in the message input field
  /// Bound to the ChatInputView for user text entry
  @State private var messageText: String = ""
  
  /// Controls the visibility of the settings sheet
  @State var showingSettings = false
  
  /// Determines which type of settings to display (session or global)
  @State var settingsTypeToShow: SettingsType = .session
  
  /// Manages keyboard shortcuts and captures text from external sources
  @State private var keyboardManager = KeyboardShortcutManager()
  
  /// Triggers focus on the text editor when keyboard shortcuts are activated
  @State private var triggerTextEditorFocus = false
  
  /// Currently selected artifact for viewing in a sheet
  /// Set when user clicks on an artifact in a message
  @State var artifact: Artifact? = nil
  
  /// Tracks whether the session ID has been copied to clipboard
  /// Used for visual feedback on the copy button
  @State private var isCopied = false
  
  public var body: some View {
    VStack {
      // Always show the messages list (WelcomeRow will handle empty state)
      messagesListView
        .padding(.bottom, 8)
      
      // Loading indicator
      loadingView
      
      ChatInputView(
        text: $messageText,
        chatViewModel: $viewModel,
        contextManager: contextManager,
        xcodeObservationViewModel: xcodeObservationViewModel,
        permissionsService: permissionsService,
        triggerFocus: $triggerTextEditorFocus)
    }
    .overlay(approvalToastOverlay)
    .overlay(
      errorToastOverlay
        .zIndex(999) // Ensure error toast is on top
    )
    .navigationTitle(uiConfiguration.appName)
    .toolbar {
      ToolbarItem(placement: .automatic) {
        toolbarContent
      }
      // #if DEBUG
      // ToolbarItem(placement: .automatic) {
      //   Button("Test Error") {
      //     let testError = NSError(
      //       domain: "TestDomain",
      //       code: 999,
      //       userInfo: [NSLocalizedDescriptionKey: "Test error to verify toast display"]
      //     )
      //     viewModel.handleError(testError, operation: .apiCall)
      //   }
      // }
      // #endif
    }
    .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
    .sheet(isPresented: $showingSettings) {
      settingsSheet
    }
    .sheet(item: $artifact) { artifact in
      ArtifactView(artifact: artifact)
    }
    .onChange(of: keyboardManager.capturedText, keyboardTextChanged)
    .onChange(of: keyboardManager.shouldFocusTextEditor, focusTextEditorChanged)
    .focusedValue(\.toggleSidebar, toggleSidebar)
  }
  
  // MARK: - Subviews
  
  @ViewBuilder
  private var errorToastOverlay: some View {
    ErrorToastContainer(
      errorQueue: $viewModel.errorQueue,
      onRetry: {
        // Clear error and retry last operation if possible
        if let lastMessage = viewModel.messages.last(where: { $0.role == .user }) {
          viewModel.sendMessage(lastMessage.content)
        }
      }
    )
  }
  
  @ViewBuilder
  private var loadingView: some View {
    let isToastVisible = (customPermissionService as? DefaultCustomPermissionService)?.isToastVisible ?? false
    if viewModel.isLoading, !isToastVisible, let startTime = viewModel.streamingStartTime {
      LoadingIndicator(
        startTime: startTime,
        inputTokens: viewModel.currentInputTokens,
        outputTokens: viewModel.currentOutputTokens,
        costUSD: viewModel.currentCostUSD,
        showTokenCount: uiConfiguration.showTokenCount
      )
      .padding(.horizontal)
      .padding(.bottom, 8)
      .transition(.asymmetric(
        insertion: .move(edge: .bottom).combined(with: .opacity),
        removal: .move(edge: .bottom).combined(with: .opacity)
      ))
    }
  }
  
  @ViewBuilder
  private var approvalToastOverlay: some View {
    if let permissionService = customPermissionService as? DefaultCustomPermissionService {
      ToastContainer(isPresented: .constant(permissionService.isToastVisible)) {
        if let request = permissionService.currentToastRequest {
        ApprovalToast(
          request: request,
          showRiskData: uiConfiguration.showRiskData,
          queueCount: permissionService.approvalQueue.count,
          onApprove: {
            permissionService.approveCurrentToast()
            // Find and collapse the tool message that was just approved
            if let toolMessage = findCurrentToolMessage() {
              viewModel.messageExpansionStates[toolMessage.id] = false
            }
          },
          onDeny: {
            permissionService.denyCurrentToast()
            // Find and collapse the tool message that was just denied
            if let toolMessage = findCurrentToolMessage() {
              viewModel.messageExpansionStates[toolMessage.id] = false
            }
          },
          onDenyWithGuidance: { guidance in
            permissionService.denyCurrentToastWithGuidance(guidance)
            // Find and collapse the tool message that was just denied
            if let toolMessage = findCurrentToolMessage() {
              viewModel.messageExpansionStates[toolMessage.id] = false
            }
          },
          onCancel: {
            // Cancel the stream entirely - same as pressing escape
            viewModel.cancelRequest()
            // Also hide the toast
            permissionService.denyCurrentToast()
            // Find and collapse the tool message that was just cancelled
            if let toolMessage = findCurrentToolMessage() {
              viewModel.messageExpansionStates[toolMessage.id] = false
            }
          }
        )
      }
    }
    }
  }
  
  /// Find the most recent tool message that matches the current approval request
  private func findCurrentToolMessage() -> ChatMessage? {
    guard let permissionService = customPermissionService as? DefaultCustomPermissionService,
          let request = permissionService.currentToastRequest else { return nil }
    
    // Look for the most recent tool message with matching toolName
    // Iterate from end (most recent) to find the matching tool
    return viewModel.messages.reversed().first { message in
      message.messageType == .toolUse &&
      message.toolName == request.toolName &&
      // Only collapse Edit, MultiEdit, Write tools (the ones with diffs)
      ["Edit", "MultiEdit", "Write"].contains(message.toolName ?? "")
    }
  }
  
  private var toolbarContent: some View {
    HStack(spacing: 8) {
      // Copy session ID button
      copySessionButton
      
      // Clear chat button
      clearChatButton
      
      // Settings button
      settingsButton
    }
  }
  
  @ViewBuilder
  private var copySessionButton: some View {
    if let sessionId = viewModel.activeSessionId {
      Button(action: {
        launchTerminalWithSession(sessionId)
      }) {
        Image(systemName: isCopied ? "checkmark" : "terminal")
          .font(.title2)
      }
      .help("Continue in Terminal")
      .disabled(isCopied)
    }
  }
  
  private var clearChatButton: some View {
    Button(action: clearChat) {
      Image(systemName: "trash")
        .font(.title2)
    }
    .disabled(viewModel.messages.isEmpty)
  }
  
  @ViewBuilder
  private var settingsButton: some View {
    if uiConfiguration.showSettingsInNavBar {
      Button(action: {
        settingsTypeToShow = .global
        showingSettings = true
      }) {
        Image(systemName: "gearshape")
          .font(.title2)
      }
      .help("Global Settings")
    }
  }
  
  @ViewBuilder
  private var settingsSheet: some View {
    switch settingsTypeToShow {
    case .session:
      SettingsView(chatViewModel: viewModel)
    case .global:
      GlobalSettingsView(
        uiConfiguration: uiConfiguration,
        xcodeObservationViewModel: xcodeObservationViewModel,
        permissionsService: permissionsService,
        chatViewModel: viewModel
      )
    }
  }
  
  // MARK: - Actions
  
  private func keyboardTextChanged(oldValue: String, newValue: String) {
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
  
  private func focusTextEditorChanged(_: Bool, shouldFocus: Bool) {
    if shouldFocus {
      triggerTextEditorFocus = true
      // Reset the flag after using it
      keyboardManager.shouldFocusTextEditor = false
    }
  }
  
  private func clearChat() {
    viewModel.clearConversation()
  }
  
  private func copyToClipboard(_ text: String) {
#if os(macOS)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
#endif
    
    isCopied = true
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      isCopied = false
    }
  }
  
  private func launchTerminalWithSession(_ sessionId: String) {
    // Use the TerminalLauncher helper to launch Terminal
    if let error = TerminalLauncher.launchTerminalWithSession(
      sessionId,
      claudeClient: viewModel.claudeClient,
      projectPath: viewModel.projectPath
    ) {
      viewModel.errorInfo = ErrorInfo.fileError(error, fileName: "Terminal launch")
      viewModel.errorQueue.append(viewModel.errorInfo!)
    } else {
      // Show success indicator
      isCopied = true
      DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        isCopied = false
      }
    }
  }
  
  private func toggleSidebar() {
    withAnimation {
      switch columnVisibility {
      case .all:
        columnVisibility = .detailOnly
      case .detailOnly:
        columnVisibility = .all
      default:
        columnVisibility = .all
      }
    }
  }
}
