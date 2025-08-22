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