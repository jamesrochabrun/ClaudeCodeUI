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
  
  /// Array of code differences parsed from XML format
  let xmlDiffs: [CodeDiff]
  
  /// Groups of related diffs organized by the DiffTerminalService
  let diffGroups: [DiffTerminalService.DiffGroup]
  
  /// Maps individual diff identifiers to their corresponding group IDs
  let diffToGroupIDMap: [String: UUID]
  
  /// Maps group IDs back to their diff identifiers
  let groupIDToDiffMap: [UUID: String]
  
  /// Set of group IDs that have been applied to the file
  let appliedDiffGroupIDs: Set<UUID>
  
  /// The result of the diff operation (initial, success, or failure)
  let diffResult: DiffResult
  
  /// Computed property indicating if all changes have been applied
  var areAllChangesApplied: Bool {
    !diffGroups.isEmpty && appliedDiffGroupIDs.count == diffGroups.count
  }
}
