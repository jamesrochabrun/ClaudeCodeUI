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
    
    // Custom permission settings
    static let autoApproveToolCalls = "global.autoApproveToolCalls"
    static let autoApproveLowRisk = "global.autoApproveLowRisk"
    static let showDetailedPermissionInfo = "global.showDetailedPermissionInfo"
    static let permissionRequestTimeout = "global.permissionRequestTimeout"
    static let permissionTimeoutEnabled = "global.permissionTimeoutEnabled"
    static let maxConcurrentPermissionRequests = "global.maxConcurrentPermissionRequests"
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
  
  // MARK: - Custom Permission Settings
  
  public var autoApproveToolCalls: Bool {
    didSet {
      userDefaults.set(autoApproveToolCalls, forKey: Keys.autoApproveToolCalls)
    }
  }
  
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
  
  // MARK: - Initialization
  public init() {
    // Load saved values or use defaults
    self.maxTurns = userDefaults.object(forKey: Keys.maxTurns) as? Int ?? 50
    self.systemPrompt = userDefaults.string(forKey: Keys.systemPrompt) ?? ""
    self.appendSystemPrompt = userDefaults.string(forKey: Keys.appendSystemPrompt) ?? ""
    self.allowedTools = userDefaults.stringArray(forKey: Keys.allowedTools) ?? ["Bash", "LS", "Read", "WebFetch", "Batch", "TodoRead/Write", "Glob", "Grep", "Edit", "MultiEdit", "Write", "NotebookRead", "NotebookEdit", "WebSearch", "Task", "mcp__approval_server__approval_prompt"]
    self.mcpConfigPath = userDefaults.string(forKey: Keys.mcpConfigPath) ?? ""
    
    // Load custom permission settings or use defaults
    self.autoApproveToolCalls = userDefaults.object(forKey: Keys.autoApproveToolCalls) as? Bool ?? false
    self.autoApproveLowRisk = userDefaults.object(forKey: Keys.autoApproveLowRisk) as? Bool ?? false
    self.showDetailedPermissionInfo = userDefaults.object(forKey: Keys.showDetailedPermissionInfo) as? Bool ?? true
    self.permissionRequestTimeout = userDefaults.object(forKey: Keys.permissionRequestTimeout) as? TimeInterval ?? 240.0 // 4 minutes
    self.permissionTimeoutEnabled = userDefaults.object(forKey: Keys.permissionTimeoutEnabled) as? Bool ?? false // Default to no timeout
    self.maxConcurrentPermissionRequests = userDefaults.object(forKey: Keys.maxConcurrentPermissionRequests) as? Int ?? 5
  }
  
  // MARK: - Methods
  public func resetToDefaults() {
    maxTurns = 50
    systemPrompt = ""
    appendSystemPrompt = ""
    allowedTools = ["Bash", "LS", "Read", "WebFetch", "Batch", "TodoRead/Write", "Glob", "Grep", "Edit", "MultiEdit", "Write", "NotebookRead", "NotebookEdit", "WebSearch", "Task", "mcp__approval_server__approval_prompt"]
    mcpConfigPath = ""
    
    // Reset permission settings
    autoApproveToolCalls = false
    autoApproveLowRisk = false
    showDetailedPermissionInfo = true
    permissionRequestTimeout = 240.0
    permissionTimeoutEnabled = false
    maxConcurrentPermissionRequests = 5
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
