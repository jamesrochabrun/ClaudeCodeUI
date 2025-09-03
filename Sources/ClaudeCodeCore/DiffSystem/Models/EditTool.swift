//
//  EditTools.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 9/3/25.
//

import Foundation

/// Claude Code edit tools that modify files
public enum EditTool: String {
  
  /// Performs exact string replacements in files
  case edit = "Edit"
  
  /// Makes multiple edits to a single file in one operation
  case multiEdit = "MultiEdit"
  
  /// Writes a file to the local filesystem
  case write = "Write"
}
