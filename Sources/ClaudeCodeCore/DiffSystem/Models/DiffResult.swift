//
//  DiffResult.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 9/3/25.
//

import Foundation

// MARK: - DiffResult

struct DiffResult: Equatable, Codable {
  
  // MARK: Lifecycle
  
  init(
    filePath: String,
    fileName: String,
    original: String,
    updated: String,
    diff: String,
    storage: String,
    isInitial: Bool = false
  ) {
    self.filePath = filePath
    self.fileName = fileName
    self.original = original
    self.updated = updated
    self.diff = diff
    self.storage = storage
    self.isInitial = isInitial
  }
  
  // MARK: Internal
  
  var filePath: String
  var fileName: String
  var original: String
  var updated: String
  var diff: String
  var storage: String
  var isInitial: Bool
}

extension DiffResult {
  
  static let initial = DiffResult(filePath: "", fileName: "", original: "", updated: "", diff: "", storage: "", isInitial: true)
}
