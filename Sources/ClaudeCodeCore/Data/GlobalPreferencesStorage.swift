//
//  GlobalPreferencesStorage.swift
//  ClaudeCodeUI
//
//  Created on 12/19/24.
//

import Foundation
import Observation
import CCCustomPermissionServiceInterface

@Observable
@MainActor
public final class GlobalPreferencesStorage: MCPConfigStorage {
  private let userDefaults = UserDefaults.standard
  
  // MARK: - Keys
  private enum Keys {
    static let maxTurns = "global.maxTurns"
    static let systemPrompt = "global.systemPrompt"
    static let appendSystemPrompt = "global.appendSystemPrompt"
    static let allowedTools = "global.allowedTools"
    static let mcpConfigPath = "global.mcpConfigPath"
    static let defaultWorkingDirectory = "global.defaultWorkingDirectory"
    static let claudeCommand = "global.claudeCommand"
    static let claudePath = "global.claudePath"

    // Custom permission settings
    static let autoApproveLowRisk = "global.autoApproveLowRisk"
    static let showDetailedPermissionInfo = "global.showDetailedPermissionInfo"
    static let permissionRequestTimeout = "global.permissionRequestTimeout"
    static let permissionTimeoutEnabled = "global.permissionTimeoutEnabled"
    static let maxConcurrentPermissionRequests = "global.maxConcurrentPermissionRequests"
    static let mcpServerTools = "global.mcpServerTools"
    static let selectedMCPTools = "global.selectedMCPTools"
  }
  
  public var maxTurns: Int {
    didSet {
      userDefaults.set(maxTurns, forKey: Keys.maxTurns)
    }
  }
  
  public var systemPrompt: String {
    didSet {
      userDefaults.set(systemPrompt, forKey: Keys.systemPrompt)
    }
  }
  
  public var appendSystemPrompt: String {
    didSet {
      userDefaults.set(appendSystemPrompt, forKey: Keys.appendSystemPrompt)
    }
  }
  
  public var allowedTools: [String] {
    didSet {
      userDefaults.set(allowedTools, forKey: Keys.allowedTools)
    }
  }
  
  public var mcpConfigPath: String {
    didSet {
      userDefaults.set(mcpConfigPath, forKey: Keys.mcpConfigPath)
    }
  }

  public var defaultWorkingDirectory: String {
    didSet {
      userDefaults.set(defaultWorkingDirectory, forKey: Keys.defaultWorkingDirectory)
    }
  }

  public var claudeCommand: String {
    didSet {
      userDefaults.set(claudeCommand, forKey: Keys.claudeCommand)
    }
  }

  public var claudePath: String {
    didSet {
      userDefaults.set(claudePath, forKey: Keys.claudePath)
    }
  }

  // MARK: - Custom Permission Settings
  
  public var autoApproveLowRisk: Bool {
    didSet {
      userDefaults.set(autoApproveLowRisk, forKey: Keys.autoApproveLowRisk)
    }
  }
  
  public var showDetailedPermissionInfo: Bool {
    didSet {
      userDefaults.set(showDetailedPermissionInfo, forKey: Keys.showDetailedPermissionInfo)
    }
  }
  
  public var permissionRequestTimeout: TimeInterval {
    didSet {
      userDefaults.set(permissionRequestTimeout, forKey: Keys.permissionRequestTimeout)
    }
  }
  
  public var permissionTimeoutEnabled: Bool {
    didSet {
      userDefaults.set(permissionTimeoutEnabled, forKey: Keys.permissionTimeoutEnabled)
    }
  }
  
  public var maxConcurrentPermissionRequests: Int {
    didSet {
      userDefaults.set(maxConcurrentPermissionRequests, forKey: Keys.maxConcurrentPermissionRequests)
    }
  }
  
  // MARK: - MCP Tools Discovery
  
  /// Discovered MCP tools by server name
  public var mcpServerTools: [String: [String]] {
    didSet {
      userDefaults.set(mcpServerTools, forKey: Keys.mcpServerTools)
    }
  }
  
  /// Selected MCP tools by server name
  public var selectedMCPTools: [String: Set<String>] {
    didSet {
      // Convert Set to Array for UserDefaults storage
      let dictForStorage = selectedMCPTools.mapValues { Array($0) }
      userDefaults.set(dictForStorage, forKey: Keys.selectedMCPTools)
    }
  }
  
  // MARK: - Initialization
  public init() {
    // Load saved values or use defaults
    self.maxTurns = userDefaults.object(forKey: Keys.maxTurns) as? Int ?? 50
    self.systemPrompt = userDefaults.string(forKey: Keys.systemPrompt) ?? ""
    self.appendSystemPrompt = userDefaults.string(forKey: Keys.appendSystemPrompt) ?? ""
    self.allowedTools = userDefaults.stringArray(forKey: Keys.allowedTools) ?? ["Bash", "LS", "Read", "WebFetch", "Batch", "TodoRead/Write", "Glob", "Grep", "Edit", "MultiEdit", "Write", "NotebookRead", "NotebookEdit", "WebSearch", "Task", "mcp__approval_server__approval_prompt"]
    // Default to Claude's standard config location if not set
    if let savedPath = userDefaults.string(forKey: Keys.mcpConfigPath), !savedPath.isEmpty {
      self.mcpConfigPath = savedPath
    } else {
      // Use Claude's default location
      let homeURL = FileManager.default.homeDirectoryForCurrentUser
      let defaultPath = homeURL
        .appendingPathComponent(".config/claude/mcp-config.json")
        .path
      self.mcpConfigPath = defaultPath
      // Save it so it persists
      userDefaults.set(defaultPath, forKey: Keys.mcpConfigPath)
    }

    // Load default working directory or use empty string
    self.defaultWorkingDirectory = userDefaults.string(forKey: Keys.defaultWorkingDirectory) ?? ""

    // Load Claude command or use default
    self.claudeCommand = userDefaults.string(forKey: Keys.claudeCommand) ?? "claude"

    // Load Claude path or use empty string (optional field)
    self.claudePath = userDefaults.string(forKey: Keys.claudePath) ?? ""

    // Load custom permission settings or use defaults
    self.autoApproveLowRisk = userDefaults.object(forKey: Keys.autoApproveLowRisk) as? Bool ?? false
    self.showDetailedPermissionInfo = userDefaults.object(forKey: Keys.showDetailedPermissionInfo) as? Bool ?? true
    self.permissionRequestTimeout = userDefaults.object(forKey: Keys.permissionRequestTimeout) as? TimeInterval ?? 240.0 // 4 minutes
    self.permissionTimeoutEnabled = userDefaults.object(forKey: Keys.permissionTimeoutEnabled) as? Bool ?? false // Default to no timeout
    self.maxConcurrentPermissionRequests = userDefaults.object(forKey: Keys.maxConcurrentPermissionRequests) as? Int ?? 5
    
    // Load MCP tools discovery data
    self.mcpServerTools = userDefaults.dictionary(forKey: Keys.mcpServerTools) as? [String: [String]] ?? [:]
    
    // Load selected MCP tools and convert Arrays back to Sets
    if let savedDict = userDefaults.dictionary(forKey: Keys.selectedMCPTools) as? [String: [String]] {
      self.selectedMCPTools = savedDict.mapValues { Set($0) }
    } else {
      self.selectedMCPTools = [:]
    }
  }
  
  // MARK: - Methods
  public func resetToDefaults() {
    maxTurns = 50
    systemPrompt = ""
    appendSystemPrompt = ""
    allowedTools = ["Bash", "LS", "Read", "WebFetch", "Batch", "TodoRead/Write", "Glob", "Grep", "Edit", "MultiEdit", "Write", "NotebookRead", "NotebookEdit", "WebSearch", "Task", "mcp__approval_server__approval_prompt"]
    // Reset to Claude's default location
    let homeURL = FileManager.default.homeDirectoryForCurrentUser
    mcpConfigPath = homeURL
      .appendingPathComponent(".config/claude/mcp-config.json")
      .path
    defaultWorkingDirectory = ""
    claudeCommand = "claude"

    // Reset permission settings
    autoApproveLowRisk = false
    showDetailedPermissionInfo = true
    permissionRequestTimeout = 240.0
    permissionTimeoutEnabled = false
    maxConcurrentPermissionRequests = 50
    mcpServerTools = [:]
    selectedMCPTools = [:]
  }
  
  // MARK: - Custom Permission Configuration
  
  /// Creates a PermissionConfiguration from the current settings
  public func createPermissionConfiguration() -> PermissionConfiguration {
    return PermissionConfiguration(
      defaultTimeout: permissionTimeoutEnabled ? permissionRequestTimeout : nil,
      autoApproveLowRisk: autoApproveLowRisk,
      showDetailedInfo: showDetailedPermissionInfo,
      maxConcurrentRequests: maxConcurrentPermissionRequests
    )
  }
  
  /// Updates the permission settings from a PermissionConfiguration
  public func updateFromPermissionConfiguration(_ config: PermissionConfiguration) {
    if let timeout = config.defaultTimeout {
      permissionTimeoutEnabled = true
      permissionRequestTimeout = timeout
    } else {
      permissionTimeoutEnabled = false
    }
    autoApproveLowRisk = config.autoApproveLowRisk
    showDetailedPermissionInfo = config.showDetailedInfo
    maxConcurrentPermissionRequests = config.maxConcurrentRequests
  }
  
  // MARK: - MCPConfigStorage
  func setMcpConfigPath(_ path: String) {
    mcpConfigPath = path
  }
}
