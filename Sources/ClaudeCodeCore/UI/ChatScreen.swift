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

struct ChatScreen: View {
  
  init(viewModel: ChatViewModel, contextManager: ContextManager, xcodeObservationViewModel: XcodeObservationViewModel, permissionsService: PermissionsService, terminalService: TerminalService, customPermissionService: CustomPermissionService, columnVisibility: Binding<NavigationSplitViewVisibility>, uiConfiguration: UIConfiguration = .default) {
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
  @State private var keyboardManager = KeyboardShortcutManager()
  @State private var triggerTextEditorFocus = false
  @State var artifact: Artifact? = nil
  @State private var isCopied = false
  
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
        placeholder: "Type a message...",
        triggerFocus: $triggerTextEditorFocus)
    }
    .overlay(
      // Approval Toast Overlay
      ToastContainer(isPresented: $observedPermissionService.isToastVisible) {
        if let request = observedPermissionService.currentToastRequest {
          ApprovalToast(
            request: request,
            onApprove: {
              observedPermissionService.approveCurrentToast()
            },
            onDeny: {
              observedPermissionService.denyCurrentToast()
            }
          )
        }
      }
    )
    .navigationTitle("\(uiConfiguration.appName) Chat")
    .toolbar {
      ToolbarItem(placement: .automatic) {
        HStack(spacing: 8) {
          // PermissionStatusView(customPermissionService: customPermissionService)
          
          // Copy session ID button
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
          
          Button(action: clearChat) {
            Image(systemName: "trash")
              .font(.title2)
          }
          .disabled(viewModel.messages.isEmpty)
          
          // Show settings button if configured
          if uiConfiguration.showSettingsInNavBar {
            Button(action: {
              showingSettings = true
            }) {
              Image(systemName: "gearshape")
                .font(.title2)
            }
            .help("Global Settings")
          }
        }
      }
    }
    .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
    .sheet(isPresented: $showingSettings) {
      if uiConfiguration.showSettingsInNavBar {
        GlobalSettingsView()
      } else {
        SettingsView(chatViewModel: viewModel, xcodeObservationViewModel: xcodeObservationViewModel, permissionsService: permissionsService)
      }
    }
    .sheet(item: $artifact) { artifact in
      ArtifactView(artifact: artifact)
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
    .onChange(of: keyboardManager.shouldFocusTextEditor) { _, shouldFocus in
      if shouldFocus {
        triggerTextEditorFocus = true
        // Reset the flag after using it
        keyboardManager.shouldFocusTextEditor = false
      }
    }
    .focusedValue(\.toggleSidebar, toggleSidebar)
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
