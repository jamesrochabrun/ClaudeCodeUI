//
//  DiffState.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 9/3/25.
//

import Foundation

// MARK: - DiffState

/// Immutable state struct that's safe for SwiftUI.
/// Contains the diff result for WebView-based rendering via @pierre/diffs.
struct DiffState: Equatable {
  static let empty = DiffState(diffResult: .initial)

  /// The result of the diff operation
  let diffResult: DiffResult

  /// Whether this state has actual content to display
  var hasContent: Bool {
    !diffResult.isInitial && (!diffResult.original.isEmpty || !diffResult.updated.isEmpty)
  }
}
