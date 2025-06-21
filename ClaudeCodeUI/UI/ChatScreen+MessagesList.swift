//
//  ChatScreen+MessagesList.swift
//  ClaudeCodeUI
//
//  Created on 12/19/24.
//

import SwiftUI

extension ChatScreen {
  var messagesListView: some View {
    ScrollViewReader { scrollView in
      List {
        // Add WelcomeRow at the top when project path is available
        if !viewModel.projectPath.isEmpty {
          WelcomeRow(
            path: viewModel.projectPath
          )
          .listRowSeparator(.hidden)
          .id("welcome-row")
        }
        
        ForEach(viewModel.messages) { message in
          ChatMessageRow(
            message: message,
            settingsStorage: viewModel.settingsStorage,
            fontSize: 13.0  // Default font size for now
          )
          .listRowSeparator(.hidden)
          .listRowInsets(EdgeInsets())
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
}
