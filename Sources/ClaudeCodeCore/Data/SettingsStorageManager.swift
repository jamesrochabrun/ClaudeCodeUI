//
//  SettingsStorageManager.swift
//  ClaudeCodeUI
//
//  Created on 12/6/2025.
//

import Foundation
import SwiftUI

/// Default implementation of SettingsStorage that uses UserDefaults for persistence.
@MainActor
@Observable
public final class SettingsStorageManager: SettingsStorage {
  
  private struct Keys {
    static let sessionProjectPathPrefix = "session.projectPath."
  }
  
  private let userDefaults = UserDefaults.standard
  
  /// Creates a new SettingsStorageManager instance.
  public init() {
    // Default initialization
  }
  
  // MARK: - Temporary/Active Project Path
  // This is only used for the currently active session
  private var _activeProjectPath: String = ""
  
  public var projectPath: String {
    get { _activeProjectPath }
    set { _activeProjectPath = newValue }
  }
  
  // MARK: - Project Path Management
  
  public func setProjectPath(_ path: String) {
    _activeProjectPath = path
  }
  
  public func getProjectPath() -> String? {
    _activeProjectPath.isEmpty ? nil : _activeProjectPath
  }
  
  public func clearProjectPath() {
    _activeProjectPath = ""
  }
  
  // MARK: - Per-Session Project Path
  
  public func setProjectPath(_ path: String, forSessionId sessionId: String) {
    let key = Keys.sessionProjectPathPrefix + sessionId
    userDefaults.set(path, forKey: key)
    print("[SettingsStorage] Saved path '\(path)' for session '\(sessionId)' with key '\(key)'")
  }
  
  public func getProjectPath(forSessionId sessionId: String) -> String? {
    let key = Keys.sessionProjectPathPrefix + sessionId
    let path = userDefaults.string(forKey: key)
    print("[SettingsStorage] Retrieved path '\(path ?? "nil")' for session '\(sessionId)' with key '\(key)'")
    return path?.isEmpty == false ? path : nil
  }
}