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
  
  var body: some View {
    VStack {
      // Top button bar
      HStack {
        Spacer()
        Button(action: {
          clearChat()
        }) {
          Image(systemName: "trash")
            .font(.title2)
        }
        .disabled(viewModel.messages.isEmpty)
      }
      .padding(.horizontal)
      .padding(.top, 8)
      
      // Chat messages list
      ScrollViewReader { scrollView in
        List {
          ForEach(viewModel.messages) { message in
            ChatMessageRow(message: message)
              .listRowSeparator(.hidden)
              .id(message.id)
          }
        }
        .listStyle(PlainListStyle())
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
      
      // Error message if present
      if let error = viewModel.error {
        Text(error.localizedDescription)
          .foregroundColor(.red)
          .padding()
      }
      
      MessageInputView(
        text: $messageText,
        chatViewModel: $viewModel,
        placeholder: "Type a message...")
    }
    .navigationTitle("Claude Code Chat")
  }

  
  private func clearChat() {
    viewModel.clearConversation()
  }
}
