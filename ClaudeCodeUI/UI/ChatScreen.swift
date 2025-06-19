//
//  ChatScreen.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 5/25/25.
//

import ClaudeCodeSDK
import Foundation
import SwiftUI

struct ChatScreen: View {
  
  init(viewModel: ChatViewModel) {
    self.viewModel = viewModel
  }
  
  @State private var viewModel: ChatViewModel
  @State private var messageText: String = ""
  @State private var showingSettings = false
  
  var body: some View {
    VStack {
      // Show empty state if no project path is selected and no messages
      if viewModel.projectPath.isEmpty && viewModel.messages.isEmpty {
        VStack(spacing: 20) {
          Spacer()
          Image(systemName: "folder.badge.questionmark")
            .font(.system(size: 60))
            .foregroundColor(.secondary)
          Text("No Working Directory Selected")
            .font(.title2)
            .fontWeight(.semibold)
          Text("Select a working directory to start chatting with Claude")
            .font(.body)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
          Button("Open Settings") {
            showingSettings = true
          }
          .buttonStyle(.borderedProminent)
          Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
      } else {
        // Chat messages list
        ScrollViewReader { scrollView in
          List {
            ForEach(viewModel.messages) { message in
              ChatMessageRow(message: message, settingsStorage: viewModel.settingsStorage)
                .listRowSeparator(.hidden)
                .id(message.id)
            }
          }
          .listStyle(.plain)
          .listRowBackground(Color.clear)
          .scrollContentBackground(.hidden)
          .onChange(of: viewModel.messages) { _, newMessages in
            // Scroll to bottom when new messages are added
            if let lastMessage = viewModel.messages.last {
              withAnimation {
                scrollView.scrollTo(lastMessage.id, anchor: .bottom)
              }
            }
          }
        }
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
        placeholder: "Type a message...")
    }
    .navigationTitle("Claude Code Chat")
    .toolbar {
      ToolbarItem(placement: .automatic) {
        HStack {
          Button(action: { showingSettings = true }) {
            Image(systemName: "gearshape")
              .font(.title2)
          }
          
          Button(action: clearChat) {
            Image(systemName: "trash")
              .font(.title2)
          }
          .disabled(viewModel.messages.isEmpty)
        }
      }
    }
    .sheet(isPresented: $showingSettings) {
      SettingsView(chatViewModel: viewModel)
    }
    .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
  }
  
  
  private func clearChat() {
    viewModel.clearConversation()
  }
}
