//
//  DiffProcessor.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 9/3/25.
//

import CCTerminalServiceInterface
import Foundation

/// Processor that creates and modifies diff states without affecting SwiftUI render cycle
final class DiffProcessor {

  // MARK: Lifecycle

  init(terminalService: TerminalService) {
    self.terminalService = terminalService
    diffPreviewGenerator = DiffTerminalService(terminalService: terminalService)
  }

  // MARK: Internal

  /// Processes a diff result into a complete DiffState containing all necessary data structures
  /// for diff management and visualization.
  ///
  /// - Parameter diffResult: The raw diff result containing original content and diff information
  /// - Returns: A fully initialized DiffState with parsed diffs, groups, and mappings
  func processState(diffResult: DiffResult) async -> DiffState {
    let xmlDiffs = parseDiffs(from: diffResult)
    let processedDiffResult = prepareProcessedResult(diffResult, xmlDiffs: xmlDiffs)
    
    // Extract file extension from the file path
    let fileExtension = extractFileExtension(from: diffResult.filePath)
    
    let (diffGroups, mappings) = await map(
      xmlDiffs: xmlDiffs,
      original: diffResult.original,
      fileExtension: fileExtension
    )
    
    return DiffState(
      xmlDiffs: xmlDiffs,
      diffGroups: diffGroups,
      diffToGroupIDMap: mappings.diffToGroup,
      groupIDToDiffMap: mappings.groupToDiff,
      appliedDiffGroupIDs: [],
      diffResult: processedDiffResult
    )
  }
  
  // MARK: - Processing Helpers
  
  /// Parses XML-formatted diffs from a DiffResult into structured CodeDiff objects.
  ///
  /// - Parameter diffResult: The result containing the diff XML to parse
  /// - Returns: An array of parsed CodeDiff objects
  private func parseDiffs(from diffResult: DiffResult) -> [CodeDiff] {
    let combinedXML = buildCombinedXML(original: diffResult.original, diff: diffResult.diff)
    return diffApplier.parseDiffsIn(combinedXML)
  }
  
  /// Builds a combined XML string containing both the original code and diff information.
  ///
  /// - Parameters:
  ///   - original: The original code content
  ///   - diff: The diff XML content
  /// - Returns: A formatted XML string combining both inputs
  private func buildCombinedXML(original: String, diff: String) -> String {
    """
    <code_file>
    \(original)
    </code_file>
    
    \(diff)
    """
  }
  
  /// Prepares a processed version of the DiffResult with applied diffs and proper storage initialization.
  ///
  /// - Parameters:
  ///   - diffResult: The original diff result to process
  ///   - xmlDiffs: The parsed diffs to apply
  /// - Returns: A modified DiffResult with storage initialized and diffs applied to generate updated content
  private func prepareProcessedResult(_ diffResult: DiffResult, xmlDiffs: [CodeDiff]) -> DiffResult {
    var processedResult = diffResult
    
    if processedResult.storage.isEmpty {
      processedResult.storage = processedResult.original
    }
    
    processedResult.updated = diffApplier.apply(
      diffs: xmlDiffs,
      to: processedResult.original
    )
    
    return processedResult
  }
  
  /// Extracts the file extension from a file path.
  ///
  /// - Parameter filePath: The file path to extract extension from
  /// - Returns: The file extension without the dot, or nil if no extension found
  private func extractFileExtension(from filePath: String) -> String? {
    let url = URL(fileURLWithPath: filePath)
    let ext = url.pathExtension
    return ext.isEmpty ? nil : ext
  }

  private func map(
    xmlDiffs: [CodeDiff],
    original: String,
    fileExtension: String? = nil
  ) async -> (
    diffGroups: [DiffTerminalService.DiffGroup],
    mappings: (diffToGroup: [String: UUID], groupToDiff: [UUID: String])
  ) {
    var diffGroups = [DiffTerminalService.DiffGroup]()
    var diffToGroupIDMap = [String: UUID]()
    var groupIDToDiffMap = [UUID: String]()
    
    for diff in xmlDiffs {
      let diffGroup = await diffPreviewGenerator.createDiffGroup(
        for: diff,
        original: original,
        diffApplier: diffApplier,
        fileExtension: fileExtension
      )
      
      diffGroups.append(diffGroup)
      
      let diffKey = getDiffKey(diff)
      diffToGroupIDMap[diffKey] = diffGroup.id
      groupIDToDiffMap[diffGroup.id] = diffKey
    }
    
    return (diffGroups, (diffToGroupIDMap, groupIDToDiffMap))
  }

  // MARK: Private

  private let terminalService: TerminalService
  private let diffApplier = DiffApplyManager()
  private let diffPreviewGenerator: DiffTerminalService

  private func getDiffKey(_ diff: CodeDiff) -> String {
    diff.externalID ?? diff.id.uuidString
  }
}
