//
//  FileDataReader.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 9/2/25.
//

import Foundation

// MARK: - FileDataReader

protocol FileDataReader {
  
  /// The root path of the project. This can be used as a base for relative file paths.
  var projectPath: String? { get }
  
  func readFileContent(
    in paths: [String],
    maxTasks: Int,
  ) async throws -> [String: String]
  
  /// Cancels the current file content loading task if one exists.
  /// This method can be called to stop any ongoing file reading operations.
  func cancelCurrentTask()
}

// MARK: - DefaultFileDataReader

final class DefaultFileDataReader: FileDataReader {
  
  // MARK: Lifecycle
  
  init(projectPath: String?) {
    self.projectPath = projectPath
  }
  
  // MARK: Internal
  
  let projectPath: String?
  
  func readFileContent(
    in paths: [String],
    maxTasks: Int = 10,
  ) async throws -> [String: String] {
    guard !paths.isEmpty else {
      throw FileDataReaderError.noPaths
    }
    
    currentTask?.cancel()
    let task = Task<[String: String], Error> {
      var results = [String: String]()
      
      let batches = paths.chunked(into: maxTasks)
      for batch in batches {
        try await withThrowingTaskGroup(of: (String, String?).self) { group in
          for path in batch {
            if Task.isCancelled { break }
            
            group.addTask {
              guard !Task.isCancelled else {
                throw CancellationError()
              }
              
              return try autoreleasepool {
                do {
                  let url = URL(fileURLWithPath: path)
                  let fileHandle = try FileHandle(forReadingFrom: url)
                  defer {
                    try? fileHandle.close()
                  }
                  
                  guard let data = try fileHandle.readToEnd() else {
                    return (path, nil)
                  }
                  
                  guard let content = String(data: data, encoding: .utf8) else {
                    throw FileDataReaderError.invalidEncoding(path: path)
                  }
                  
                  return (path, content)
                } catch let error as FileDataReaderError {
                  throw error
                } catch {
                  throw FileDataReaderError.fileReadError(path: path, underlying: error)
                }
              }
            }
          }
          
          for try await (path, content) in group {
            if let content {
              results[path] = content
            }
          }
        }
      }
      return results
    }
    
    currentTask = task
    return try await task.value
  }
  
  func cancelCurrentTask() {
    currentTask?.cancel()
    currentTask = nil
  }
  
  // MARK: Private
  
  private var currentTask: Task<[String: String], Error>?
  
}

// MARK: - FileDataReaderError

enum FileDataReaderError: LocalizedError {
  case noPaths
  case fileReadError(path: String, underlying: Error)
  case invalidEncoding(path: String)
  
  // MARK: Internal
  
  var errorDescription: String? {
    switch self {
    case .noPaths:
      "No file names provided"
    case .fileReadError(let path, let error):
      "Failed to read file at path: \(path), error: \(error.localizedDescription)"
    case .invalidEncoding(let path):
      "Failed to decode UTF-8 content for file at path: \(path)"
    }
  }
}

extension Array {
  func chunked(into size: Int) -> [[Element]] {
    var chunks = [[Element]]()
    var index = 0
    while index < count {
      let chunk = Array(self[index..<Swift.min(index + size, count)])
      chunks.append(chunk)
      index += size
    }
    return chunks
  }
}
