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
    static let debugMode = "debugMode"
    static let verboseMode = "verboseMode"
    static let maxTurns = "maxTurns"
    static let allowedTools = "allowedTools"
    static let systemPrompt = "systemPrompt"
    static let appendSystemPrompt = "appendSystemPrompt"
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
  
  var debugMode: Bool {
    get {
      userDefaults.bool(forKey: Keys.debugMode)
    }
    set {
      userDefaults.set(newValue, forKey: Keys.debugMode)
    }
  }
  
  var verboseMode: Bool {
    get {
      userDefaults.bool(forKey: Keys.verboseMode)
    }
    set {
      userDefaults.set(newValue, forKey: Keys.verboseMode)
    }
  }
  
  var maxTurns: Int {
    get {
      let value = userDefaults.integer(forKey: Keys.maxTurns)
      return value == 0 ? 30 : value
    }
    set {
      userDefaults.set(newValue, forKey: Keys.maxTurns)
    }
  }
  
  var allowedTools: [String] {
    get {
      userDefaults.array(forKey: Keys.allowedTools) as? [String] ?? ["Bash", "LS", "Read", "WebFetch", "Batch", "TodoRead/Write", "Glob", "Grep", "Edit", "MultiEdit", "Write"]
    }
    set {
      userDefaults.set(newValue, forKey: Keys.allowedTools)
    }
  }
  
  var systemPrompt: String {
    get {
      userDefaults.string(forKey: Keys.systemPrompt) ?? ""
    }
    set {
      userDefaults.set(newValue, forKey: Keys.systemPrompt)
    }
  }
  
  var appendSystemPrompt: String {
    get {
      userDefaults.string(forKey: Keys.appendSystemPrompt) ?? ""
    }
    set {
      userDefaults.set(newValue, forKey: Keys.appendSystemPrompt)
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
  
  func setDebugMode(_ enabled: Bool) {
    debugMode = enabled
  }
  
  func getDebugMode() -> Bool {
    return debugMode
  }
  
  func setVerboseMode(_ enabled: Bool) {
    verboseMode = enabled
  }
  
  func getVerboseMode() -> Bool {
    return verboseMode
  }
  
  func setMaxTurns(_ turns: Int) {
    maxTurns = turns
  }
  
  func getMaxTurns() -> Int {
    return maxTurns
  }
  
  func setAllowedTools(_ tools: [String]) {
    allowedTools = tools
  }
  
  func getAllowedTools() -> [String] {
    return allowedTools
  }
  
  func setSystemPrompt(_ prompt: String) {
    systemPrompt = prompt
  }
  
  func getSystemPrompt() -> String? {
    return systemPrompt.isEmpty ? nil : systemPrompt
  }
  
  func setAppendSystemPrompt(_ prompt: String) {
    appendSystemPrompt = prompt
  }
  
  func getAppendSystemPrompt() -> String? {
    return appendSystemPrompt.isEmpty ? nil : appendSystemPrompt
  }
  
  func resetAllSettings() {
    projectPath = ""
    colorScheme = "system"
    fontSize = 14.0
    debugMode = false
    verboseMode = false
    maxTurns = 30
    allowedTools = ["Bash", "LS", "Read", "WebFetch", "Batch", "TodoRead/Write", "Glob", "Grep", "Edit", "MultiEdit", "Write"]
    systemPrompt = ""
    appendSystemPrompt = ""
    userDefaults.removeObject(forKey: Keys.apiKey)
  }
}
