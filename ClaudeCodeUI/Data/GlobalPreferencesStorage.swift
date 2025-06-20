//
//  GlobalPreferencesStorage.swift
//  ClaudeCodeUI
//
//  Created on 12/19/24.
//

import Foundation
import Observation

@Observable
@MainActor
final class GlobalPreferencesStorage: MCPConfigStorage {
  private let userDefaults = UserDefaults.standard
  
  // MARK: - Keys
  private enum Keys {
    static let maxTurns = "global.maxTurns"
    static let systemPrompt = "global.systemPrompt"
    static let appendSystemPrompt = "global.appendSystemPrompt"
    static let allowedTools = "global.allowedTools"
    static let mcpConfigPath = "global.mcpConfigPath"
  }
  
  var maxTurns: Int {
    didSet {
      userDefaults.set(maxTurns, forKey: Keys.maxTurns)
    }
  }
  
  var systemPrompt: String {
    didSet {
      userDefaults.set(systemPrompt, forKey: Keys.systemPrompt)
    }
  }
  
  var appendSystemPrompt: String {
    didSet {
      userDefaults.set(appendSystemPrompt, forKey: Keys.appendSystemPrompt)
    }
  }
  
  var allowedTools: [String] {
    didSet {
      userDefaults.set(allowedTools, forKey: Keys.allowedTools)
    }
  }
  
  var mcpConfigPath: String {
    didSet {
      userDefaults.set(mcpConfigPath, forKey: Keys.mcpConfigPath)
    }
  }
  
  // MARK: - Initialization
  init() {
    // Load saved values or use defaults
    self.maxTurns = userDefaults.object(forKey: Keys.maxTurns) as? Int ?? 50
    self.systemPrompt = userDefaults.string(forKey: Keys.systemPrompt) ?? ""
    self.appendSystemPrompt = userDefaults.string(forKey: Keys.appendSystemPrompt) ?? ""
    self.allowedTools = userDefaults.stringArray(forKey: Keys.allowedTools) ?? ["Bash", "LS", "Read", "WebFetch", "Batch", "TodoRead/Write", "Glob", "Grep", "Edit", "MultiEdit", "Write", "NotebookRead", "NotebookEdit", "WebSearch", "Task"]
    self.mcpConfigPath = userDefaults.string(forKey: Keys.mcpConfigPath) ?? ""
  }
  
  // MARK: - Methods
  func resetToDefaults() {
    maxTurns = 50
    systemPrompt = ""
    appendSystemPrompt = ""
    allowedTools = ["Bash", "LS", "Read", "WebFetch", "Batch", "TodoRead/Write", "Glob", "Grep", "Edit", "MultiEdit", "Write", "NotebookRead", "NotebookEdit", "WebSearch", "Task"]
    mcpConfigPath = ""
  }
  
  // MARK: - MCPConfigStorage
  func setMcpConfigPath(_ path: String) {
    mcpConfigPath = path
  }
}
