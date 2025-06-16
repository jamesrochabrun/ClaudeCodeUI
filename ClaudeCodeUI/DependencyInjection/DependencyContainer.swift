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

  init() {
    self.settingsStorage = SettingsStorageManager()
    self.sessionStorage = UserDefaultsSessionStorage()
  }
  
  func setSessionStorage(_ storage: SessionStorageProtocol) {
    self.sessionStorage = storage
  }
}
