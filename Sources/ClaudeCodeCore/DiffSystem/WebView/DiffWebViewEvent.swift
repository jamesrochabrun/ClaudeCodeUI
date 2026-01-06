//
//  DiffWebViewEvent.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 1/6/26.
//

import Foundation

/// Events sent from the JavaScript diff renderer to Swift.
enum DiffWebViewEvent {
  /// The JavaScript bridge is ready to receive commands
  case bridgeReady

  /// The diff has been rendered and is ready for interaction
  case ready

  /// A line was clicked
  case lineClicked(lineNumber: Int, side: String)

  /// Text selection changed
  case selectionChanged(startLine: Int, endLine: Int, side: String)

  /// System theme changed
  case systemThemeChanged(isDark: Bool)

  /// An error occurred in the JavaScript layer
  case error(message: String)
}
