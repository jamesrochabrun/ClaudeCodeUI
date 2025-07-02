//
//  FileSearchViewModel.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 2025-07-01.
//

import Foundation
import SwiftUI

// MARK: - Observable View Model

@Observable
@MainActor
final class FileSearchViewModel {
  // MARK: - Properties
  
  private let xcodeObservationViewModel: XcodeObservationViewModel
  private let fileSearchManager: InlineFileSearchProtocol
  private var projectPath: String?
  
  var searchQuery: String = "" {
    didSet {
      if searchQuery != oldValue {
        performSearch()
      }
    }
  }
  
  var searchResults: [FileResult] = [] {
    didSet {
      // Reset selection when results change
      if searchResults.isEmpty {
        selectedIndex = 0
      } else if selectedIndex >= searchResults.count {
        selectedIndex = 0
      }
    }
  }
  var selectedIndex: Int = 0
  var isSearching: Bool = false
  
  private var searchTask: Task<Void, Never>?
  
  // MARK: - Initialization
  
  init(xcodeObservationViewModel: XcodeObservationViewModel, projectPath: String? = nil) {
    self.xcodeObservationViewModel = xcodeObservationViewModel
    
    // Try to get a valid search path
    var searchPath = projectPath
    
    // If no project path provided, try to get from XcodeObservationViewModel
    if searchPath == nil || searchPath?.isEmpty == true {
      searchPath = xcodeObservationViewModel.getProjectRootPath()
    }
    
    // If still no path, try to use current working directory
    if searchPath == nil || searchPath?.isEmpty == true {
      searchPath = FileManager.default.currentDirectoryPath
      print("[FileSearchViewModel] No project path provided, using current directory: '\(searchPath ?? "")'")
    }
    
    self.projectPath = searchPath
    self.fileSearchManager = InlineFileSearchManager(projectPath: searchPath)
  }
  
  // MARK: - Public Methods
  
  func updateProjectPath(_ path: String?) {
    self.projectPath = path
    if let path = path {
      fileSearchManager.updateSearchPath(path)
    }
  }
  
  func startSearch(query: String) {
    searchQuery = query
  }
  
  func clearSearch() {
    searchQuery = ""
    searchResults = []
    selectedIndex = 0
    isSearching = false
    searchTask?.cancel()
    searchTask = nil
    fileSearchManager.cancelSearch()
  }
  
  func selectNext() {
    guard !searchResults.isEmpty else { return }
    selectedIndex = min(selectedIndex + 1, searchResults.count - 1)
  }
  
  func selectPrevious() {
    guard !searchResults.isEmpty else { return }
    selectedIndex = max(selectedIndex - 1, 0)
  }
  
  func getSelectedResult() -> FileResult? {
    guard selectedIndex >= 0 && selectedIndex < searchResults.count else { return nil }
    return searchResults[selectedIndex]
  }
  
  // MARK: - Private Methods
  
  private func performSearch() {
    // Cancel any existing search
    searchTask?.cancel()
    fileSearchManager.cancelSearch()
    
    guard !searchQuery.isEmpty else {
      searchResults = []
      return
    }
    
    // Use the project path if available
    if let projectPath = projectPath, !projectPath.isEmpty {
      fileSearchManager.updateSearchPath(projectPath)
    }
      
    isSearching = true
    
    searchTask = Task { @MainActor in
      do {
        // Add debounce
        try await Task.sleep(nanoseconds: 150_000_000) // 0.15 seconds
        try Task.checkCancellation()
        
        let results = try await fileSearchManager.performSearch(
          query: searchQuery,
          existingFiles: Set<FileResult>(), // Empty set for now
          maxResults: 100
        )
        
        if !Task.isCancelled {
          self.searchResults = results
          self.selectedIndex = results.isEmpty ? 0 : 0
        }
      } catch is CancellationError {
        print("[FileSearchViewModel] Search cancelled")
      } catch {
        print("[FileSearchViewModel] Search error: \(error)")
        self.searchResults = []
      }
      self.isSearching = false
    }
  }
}
