//
//  AppearanceSettings.swift
//  ClaudeCodeUI
//
//  Created on 12/19/24.
//

import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
final class AppearanceSettings {
  // MARK: - Constants
  private enum Keys {
    static let colorScheme = "colorScheme"
    static let fontSize = "fontSize"
  }
  
  private enum Defaults {
    static let colorScheme = "system"
    static let fontSize: Double = 12.0
  }
  
  // MARK: - Properties
  var colorScheme: String {
    didSet {
      UserDefaults.standard.set(colorScheme, forKey: Keys.colorScheme)
    }
  }
  
  var fontSize: Double {
    didSet {
      UserDefaults.standard.set(fontSize, forKey: Keys.fontSize)
    }
  }
  
  // MARK: - Initialization
  init() {
    self.colorScheme = UserDefaults.standard.string(forKey: Keys.colorScheme) ?? Defaults.colorScheme
    let storedFontSize = UserDefaults.standard.double(forKey: Keys.fontSize)
    self.fontSize = storedFontSize != 0 ? storedFontSize : Defaults.fontSize
  }
}
