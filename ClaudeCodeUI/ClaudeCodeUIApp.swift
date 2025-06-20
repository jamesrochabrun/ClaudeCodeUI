//
//  ClaudeCodeUIApp.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 5/25/25.
//

import SwiftUI

@main
struct ClaudeCodeUIApp: App {
  @State private var globalPreferences = GlobalPreferencesStorage()
  
  var body: some Scene {
    WindowGroup(id: "main") {
      RootView()
        .toolbar(removing: .title)
        .containerBackground(
          .thinMaterial, for: .window
        )
        .toolbarBackgroundVisibility(
          .hidden, for: .windowToolbar
        )
        .environment(globalPreferences)
    }
    //  .windowResizability(.contentSize)
    .windowStyle(.hiddenTitleBar)
    //      .windowBackgroundDragBehavior(.enabled)
    //      .restorationBehavior(.disabled)
    .commands {
      AppearanceCommands()
    }
    
    WindowGroup("Session", id: "session", for: String.self) { $sessionId in
      if let sessionId = sessionId {
        RootView(sessionId: sessionId)
          .toolbar(removing: .title)
          .containerBackground(
            .thinMaterial, for: .window
          )
          .toolbarBackgroundVisibility(
            .hidden, for: .windowToolbar
          )
          .environment(globalPreferences)
      }
    }
    .windowStyle(.hiddenTitleBar)
    
    // Global Settings Window
    Window("Global Settings", id: "global-settings") {
      GlobalSettingsView()
        .environment(globalPreferences)
    }
    .windowResizability(.contentSize)
  }
}

// Custom Commands for Appearance Menu
struct AppearanceCommands: Commands {
  @Environment(\.openWindow) private var openWindow
  
  var body: some Commands {
    CommandGroup(after: .appSettings) {
      Button("Global Settings...") {
        openWindow(id: "global-settings")
      }
      .keyboardShortcut(",", modifiers: [.command, .shift])
    }
  }
}

