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
import KeyboardShortcuts

struct ChatScreen: View {
  
  init(viewModel: ChatViewModel, contextManager: ContextManager, xcodeObservationViewModel: XcodeObservationViewModel, permissionsService: PermissionsService) {
    self.viewModel = viewModel
    self.contextManager = contextManager
    self.xcodeObservationViewModel = xcodeObservationViewModel
    self.permissionsService = permissionsService
  }
  
  @State var viewModel: ChatViewModel
  @State var contextManager: ContextManager
  let xcodeObservationViewModel: XcodeObservationViewModel
  let permissionsService: PermissionsService
  @State private var messageText: String = ""
  @State var showingSettings = false
  @State private var keyboardManager = KeyboardShortcutManager()
  
  var body: some View {
    VStack {
      // Show empty state if no project path is selected and no messages
      if viewModel.projectPath.isEmpty && viewModel.messages.isEmpty {
        emptyStateView
      } else {
        // Chat messages list
        messagesListView
      }
      
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
      // Thinking indicator overlay
      if viewModel.isLoading {
        ThinkingIndicator(message: "")
          .background(.clear)
          .padding(.horizontal)
          .padding(.bottom, 8)
          .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
          ))
          .zIndex(1)
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
}
