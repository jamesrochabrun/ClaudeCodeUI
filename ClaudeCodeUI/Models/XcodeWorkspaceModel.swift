//
//  XcodeWorkspaceModel.swift
//  ClaudeCodeUI
//
//  Created on 12/27/24.
//

import Foundation

/// Represents the current state of the Xcode workspace
public struct XcodeWorkspaceModel: Equatable {
  /// The name of the current workspace or project
  public let workspaceName: String?
  
  /// Information about the currently active file in the editor
  public let activeFile: FileInfo?
  
  /// All files currently open in Xcode
  public let openFiles: [FileInfo]
  
  /// Current text selections across all files
  public let selectedText: [TextSelection]
  
  /// Timestamp of when this state was captured
  public let timestamp: Date
  
  public init(
    workspaceName: String? = nil,
    activeFile: FileInfo? = nil,
    openFiles: [FileInfo] = [],
    selectedText: [TextSelection] = [],
    timestamp: Date = Date()
  ) {
    self.workspaceName = workspaceName
    self.activeFile = activeFile
    self.openFiles = openFiles
    self.selectedText = selectedText
    self.timestamp = timestamp
  }
}

/// Represents information about a file in Xcode
public struct FileInfo: Equatable, Identifiable {
  public let id = UUID()
  
  /// Full path to the file
  public let path: String
  
  /// File name without path
  public let name: String
  
  /// File content (optional, loaded on demand)
  public let content: String?
  
  /// File extension
  public var fileExtension: String? {
    URL(fileURLWithPath: path).pathExtension.isEmpty ? nil : URL(fileURLWithPath: path).pathExtension
  }
  
  /// Programming language based on file extension
  public var language: String? {
    guard let ext = fileExtension else { return nil }
    switch ext.lowercased() {
    case "swift": return "swift"
    case "m", "mm": return "objective-c"
    case "h", "hpp": return "c++"
    case "js", "jsx": return "javascript"
    case "ts", "tsx": return "typescript"
    case "py": return "python"
    case "rb": return "ruby"
    case "java": return "java"
    case "kt": return "kotlin"
    case "go": return "go"
    case "rs": return "rust"
    case "php": return "php"
    case "cs": return "csharp"
    case "sh", "bash": return "bash"
    case "yml", "yaml": return "yaml"
    case "json": return "json"
    case "xml": return "xml"
    case "md": return "markdown"
    default: return nil
    }
  }
  
  public init(path: String, name: String? = nil, content: String? = nil) {
    self.path = path
    self.name = name ?? URL(fileURLWithPath: path).lastPathComponent
    self.content = content
  }
}

/// Represents a text selection in a file
public struct TextSelection: Equatable, Identifiable {
  public let id = UUID()
  
  /// Path to the file containing the selection
  public let filePath: String
  
  /// The selected text
  public let selectedText: String
  
  /// Line range of the selection (1-based)
  public let lineRange: ClosedRange<Int>
  
  /// Column range on the start line
  public let columnRange: Range<Int>?
  
  /// Timestamp when the selection was captured
  public let timestamp: Date
  
  /// File name for display
  public var fileName: String {
    URL(fileURLWithPath: filePath).lastPathComponent
  }
  
  /// Formatted line range for display
  public var lineRangeDescription: String {
    if lineRange.lowerBound == lineRange.upperBound {
      return "Line \(lineRange.lowerBound)"
    } else {
      return "Lines \(lineRange.lowerBound)-\(lineRange.upperBound)"
    }
  }
  
  public init(
    filePath: String,
    selectedText: String,
    lineRange: ClosedRange<Int>,
    columnRange: Range<Int>? = nil,
    timestamp: Date = Date()
  ) {
    self.filePath = filePath
    self.selectedText = selectedText
    self.lineRange = lineRange
    self.columnRange = columnRange
    self.timestamp = timestamp
  }
}
