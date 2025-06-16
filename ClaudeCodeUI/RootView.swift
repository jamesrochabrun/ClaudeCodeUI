//
//  RootView.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 5/25/25.
//

import SwiftUI
import ClaudeCodeSDK

struct RootView: View {
  
  private let dependencyContainer: DependencyContainer = DependencyContainer()
  @State private var viewModel: ChatViewModel
  private let sessionId: String?
  
  init(sessionId: String? = nil) {
    self.sessionId = sessionId
    let workingDirectory = dependencyContainer.settingsStorage.getProjectPath() ?? ""
    let debugMode = dependencyContainer.settingsStorage.getDebugMode()
    let claudeClient = ClaudeCodeClient(workingDirectory: workingDirectory, debug: debugMode)
    viewModel = ChatViewModel(claudeClient: claudeClient, sessionStorage: dependencyContainer.sessionStorage, settingsStorage: dependencyContainer.settingsStorage)
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
  }
}

#Preview {
  RootView()
}
