//
//  FileResult.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 2025-01-01.
//

import Foundation
import SwiftUI

// MARK: - SelectionMode

/// Represents how a file was set to selected.
enum SelectionMode: Codable {
  /// File was selected through user interaction in the UI.
  case userInteraction
  
  /// File was automatically marked as selected when opened in a new tab.
  case tab
}

// MARK: - FileResult

struct FileResult: Hashable, Identifiable, Codable {
  
  // MARK: Lifecycle
  
  init(
    filePath: String,
    isSelected: Bool = false,
    isActive: Bool = false,
    selectionMode: SelectionMode? = nil,
    matchingLines: [FileLine]? = nil
  ) {
    self.filePath = filePath
    self.isSelected = isSelected
    self.isActive = isActive
    self.selectionMode = selectionMode
    lowercasedFileName = (filePath as NSString).lastPathComponent.lowercased()
    fileName = (filePath as NSString).lastPathComponent
    id = filePath
    self.matchingLines = matchingLines
  }
  
  // MARK: Internal
  
  /// A matching line from a file in a Search Query.
  struct FileLine: Identifiable, Codable {
    let id: UUID
    let line: String
    let lineNumber: Int
    
    init(line: String, lineNumber: Int) {
      self.id = UUID()
      self.line = line
      self.lineNumber = lineNumber
    }
  }
  
  let id: String
  let filePath: String
  var isSelected: Bool
  var isActive: Bool
  var selectionMode: SelectionMode?
  let lowercasedFileName: String
  let fileName: String
  let matchingLines: [FileLine]?
  
  var fileExtension: String {
    let components = fileName.split(separator: ".")
    return components.last.map(String.init) ?? ""
  }
  
  var fileExtensionImageName: String {
    switch fileExtension {
    case "swift": "swift"
    case "md": "book"
    default: "doc"
    }
  }
  
  var imageForegroundColorForFileExtension: Color {
    switch fileExtension {
    case "swift": Color(red: 255/255, green: 88/255, blue: 44/255)
    default: .primary
    }
  }
  
  static func ==(lhs: FileResult, rhs: FileResult) -> Bool {
    lhs.filePath == rhs.filePath
  }
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(filePath)
  }
  
  // Convert to FileInfo for compatibility
  var fileInfo: FileInfo {
    FileInfo(path: filePath, name: fileName)
  }
}