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
    
  var settingsStorage: SettingsStorage
  var sessionStorage: SessionStorageProtocol
  let globalSettingsStorage: GlobalSettingsStorage
  let sessionSettingsStorage: SessionSettingsStorageManager

  init() {
    self.globalSettingsStorage = GlobalSettingsStorageManager()
    self.sessionSettingsStorage = SessionSettingsStorageManager()
    self.settingsStorage = CombinedSettingsStorageManager(
      globalStorage: globalSettingsStorage,
      sessionStorage: sessionSettingsStorage
    )
    self.sessionStorage = UserDefaultsSessionStorage()
  }
  
  func setSessionStorage(_ storage: SessionStorageProtocol) {
    self.sessionStorage = storage
  }
  
  func setCurrentSession(_ sessionId: String) {
    sessionSettingsStorage.setCurrentSession(sessionId)
  }
}
