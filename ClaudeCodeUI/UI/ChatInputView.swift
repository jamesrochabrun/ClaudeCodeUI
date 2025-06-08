//
//  ChatInputView.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 6/7/2025.
//

import SwiftUI
import ClaudeCodeSDK

struct ChatInputView: View {
  
  // MARK: - Properties
  
  @Binding var text: String
  @Binding var viewModel: ChatViewModel

  @FocusState private var isFocused: Bool
  let placeholder: String
  @State private var shouldSubmit = false
  
  // MARK: - Constants
  
  private let textAreaEdgeInsets = EdgeInsets(top: 10, leading: 15, bottom: 10, trailing: 15)
  private let textAreaCornerRadius = 24.0
  
  // MARK: - Initialization
  
  init(
    text: Binding<String>,
    chatViewModel: Binding<ChatViewModel>,
    placeholder: String = "Type a message...")
  {
    _text = text
    _viewModel = chatViewModel
    self.placeholder = placeholder
  }
  // MARK: - Body
  
  var body: some View {
    HStack {
      textArea
      if viewModel.isLoading {
        Button(action: {
          viewModel.cancelRequest()
        }) {
          Image(systemName: "stop.fill")
        }
        .padding(10)
        .buttonStyle(.plain)
      } else {
        Button(action: {
          sendMessage()
        }) {
          Image(systemName: "arrow.up.circle.fill")
            .foregroundColor(.blue)
            .font(.title2)
        }
        .padding(10)
        .buttonStyle(.plain)
        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
    .background(Color(NSColor.controlBackgroundColor))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
    )
    .padding(.horizontal, 12)
    .padding(.bottom, 12)
  }
  
  private var textArea: some View {
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
  
  private func sendMessage() {
    let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return }
    
    // Remove focus first
    viewModel.sendMessage(text)
    DispatchQueue.main.async {
      self.text = ""
    }
  }
}

