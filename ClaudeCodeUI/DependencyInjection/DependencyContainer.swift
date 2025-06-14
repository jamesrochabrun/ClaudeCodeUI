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
  
  private init() {
    self.settingsStorage = SettingsStorageManager()
  }
  
  func setSettingsStorage(_ storage: SettingsStorage) {
    self.settingsStorage = storage
  }
}
