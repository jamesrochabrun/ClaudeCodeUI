//
//  CommandScanner.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 2025-11-05.
//

import Foundation

// MARK: - CommandScanner

@MainActor
final class CommandScanner: CommandScannerProtocol {

  // MARK: Lifecycle

  init(projectPath: String? = nil) {
    self.projectPath = projectPath
  }

  // MARK: Internal

  /// All loaded commands (both user and project)
  private(set) var allCommands: [SlashCommand] = []

  /// Current project path
  private(set) var projectPath: String?

  func loadCommands(projectPath: String?) async {
    self.projectPath = projectPath
    await scanAllCommands()
  }

  func searchCommands(query: String, maxResults: Int) -> [SlashCommand] {
    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

    // If query is empty, return all commands (up to maxResults)
    if trimmedQuery.isEmpty {
      return Array(allCommands.prefix(maxResults))
    }

    // Filter commands by name (substring match)
    let filtered = allCommands.filter { command in
      command.name.lowercased().contains(trimmedQuery) ||
      command.fullName.lowercased().contains(trimmedQuery)
    }

    return Array(filtered.prefix(maxResults))
  }

  func reloadCommands(projectPath: String?) async {
    self.projectPath = projectPath
    await scanAllCommands()
  }

  func updateProjectPath(_ projectPath: String?) async {
    self.projectPath = projectPath
    await scanAllCommands()
  }

  // MARK: Private

  /// Scans both user and project command directories
  private func scanAllCommands() async {
    var commands: [SlashCommand] = []

    // Scan user commands
    let userCommands = await scanCommandDirectory(scope: .user)
    commands.append(contentsOf: userCommands)

    // Scan project commands if projectPath is available
    if projectPath != nil {
      let projectCommands = await scanCommandDirectory(scope: .project)
      commands.append(contentsOf: projectCommands)
    }

    // Sort by name for consistent ordering
    allCommands = commands.sorted { $0.name < $1.name }
  }

  /// Scans a single command directory (user or project)
  private func scanCommandDirectory(scope: CommandScope) -> [SlashCommand] {
    guard let commandsPath = commandsDirectoryPath(for: scope) else {
      return []
    }

    // Check if directory exists
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: commandsPath, isDirectory: &isDirectory),
          isDirectory.boolValue else {
      return []
    }

    // Enumerate all .md files recursively
    guard let enumerator = FileManager.default.enumerator(
      at: URL(fileURLWithPath: commandsPath),
      includingPropertiesForKeys: [.isRegularFileKey],
      options: [.skipsHiddenFiles]
    ) else {
      return []
    }

    var commands: [SlashCommand] = []

    for case let fileURL as URL in enumerator {
      // Check if it's a regular file with .md extension
      guard fileURL.pathExtension == "md",
            let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
            resourceValues.isRegularFile == true else {
        continue
      }

      // Parse the command file
      if let command = CommandParser.parse(filePath: fileURL.path, scope: scope) {
        commands.append(command)
      }
    }

    return commands
  }

  /// Gets the commands directory path for the given scope
  private func commandsDirectoryPath(for scope: CommandScope) -> String? {
    switch scope {
    case .user:
      // User commands: ~/.claude/commands/
      let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
      return homeDirectory
        .appendingPathComponent(".claude")
        .appendingPathComponent("commands")
        .path

    case .project:
      // Project commands: <projectPath>/.claude/commands/
      guard let projectPath = projectPath else {
        return nil
      }
      return URL(fileURLWithPath: projectPath)
        .appendingPathComponent(".claude")
        .appendingPathComponent("commands")
        .path
    }
  }
}
