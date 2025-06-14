//
//  RootView.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 5/25/25.
//

import SwiftUI
import ClaudeCodeSDK

struct RootView: View {
  
  @State private var dependencyContainer = DependencyContainer.shared
  @State private var viewModel: ChatViewModel
  private let sessionId: String?
  
  init(sessionId: String? = nil) {
    self.sessionId = sessionId
    let container = DependencyContainer.shared
    let workingDirectory = container.settingsStorage.getProjectPath() ?? ""
    let claudeClient = ClaudeCodeClient(workingDirectory: workingDirectory, debug: true)
    _viewModel = State(initialValue: ChatViewModel(claudeClient: claudeClient, sessionStorage: container.sessionStorage))
  }
  
  var body: some View {
    ChatScreen(viewModel: viewModel)
      .task {
        if let sessionId = sessionId {
          // Resume the session when window opens
          await viewModel.resumeSession(id: sessionId)
          // Update last accessed time
          viewModel.sessionManager.updateLastAccessed(id: sessionId)
        }
      }
      .onChange(of: dependencyContainer.settingsStorage.projectPath) { _, newPath in
        // Update the ClaudeCodeClient with new path
        let claudeClient = ClaudeCodeClient(workingDirectory: newPath, debug: true)
        viewModel = ChatViewModel(claudeClient: claudeClient, sessionStorage: dependencyContainer.sessionStorage)
      }
  }
}

#Preview {
  RootView()
}
