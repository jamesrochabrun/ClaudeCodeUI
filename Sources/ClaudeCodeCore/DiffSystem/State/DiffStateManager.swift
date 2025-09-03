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
final class DiffStateManager {
  
  // MARK: Lifecycle
  
  init(terminalService: TerminalService) {
    processor = DiffProcessor(terminalService: terminalService)
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
    guard !diffs.isEmpty, let firstResult = diffs.first else { return }
    
    if
      let existingState = states[messageID],
      existingState.diffResult.diff == firstResult.diff,
      existingState.diffResult.original == firstResult.original
    {
      return
    }
    
    let newState = await processor.processState(diffResult: firstResult)
    
    states[messageID] = newState
  }
  
  func removeState(for messageID: UUID) {
    states.removeValue(forKey: messageID)
  }
  
  func clearAllStates() {
    states.removeAll()
  }
  
  // MARK: Private
  
  private var states: [UUID: DiffState] = [:]
  
  private let processor: DiffProcessor
}
