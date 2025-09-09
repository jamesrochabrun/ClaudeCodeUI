//
//  App.swift
//  ClaudeCodeUI
//
//  App entry point using ClaudeCodeCore package
//

import SwiftUI
import ClaudeCodeCore
import ClaudeCodeSDK

@main
struct ClaudeCodeUIAppWrapper: App {
  @State private var globalPreferences = GlobalPreferencesStorage()
  @State private var viewModel: ChatViewModel?
  @State private var dependencies: DependencyContainer?
  
  var body: some Scene {
    WindowGroup {
      if let viewModel = viewModel, let deps = dependencies {
        ChatScreen(
          viewModel: viewModel,
          contextManager: deps.contextManager,
          xcodeObservationViewModel: deps.xcodeObservationViewModel,
          permissionsService: deps.permissionsService,
          terminalService: deps.terminalService,
          customPermissionService: deps.customPermissionService,
          columnVisibility: .constant(.detailOnly), // No sidebar
          uiConfiguration: UIConfiguration(
            appName: "Claude Code UI",
            showSettingsInNavBar: true,
            showRiskData: false)
        )
        .environment(globalPreferences)
      } else {
        ProgressView("Initializing Claude Code...")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .onAppear { setupChatScreen() }
      }
    }
  }
  
  private func setupChatScreen() {
    // Use optimized initialization for direct ChatScreen usage
    // This avoids all session storage overhead and file system checks
    let deps = DependencyContainer.forDirectChatScreen(globalPreferences: globalPreferences)
    
    // Configure Claude client with additional paths for Claude CLI
    let homeDir = NSHomeDirectory()
    var config = ClaudeCodeConfiguration.default
    config.enableDebugLogging = true
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
    
    // Create view model without session management for better performance
    let vm = deps.createChatViewModelWithoutSessions(
      claudeClient: ClaudeCodeClient(configuration: config),
      workingDirectory: nil // User will select working directory manually
    )
    
    // Optional: Inject a session with a default working directory
    // This can be customized or removed to let the user select manually
    // vm.injectSession(
    //     sessionId: UUID().uuidString,
    //     messages: [],
    //     workingDirectory: nil  // User will select manually
    // )
    
    self.viewModel = vm
    self.dependencies = deps
  }
}
