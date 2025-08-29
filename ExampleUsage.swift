// Example usage of ClaudeCodeCore with custom configuration

import SwiftUI
import ClaudeCodeCore
import ClaudeCodeSDK

// Example 1: Using convenience initializers
struct MyApp1: App {
  @State private var globalPreferences = GlobalPreferencesStorage()
  
  var body: some Scene {
    WindowGroup {
      // Simple configuration with just app name
      RootView(configuration: ClaudeCodeAppConfiguration(appName: "My Claude App"))
        .environment(globalPreferences)
    }
  }
}

// Example 2: Using full configuration with settings in nav bar
struct MyApp2: App {
  @State private var globalPreferences = GlobalPreferencesStorage()
  
  var body: some Scene {
    WindowGroup {
      // Configuration with app name and settings in nav bar
      // Note: When showSettingsInNavBar is true, the gear icon in the navigation bar
      // opens GlobalSettingsView. The "Select Working Directory" button always opens
      // the session-specific SettingsView.
      RootView(configuration: ClaudeCodeAppConfiguration(
        appName: "My Custom IDE",
        showSettingsInNavBar: true
      ))
      .environment(globalPreferences)
    }
  }
}

// Example 3: Using both ClaudeCode and UI configurations
struct MyApp3: App {
  @State private var globalPreferences = GlobalPreferencesStorage()
  
  var body: some Scene {
    WindowGroup {
      // Full custom configuration
      RootView(configuration: ClaudeCodeAppConfiguration(
        claudeCodeConfiguration: ClaudeCodeConfiguration(
          command: "claude",
          workingDirectory: "/Users/me/projects",
          enableDebugLogging: true
        ),
        uiConfiguration: UIConfiguration(
          appName: "AI Code Assistant",
          showSettingsInNavBar: false
        )
      ))
      .environment(globalPreferences)
    }
  }
}

// Example 4: Library default (minimal UI)
struct MyLibraryApp: App {
  @State private var globalPreferences = GlobalPreferencesStorage()
  
  var body: some Scene {
    WindowGroup {
      // Uses library defaults: "Claude Code" name, no settings in nav
      RootView(configuration: .library)
        .environment(globalPreferences)
    }
  }
}

// Example 5: App with initial working directory (no manual selection needed!)
struct MyAppWithDirectory: App {
  @State private var globalPreferences = GlobalPreferencesStorage()
  
  var body: some Scene {
    WindowGroup {
      // Initialize with a working directory - skips manual directory selection
      RootView(configuration: ClaudeCodeAppConfiguration(
        appName: "My Project App",
        workingDirectory: "/Users/me/my-project"
      ))
      .environment(globalPreferences)
    }
  }
}

// Example 6: Direct ChatScreen usage with session injection
struct DirectChatApp: App {
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
          uiConfiguration: UIConfiguration(appName: "Direct Chat App")
        )
      } else {
        ProgressView("Loading...")
          .onAppear { setupWithInjectedSession() }
      }
    }
  }
  
  func setupWithInjectedSession() {
    let deps = DependencyContainer(globalPreferences: globalPreferences)
    let vm = ChatViewModel(
      claudeClient: ClaudeCodeClient(configuration: .default),
      sessionStorage: UserDefaultsSessionStorage(),
      settingsStorage: deps.settingsStorage,
      globalPreferences: globalPreferences,
      customPermissionService: deps.customPermissionService
    )
    
    // Inject a session with working directory - ready to use immediately!
    vm.injectSession(
      sessionId: "my-session-123",
      messages: [], // Can pre-populate with saved messages
      workingDirectory: "/Users/me/my-project"
    )
    
    self.viewModel = vm
    self.dependencies = deps
  }
}