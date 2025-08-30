//
//  FileDiffTypes.swift
//  ClaudeCodeUI
//
//  Created on 1/30/2025.
//

import Foundation
import SwiftUI

// MARK: - Core Types

/// Represents a search and replace operation
public struct SearchReplace: Codable, Sendable {
  public let search: String
  public let replace: String
  
  public init(search: String, replace: String) {
    self.search = search
    self.replace = replace
  }
}

/// Represents a complete file change with diff information
public struct FileChangeDiff: Codable, Sendable {
  public let oldContent: String
  public let newContent: String
  public let diff: [LineChange]
  
  public init(oldContent: String, newContent: String, diff: [LineChange]) {
    self.oldContent = oldContent
    self.newContent = newContent
    self.diff = diff
  }
}

/// Enhanced FileChange with baseline tracking
public struct FileChange: Codable, Sendable {
  public let filePath: URL
  public let oldContent: String
  public let suggestedNewContent: String
  public let selectedChange: [LineChange]
  public let id: String
  public var baselineContent: String?
  
  public init(
    filePath: URL,
    oldContent: String,
    suggestedNewContent: String,
    selectedChange: [LineChange],
    id: String = UUID().uuidString,
    baselineContent: String? = nil
  ) {
    self.filePath = filePath
    self.oldContent = oldContent
    self.suggestedNewContent = suggestedNewContent
    self.selectedChange = selectedChange
    self.id = id
    self.baselineContent = baselineContent
  }
}

// MARK: - Diff Errors

public enum DiffError: LocalizedError {
  case message(String)
  case notADiff(content: String)
  case searchPatternNotFound(pattern: String)
  case gitDiffFailed(String)
  case invalidFormat(String)
  
  public var errorDescription: String? {
    switch self {
    case .message(let message):
      return message
    case .notADiff(let content):
      return "The diff is not correctly formatted. Could not parse \(content)"
    case .searchPatternNotFound(let pattern):
      return "Search pattern not found: \(pattern)"
    case .gitDiffFailed(let message):
      return "Git diff failed: \(message)"
    case .invalidFormat(let message):
      return "Invalid format: \(message)"
    }
  }
}