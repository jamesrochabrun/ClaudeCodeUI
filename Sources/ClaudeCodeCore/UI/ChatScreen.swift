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
/// This view can be used directly for custom UI implementations without requiring RootView.
public struct ChatScreen: View {
  
  public enum SettingsType {
    case session
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
    self.customPermissionService = customPermissionService
    self._columnVisibility = columnVisibility
    self.uiConfiguration = uiConfiguration
    // Cast to DefaultCustomPermissionService for @ObservedObject support
    self.observedPermissionService = customPermissionService as! DefaultCustomPermissionService
  }
  
  @State var viewModel: ChatViewModel
  @State var contextManager: ContextManager
  let xcodeObservationViewModel: XcodeObservationViewModel
  let permissionsService: PermissionsService
  let terminalService: TerminalService
  let customPermissionService: CustomPermissionService
  let uiConfiguration: UIConfiguration
  @ObservedObject private var observedPermissionService: DefaultCustomPermissionService
  @Binding var columnVisibility: NavigationSplitViewVisibility
  @State private var messageText: String = ""
  @State var showingSettings = false
  @State var settingsTypeToShow: SettingsType = .session
  @State private var keyboardManager = KeyboardShortcutManager()
  @State private var triggerTextEditorFocus = false
  @State var artifact: Artifact? = nil
  @State private var isCopied = false
  
  public var body: some View {
    VStack {
      // Always show the messages list (WelcomeRow will handle empty state)
      messagesListView
      
      // Error message if present
      errorView
      
      // Loading indicator
      loadingView
      
      ChatInputView(
        text: $messageText,
        chatViewModel: $viewModel,
        contextManager: contextManager,
        xcodeObservationViewModel: xcodeObservationViewModel,
        permissionsService: permissionsService,
        placeholder: "Type a message...",
        triggerFocus: $triggerTextEditorFocus)
    }
    .overlay(approvalToastOverlay)
    .navigationTitle(uiConfiguration.appName)
    .toolbar {
      ToolbarItem(placement: .automatic) {
        toolbarContent
      }
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
  private var errorView: some View {
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
  }
  
  @ViewBuilder
  private var loadingView: some View {
    if viewModel.isLoading, !observedPermissionService.isToastVisible, let startTime = viewModel.streamingStartTime {
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
  }
  
  @ViewBuilder
  private var approvalToastOverlay: some View {
    ToastContainer(isPresented: $observedPermissionService.isToastVisible) {
      if let request = observedPermissionService.currentToastRequest {
        ApprovalToast(
          request: request,
          showRiskLabel: uiConfiguration.showRiskLabel,
          onApprove: {
            observedPermissionService.approveCurrentToast()
          },
          onDeny: {
            observedPermissionService.denyCurrentToast()
          }
        )
      }
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
    if let sessionId = viewModel.currentSessionId {
      Button(action: {
        copyToClipboard(sessionId)
      }) {
        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
          .font(.title2)
      }
      .help("Copy Session ID")
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
      SettingsView(
        chatViewModel: viewModel,
        xcodeObservationViewModel: xcodeObservationViewModel,
        permissionsService: permissionsService
      )
    case .global:
      GlobalSettingsView()
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
