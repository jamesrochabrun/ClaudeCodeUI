//
//  FileContent.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 9/3/25.
//

import Foundation

// MARK: - FileContent

struct FileContent: Codable {
  enum CodingKeys: String, CodingKey {
    case content
    case filePath = "file_path"
  }

  let content: String
  let filePath: String
}

extension FileContent {

  static func from(jsonData: Data) throws -> FileContent {
    let decoder = JSONDecoder()
    return try decoder.decode(FileContent.self, from: jsonData)
  }
  
  static func from(jsonString: String) throws -> FileContent {
    guard let data = jsonString.data(using: .utf8) else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: [],
          debugDescription: "Unable to convert string to data"
        )
      )
    }
    return try from(jsonData: data)
  }
}
