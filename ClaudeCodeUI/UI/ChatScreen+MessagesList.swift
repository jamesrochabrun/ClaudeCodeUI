//
//  ChatScreen+MessagesList.swift
//  ClaudeCodeUI
//
//  Created on 12/19/24.
//

import SwiftUI

extension ChatScreen {
  
  /// Determines the effective working directory based on manual selection or Xcode active file
  var effectiveWorkingDirectory: String? {
    // First priority: manually set project path
    if !viewModel.projectPath.isEmpty {
      return "cwd: \(viewModel.projectPath)"
    }
    
    return nil
  }
  
  /// Determines whether to show the settings button
  var shouldShowSettingsButton: Bool {
    // Show settings button when there's no working directory
    return effectiveWorkingDirectory == nil
  }
  
  var messagesListView: some View {
    ScrollViewReader { scrollView in
      List {
        // Always show WelcomeRow at the top
        WelcomeRow(
          path: effectiveWorkingDirectory,
          showSettingsButton: shouldShowSettingsButton,
          onSettingsTapped: {
            showingSettings = true
          }
        )
        .listRowSeparator(.hidden)
        .id("welcome-row")
        
        ForEach(viewModel.messages) { message in
          ChatMessageView(
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
      .onAppear {
        checkForAutoDetection()
      }
      .onChange(of: xcodeObservationViewModel.workspaceModel) { _, _ in
        checkForAutoDetection()
      }
    }
  }
}
