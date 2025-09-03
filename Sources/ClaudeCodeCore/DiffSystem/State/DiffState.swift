//
//  DiffState.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 9/3/25.
//

import Foundation

// MARK: - DiffState

/// Immutable state struct that's safe for SwiftUI
struct DiffState: Equatable {
  static let empty = DiffState(
    xmlDiffs: [],
    diffGroups: [],
    diffToGroupIDMap: [:],
    groupIDToDiffMap: [:],
    appliedDiffGroupIDs: [],
    diffResult: .initial
  )
  
  let xmlDiffs: [CodeDiff]
  let diffGroups: [DiffTerminalService.DiffGroup]
  let diffToGroupIDMap: [String: UUID]
  let groupIDToDiffMap: [UUID: String]
  let appliedDiffGroupIDs: Set<UUID>
  //let diffHistory: [DiffHistoryEntry]
  let diffResult: DiffResult
  
  var areAllChangesApplied: Bool {
    !diffGroups.isEmpty && appliedDiffGroupIDs.count == diffGroups.count
  }
}
