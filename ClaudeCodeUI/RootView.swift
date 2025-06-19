//
//  RootView.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 5/25/25.
//

import SwiftUI
import ClaudeCodeSDK

struct RootView: View {
  
  private let dependencyContainer: DependencyContainer
  @State private var viewModel: ChatViewModel
  private let sessionId: String?
  
  init(sessionId: String? = nil) {
    self.sessionId = sessionId
    
    let container = DependencyContainer()
    self.dependencyContainer = container
    
    // Set the current session for settings storage
    if let sessionId = sessionId {
      container.setCurrentSession(sessionId)
    }
    
    let workingDirectory = container.settingsStorage.getProjectPath() ?? ""
    
    #if DEBUG
    let debugMode = true
    #else
    let debugMode = false
    #endif
    
    let claudeClient = ClaudeCodeClient(workingDirectory: workingDirectory, debug: debugMode)
    let vm = ChatViewModel(
      claudeClient: claudeClient,
      sessionStorage: container.sessionStorage,
      settingsStorage: container.settingsStorage,
      onSessionChange: { newSessionId in
        container.setCurrentSession(newSessionId)
      }
    )
    self._viewModel = State(initialValue: vm)
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
