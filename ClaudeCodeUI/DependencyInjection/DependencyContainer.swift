//
//  DependencyContainer.swift
//  ClaudeCodeUI
//
//  Created on 12/6/2025.
//

import Foundation
import SwiftUI

@MainActor
final class DependencyContainer {
  
  let settingsStorage: SettingsStorage
  let sessionStorage: SessionStorageProtocol
  let globalPreferences: GlobalPreferencesStorage
  
  init(globalPreferences: GlobalPreferencesStorage) {
    self.settingsStorage = SettingsStorageManager()
    self.sessionStorage = UserDefaultsSessionStorage()
    self.globalPreferences = globalPreferences
  }
  
  func setCurrentSession(_ sessionId: String) {
    // Load session-specific working directory if available
    if let sessionPath = settingsStorage.getProjectPath(forSessionId: sessionId) {
      // Existing session - load its working directory
      settingsStorage.setProjectPath(sessionPath)
      print("[DependencyContainer] Loaded existing session path '\(sessionPath)' for session '\(sessionId)'")
    } else {
      // New session - save the current working directory if it exists
      let currentPath = settingsStorage.projectPath
      if !currentPath.isEmpty {
        settingsStorage.setProjectPath(currentPath, forSessionId: sessionId)
        print("[DependencyContainer] Saved current path '\(currentPath)' to new session '\(sessionId)'")
      } else {
        print("[DependencyContainer] New session '\(sessionId)' with no working directory")
      }
    }
  }
}
