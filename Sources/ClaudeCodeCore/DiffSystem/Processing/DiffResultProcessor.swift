//
//  DiffResultProcessor.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 9/3/25.
//

import Foundation
import SwiftUI

struct DiffResultProcessor {
  
  init(
    fileDataReader: FileDataReader
  ) {
    self.fileDataReader = fileDataReader
  }
  
  // MARK: Internal
  
  func processEditTool(
    response: String,
    tool: EditTool
  ) async -> [DiffResult]? {
    let decoder = JSONDecoder()
    guard let jsonData = response.data(using: .utf8) else {
      AppLogger.error("Error: Unable to instantiate jsonData")
      return nil
    }
    
    switch tool {
    case .edit, .multiEdit:
      return await processEditToolResponse(jsonData: jsonData, decoder: decoder)
      
    case .write:
      return await processWriteToolResponse(jsonData: jsonData, decoder: decoder)
    }
  }
  
  // MARK: Private
  
  private let fileDataReader: FileDataReader
  
  /// Processes the response from edit and multiEdit tools.
  ///
  /// - Parameters:
  ///   - jsonData: The decoded JSON data from the tool response
  ///   - decoder: The JSON decoder instance
  /// - Returns: An array of created diff results, or nil if processing failed
  private func processEditToolResponse(
    jsonData: Data,
    decoder: JSONDecoder
  ) async -> [DiffResult]? {
    do {
      let fileEdit = try decoder.decode(FileEdit.self, from: jsonData)
      let contentOfFile = try await fileDataReader.readFileContent(
        in: [fileEdit.filePath],
        maxTasks: 3
      ).values.first

      guard let contentOfFile else {
        AppLogger.error("Error: Unable to find content for \(fileEdit.filePath)")
        return nil
      }

      // Apply edits to get the updated content for diff display
      let updatedContent = applyEdits(fileEdit.allEdits, to: contentOfFile)

      let diffResult = DiffResult(
        filePath: fileEdit.filePath,
        fileName: fileEdit.filePath,
        original: contentOfFile,
        updated: updatedContent
      )
      return [diffResult]
    } catch {
      AppLogger.error("Error processing edit tool response: \(error)")
      return nil
    }
  }
  
  /// Processes the response from write tools.
  ///
  /// This method handles both new file creation and modifications to existing files.
  ///
  /// - Parameters:
  ///   - jsonData: The decoded JSON data from the tool response
  ///   - decoder: The JSON decoder instance
  /// - Returns: An array of created diff results, or nil if processing failed
  private func processWriteToolResponse(
    jsonData: Data,
    decoder: JSONDecoder
  ) async -> [DiffResult]? {
    do {
      let fileContent = try decoder.decode(FileContent.self, from: jsonData)
      
      if
        let contentOfFile = try? await fileDataReader.readFileContent(
          in: [fileContent.filePath],
          maxTasks: 3
        ).values.first
      {
        // Existing file - create diff
        let diffResult = DiffResult(
          filePath: fileContent.filePath,
          fileName: fileContent.filePath,
          original: contentOfFile,
          updated: fileContent.content
        )
        return [diffResult]
      } else {
        // New file
        return [createNewFileDiffResult(
          filePath: fileContent.filePath,
          content: fileContent.content
        )]
      }
    } catch {
      AppLogger.error("Error processing write tool response: \(error)")
      return nil
    }
  }
  
  /// Creates a diff result for a new file.
  ///
  /// - Parameters:
  ///   - filePath: The path where the new file will be created
  ///   - content: The content of the new file
  /// - Returns: A `DiffResult` object representing the new file
  private func createNewFileDiffResult(
    filePath: String,
    content: String
  ) -> DiffResult {
    .init(
      filePath: filePath,
      fileName: filePath,
      original: "",      // Empty since file doesn't exist
      updated: content   // The new content to be created
    )
  }

  /// Applies a list of edits to the original content.
  ///
  /// - Parameters:
  ///   - edits: The list of edits to apply
  ///   - content: The original content to modify
  /// - Returns: The content with all edits applied
  private func applyEdits(_ edits: [Edit], to content: String) -> String {
    var result = content
    for edit in edits {
      if edit.replaceAll {
        result = result.replacingOccurrences(of: edit.oldString, with: edit.newString)
      } else {
        // Replace only first occurrence
        if let range = result.range(of: edit.oldString) {
          result = result.replacingCharacters(in: range, with: edit.newString)
        }
      }
    }
    return result
  }
}
