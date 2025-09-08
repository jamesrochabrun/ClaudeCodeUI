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
      
      let diffResult = DiffResult(
        filePath: fileEdit.filePath,
        fileName: fileEdit.filePath,
        original: contentOfFile,
        updated: "",
        diff: fileEdit.xmlDiff,
        storage: contentOfFile
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
        let xmlDiff = createXMLDiff(
          original: contentOfFile,
          replacement: fileContent.content
        )
        
        let diffResult = DiffResult(
          filePath: fileContent.filePath,
          fileName: fileContent.filePath,
          original: contentOfFile,
          updated: "",
          diff: xmlDiff,
          storage: fileContent.content
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
  /// - Returns: A `MergeResult` object representing the new file
  private func createNewFileDiffResult(
    filePath: String,
    content: String
  ) -> DiffResult {
    // For new files, create a special XML diff with no SEARCH section
    // This ensures only additions are shown, not removals
    let xmlDiff = """
    <DIFF id="\(UUID().uuidString)">
    <SEARCH></SEARCH>
    <REPLACE>
    \(content)
    </REPLACE>
    </DIFF>
    """
    
    return .init(
      filePath: filePath,
      fileName: filePath,
      original: "",      // Empty since file doesn't exist
      updated: content,  // The new content to be created
      diff: xmlDiff,     // XML diff showing only additions
      storage: content   // Storage remains the same
    )
  }
  
  /// Creates an XML diff string representing the difference between two strings.
  ///
  /// - Parameters:
  ///   - original: The original content
  ///   - replacement: The new content that will replace the original
  /// - Returns: An XML string representing the diff
  private func createXMLDiff(
    original: String,
    replacement: String
  ) -> String {
    """
    <DIFF id="\(UUID().uuidString)">
    <SEARCH>
    \(original)
    </SEARCH>
    <REPLACE>
    \(replacement)
    </REPLACE>
    </DIFF>
    """
  }
}
