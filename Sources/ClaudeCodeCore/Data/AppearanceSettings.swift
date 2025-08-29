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
    static let selectedTheme = "selectedTheme"
    static let customPrimaryHex = "customPrimaryHex"
    static let customSecondaryHex = "customSecondaryHex"
    static let customTertiaryHex = "customTertiaryHex"
  }
  
  private enum Defaults {
    static let colorScheme = "system"
    static let fontSize: Double = 12.0
    static let theme: AppTheme = .claude
    static let customPrimaryHex = "#7C3AED"   // purple
    static let customSecondaryHex = "#FFB000" // mustard
    static let customTertiaryHex = "#64748B"  // slate
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
  
  var selectedTheme: AppTheme {
    didSet {
      UserDefaults.standard.set(selectedTheme.rawValue, forKey: Keys.selectedTheme)
    }
  }

  // Custom theme colors (stored as hex strings)
  var customPrimaryHex: String {
    didSet {
      UserDefaults.standard.set(customPrimaryHex, forKey: Keys.customPrimaryHex)
    }
  }
  var customSecondaryHex: String {
    didSet {
      UserDefaults.standard.set(customSecondaryHex, forKey: Keys.customSecondaryHex)
    }
  }
  var customTertiaryHex: String {
    didSet {
      UserDefaults.standard.set(customTertiaryHex, forKey: Keys.customTertiaryHex)
    }
  }
  
  // MARK: - Initialization
  init() {
    self.colorScheme = UserDefaults.standard.string(forKey: Keys.colorScheme) ?? Defaults.colorScheme
    let storedFontSize = UserDefaults.standard.double(forKey: Keys.fontSize)
    self.fontSize = storedFontSize != 0 ? storedFontSize : Defaults.fontSize
    
    // Initialize theme
    let storedTheme = UserDefaults.standard.string(forKey: Keys.selectedTheme) ?? Defaults.theme.rawValue
    self.selectedTheme = AppTheme(rawValue: storedTheme) ?? Defaults.theme

    // Initialize custom theme colors
    self.customPrimaryHex = UserDefaults.standard.string(forKey: Keys.customPrimaryHex) ?? Defaults.customPrimaryHex
    self.customSecondaryHex = UserDefaults.standard.string(forKey: Keys.customSecondaryHex) ?? Defaults.customSecondaryHex
    self.customTertiaryHex = UserDefaults.standard.string(forKey: Keys.customTertiaryHex) ?? Defaults.customTertiaryHex
  }
}
