//
//  SessionSettingsStorageManager.swift
//  ClaudeCodeUI
//
//  Created on 12/14/2025.
//

import Foundation

@MainActor
public final class SessionSettingsStorageManager: SessionSettingsStorage {
  private let defaults = UserDefaults.standard
  private let keyPrefix = "session."
  
  // Current session ID for property accessors
  private var currentSessionId: String = ""
  // Temporary storage for settings before session is created
  private var pendingSettings: [String: Any] = [:]
  
  public init() {}
  
  public func setCurrentSession(_ sessionId: String) {
    // If we have pending settings and this is a new session, migrate them
    if currentSessionId.isEmpty && !sessionId.isEmpty && !pendingSettings.isEmpty {
      // Migrate pending settings to the new session
      if let projectPath = pendingSettings["projectPath"] as? String {
        setProjectPath(projectPath, for: sessionId)
      }
      if let debugMode = pendingSettings["debugMode"] as? Bool {
        setDebugMode(debugMode, for: sessionId)
      }
      if let verboseMode = pendingSettings["verboseMode"] as? Bool {
        setVerboseMode(verboseMode, for: sessionId)
      }
      if let maxTurns = pendingSettings["maxTurns"] as? Int {
        setMaxTurns(maxTurns, for: sessionId)
      }
      if let allowedTools = pendingSettings["allowedTools"] as? [String] {
        setAllowedTools(allowedTools, for: sessionId)
      }
      if let systemPrompt = pendingSettings["systemPrompt"] as? String {
        setSystemPrompt(systemPrompt, for: sessionId)
      }
      if let appendSystemPrompt = pendingSettings["appendSystemPrompt"] as? String {
        setAppendSystemPrompt(appendSystemPrompt, for: sessionId)
      }
      // Clear pending settings after migration
      pendingSettings.removeAll()
    }
    currentSessionId = sessionId
  }
  
  // MARK: - Property Accessors (for current session)
  
  public var projectPath: String {
    get {
      if currentSessionId.isEmpty {
        return pendingSettings["projectPath"] as? String ?? ""
      }
      return getProjectPath(for: currentSessionId) ?? ""
    }
    set {
      if currentSessionId.isEmpty {
        pendingSettings["projectPath"] = newValue
      } else {
        setProjectPath(newValue, for: currentSessionId)
      }
    }
  }
  
  public var debugMode: Bool {
    get {
      if currentSessionId.isEmpty {
        return pendingSettings["debugMode"] as? Bool ?? false
      }
      return getDebugMode(for: currentSessionId)
    }
    set {
      if currentSessionId.isEmpty {
        pendingSettings["debugMode"] = newValue
      } else {
        setDebugMode(newValue, for: currentSessionId)
      }
    }
  }
  
  public var verboseMode: Bool {
    get {
      if currentSessionId.isEmpty {
        return pendingSettings["verboseMode"] as? Bool ?? false
      }
      return getVerboseMode(for: currentSessionId)
    }
    set {
      if currentSessionId.isEmpty {
        pendingSettings["verboseMode"] = newValue
      } else {
        setVerboseMode(newValue, for: currentSessionId)
      }
    }
  }
  
  public var maxTurns: Int {
    get {
      if currentSessionId.isEmpty {
        return pendingSettings["maxTurns"] as? Int ?? 50
      }
      return getMaxTurns(for: currentSessionId)
    }
    set {
      if currentSessionId.isEmpty {
        pendingSettings["maxTurns"] = newValue
      } else {
        setMaxTurns(newValue, for: currentSessionId)
      }
    }
  }
  
  public var allowedTools: [String] {
    get {
      if currentSessionId.isEmpty {
        return pendingSettings["allowedTools"] as? [String] ?? [
          "Bash", "LS", "Read", "WebFetch", "Batch", "TodoRead/Write", "Glob", "Grep",
          "Edit", "MultiEdit", "Write", "NotebookRead", "NotebookEdit", "WebSearch", "Task"
        ]
      }
      return getAllowedTools(for: currentSessionId)
    }
    set {
      if currentSessionId.isEmpty {
        pendingSettings["allowedTools"] = newValue
      } else {
        setAllowedTools(newValue, for: currentSessionId)
      }
    }
  }
  
  public var systemPrompt: String {
    get {
      if currentSessionId.isEmpty {
        return pendingSettings["systemPrompt"] as? String ?? ""
      }
      return getSystemPrompt(for: currentSessionId) ?? ""
    }
    set {
      if currentSessionId.isEmpty {
        pendingSettings["systemPrompt"] = newValue
      } else {
        setSystemPrompt(newValue, for: currentSessionId)
      }
    }
  }
  
  public var appendSystemPrompt: String {
    get {
      if currentSessionId.isEmpty {
        return pendingSettings["appendSystemPrompt"] as? String ?? ""
      }
      return getAppendSystemPrompt(for: currentSessionId) ?? ""
    }
    set {
      if currentSessionId.isEmpty {
        pendingSettings["appendSystemPrompt"] = newValue
      } else {
        setAppendSystemPrompt(newValue, for: currentSessionId)
      }
    }
  }
  
  // MARK: - Session-specific methods
  
  private func key(for setting: String, sessionId: String) -> String {
    "\(keyPrefix)\(sessionId).\(setting)"
  }
  
  // MARK: - Project Path
  
  public func setProjectPath(_ path: String, for sessionId: String) {
    defaults.set(path, forKey: key(for: "projectPath", sessionId: sessionId))
  }
  
  public func getProjectPath(for sessionId: String) -> String? {
    defaults.string(forKey: key(for: "projectPath", sessionId: sessionId))
  }
  
  public func clearProjectPath(for sessionId: String) {
    defaults.removeObject(forKey: key(for: "projectPath", sessionId: sessionId))
  }
  
  // MARK: - Debug Mode
  
  public func setDebugMode(_ enabled: Bool, for sessionId: String) {
    defaults.set(enabled, forKey: key(for: "debugMode", sessionId: sessionId))
  }
  
  public func getDebugMode(for sessionId: String) -> Bool {
    defaults.bool(forKey: key(for: "debugMode", sessionId: sessionId))
  }
  
  // MARK: - Verbose Mode
  
  public func setVerboseMode(_ enabled: Bool, for sessionId: String) {
    defaults.set(enabled, forKey: key(for: "verboseMode", sessionId: sessionId))
  }
  
  public func getVerboseMode(for sessionId: String) -> Bool {
    defaults.bool(forKey: key(for: "verboseMode", sessionId: sessionId))
  }
  
  // MARK: - Max Turns
  
  public func setMaxTurns(_ turns: Int, for sessionId: String) {
    defaults.set(turns, forKey: key(for: "maxTurns", sessionId: sessionId))
  }
  
  public func getMaxTurns(for sessionId: String) -> Int {
    let turns = defaults.integer(forKey: key(for: "maxTurns", sessionId: sessionId))
    return turns > 0 ? turns : 50
  }
  
  // MARK: - Allowed Tools
  
  public func setAllowedTools(_ tools: [String], for sessionId: String) {
    defaults.set(tools, forKey: key(for: "allowedTools", sessionId: sessionId))
  }
  
  public func getAllowedTools(for sessionId: String) -> [String] {
    defaults.stringArray(forKey: key(for: "allowedTools", sessionId: sessionId)) ?? [
      "Bash", "LS", "Read", "WebFetch", "Batch", "TodoRead/Write", "Glob", "Grep",
      "Edit", "MultiEdit", "Write", "NotebookRead", "NotebookEdit", "WebSearch", "Task"
    ]
  }
  
  // MARK: - System Prompt
  
  public func setSystemPrompt(_ prompt: String, for sessionId: String) {
    defaults.set(prompt, forKey: key(for: "systemPrompt", sessionId: sessionId))
  }
  
  public func getSystemPrompt(for sessionId: String) -> String? {
    defaults.string(forKey: key(for: "systemPrompt", sessionId: sessionId))
  }
  
  // MARK: - Append System Prompt
  
  public func setAppendSystemPrompt(_ prompt: String, for sessionId: String) {
    defaults.set(prompt, forKey: key(for: "appendSystemPrompt", sessionId: sessionId))
  }
  
  public func getAppendSystemPrompt(for sessionId: String) -> String? {
    defaults.string(forKey: key(for: "appendSystemPrompt", sessionId: sessionId))
  }
  
  // MARK: - Reset & Delete
  
  public func resetSettings(for sessionId: String) {
    clearProjectPath(for: sessionId)
    defaults.removeObject(forKey: key(for: "debugMode", sessionId: sessionId))
    defaults.removeObject(forKey: key(for: "verboseMode", sessionId: sessionId))
    defaults.removeObject(forKey: key(for: "maxTurns", sessionId: sessionId))
    defaults.removeObject(forKey: key(for: "allowedTools", sessionId: sessionId))
    defaults.removeObject(forKey: key(for: "systemPrompt", sessionId: sessionId))
    defaults.removeObject(forKey: key(for: "appendSystemPrompt", sessionId: sessionId))
  }
  
  public func deleteSettings(for sessionId: String) {
    resetSettings(for: sessionId)
  }
}
