//
//  PersistentPreferencesManager.swift
//  ClaudeCodeUI
//
//  Created on 1/18/25.
//

import Foundation

/// Manages persistent storage of user preferences in Application Support directory
/// These preferences survive app deletion and reinstallation
@MainActor
public final class PersistentPreferencesManager {
  
  /// Singleton instance
  public static let shared = PersistentPreferencesManager()
  
  /// Application Support directory URL
  private var applicationSupportURL: URL? {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
  }
  
  /// Directory for storing ClaudeCodeUI preferences
  private var preferencesDirectoryURL: URL? {
    applicationSupportURL?.appendingPathComponent("ClaudeCodeUI", isDirectory: true)
  }
  
  /// URL for the preferences JSON file
  private var preferencesFileURL: URL? {
    preferencesDirectoryURL?.appendingPathComponent("preferences.json")
  }
  
  /// URL for the backup preferences file
  private var backupFileURL: URL? {
    preferencesDirectoryURL?.appendingPathComponent("preferences.backup.json")
  }
  
  private init() {
    ensureDirectoryExists()
  }
  
  /// Ensures the preferences directory exists
  private func ensureDirectoryExists() {
    guard let directoryURL = preferencesDirectoryURL else {
      ClaudeCodeLogger.shared.preferences("ERROR: Could not determine preferences directory URL")
      return
    }
    
    do {
      try FileManager.default.createDirectory(
        at: directoryURL,
        withIntermediateDirectories: true,
        attributes: nil
      )
    } catch {
      ClaudeCodeLogger.shared.preferences("ERROR: Failed to create preferences directory - \(error.localizedDescription)")
    }
  }
  
  /// Load preferences from persistent storage
  /// Returns a Result indicating success with preferences or failure with specific error
  public func loadPreferencesWithResult() -> Result<PersistentPreferences, PreferencesLoadError> {
    guard let fileURL = preferencesFileURL else {
      return .failure(.fileSystemError(underlying: CocoaError(.fileNoSuchFile)))
    }
    
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      return .failure(.fileSystemError(underlying: CocoaError(.fileNoSuchFile)))
    }
    
    do {
      let data = try Data(contentsOf: fileURL)
      
      // Check for empty file
      if data.isEmpty {
        ClaudeCodeLogger.shared.preferences("ERROR: Preferences file is empty")
        return .failure(.emptyFile)
      }
      
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      
      let preferences = try decoder.decode(PersistentPreferences.self, from: data)
      return .success(preferences)
    } catch let decodingError as DecodingError {
      var formatDetails = ""
      switch decodingError {
      case .dataCorrupted:
        formatDetails = "Data corrupted"
      case .keyNotFound(let key, _):
        formatDetails = "Missing key: \(key.stringValue)"
      case .typeMismatch(let type, _):
        formatDetails = "Type mismatch for \(type)"
      case .valueNotFound(let type, _):
        formatDetails = "Missing value for \(type)"
      @unknown default:
        formatDetails = "Unknown format issue"
      }
      ClaudeCodeLogger.shared.preferences("ERROR: JSON decoding failed - \(formatDetails)")
      return .failure(.invalidFormat(details: formatDetails))
    } catch {
      // Check if it's a file system error
      if (error as NSError).domain == NSCocoaErrorDomain {
        return .failure(.fileSystemError(underlying: error))
      }
      return .failure(.unknownCorruption(underlying: error))
    }
  }
  
  /// Load preferences from persistent storage (backward compatibility)
  public func loadPreferences() -> PersistentPreferences? {
    switch loadPreferencesWithResult() {
    case .success(let preferences):
      return preferences
    case .failure:
      return nil
    }
  }
  
  /// Create a backup of current preferences if they exist and are valid
  private func createBackupIfNeeded() {
    guard let fileURL = preferencesFileURL,
          let backupURL = backupFileURL,
          FileManager.default.fileExists(atPath: fileURL.path) else {
      return
    }
    
    // Only backup if current file is valid
    if case .success = loadPreferencesWithResult() {
      do {
        // Remove old backup if it exists
        if FileManager.default.fileExists(atPath: backupURL.path) {
          try FileManager.default.removeItem(at: backupURL)
        }
        try FileManager.default.copyItem(at: fileURL, to: backupURL)
      } catch {
        ClaudeCodeLogger.shared.preferences("ERROR: Failed to create backup - \(error.localizedDescription)")
      }
    }
  }
  
  /// Save preferences to persistent storage
  public func savePreferences(_ preferences: PersistentPreferences) {
    guard let fileURL = preferencesFileURL else {
      ClaudeCodeLogger.shared.preferences("ERROR: Could not determine preferences file URL for saving")
      return
    }
    
    do {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      encoder.dateEncodingStrategy = .iso8601
      
      let data = try encoder.encode(preferences)
      
      // Create backup before overwriting
      createBackupIfNeeded()
      
      // Write atomically to prevent corruption
      try data.write(to: fileURL, options: .atomic)
    } catch {
      ClaudeCodeLogger.shared.preferences("ERROR: Failed to save preferences - \(error.localizedDescription)")
    }
  }
  
  /// Delete corrupted preferences file
  public func deleteCorruptedFile() {
    guard let fileURL = preferencesFileURL else {
      return
    }
    
    do {
      // Move corrupted file to a .corrupted backup instead of deleting
      let corruptedURL = fileURL.appendingPathExtension("corrupted")
      if FileManager.default.fileExists(atPath: corruptedURL.path) {
        try FileManager.default.removeItem(at: corruptedURL)
      }
      if FileManager.default.fileExists(atPath: fileURL.path) {
        try FileManager.default.moveItem(at: fileURL, to: corruptedURL)
        ClaudeCodeLogger.shared.preferences("Moved corrupted preferences to backup")
      }
    } catch {
      ClaudeCodeLogger.shared.preferences("ERROR: Failed to handle corrupted file - \(error.localizedDescription)")
    }
  }
  
  /// Attempt to restore from backup
  public func restoreFromBackup() -> PersistentPreferences? {
    guard let backupURL = backupFileURL,
          let fileURL = preferencesFileURL,
          FileManager.default.fileExists(atPath: backupURL.path) else {
      return nil
    }
    
    do {
      // First verify the backup is valid
      let data = try Data(contentsOf: backupURL)
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let preferences = try decoder.decode(PersistentPreferences.self, from: data)
      
      // If valid, restore it
      if FileManager.default.fileExists(atPath: fileURL.path) {
        try FileManager.default.removeItem(at: fileURL)
      }
      try FileManager.default.copyItem(at: backupURL, to: fileURL)
      ClaudeCodeLogger.shared.preferences("Successfully restored from backup")
      return preferences
    } catch {
      ClaudeCodeLogger.shared.preferences("ERROR: Failed to restore from backup - \(error.localizedDescription)")
      return nil
    }
  }
  
  /// Delete all persistent preferences
  public func deleteAllPreferences() {
    guard let fileURL = preferencesFileURL else {
      return
    }
    
    do {
      try FileManager.default.removeItem(at: fileURL)
    } catch {
      ClaudeCodeLogger.shared.preferences("ERROR: Failed to delete preferences - \(error.localizedDescription)")
    }
  }
  
  /// Export preferences to a specific location
  public func exportPreferences(to url: URL) throws {
    guard let preferences = loadPreferences() else {
      throw PreferencesError.noPreferencesToExport
    }
    
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    
    let data = try encoder.encode(preferences)
    try data.write(to: url)
    
    ClaudeCodeLogger.shared.preferences("Exported preferences to: \(url.lastPathComponent)")
  }
  
  /// Import preferences from a specific location
  public func importPreferences(from url: URL) throws {
    let data = try Data(contentsOf: url)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let preferences = try decoder.decode(PersistentPreferences.self, from: data)
    
    savePreferences(preferences)
    ClaudeCodeLogger.shared.preferences("Imported preferences from: \(url.lastPathComponent)")
  }
}

/// Errors that can occur during preference operations
public enum PreferencesError: LocalizedError {
  case noPreferencesToExport
  case invalidPreferencesFormat
  
  public var errorDescription: String? {
    switch self {
    case .noPreferencesToExport:
      return "No preferences found to export"
    case .invalidPreferencesFormat:
      return "Invalid preferences file format"
    }
  }
}

/// Container for all persistent preferences
public struct PersistentPreferences: Codable {
  public let version: String
  public let lastUpdated: Date
  public var toolPreferences: ToolPreferencesContainer
  public var generalPreferences: GeneralPreferences
  
  public init(
    version: String = "1.0",
    lastUpdated: Date = Date(),
    toolPreferences: ToolPreferencesContainer = ToolPreferencesContainer(),
    generalPreferences: GeneralPreferences = GeneralPreferences()
  ) {
    self.version = version
    self.lastUpdated = lastUpdated
    self.toolPreferences = toolPreferences
    self.generalPreferences = generalPreferences
  }
}

/// Container for tool-specific preferences organized by source
public struct ToolPreferencesContainer: Codable {
  /// Claude Code built-in tools preferences
  public var claudeCode: [String: ToolPreference] = [:]
  
  /// MCP server tools preferences, keyed by server name
  public var mcpServers: [String: [String: ToolPreference]] = [:]
  
  public init(
    claudeCode: [String: ToolPreference] = [:],
    mcpServers: [String: [String: ToolPreference]] = [:]
  ) {
    self.claudeCode = claudeCode
    self.mcpServers = mcpServers
  }
}

/// General application preferences
public struct GeneralPreferences: Codable {
  public var autoApproveLowRisk: Bool
  public var claudeCommand: String
  public var claudePath: String
  public var defaultWorkingDirectory: String
  public var appendSystemPrompt: String
  public var systemPrompt: String
  public var showDetailedPermissionInfo: Bool
  public var permissionRequestTimeout: TimeInterval
  public var permissionTimeoutEnabled: Bool
  public var maxConcurrentPermissionRequests: Int
  
  public init(
    autoApproveLowRisk: Bool = false,
    claudeCommand: String = "claude",
    claudePath: String = "",
    defaultWorkingDirectory: String = "",
    appendSystemPrompt: String = "",
    systemPrompt: String = "",
    showDetailedPermissionInfo: Bool = true,
    permissionRequestTimeout: TimeInterval = 3600.0,
    permissionTimeoutEnabled: Bool = false,
    maxConcurrentPermissionRequests: Int = 5
  ) {
    self.autoApproveLowRisk = autoApproveLowRisk
    self.claudeCommand = claudeCommand
    self.claudePath = claudePath
    self.defaultWorkingDirectory = defaultWorkingDirectory
    self.appendSystemPrompt = appendSystemPrompt
    self.systemPrompt = systemPrompt
    self.showDetailedPermissionInfo = showDetailedPermissionInfo
    self.permissionRequestTimeout = permissionRequestTimeout
    self.permissionTimeoutEnabled = permissionTimeoutEnabled
    self.maxConcurrentPermissionRequests = maxConcurrentPermissionRequests
  }
}
