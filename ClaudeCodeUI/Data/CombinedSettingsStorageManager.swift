//
//  CombinedSettingsStorageManager.swift
//  ClaudeCodeUI
//
//  Created on 12/14/2025.
//

import Foundation

@MainActor
public final class CombinedSettingsStorageManager: SettingsStorage {
  private let globalStorage: GlobalSettingsStorage
  private let sessionStorage: SessionSettingsStorage
  
  public init(globalStorage: GlobalSettingsStorage, sessionStorage: SessionSettingsStorage) {
    self.globalStorage = globalStorage
    self.sessionStorage = sessionStorage
  }
  
  // MARK: - Global Settings (delegated to globalStorage)
  
  public var colorScheme: String {
    get { globalStorage.colorScheme }
    set { globalStorage.colorScheme = newValue }
  }
  
  public var fontSize: Double {
    get { globalStorage.fontSize }
    set { globalStorage.fontSize = newValue }
  }
  
  // MARK: - Session Settings (delegated to sessionStorage)
  
  public var projectPath: String {
    get { sessionStorage.projectPath }
    set { sessionStorage.projectPath = newValue }
  }
  
  public var debugMode: Bool {
    get { sessionStorage.debugMode }
    set { sessionStorage.debugMode = newValue }
  }
  
  public var verboseMode: Bool {
    get { sessionStorage.verboseMode }
    set { sessionStorage.verboseMode = newValue }
  }
  
  public var maxTurns: Int {
    get { sessionStorage.maxTurns }
    set { sessionStorage.maxTurns = newValue }
  }
  
  public var allowedTools: [String] {
    get { sessionStorage.allowedTools }
    set { sessionStorage.allowedTools = newValue }
  }
  
  public var systemPrompt: String {
    get { sessionStorage.systemPrompt }
    set { sessionStorage.systemPrompt = newValue }
  }
  
  public var appendSystemPrompt: String {
    get { sessionStorage.appendSystemPrompt }
    set { sessionStorage.appendSystemPrompt = newValue }
  }
  
  // MARK: - Global Methods
  
  public func setColorScheme(_ scheme: String) {
    globalStorage.setColorScheme(scheme)
  }
  
  public func getColorScheme() -> String {
    globalStorage.getColorScheme()
  }
  
  public func setFontSize(_ size: Double) {
    globalStorage.setFontSize(size)
  }
  
  public func getFontSize() -> Double {
    globalStorage.getFontSize()
  }
  
  // MARK: - Session Methods
  
  public func setProjectPath(_ path: String) {
    sessionStorage.projectPath = path
  }
  
  public func getProjectPath() -> String? {
    sessionStorage.projectPath.isEmpty ? nil : sessionStorage.projectPath
  }
  
  public func clearProjectPath() {
    sessionStorage.projectPath = ""
  }
  
  public func setDebugMode(_ enabled: Bool) {
    sessionStorage.debugMode = enabled
  }
  
  public func getDebugMode() -> Bool {
    sessionStorage.debugMode
  }
  
  public func setVerboseMode(_ enabled: Bool) {
    sessionStorage.verboseMode = enabled
  }
  
  public func getVerboseMode() -> Bool {
    sessionStorage.verboseMode
  }
  
  public func setMaxTurns(_ turns: Int) {
    sessionStorage.maxTurns = turns
  }
  
  public func getMaxTurns() -> Int {
    sessionStorage.maxTurns
  }
  
  public func setAllowedTools(_ tools: [String]) {
    sessionStorage.allowedTools = tools
  }
  
  public func getAllowedTools() -> [String] {
    sessionStorage.allowedTools
  }
  
  public func setSystemPrompt(_ prompt: String) {
    sessionStorage.systemPrompt = prompt
  }
  
  public func getSystemPrompt() -> String? {
    sessionStorage.systemPrompt.isEmpty ? nil : sessionStorage.systemPrompt
  }
  
  public func setAppendSystemPrompt(_ prompt: String) {
    sessionStorage.appendSystemPrompt = prompt
  }
  
  public func getAppendSystemPrompt() -> String? {
    sessionStorage.appendSystemPrompt.isEmpty ? nil : sessionStorage.appendSystemPrompt
  }
  
  // MARK: - Secure storage (kept for compatibility)
  
  public func saveSecureValue(_ value: String, forKey key: String) {
    // This is handled by the existing SettingsStorageManager
    // We'll keep it empty for now as it's not session-specific
  }
  
  public func getSecureValue(forKey key: String) -> String? {
    nil
  }
  
  public func removeSecureValue(forKey key: String) {
    // Empty implementation
  }
  
  // MARK: - Reset
  
  public func resetAllSettings() {
    // Reset session settings for current session
    if let sessionStorage = sessionStorage as? SessionSettingsStorageManager {
      sessionStorage.resetSettings(for: sessionStorage.projectPath)
    }
  }
}