//
//  CommandSearchViewModel.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 2025-11-05.
//

import Foundation
import SwiftUI

// MARK: - Observable View Model

@Observable
@MainActor
public final class CommandSearchViewModel {
  // MARK: - Properties

  private let commandScanner: CommandScannerProtocol
  private var projectPath: String?

  public var searchQuery: String = "" {
    didSet {
      if searchQuery != oldValue {
        print("[CommandSearchViewModel] searchQuery changed from '\(oldValue)' to '\(searchQuery)'")
        performSearch()
      }
    }
  }

  public var searchResults: [CommandResult] = [] {
    didSet {
      print("[CommandSearchViewModel] searchResults didSet called: \(searchResults.count) results (was \(oldValue.count))")
      // Reset selection when results change
      if searchResults.isEmpty {
        selectedIndex = 0
      } else if selectedIndex >= searchResults.count {
        selectedIndex = 0
      }
    }
  }

  public var selectedIndex: Int = 0
  public var isSearching: Bool = false

  private var searchTask: Task<Void, Never>?
  private var loadTask: Task<Void, Never>?

  // MARK: - Initialization

  public init(projectPath: String? = nil) {
    print("[CommandSearchViewModel] Initializing with projectPath: \(projectPath ?? "nil")")
    self.projectPath = projectPath
    self.commandScanner = CommandScanner(projectPath: projectPath)

    // Load commands asynchronously on init
    loadTask = Task { @MainActor in
      print("[CommandSearchViewModel] Starting command loading task")
      await commandScanner.loadCommands(projectPath: projectPath)
      print("[CommandSearchViewModel] Command loading task completed")
    }
  }

  // MARK: - Public Methods

  public func updateProjectPath(_ path: String?) {
    self.projectPath = path
    loadTask?.cancel()
    loadTask = Task { @MainActor in
      await commandScanner.updateProjectPath(path)
    }
  }

  public func startSearch(query: String) {
    print("[CommandSearchViewModel] startSearch called with query: '\(query)'")
    searchQuery = query
    // Force search even if query hasn't changed (e.g., from "" to "")
    performSearch()
  }

  public func clearSearch() {
    searchQuery = ""
    searchResults = []
    selectedIndex = 0
    isSearching = false
    searchTask?.cancel()
    searchTask = nil
  }

  public func selectNext() {
    guard !searchResults.isEmpty else { return }
    selectedIndex = min(selectedIndex + 1, searchResults.count - 1)
  }

  public func selectPrevious() {
    guard !searchResults.isEmpty else { return }
    selectedIndex = max(selectedIndex - 1, 0)
  }

  public func getSelectedResult() -> CommandResult? {
    guard selectedIndex >= 0 && selectedIndex < searchResults.count else { return nil }
    return searchResults[selectedIndex]
  }

  public func reloadCommands() {
    loadTask?.cancel()
    loadTask = Task { @MainActor in
      await commandScanner.reloadCommands(projectPath: projectPath)
      // Re-run search if there's an active query
      if !searchQuery.isEmpty {
        performSearch()
      }
    }
  }

  // MARK: - Private Methods

  private func performSearch() {
    print("[CommandSearchViewModel] performSearch called with query: '\(searchQuery)'")
    // Cancel any existing search
    searchTask?.cancel()

    isSearching = true

    searchTask = Task { @MainActor in
      do {
        print("[CommandSearchViewModel] Waiting for command loading to complete...")
        // Wait for initial command loading to complete if it's still running
        await loadTask?.value
        print("[CommandSearchViewModel] Command loading complete, proceeding with search")

        // Add debounce only if there's a query
        if !searchQuery.isEmpty {
          print("[CommandSearchViewModel] Debouncing search...")
          try await Task.sleep(nanoseconds: 150_000_000) // 0.15 seconds
          try Task.checkCancellation()
        }

        // Search commands (synchronous operation, but wrapped in Task for consistency)
        // Empty query returns all commands
        let commands = commandScanner.searchCommands(query: searchQuery, maxResults: 100)
        print("[CommandSearchViewModel] Got \(commands.count) commands from scanner")

        // Convert to CommandResult
        let results = commands.map { command in
          CommandResult(command: command, isSelected: false)
        }

        if !Task.isCancelled {
          print("[CommandSearchViewModel] Setting \(results.count) results")
          self.searchResults = results
          self.selectedIndex = results.isEmpty ? 0 : 0
        }
      } catch is CancellationError {
        print("[CommandSearchViewModel] Search cancelled")
      } catch {
        print("[CommandSearchViewModel] Search error: \(error)")
        self.searchResults = []
      }
      self.isSearching = false
      print("[CommandSearchViewModel] Search completed, isSearching = false")
    }
  }
}
