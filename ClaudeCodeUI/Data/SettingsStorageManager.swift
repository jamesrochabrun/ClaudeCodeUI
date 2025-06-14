//
//  SettingsStorageManager.swift
//  ClaudeCodeUI
//
//  Created on 12/6/2025.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class SettingsStorageManager: SettingsStorage {
  
  private struct Keys {
    static let projectPath = "projectPath"
    static let colorScheme = "colorScheme"
    static let fontSize = "fontSize"
    static let apiKey = "apiKey"
  }
  
  var projectPath: String {
    get {
      userDefaults.string(forKey: Keys.projectPath) ?? ""
    }
    set {
      userDefaults.set(newValue, forKey: Keys.projectPath)
    }
  }
  
  var colorScheme: String {
    get {
      userDefaults.string(forKey: Keys.colorScheme) ?? "system"
    }
    set {
      userDefaults.set(newValue, forKey: Keys.colorScheme)
    }
  }
  
  var fontSize: Double {
    get {
      userDefaults.double(forKey: Keys.fontSize) == 0 ? 14.0 : userDefaults.double(forKey: Keys.fontSize)
    }
    set {
      userDefaults.set(newValue, forKey: Keys.fontSize)
    }
  }
  
  private let userDefaults = UserDefaults.standard
  
  init() {}
  
  func setProjectPath(_ path: String) {
    projectPath = path
  }
  
  func getProjectPath() -> String? {
    return projectPath.isEmpty ? nil : projectPath
  }
  
  func clearProjectPath() {
    projectPath = ""
  }
  
  func setColorScheme(_ scheme: String) {
    colorScheme = scheme
  }
  
  func getColorScheme() -> String {
    return colorScheme
  }
  
  func setFontSize(_ size: Double) {
    fontSize = size
  }
  
  func getFontSize() -> Double {
    return fontSize
  }
  
  func saveSecureValue(_ value: String, forKey key: String) {
    if let data = value.data(using: .utf8) {
      userDefaults.set(data, forKey: key)
    }
  }
  
  func getSecureValue(forKey key: String) -> String? {
    guard let data = userDefaults.data(forKey: key),
          let value = String(data: data, encoding: .utf8) else {
      return nil
    }
    return value
  }
  
  func removeSecureValue(forKey key: String) {
    userDefaults.removeObject(forKey: key)
  }
  
  func resetAllSettings() {
    projectPath = ""
    colorScheme = "system"
    fontSize = 14.0
    userDefaults.removeObject(forKey: Keys.apiKey)
  }
}
