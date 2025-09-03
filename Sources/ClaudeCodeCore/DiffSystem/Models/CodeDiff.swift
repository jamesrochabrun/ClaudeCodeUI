//
//  CodeDiff.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 9/3/25.
//

import Foundation

struct CodeDiff {
  let id = UUID()
  let externalID: String?
  let searchPattern: String
  let replacement: String
  let description: String?
  
  /// Initializes a new CodeDiff instance.
  ///
  /// - Parameters:
  ///   - externalID: Optional external identifier for the diff. Defaults to nil.
  ///   - find: The string pattern to search for in the original text.
  ///   - replace: The replacement string to substitute for the found pattern.
  ///   - note: Optional description providing context about the change. Defaults to nil.
  init(
    _ externalID: String? = nil,
    find: String,
    replace: String,
    note: String? = nil)
  {
    self.externalID = externalID
    self.searchPattern = find
    self.replacement = replace
    self.description = note
  }
}

extension CodeDiff: Identifiable, Equatable {
  static func == (lhs: CodeDiff, rhs: CodeDiff) -> Bool {
    lhs.id == rhs.id
  }
}

extension CodeDiff {
  var hasShortPattern: Bool {
    searchPattern.trimmingCharacters(in: .whitespacesAndNewlines).count < 5
  }
  
  var inverse: CodeDiff {
    CodeDiff(
      externalID,
      find: replacement,
      replace: searchPattern,
      note: description.map { "Undo: \($0)" }
    )
  }
}
