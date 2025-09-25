//
//  ToolPreference.swift
//  ClaudeCodeUI
//
//  Created on 1/18/25.
//

import Foundation

/// Represents a user's preference for a specific tool with metadata
public struct ToolPreference: Codable, Equatable {
  /// Whether the tool is allowed/enabled
  public var isAllowed: Bool

  /// Last time this tool was seen in the discovery process
  public var lastSeen: Date

  /// Optional notes about why the tool was allowed/disallowed
  public var notes: String?

  /// Previous names this tool might have had (for tracking renames)
  public var previousNames: [String]

  /// When the preference was first created
  public let createdAt: Date

  /// When the preference was last modified by the user
  public var lastModified: Date

  public init(
    isAllowed: Bool,
    lastSeen: Date = Date(),
    notes: String? = nil,
    previousNames: [String] = [],
    createdAt: Date = Date(),
    lastModified: Date = Date()
  ) {
    self.isAllowed = isAllowed
    self.lastSeen = lastSeen
    self.notes = notes
    self.previousNames = previousNames
    self.createdAt = createdAt
    self.lastModified = lastModified
  }

  // Custom Decodable implementation for backward compatibility
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    // Required field - this one should always exist
    self.isAllowed = try container.decode(Bool.self, forKey: .isAllowed)

    // Optional fields with sensible defaults for backward compatibility
    self.lastSeen = try container.decodeIfPresent(Date.self, forKey: .lastSeen) ?? Date()
    self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
    self.previousNames = try container.decodeIfPresent([String].self, forKey: .previousNames) ?? []
    self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    self.lastModified = try container.decodeIfPresent(Date.self, forKey: .lastModified) ?? Date()
  }

  private enum CodingKeys: String, CodingKey {
    case isAllowed
    case lastSeen
    case notes
    case previousNames
    case createdAt
    case lastModified
  }

  /// Update the tool as seen with current timestamp
  public mutating func markAsSeen() {
    lastSeen = Date()
  }

  /// Update the allowed status and track the modification
  public mutating func setAllowed(_ allowed: Bool) {
    if isAllowed != allowed {
      isAllowed = allowed
      lastModified = Date()
    }
  }

  /// Add a previous name for tracking tool renames
  public mutating func addPreviousName(_ name: String) {
    if !previousNames.contains(name) {
      previousNames.append(name)
      lastModified = Date()
    }
  }

  /// Check if this tool might be a renamed version of another tool
  public func mightBeRenamedFrom(_ name: String) -> Bool {
    previousNames.contains(name)
  }
}

/// Extension to provide default tool preferences for common tools
public extension ToolPreference {
  /// Create a default preference for a newly discovered tool
  static func defaultForNewTool(isAllowed: Bool = false) -> ToolPreference {
    ToolPreference(isAllowed: isAllowed)
  }

  /// Create a preference for a known safe tool
  static func allowedByDefault() -> ToolPreference {
    ToolPreference(isAllowed: true, notes: "Allowed by default")
  }

  /// Create a preference for a potentially risky tool
  static func disallowedByDefault() -> ToolPreference {
    ToolPreference(isAllowed: false, notes: "Requires explicit approval")
  }
}

/// Tool discovery status for reconciliation
public enum ToolStatus {
  case active       // Tool is currently available and seen
  case missing      // Tool was known but not seen in latest discovery
  case new          // Tool is newly discovered
  case renamed(from: String) // Tool appears to be renamed from another

  public var isAvailable: Bool {
    switch self {
    case .active, .new, .renamed:
      return true
    case .missing:
      return false
    }
  }
}

/// Result of tool reconciliation
public struct ToolReconciliationResult {
  public let toolName: String
  public let status: ToolStatus
  public let preference: ToolPreference
  public let source: ToolSource

  public enum ToolSource {
    case claudeCode
    case mcpServer(name: String)
  }

  public init(
    toolName: String,
    status: ToolStatus,
    preference: ToolPreference,
    source: ToolSource
  ) {
    self.toolName = toolName
    self.status = status
    self.preference = preference
    self.source = source
  }
}