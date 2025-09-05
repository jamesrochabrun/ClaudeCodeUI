//
//  FileEdit.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 9/3/25.
//

import Foundation

// MARK: - FileEdit

struct FileEdit: Codable {
  enum CodingKeys: String, CodingKey {
    case filePath = "file_path"
    case edits
    case newString = "new_string"
    case oldString = "old_string"
    case replaceAll = "replace_all"
  }
  
  let filePath: String
  let edits: [Edit]?
  let newString: String?
  let oldString: String?
  let replaceAll: Bool?
  
  var allEdits: [Edit] {
    if let edits {
      return edits
    } else if let newString, let oldString {
      return [Edit(newString: newString, oldString: oldString, replaceAll: replaceAll ?? false)]
    }
    return []
  }
  
  /// XML representation of all edits for diffing purposes
  var xmlDiff: String {
    allEdits.map { $0.xmlDiff }.joined(separator: "\n")
  }
}

// MARK: - Edit

struct Edit: Codable {
  
  let newString: String
  let oldString: String
  let replaceAll: Bool
  let id = UUID()
  
  enum CodingKeys: String, CodingKey {
    case newString = "new_string"
    case oldString = "old_string"
    case replaceAll = "replace_all"
  }
  
  var xmlDiff: String {
    """
      <DIFF id="\(id.uuidString)">
      <SEARCH>
      \(oldString)
      </SEARCH>
      <REPLACE>
      \(newString)
      </REPLACE>
      </DIFF>
    """
  }
}
