//
//  RootView.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 5/25/25.
//

import SwiftUI
import ClaudeCodeSDK

struct RootView: View {
  @Environment(GlobalPreferencesStorage.self) private var globalPreferences
  
  @State private var dependencyContainer: DependencyContainer?
  @State private var viewModel: ChatViewModel?
  private let sessionId: String?
  
  init(sessionId: String? = nil) {
    self.sessionId = sessionId
  }
  
  var body: some View {
    if let viewModel = viewModel {
      ChatScreen(viewModel: viewModel)
    } else {
      ProgressView()
        .onAppear {
          setupViewModel()
        }
    }
  }
  
  private func setupViewModel() {
    let container = DependencyContainer(globalPreferences: globalPreferences)
    self.dependencyContainer = container
    
    // Set the current session for settings storage
    if let sessionId = sessionId {
      container.setCurrentSession(sessionId)
      print("[RootView] Setting up with session ID: \(sessionId)")
    } else {
      print("[RootView] Setting up with no session ID (new session)")
    }
    
    // Get session-specific working directory if available
    let workingDirectory: String
    if let sessionId = sessionId,
       let sessionPath = container.settingsStorage.getProjectPath(forSessionId: sessionId) {
      workingDirectory = sessionPath
      // Also set it as the active path for this session
      container.settingsStorage.setProjectPath(sessionPath)
      print("[RootView] Loaded working directory '\(sessionPath)' for session '\(sessionId)'")
    } else {
      // New session starts with empty working directory
      workingDirectory = ""
      container.settingsStorage.clearProjectPath()
      print("[RootView] No working directory found. Session ID: \(sessionId ?? "nil")")
    }
    
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
      globalPreferences: container.globalPreferences,
      onSessionChange: { newSessionId in
        container.setCurrentSession(newSessionId)
      }
    )
    self.viewModel = vm
    
    // Refresh the project path in the view model after we've set up the storage
    vm.refreshProjectPath()
    
    // Resume session if needed
    if let sessionId = sessionId {
      Task {
        // Resume the session when window opens
        await vm.resumeSession(id: sessionId)
        // Update last accessed time
        vm.sessionManager.updateLastAccessed(id: sessionId)
      }
    }
  }
}

#Preview {
  RootView()
}
