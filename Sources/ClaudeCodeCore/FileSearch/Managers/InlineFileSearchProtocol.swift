//
//  InlineFileSearchProtocol.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 2025-01-01.
//

import Foundation

// MARK: - InlineFileSearchProtocol

/// Protocol defining the inline file search capabilities for @ mentions.
/// Implementations should provide efficient file system search operations with proper
/// cancellation support and resource management.
@MainActor
protocol InlineFileSearchProtocol {
  
  /// Cancels any ongoing search operations immediately.
  /// This method should be called when search needs to be interrupted, such as when starting a new search
  /// or when the user cancels the current search operation.
  func cancelSearch()
  
  /// Performs an asynchronous search for files matching the given query.
  ///
  /// - Parameters:
  ///   - query: The search string to match against file names.
  ///   - existingFiles: A set of already known `FileResult` objects to avoid duplicates and preserve their states.
  ///   - maxResults: The maximum number of search results to return. Defaults to 100 if not specified.
  ///
  /// - Returns: An array of `FileResult` objects matching the search criteria.
  ///
  /// - Throws: An error if the search operation fails or is cancelled.
  func performSearch(
    query: String,
    existingFiles: Set<FileResult>,
    maxResults: Int
  ) async throws -> [FileResult]
  
  /// Performs an asynchronous search for files containing the specified text content.
  ///
  /// This method searches through file contents rather than just file names, making it useful for finding
  /// specific code implementations, text patterns, or documentation within files.
  ///
  /// - Parameters:
  ///   - query: The search string to match against file contents.
  ///   - existingFiles: A set of already known `FileResult` objects to avoid duplicates and preserve their states.
  ///   - maxResults: The maximum number of search results to return. This helps limit resource usage for large searches.
  ///
  /// - Returns: An array of `FileResult` objects matching the search criteria. Each `FileResult` includes the matching
  ///           lines and their line numbers where the query text was found.
  ///
  /// - Throws: An error if:
  ///   - The search operation is cancelled
  ///   - Files cannot be accessed or read
  ///   - The file system cannot be queried
  ///
  /// - Note: The search is case-insensitive and has a file size limit of 5MB per file to ensure performance.
  func performContentSearch(
    query: String,
    existingFiles: Set<FileResult>,
    maxResults: Int
  ) async throws -> [FileResult]
  
  /// Updates the base search path for all future search operations.
  ///
  /// - Parameters:
  ///   - path: The new project directory path to use as the search root.
  func updateSearchPath(_ path: String)
}