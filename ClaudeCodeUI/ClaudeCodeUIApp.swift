//
//  ClaudeCodeUIApp.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 5/25/25.
//

import SwiftUI

@main
struct ClaudeCodeUIApp: App {
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
    }
    //  .windowResizability(.contentSize)
    .windowStyle(.hiddenTitleBar)
    //      .windowBackgroundDragBehavior(.enabled)
    //      .restorationBehavior(.disabled)
    
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
      }
    }
    .windowStyle(.hiddenTitleBar)
  }
}
