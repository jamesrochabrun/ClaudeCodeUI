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
  
  init() {
    let container = DependencyContainer.shared
    let workingDirectory = container.settingsStorage.getProjectPath() ?? ""
    let claudeClient = ClaudeCodeClient(workingDirectory: workingDirectory, debug: true)
    _viewModel = State(initialValue: ChatViewModel(claudeClient: claudeClient))
  }
  
  var body: some View {
    ChatScreen(viewModel: viewModel)
      .onChange(of: dependencyContainer.settingsStorage.projectPath) { _, newPath in
        // Update the ClaudeCodeClient with new path
        let claudeClient = ClaudeCodeClient(workingDirectory: newPath, debug: true)
        viewModel = ChatViewModel(claudeClient: claudeClient)
      }
  }
}

#Preview {
  RootView()
}
