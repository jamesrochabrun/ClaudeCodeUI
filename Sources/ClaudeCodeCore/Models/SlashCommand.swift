//
//  SlashCommand.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 2025-11-05.
//

import Foundation

// MARK: - Command Scope
public enum CommandScope: String, Codable, Equatable {
  case user = "user"
  case project = "project"

  var displayName: String {
    switch self {
    case .user: return "User"
    case .project: return "Project"
    }
  }

  var systemImageName: String {
    switch self {
    case .user: return "person.circle"
    case .project: return "folder.circle"
    }
  }
}

// MARK: - Slash Command Model
public struct SlashCommand: Identifiable, Codable, Equatable, Hashable {
  public let id: UUID
  public let name: String
  public let filePath: String
  public let description: String?
  public let scope: CommandScope
  public let namespace: String?

  // Frontmatter metadata
  public let argumentHint: String?
  public let allowedTools: [String]?
  public let model: String?
  public let disableModelInvocation: Bool

  public init(
    id: UUID = UUID(),
    name: String,
    filePath: String,
    description: String? = nil,
    scope: CommandScope,
    namespace: String? = nil,
    argumentHint: String? = nil,
    allowedTools: [String]? = nil,
    model: String? = nil,
    disableModelInvocation: Bool = false
  ) {
    self.id = id
    self.name = name
    self.filePath = filePath
    self.description = description
    self.scope = scope
    self.namespace = namespace
    self.argumentHint = argumentHint
    self.allowedTools = allowedTools
    self.model = model
    self.disableModelInvocation = disableModelInvocation
  }

  // Display name with slash prefix
  public var displayName: String {
    "/\(name)"
  }

  // Full command path with namespace if applicable
  public var fullName: String {
    if let namespace = namespace, !namespace.isEmpty {
      return "\(namespace)/\(name)"
    }
    return name
  }

  // Display full name with slash prefix
  public var displayFullName: String {
    "/\(fullName)"
  }
}

// MARK: - Command Result (for search)
public struct CommandResult: Identifiable, Hashable, Equatable {
  public let id: UUID
  public let command: SlashCommand
  public var isSelected: Bool

  public init(
    id: UUID = UUID(),
    command: SlashCommand,
    isSelected: Bool = false
  ) {
    self.id = id
    self.command = command
    self.isSelected = isSelected
  }

  // Display properties
  public var displayName: String {
    command.displayFullName
  }

  public var scopeLabel: String {
    command.scope.displayName
  }

  public var scopeIcon: String {
    command.scope.systemImageName
  }

  public var argumentHint: String? {
    command.argumentHint
  }

  public var description: String? {
    command.description
  }
}
