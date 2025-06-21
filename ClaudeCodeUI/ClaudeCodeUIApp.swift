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
  @Environment(\.openWindow) private var openWindow
  
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
    
    // Menu Bar Extra
    MenuBarExtra("Claude Code", systemImage: "brain") {
      Button("Open Claude Code") {
        openWindow(id: "main")
      }
      .keyboardShortcut("o", modifiers: [.command, .shift])
      
      Divider()
      
      Button("Global Settings...") {
        openWindow(id: "global-settings")
      }
      .keyboardShortcut(",", modifiers: [.command, .shift])
      
      Divider()
      
      Button("Quit") {
        NSApplication.shared.terminate(nil)
      }
      .keyboardShortcut("q")
    }
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

