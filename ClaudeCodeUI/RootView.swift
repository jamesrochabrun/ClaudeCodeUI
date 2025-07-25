//
//  RootView.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 5/25/25.
//

import SwiftUI
import ClaudeCodeSDK
import CustomPermissionService

struct RootView: View {
  @Environment(GlobalPreferencesStorage.self) private var globalPreferences
  
  @State private var dependencyContainer: DependencyContainer?
  @State private var viewModel: ChatViewModel?
  private let sessionId: String?
  
  init(sessionId: String? = nil) {
    self.sessionId = sessionId
  }
  
  var body: some View {
    if let viewModel = viewModel, let container = dependencyContainer {
      ChatScreen(
        viewModel: viewModel,
        contextManager: container.contextManager,
        xcodeObservationViewModel: container.xcodeObservationViewModel,
        permissionsService: container.permissionsService,
        terminalService: container.terminalService,
        customPermissionService: container.customPermissionService
      )
      .environment(container.xcodeObservationViewModel)
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
    }
    
    // Get session-specific working directory if available
    let workingDirectory: String
    if let sessionId = sessionId,
       let sessionPath = container.settingsStorage.getProjectPath(forSessionId: sessionId) {
      workingDirectory = sessionPath
      // Also set it as the active path for this session
      container.settingsStorage.setProjectPath(sessionPath)
    } else {
      // New session starts with empty working directory to allow auto-detection
      workingDirectory = ""
      container.settingsStorage.clearProjectPath()
    }
    
#if DEBUG
    let debugMode = true
#else
    let debugMode = false
#endif

    var config = ClaudeCodeConfiguration.default
    config.workingDirectory = workingDirectory
    config.enableDebugLogging = debugMode
    
    // Load existing MCP servers from configuration
    let mcpManager = MCPConfigurationManager()
    var options = ClaudeCodeOptions()
    
    // Add existing MCP servers
    if !mcpManager.configuration.mcpServers.isEmpty {
      options.mcpServers = [:]
      for (name, server) in mcpManager.configuration.mcpServers {
        // Convert MCPServerConfig to ClaudeCodeSDK format
        if !server.command.isEmpty {
          let mcpConfig = McpStdioServerConfig(
            command: server.command,
            args: server.args,
            env: server.env
          )
          options.mcpServers?[name] = .stdio(mcpConfig)
        }
      }
    }
    
    // Configure MCP approval server
    let approvalTool = MCPApprovalTool(permissionService: container.customPermissionService)
    approvalTool.configure(options: &options)
    
    // Add nvm paths to support npm installed via nvm
//    let homeDir = NSHomeDirectory()
//    config.additionalPaths = [
//      "/usr/local/bin",
//      "/opt/homebrew/bin",
//      "/usr/bin",
//      "\(homeDir)/.nvm/versions/node/v22.16.0/bin",  // Your actual Node version
//      "\(homeDir)/.nvm/current/bin",
//      "\(homeDir)/.nvm/versions/node/v20.11.1/bin",
//      "\(homeDir)/.nvm/versions/node/v18.19.0/bin"
//    ]
    
    // Create the client with configuration and options
    let claudeClient = ClaudeCodeClient(configuration: config, options: options)
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
