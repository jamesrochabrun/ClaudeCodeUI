//
//  ClaudeCodeUIApp.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 5/25/25.
//

import SwiftUI

// Note: @main attribute removed - this is now a library component
// The actual app entry point is in the executable target
public struct ClaudeCodeUIApp: App {
  @State private var globalPreferences = GlobalPreferencesStorage()
  @State private var dependencyContainer: DependencyContainer?
  @Environment(\.openWindow) private var openWindow
  @Environment(\.colorScheme) private var colorScheme

  public init() {
    // Initialize dependency container for global settings
    _dependencyContainer = State(initialValue: DependencyContainer(
      globalPreferences: globalPreferences,
      useNoOpStorage: true
    ))
  }
  
  public var body: some Scene {
    WindowGroup(id: "main") {
      RootView()
        .modifier(ConditionalToolbarModifier())
        .environment(globalPreferences)
    }
    //  .windowResizability(.contentSize)
    .windowStyle(.hiddenTitleBar)
    //      .windowBackgroundDragBehavior(.enabled)
    //      .restorationBehavior(.disabled)
    .commands {
      AppearanceCommands()
      SidebarCommands()
    }
    
    WindowGroup("Session", id: "session", for: String.self) { $sessionId in
      if let sessionId = sessionId {
        RootView(sessionId: sessionId)
          .modifier(ConditionalToolbarModifier())
          .modifier(ConditionalBackgroundModifier())
          .environment(globalPreferences)
      }
    }
    .windowStyle(.hiddenTitleBar)
    
    // Global Settings Window
    Window("Global Settings", id: "global-settings") {
      if let container = dependencyContainer {
        GlobalSettingsView(
          xcodeObservationViewModel: container.xcodeObservationViewModel,
          permissionsService: container.permissionsService
        )
        .environment(globalPreferences)
      } else {
        GlobalSettingsView()
          .environment(globalPreferences)
      }
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

// Custom Commands for View Menu
struct SidebarCommands: Commands {
  @FocusedValue(\.toggleSidebar) private var toggleSidebar
  
  var body: some Commands {
    CommandGroup(after: .sidebar) {
      Button("Toggle Sidebar") {
        toggleSidebar?()
      }
      .keyboardShortcut("s", modifiers: [.command, .option])
      .disabled(toggleSidebar == nil)
    }
  }
}

// Define the focused value key
struct ToggleSidebarKey: FocusedValueKey {
  typealias Value = () -> Void
}

extension FocusedValues {
  var toggleSidebar: (() -> Void)? {
    get { self[ToggleSidebarKey.self] }
    set { self[ToggleSidebarKey.self] = newValue }
  }
}

// Conditional modifiers for macOS version compatibility
struct ConditionalToolbarModifier: ViewModifier {
  func body(content: Content) -> some View {
    if #available(macOS 15.0, *) {
      content
        .toolbar(removing: .title)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
    } else {
      content
    }
  }
}

struct ConditionalBackgroundModifier: ViewModifier {
  func body(content: Content) -> some View {
    if #available(macOS 15.0, *) {
      content
        .containerBackground(.thinMaterial, for: .window)
    } else {
      content
    }
  }
}

