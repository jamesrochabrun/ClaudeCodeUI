//
//  CommandScannerProtocol.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 2025-11-05.
//

import Foundation

// MARK: - CommandScannerProtocol

/// Protocol defining slash command scanning and search capabilities.
/// Implementations should scan both user and project command directories,
/// parse markdown files, and provide efficient filtering.
@MainActor
protocol CommandScannerProtocol {

  /// Scans command directories and loads all available commands.
  /// This should be called when the scanner is initialized or when commands need to be refreshed.
  ///
  /// - Parameter projectPath: The current project path for scanning project-scoped commands.
  ///   If nil, only user-scoped commands will be scanned.
  func loadCommands(projectPath: String?) async

  /// Searches for commands matching the given query.
  ///
  /// - Parameters:
  ///   - query: The search string to match against command names.
  ///   - maxResults: The maximum number of search results to return.
  ///
  /// - Returns: An array of matching SlashCommand objects.
  func searchCommands(query: String, maxResults: Int) -> [SlashCommand]

  /// Reloads all commands from disk.
  /// Use this when you want to refresh the command list after external changes.
  ///
  /// - Parameter projectPath: The current project path.
  func reloadCommands(projectPath: String?) async

  /// Updates the project path and rescans project commands.
  ///
  /// - Parameter projectPath: The new project path.
  func updateProjectPath(_ projectPath: String?) async
}
