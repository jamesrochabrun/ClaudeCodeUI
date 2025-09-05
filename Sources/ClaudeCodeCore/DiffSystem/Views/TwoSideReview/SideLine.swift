//
//  SideLine.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 9/2/25.
//

import Foundation

// MARK: - SideLine

struct SideLine: Identifiable {
  let id: String
  let text: String
  let originalLineNumber: Int?
  let updatedLineNumber: Int?
  let type: DiffTerminalService.DiffType
}
