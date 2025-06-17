//
//  GlobalSettingsStorageManager.swift
//  ClaudeCodeUI
//
//  Created on 12/14/2025.
//

import Foundation

public final class GlobalSettingsStorageManager: GlobalSettingsStorage {
  private let defaults = UserDefaults.standard
  
  private enum Keys {
    static let colorScheme = "colorScheme"
    static let fontSize = "fontSize"
  }
  
  public init() {}
  
  // MARK: - Properties
  
  public var colorScheme: String {
    get { getColorScheme() }
    set { setColorScheme(newValue) }
  }
  
  public var fontSize: Double {
    get { getFontSize() }
    set { setFontSize(newValue) }
  }
  
  // MARK: - Color Scheme
  
  public func setColorScheme(_ scheme: String) {
    defaults.set(scheme, forKey: Keys.colorScheme)
  }
  
  public func getColorScheme() -> String {
    defaults.string(forKey: Keys.colorScheme) ?? "system"
  }
  
  // MARK: - Font Size
  
  public func setFontSize(_ size: Double) {
    defaults.set(size, forKey: Keys.fontSize)
  }
  
  public func getFontSize() -> Double {
    let size = defaults.double(forKey: Keys.fontSize)
    return size > 0 ? size : 14.0
  }
}