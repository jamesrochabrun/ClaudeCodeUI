//
//  ClaudeCodeUIApp.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 5/25/25.
//

import SwiftUI

@main
struct ClaudeCodeUIApp: App {
  private let globalSettingsStorage = GlobalSettingsStorageManager()
  
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
        .environment(\.globalSettingsStorage, globalSettingsStorage)
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
          .environment(\.globalSettingsStorage, globalSettingsStorage)
      }
    }
    .windowStyle(.hiddenTitleBar)
    
    // Appearance Settings Window
    Window("Appearance Settings", id: "appearance-settings") {
      AppearanceSettingsView(globalSettingsStorage: globalSettingsStorage)
    }
    .windowResizability(.contentSize)
  }
}

// Custom Commands for Appearance Menu
struct AppearanceCommands: Commands {
  @Environment(\.openWindow) private var openWindow
  
  var body: some Commands {
    CommandGroup(after: .appSettings) {
      Button("Appearance Settings...") {
        openWindow(id: "appearance-settings")
      }
      .keyboardShortcut(",", modifiers: [.command, .shift])
    }
  }
}

// Environment key for GlobalSettingsStorage
private struct GlobalSettingsStorageKey: EnvironmentKey {
  static let defaultValue: GlobalSettingsStorage = GlobalSettingsStorageManager()
}

extension EnvironmentValues {
  var globalSettingsStorage: GlobalSettingsStorage {
    get { self[GlobalSettingsStorageKey.self] }
    set { self[GlobalSettingsStorageKey.self] = newValue }
  }
}
