//
//  SettingsStorage.swift
//  ClaudeCodeUI
//
//  Created on 12/6/2025.
//

import Foundation

/// Protocol defining the interface for managing application settings storage.
///
/// This protocol provides methods for storing and retrieving project paths,
/// both globally (for the current active session) and on a per-session basis.
/// All operations are performed on the main actor to ensure thread safety
/// when updating UI-related settings.
///
/// - Note: Implementations should use persistent storage (e.g., UserDefaults)
///         to ensure settings survive app restarts.
@MainActor
public protocol SettingsStorage: AnyObject {
  /// The currently active project path for the current session.
  /// This is an in-memory property that represents the working directory
  /// for the active Claude conversation.
  ///
  /// - Note: This value is not persisted globally. Use session-specific
  ///         methods to persist paths across app launches.
  var projectPath: String { get set }
  
  /// Sets the active project path for the current session.
  /// This updates the in-memory `projectPath` property.
  ///
  /// - Parameter path: The file system path to set as the working directory
  func setProjectPath(_ path: String)
  
  /// Retrieves the active project path.
  ///
  /// - Returns: The current project path if set, nil otherwise
  func getProjectPath() -> String?
  
  /// Clears the active project path, resetting it to an empty string.
  func clearProjectPath()
  
  /// Persists a project path for a specific session.
  /// This allows each conversation session to maintain its own working directory.
  ///
  /// - Parameters:
  ///   - path: The file system path to associate with the session
  ///   - sessionId: The unique identifier of the session
  func setProjectPath(_ path: String, forSessionId sessionId: String)
  
  /// Retrieves the persisted project path for a specific session.
  ///
  /// - Parameter sessionId: The unique identifier of the session
  /// - Returns: The project path associated with the session if found, nil otherwise
  func getProjectPath(forSessionId sessionId: String) -> String?
}
