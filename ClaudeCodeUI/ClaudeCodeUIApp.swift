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
    WindowGroup {
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
  }
}
