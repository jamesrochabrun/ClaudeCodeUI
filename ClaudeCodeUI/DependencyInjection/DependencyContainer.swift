//
//  DependencyContainer.swift
//  ClaudeCodeUI
//
//  Created on 12/6/2025.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class DependencyContainer {
  
  static let shared = DependencyContainer()
  
  private(set) var settingsStorage: SettingsStorage
  private(set) var sessionStorage: SessionStorageProtocol
  
  private init() {
    self.settingsStorage = SettingsStorageManager()
    self.sessionStorage = UserDefaultsSessionStorage()
  }
  
  func setSettingsStorage(_ storage: SettingsStorage) {
    self.settingsStorage = storage
  }
  
  func setSessionStorage(_ storage: SessionStorageProtocol) {
    self.sessionStorage = storage
  }
}
