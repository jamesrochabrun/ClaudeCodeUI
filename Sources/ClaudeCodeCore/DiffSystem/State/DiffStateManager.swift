//
//  DiffStateManager.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 9/3/25.
//

import CCTerminalServiceInterface
import Foundation
import SwiftUI

// MARK: - DiffStateManager

@Observable
public final class DiffStateManager {

  // MARK: Lifecycle

  init(terminalService: TerminalService) {
    // TerminalService kept for API compatibility
  }

  // MARK: Internal

  var stateCount: Int {
    states.count
  }

  /// Get state for a message
  func getState(for messageID: UUID) -> DiffState {
    states[messageID] ?? .empty
  }

  @MainActor
  func process(diffs: [DiffResult], for messageID: UUID) async {
    guard !diffs.isEmpty, let firstResult = diffs.first else {
      return
    }

    // Skip if we already have the same content
    if
      let existingState = states[messageID],
      existingState.diffResult.original == firstResult.original,
      existingState.diffResult.updated == firstResult.updated
    {
      return
    }

    // Store the DiffResult - @pierre/diffs handles all rendering
    states[messageID] = DiffState(diffResult: firstResult)
  }

  func removeState(for messageID: UUID) {
    states.removeValue(forKey: messageID)
  }

  func clearAllStates() {
    states.removeAll()
  }

  // MARK: Private

  private var states: [UUID: DiffState] = [:]
}
