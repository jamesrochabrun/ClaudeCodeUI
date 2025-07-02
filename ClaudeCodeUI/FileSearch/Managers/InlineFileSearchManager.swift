//
//  InlineFileSearchManager.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 2025-01-01.
//

import Foundation

// MARK: - InlineFileSearchManager

@MainActor
final class InlineFileSearchManager: InlineFileSearchProtocol {
  
  // MARK: Lifecycle
  
  init(projectPath: String?) {
    self.projectPath = projectPath
  }
  
  // MARK: Internal
  
  func updateSearchPath(_ path: String) {
    print("[InlineFileSearchManager] Updating search path to: '\(path)'")
    projectPath = path
  }
  
  func cancelSearch() {
    cleanup()
  }
  
  func performSearch(
    query: String,
    existingFiles: Set<FileResult>,
    maxResults: Int
  ) async throws -> [FileResult] {
    // Trim the query string to remove leading and trailing whitespace
    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    // Cancel previous query if any and clean up
    cleanup()
    
    // Check if the task was cancelled before starting
    if Task.isCancelled {
      throw CancellationError()
    }
    
    var isContinuationResumed = false
    var continuation: CheckedContinuation<[FileResult], Error>?
    
    return try await withTaskCancellationHandler(operation: {
      try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[FileResult], Error>) in
        continuation = cont
        let queryObject = NSMetadataQuery()
        
        print("[InlineFileSearchManager] Performing search with query: '\(trimmedQuery)' in path: '\(projectPath ?? "nil")' ")
        
        // Set search scope - if no project path, use current directory
        if let projectPath = projectPath, !projectPath.isEmpty {
            queryObject.searchScopes = [projectPath]
            print("[InlineFileSearchManager] Search scope set to: '\(projectPath)'")
        } else {
            // If no project path, use current directory as fallback
            let currentDir = FileManager.default.currentDirectoryPath
            print("[InlineFileSearchManager] WARNING: No project path set, using current directory: '\(currentDir)'")
            queryObject.searchScopes = [currentDir]
        }
        
        // Build the base predicate: Name contains query
        let namePredicate = NSPredicate(format: "%K CONTAINS[cd] %@", NSMetadataItemFSNameKey, trimmedQuery)
        var predicates = [namePredicate]
        
        let excludeDirectoriesPredicate = NSPredicate(format: "%K != %@", NSMetadataItemContentTypeKey, "public.folder")
        predicates.append(excludeDirectoriesPredicate)
        
        // Combine predicates
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        queryObject.predicate = compoundPredicate
        
        let sortDescriptor = NSSortDescriptor(
          key: NSMetadataItemFSNameKey,
          ascending: true,
          selector: #selector(NSString.localizedCaseInsensitiveCompare(_:))
        )
        queryObject.sortDescriptors = [sortDescriptor]
        
        isContinuationResumed = false
        
        // Observe when the query finishes gathering results
        observer = NotificationCenter.default.addObserver(
          forName: .NSMetadataQueryDidFinishGathering,
          object: queryObject,
          queue: .main
        ) { [weak self] notification in
          Task { @MainActor in
            guard let self else {
              if !isContinuationResumed {
                isContinuationResumed = true
                continuation?.resume(returning: [])
              }
              return
            }
            
            // Get the query object from the notification to avoid capturing it
            guard let query = notification.object as? NSMetadataQuery else {
              if !isContinuationResumed {
                isContinuationResumed = true
                continuation?.resume(returning: [])
              }
              return
            }
            
            query.disableUpdates()
            let results = self.processQueryResults(query, existingFiles: existingFiles, maxResults: maxResults)
            
            self.cleanup()
            if !isContinuationResumed {
              isContinuationResumed = true
              continuation?.resume(returning: results)
            }
          }
        }
        
        // Start the query
        metadataQuery = queryObject
        queryObject.start()
      }
    }, onCancel: {
      // Cancellation handler
      Task { @MainActor [weak self] in
        guard let self else { return }
        cleanup()
        if !isContinuationResumed {
          isContinuationResumed = true
          continuation?.resume(throwing: CancellationError())
        }
      }
    })
  }
  
  func performContentSearch(
    query: String,
    existingFiles: Set<FileResult>,
    maxResults: Int
  ) async throws -> [FileResult] {
    // Trim the query string to remove leading and trailing whitespace
    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    
    // Cancel previous query if any and clean up
    cleanup()
    
    // Check if the task was cancelled before starting
    if Task.isCancelled {
      throw CancellationError()
    }
    
    var isContinuationResumed = false
    var continuation: CheckedContinuation<[FileResult], Error>?
    
    return try await withTaskCancellationHandler(operation: {
      try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[FileResult], Error>) in
        continuation = cont
        let queryObject = NSMetadataQuery()
        
        print("[InlineFileSearchManager] Performing search with query: '\(trimmedQuery)' in path: '\(projectPath ?? "nil")' ")
        
        // Set search scope - if no project path, use current directory
        if let projectPath = projectPath, !projectPath.isEmpty {
            queryObject.searchScopes = [projectPath]
            print("[InlineFileSearchManager] Search scope set to: '\(projectPath)'")
        } else {
            // If no project path, use current directory as fallback
            let currentDir = FileManager.default.currentDirectoryPath
            print("[InlineFileSearchManager] WARNING: No project path set, using current directory: '\(currentDir)'")
            queryObject.searchScopes = [currentDir]
        }
        
        // Build the predicate to search file contents
        let contentPredicate = NSPredicate(format: "%K CONTAINS[cd] %@", NSMetadataItemTextContentKey, trimmedQuery)
        var predicates = [contentPredicate]
        
        // Exclude directories
        let excludeDirectoriesPredicate = NSPredicate(format: "%K != %@", NSMetadataItemContentTypeKey, "public.folder")
        predicates.append(excludeDirectoriesPredicate)
        
        // Combine predicates
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        queryObject.predicate = compoundPredicate
        
        let sortDescriptor = NSSortDescriptor(
          key: NSMetadataItemFSNameKey,
          ascending: true,
          selector: #selector(NSString.localizedCaseInsensitiveCompare(_:))
        )
        queryObject.sortDescriptors = [sortDescriptor]
        
        isContinuationResumed = false
        
        // Observe when the query finishes gathering results
        observer = NotificationCenter.default.addObserver(
          forName: .NSMetadataQueryDidFinishGathering,
          object: queryObject,
          queue: .main
        ) { [weak self] notification in
          Task { @MainActor in
            guard let self else {
              if !isContinuationResumed {
                isContinuationResumed = true
                continuation?.resume(returning: [])
              }
              return
            }
            
            // Get the query object from the notification to avoid capturing it
            guard let query = notification.object as? NSMetadataQuery else {
              if !isContinuationResumed {
                isContinuationResumed = true
                continuation?.resume(returning: [])
              }
              return
            }
            
            query.disableUpdates()
            let results = self.processQueryResultsWithContent(
              query,
              existingFiles: existingFiles,
              maxResults: maxResults,
              queryString: trimmedQuery
            )
            
            self.cleanup()
            if !isContinuationResumed {
              isContinuationResumed = true
              continuation?.resume(returning: results)
            }
          }
        }
        
        // Start the query
        metadataQuery = queryObject
        queryObject.start()
      }
    }, onCancel: {
      // Cancellation handler
      Task { @MainActor [weak self] in
        guard let self else { return }
        cleanup()
        if !isContinuationResumed {
          isContinuationResumed = true
          continuation?.resume(throwing: CancellationError())
        }
      }
    })
  }
  
  // MARK: Private
  
  private var projectPath: String?
  private var metadataQuery: NSMetadataQuery?
  private var observer: NSObjectProtocol?
  
  private func cleanup() {
    metadataQuery?.stop()
    metadataQuery = nil
    if let observer {
      NotificationCenter.default.removeObserver(observer)
      self.observer = nil
    }
  }
  
  private func processQueryResults(
    _ query: NSMetadataQuery,
    existingFiles: Set<FileResult>,
    maxResults: Int
  ) -> [FileResult] {
    var results: [FileResult] = []
    if let items = query.results as? [NSMetadataItem] {
      for item in items.prefix(maxResults) {
        if let path = item.value(forAttribute: NSMetadataItemPathKey) as? String {
          if let existingFileResult = existingFiles.first(where: { $0.filePath == path }) {
            results.append(existingFileResult)
          } else {
            let fileResult = FileResult(filePath: path, isSelected: false, selectionMode: nil)
            results.append(fileResult)
          }
        }
      }
    }
    return results
  }
  
  private func processQueryResultsWithContent(
    _ query: NSMetadataQuery,
    existingFiles: Set<FileResult>,
    maxResults: Int,
    queryString: String
  ) -> [FileResult] {
    var results = [FileResult]()
    let maxFileSizeInBytes: UInt64 = 5 * 1024 * 1024 // Limit to 5 MB files
    for item in query.results {
      guard let metadataItem = item as? NSMetadataItem else { continue }
      guard let filePath = metadataItem.value(forAttribute: NSMetadataItemPathKey) as? String else { continue }
      // Avoid duplicates
      if existingFiles.contains(where: { $0.filePath == filePath }) {
        continue
      }
      // Check file size before reading
      do {
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: filePath)
        if let fileSize = fileAttributes[FileAttributeKey.size] as? UInt64, fileSize <= maxFileSizeInBytes {
          // Read and process the file
          let fileContents = try String(contentsOfFile: filePath, encoding: .utf8)
          let lines = fileContents.components(separatedBy: .newlines)
          let matchingLinesWithNumbers = lines.enumerated().filter { _, line in
            line.lowercased().contains(queryString.lowercased())
          }
          // Create FileLine objects
          let fileLines = matchingLinesWithNumbers.map { index, line in
            FileResult.FileLine(line: line, lineNumber: index + 1)
          }
          // Create FileResult
          let fileResult = FileResult(
            filePath: filePath,
            matchingLines: fileLines
          )
          
          results.append(fileResult)
          if results.count >= maxResults {
            break
          }
        }
      } catch {
        // Handle errors (e.g., file not readable)
        continue
      }
    }
    return results
  }
}