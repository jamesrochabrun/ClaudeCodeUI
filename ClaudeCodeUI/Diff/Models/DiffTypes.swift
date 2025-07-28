//
//  DiffTypes.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 7/7/2025.
//

import Foundation
import SwiftUI

// MARK: - Core Types

public enum DiffContentType: String, Sendable, Codable {
  case removed
  case added
  case unchanged
}

/// Represents a single line change within a diff operation.
///
/// `LineChange` captures all the information about a line that has been added, removed,
/// or remained unchanged during a diff operation. It provides both line-based and
/// character-based location information to support various diff visualization needs.
public struct LineChange: Sendable, Codable {
  
  /// The range of characters within the line that are affected by this change.
  /// This range is relative to the line content and can be used for highlighting
  /// specific portions of the line in diff visualizations.
  public let characterRange: Range<Int>
  
  /// The line number in the original (old) version of the file.
  /// This is `nil` for lines that were added (not present in the original).
  public let oldLineNumber: Int?
  
  /// The line number in the modified (new) version of the file.
  /// This is `nil` for lines that were removed (not present in the new version).
  public let newLineNumber: Int?
  
  /// The zero-based line offset used for positioning in the diff view.
  /// This value is calculated from the line numbers for backward compatibility.
  public let lineOffset: Int
  
  /// The actual text content of the line, including any modifications.
  public let content: String
  
  /// The type of change this line represents (added, removed, or unchanged).
  public let type: DiffContentType
  
  /// Creates a new `LineChange` instance with explicit line numbers.
  ///
  /// - Parameters:
  ///   - oldLineNumber: The line number in the original file (nil for added lines)
  ///   - newLineNumber: The line number in the modified file (nil for removed lines)
  ///   - characterRange: The range of characters affected within the line
  ///   - content: The text content of the line
  ///   - type: The type of change (added, removed, or unchanged)
  public init(oldLineNumber: Int?, newLineNumber: Int?, characterRange: Range<Int>, content: String, type: DiffContentType) {
    self.oldLineNumber = oldLineNumber
    self.newLineNumber = newLineNumber
    self.characterRange = characterRange
    self.content = content
    self.type = type
    // For backward compatibility, use new line number or old line number minus 1 for offset
    self.lineOffset = (newLineNumber ?? oldLineNumber ?? 1) - 1
  }
  
  /// Legacy initializer for backward compatibility.
  /// - Parameters:
  ///   - lineOffset: The zero-based line number where the change occurs
  ///   - characterRange: The range of characters affected within the line
  ///   - content: The text content of the change
  ///   - type: The type of diff operation (add, delete, or unchanged)
  public init(_ lineOffset: Int, _ characterRange: Range<Int>, _ content: String, _ type: DiffContentType) {
    self.lineOffset = lineOffset
    self.characterRange = characterRange
    self.content = content
    self.type = type
    // Convert offset to line numbers
    switch type {
    case .added:
      self.oldLineNumber = nil
      self.newLineNumber = lineOffset + 1
    case .removed:
      self.oldLineNumber = lineOffset + 1
      self.newLineNumber = nil
    case .unchanged:
      self.oldLineNumber = lineOffset + 1
      self.newLineNumber = lineOffset + 1
    }
  }
}

/// Represents a single line change with its formatted content for display.
/// 
/// This struct combines a `LineChange` with its visual representation as an `AttributedString`,
/// allowing for rich text formatting (e.g., syntax highlighting, diff indicators) while
/// maintaining the underlying change information.
/// 
/// - Note: Conforms to `Sendable` for safe concurrent access across actor boundaries.
public struct FormattedLineChange: Sendable {
  /// The formatted content of the line, including any syntax highlighting or styling.
  /// This is typically used for display in UI components.
  public let formattedContent: AttributedString
  
  /// The underlying line change information, including the line number,
  /// change type (addition/deletion), and raw content.
  public let change: LineChange
  
  /// Creates a new formatted line change.
  /// 
  /// - Parameters:
  ///   - formattedContent: The styled representation of the line content.
  ///   - change: The underlying line change data.
  public init(formattedContent: AttributedString, change: LineChange) {
    self.formattedContent = formattedContent
    self.change = change
  }
}

/// Represents a collection of formatted line changes for an entire file.
/// 
/// This struct aggregates all the formatted line changes that make up a file's diff,
/// providing a complete representation of how a file has been modified with
/// rich formatting for each line.
/// 
/// - Note: Conforms to `Sendable` for safe concurrent access across actor boundaries.
public struct FormattedFileChange: Sendable {
  /// An ordered array of formatted line changes representing the complete diff.
  /// The order preserves the sequence of changes as they appear in the file.
  public let changes: [FormattedLineChange]
  
  /// Creates a new formatted file change.
  /// 
  /// - Parameter changes: An array of formatted line changes that comprise the file's diff.
  public init(changes: [FormattedLineChange]) {
    self.changes = changes
  }
}

// MARK: - FileDiff Namespace

/// A namespace enum for organizing file diff-related types and functionality.
/// 
/// This enum serves as a container for nested types, extensions, and utilities
/// related to file diffing operations. Using an enum as a namespace prevents
/// instantiation while providing a logical grouping for related functionality.
public enum FileDiff { }
