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
  @FocusState private var isTextFieldFocused: Bool
  
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
              .id(message.id)
          }
        }
        .onChange(of: viewModel.messages) { _, newMessages in
          // Scroll to bottom when new messages are added
          if let lastMessage = viewModel.messages.last {
            withAnimation {
              scrollView.scrollTo(lastMessage.id, anchor: .bottom)
            }
          }
        }
      }
      .listStyle(PlainListStyle())
      
      // Error message if present
      if let error = viewModel.error {
        Text(error.localizedDescription)
          .foregroundColor(.red)
          .padding()
      }
      // Input area
      HStack {
        TextEditor(text: $messageText)
          .padding(8)
          .frame(minHeight: 36, maxHeight: 90)
          .cornerRadius(20)
          .focused($isTextFieldFocused)
          .overlay(
            HStack {
              if messageText.isEmpty {
                Text("Type a message...")
                  .foregroundColor(.gray)
                  .padding(.leading, 12)
                  .padding(.top, 8)
                Spacer()
              }
            },
            alignment: .topLeading
          )
          .onKeyPress(.return) {
            sendMessage()
            return .ignored
          }
        
        if viewModel.isLoading {
          Button(action: {
            viewModel.cancelRequest()
          }) {
            Image(systemName: "stop.fill")
          }
          .padding(10)
        } else {
          Button(action: {
            sendMessage()
          }) {
            Image(systemName: "arrow.up.circle.fill")
              .foregroundColor(.blue)
              .font(.title2)
          }
          .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
    }
    .navigationTitle("Claude Code Chat")
  }
  
  private func sendMessage() {
    let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return }
    
    // Remove focus first
    viewModel.sendMessage(text)
    DispatchQueue.main.async {
      messageText = ""
    }
  }
  
  private func clearChat() {
    viewModel.clearConversation()
  }
}
