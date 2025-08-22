//
//  RootView.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 5/25/25.
//

import SwiftUI
import ClaudeCodeSDK

public struct RootView: View {
  @Environment(GlobalPreferencesStorage.self) private var globalPreferences
  @Environment(\.colorScheme) private var colorScheme
  
  @State private var dependencyContainer: DependencyContainer?
  @State private var viewModel: ChatViewModel?
  @State private var columnVisibility: NavigationSplitViewVisibility = .all
  private let sessionId: String?
  private let configuration: ClaudeCodeAppConfiguration
  
  public init(sessionId: String? = nil, configuration: ClaudeCodeAppConfiguration = .default) {
    self.sessionId = sessionId
    self.configuration = configuration
  }
  
  public var body: some View {
    if let viewModel = viewModel, let container = dependencyContainer {
      NavigationSplitView(columnVisibility: $columnVisibility) {
        // Sidebar
        SessionsSidebarView(viewModel: viewModel)
          .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
      } detail: {
        // Main chat content
        ChatScreen(
          viewModel: viewModel,
          contextManager: container.contextManager,
          xcodeObservationViewModel: container.xcodeObservationViewModel,
          permissionsService: container.permissionsService,
          terminalService: container.terminalService,
          customPermissionService: container.customPermissionService,
          columnVisibility: $columnVisibility,
          uiConfiguration: configuration.uiConfiguration
        )
        .environment(container.xcodeObservationViewModel)
      }
      .navigationSplitViewStyle(.balanced)
      .background(Color.adaptiveBackground(for: colorScheme))
    } else {
      ProgressView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.adaptiveBackground(for: colorScheme))
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
    }
    
    // Get session-specific working directory if available
    let workingDirectory: String
    if let sessionId = sessionId,
       let sessionPath = container.settingsStorage.getProjectPath(forSessionId: sessionId) {
      workingDirectory = sessionPath
      // Also set it as the active path for this session
      container.settingsStorage.setProjectPath(sessionPath)
    } else {
      // New session starts with empty working directory - user must manually select
      workingDirectory = ""
      container.settingsStorage.clearProjectPath()
    }
    
    var config = configuration.claudeCodeConfiguration
    config.workingDirectory = workingDirectory
    
    // Add paths to support claude installed via npm/nvm or standalone
    let homeDir = NSHomeDirectory()
    config.additionalPaths = [
      "/usr/local/bin",
      "/opt/homebrew/bin",
      "/usr/bin",
      "\(homeDir)/.claude/local",  // Claude standalone installation
      "\(homeDir)/.nvm/versions/node/v22.16.0/bin",  // Common Node versions
      "\(homeDir)/.nvm/current/bin",
      "\(homeDir)/.nvm/versions/node/v20.11.1/bin",
      "\(homeDir)/.nvm/versions/node/v18.19.0/bin"
    ]
    
    let claudeClient = ClaudeCodeClient(configuration: config)
    let vm = ChatViewModel(
      claudeClient: claudeClient,
      sessionStorage: container.sessionStorage,
      settingsStorage: container.settingsStorage,
      globalPreferences: container.globalPreferences,
      customPermissionService: container.customPermissionService,
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
