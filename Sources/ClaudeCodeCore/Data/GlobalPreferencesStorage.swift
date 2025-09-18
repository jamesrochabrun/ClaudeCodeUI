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
  private let persistentManager = PersistentPreferencesManager.shared
  private let reconciler = PreferencesReconciler()
  
  /// Cached persistent preferences
  private var persistentPreferences: PersistentPreferences?
  
  /// Track if preferences are corrupted
  public var hasCorruptedPreferences = false
  
  /// Store the corruption error for detailed information
  public var corruptionError: PreferencesLoadError?
  
  /// Track if a backup is available
  public var hasBackupAvailable = false
  
  public var systemPrompt: String {
    didSet {
      saveToPersistentStorage()
    }
  }
  
  public var appendSystemPrompt: String {
    didSet {
      saveToPersistentStorage()
    }
  }
  
  public var allowedTools: [String] {
    didSet {
      saveToPersistentStorage()
    }
  }
  
  public var mcpConfigPath: String {
    didSet {
      saveToPersistentStorage()
    }
  }
  
  public var defaultWorkingDirectory: String {
    didSet {
      saveToPersistentStorage()
    }
  }
  
  public var claudeCommand: String {
    didSet {
      saveToPersistentStorage()
    }
  }
  
  public var claudePath: String {
    didSet {
      saveToPersistentStorage()
    }
  }
  
  // MARK: - Custom Permission Settings
  
  public var autoApproveLowRisk: Bool {
    didSet {
      saveToPersistentStorage()
    }
  }
  
  public var showDetailedPermissionInfo: Bool {
    didSet {
      saveToPersistentStorage()
    }
  }
  
  public var permissionRequestTimeout: TimeInterval {
    didSet {
      saveToPersistentStorage()
    }
  }
  
  public var permissionTimeoutEnabled: Bool {
    didSet {
      saveToPersistentStorage()
    }
  }
  
  public var maxConcurrentPermissionRequests: Int {
    didSet {
      saveToPersistentStorage()
    }
  }
  
  // MARK: - MCP Tools Discovery
  
  /// Discovered MCP tools by server name
  public var mcpServerTools: [String: [String]] {
    didSet {
      saveToPersistentStorage()
    }
  }
  
  /// Selected MCP tools by server name
  public var selectedMCPTools: [String: Set<String>] {
    didSet {
      saveToPersistentStorage()
    }
  }
  
  // MARK: - Initialization
  public init() {
    ClaudeCodeLogger.shared.preferences("GlobalPreferencesStorage initializing")
    
    // Try to load from persistent storage with corruption detection
    let loadResult = persistentManager.loadPreferencesWithResult()
    
    switch loadResult {
    case .success(let persistent):
      self.persistentPreferences = persistent
      self.hasCorruptedPreferences = false
      self.corruptionError = nil
      
      // Load general preferences from persistent storage
      let general = persistent.generalPreferences
      self.systemPrompt = general.systemPrompt
      self.appendSystemPrompt = general.appendSystemPrompt
      self.claudeCommand = general.claudeCommand
      self.claudePath = general.claudePath
      self.defaultWorkingDirectory = general.defaultWorkingDirectory
      self.autoApproveLowRisk = general.autoApproveLowRisk
      self.showDetailedPermissionInfo = general.showDetailedPermissionInfo
      self.permissionRequestTimeout = general.permissionRequestTimeout
      self.permissionTimeoutEnabled = general.permissionTimeoutEnabled
      self.maxConcurrentPermissionRequests = general.maxConcurrentPermissionRequests
      
      // MCP config path - default to Claude's standard location
      let homeURL = FileManager.default.homeDirectoryForCurrentUser
      self.mcpConfigPath = homeURL
        .appendingPathComponent(".config/claude/mcp-config.json")
        .path
      
      // Initialize tool-related properties temporarily
      self.allowedTools = []
      self.mcpServerTools = [:]
      self.selectedMCPTools = [:]
      
      // Now load tool preferences and convert to allowed tools list
      self.allowedTools = buildAllowedToolsList(from: persistent.toolPreferences)
      self.mcpServerTools = buildMCPServerTools(from: persistent.toolPreferences)
      self.selectedMCPTools = buildSelectedMCPTools(from: persistent.toolPreferences)
      
      ClaudeCodeLogger.shared.preferences("Loaded from persistent storage: \(self.allowedTools.count) allowed tools")
      
    case .failure(let error):
      // Handle different types of failures
      // Use a local variable to track corruption state
      let isCorrupted: Bool
      let corruptionErr: PreferencesLoadError?
      
      switch error {
      case .fileSystemError(let underlyingError):
        // Check if it's a file not found error
        if (underlyingError as NSError).code == CocoaError.fileNoSuchFile.rawValue {
          // File doesn't exist - normal first run scenario
          isCorrupted = false
          corruptionErr = nil
        } else {
          // Other file system error - treat as corruption
          ClaudeCodeLogger.shared.preferences("ERROR: Preferences file system error - \(error.localizedDescription)")
          isCorrupted = true
          corruptionErr = error
        }
        
      default:
        // File exists but is corrupted
        ClaudeCodeLogger.shared.preferences("ERROR: Preferences corrupted - \(error.localizedDescription)")
        isCorrupted = true
        corruptionErr = error
      }
      
      // Initialize with default values
      self.systemPrompt = ""
      self.appendSystemPrompt = ""
      
      if isCorrupted {
        // SAFETY: When corrupted, don't auto-approve ANY tools
        ClaudeCodeLogger.shared.preferences("WARNING: Due to corruption, no tools will be auto-approved for safety")
        self.allowedTools = []
      } else {
        // Normal defaults - only safe read-only tools
        self.allowedTools = ["LS", "Read", "Glob", "Grep", "WebSearch", "TodoWrite", "exit_plan_mode"]
      }
      
      // Use Claude's default location
      let homeURL = FileManager.default.homeDirectoryForCurrentUser
      self.mcpConfigPath = homeURL
        .appendingPathComponent(".config/claude/mcp-config.json")
        .path
      
      self.defaultWorkingDirectory = ""
      self.claudeCommand = "claude"
      self.claudePath = ""
      
      // Default permission settings
      self.autoApproveLowRisk = false
      self.showDetailedPermissionInfo = true
      self.permissionRequestTimeout = 3600.0 // 1 hour
      self.permissionTimeoutEnabled = false
      self.maxConcurrentPermissionRequests = 5
      
      // Initialize empty MCP tools
      self.mcpServerTools = [:]
      self.selectedMCPTools = [:]
      
      // Now set the corruption state properties after all properties are initialized
      self.hasCorruptedPreferences = isCorrupted
      self.corruptionError = corruptionErr
      
      // Only create initial preferences if not corrupted
      if !isCorrupted {
        createInitialPersistentPreferences()
      }
      
    }
    
    // Check if backup is available (useful for corruption recovery)
    checkForBackup()
    
    ClaudeCodeLogger.shared.preferences("Initialization completed" + (hasCorruptedPreferences ? " (corrupted state)" : ""))
  }
  
  /// Check if a backup is available
  private func checkForBackup() {
    let backupURL = FileManager.default
      .urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
      .appendingPathComponent("ClaudeCodeUI", isDirectory: true)
      .appendingPathComponent("preferences.backup.json")
    
    if let url = backupURL {
      hasBackupAvailable = FileManager.default.fileExists(atPath: url.path)
    }
  }
  
  // MARK: - Methods
  
  /// Reset after corruption - deletes corrupted file and starts fresh
  public func resetAfterCorruption() {
    ClaudeCodeLogger.shared.preferences("Resetting after corruption")
    
    // Delete the corrupted file
    persistentManager.deleteCorruptedFile()
    
    // Clear corruption state
    hasCorruptedPreferences = false
    corruptionError = nil
    
    // Reset to safe defaults (no auto-approvals)
    resetToDefaults()
    
  }
  
  /// Attempt to restore from backup
  public func restoreFromBackup() -> Bool {
    ClaudeCodeLogger.shared.preferences("Attempting to restore from backup")
    
    if let restored = persistentManager.restoreFromBackup() {
      // Successfully restored - reload the preferences
      self.persistentPreferences = restored
      
      // Load from restored preferences
      let general = restored.generalPreferences
      self.systemPrompt = general.systemPrompt
      self.appendSystemPrompt = general.appendSystemPrompt
      self.claudeCommand = general.claudeCommand
      self.claudePath = general.claudePath
      self.defaultWorkingDirectory = general.defaultWorkingDirectory
      self.autoApproveLowRisk = general.autoApproveLowRisk
      self.showDetailedPermissionInfo = general.showDetailedPermissionInfo
      self.permissionRequestTimeout = general.permissionRequestTimeout
      self.permissionTimeoutEnabled = general.permissionTimeoutEnabled
      self.maxConcurrentPermissionRequests = general.maxConcurrentPermissionRequests
      
      // Restore tool preferences
      self.allowedTools = buildAllowedToolsList(from: restored.toolPreferences)
      self.mcpServerTools = buildMCPServerTools(from: restored.toolPreferences)
      self.selectedMCPTools = buildSelectedMCPTools(from: restored.toolPreferences)
      
      // Clear corruption state
      hasCorruptedPreferences = false
      corruptionError = nil
      
      ClaudeCodeLogger.shared.preferences("Successfully restored from backup")
      return true
    } else {
      ClaudeCodeLogger.shared.preferences("ERROR: Failed to restore from backup")
      return false
    }
  }
  
  public func resetToDefaults() {
    systemPrompt = ""
    appendSystemPrompt = ""
    // Only allow safe read-only tools by default - risky tools require explicit approval
    allowedTools = ["LS", "Read", "Glob", "Grep", "WebSearch", "TodoWrite", "exit_plan_mode"]
    // Reset to Claude's default location
    let homeURL = FileManager.default.homeDirectoryForCurrentUser
    mcpConfigPath = homeURL
      .appendingPathComponent(".config/claude/mcp-config.json")
      .path
    defaultWorkingDirectory = ""
    claudeCommand = "claude"
    claudePath = ""
    
    // Reset permission settings
    autoApproveLowRisk = false
    showDetailedPermissionInfo = true
    permissionRequestTimeout = 3600.0
    permissionTimeoutEnabled = false
    maxConcurrentPermissionRequests = 50
    mcpServerTools = [:]
    selectedMCPTools = [:]
    
    // Clear persistent storage
    persistentManager.deleteAllPreferences()
    persistentPreferences = nil
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
  
  // MARK: - Private Helper Methods
  
  /// Save current state to persistent storage
  private func saveToPersistentStorage() {
    
    // Build tool preferences from current state
    var toolPrefs = ToolPreferencesContainer()
    
    // Add Claude Code tools
    for tool in ClaudeCodeTool.allCases {
      let toolName = tool.rawValue
      let isAllowed = allowedTools.contains(toolName)
      toolPrefs.claudeCode[toolName] = ToolPreference(isAllowed: isAllowed)
    }
    
    // Add MCP tools
    for (server, tools) in mcpServerTools {
      var serverPrefs: [String: ToolPreference] = [:]
      let selectedForServer = selectedMCPTools[server] ?? Set()
      
      for tool in tools {
        let isAllowed = selectedForServer.contains(tool)
        serverPrefs[tool] = ToolPreference(isAllowed: isAllowed)
      }
      
      toolPrefs.mcpServers[server] = serverPrefs
    }
    
    // Create persistent preferences
    let persistent = PersistentPreferences(
      version: "1.0",
      lastUpdated: Date(),
      toolPreferences: toolPrefs,
      generalPreferences: GeneralPreferences(
        autoApproveLowRisk: autoApproveLowRisk,
        claudeCommand: claudeCommand,
        claudePath: claudePath,
        defaultWorkingDirectory: defaultWorkingDirectory,
        appendSystemPrompt: appendSystemPrompt,
        systemPrompt: systemPrompt,
        showDetailedPermissionInfo: showDetailedPermissionInfo,
        permissionRequestTimeout: permissionRequestTimeout,
        permissionTimeoutEnabled: permissionTimeoutEnabled,
        maxConcurrentPermissionRequests: maxConcurrentPermissionRequests
      )
    )
    
    // Save to persistent storage
    persistentManager.savePreferences(persistent)
    self.persistentPreferences = persistent
  }
  
  /// Build allowed tools list from tool preferences
  private func buildAllowedToolsList(from toolPrefs: ToolPreferencesContainer) -> [String] {
    var allowed: [String] = []
    
    // Add allowed Claude Code tools
    for (toolName, pref) in toolPrefs.claudeCode where pref.isAllowed {
      allowed.append(toolName)
    }
    
    // Add allowed MCP tools with full name
    for (serverName, tools) in toolPrefs.mcpServers {
      for (toolName, pref) in tools where pref.isAllowed {
        allowed.append("mcp__\(serverName)__\(toolName)")
      }
    }
    
    return allowed
  }
  
  /// Build MCP server tools dictionary from tool preferences
  private func buildMCPServerTools(from toolPrefs: ToolPreferencesContainer) -> [String: [String]] {
    var serverTools: [String: [String]] = [:]
    
    for (serverName, tools) in toolPrefs.mcpServers {
      serverTools[serverName] = Array(tools.keys)
    }
    
    return serverTools
  }
  
  /// Build selected MCP tools from tool preferences
  private func buildSelectedMCPTools(from toolPrefs: ToolPreferencesContainer) -> [String: Set<String>] {
    var selected: [String: Set<String>] = [:]
    
    for (serverName, tools) in toolPrefs.mcpServers {
      let allowedTools = tools.compactMap { (name, pref) in
        pref.isAllowed ? name : nil
      }
      if !allowedTools.isEmpty {
        selected[serverName] = Set(allowedTools)
      }
    }
    
    return selected
  }
  
  /// Create initial persistent preferences from current values
  private func createInitialPersistentPreferences() {
    var toolPrefs = ToolPreferencesContainer()
    
    // Build Claude Code tool preferences
    for tool in ClaudeCodeTool.allCases {
      let toolName = tool.rawValue
      let isAllowed = allowedTools.contains(toolName)
      toolPrefs.claudeCode[toolName] = ToolPreference(isAllowed: isAllowed)
    }
    
    // Build MCP tool preferences
    for (serverName, tools) in mcpServerTools {
      var serverPrefs: [String: ToolPreference] = [:]
      let selectedForServer = selectedMCPTools[serverName] ?? Set()
      
      for tool in tools {
        let isAllowed = selectedForServer.contains(tool)
        serverPrefs[tool] = ToolPreference(isAllowed: isAllowed)
      }
      
      toolPrefs.mcpServers[serverName] = serverPrefs
    }
    
    // Create and save persistent preferences
    let persistent = PersistentPreferences(
      version: "1.0",
      lastUpdated: Date(),
      toolPreferences: toolPrefs,
      generalPreferences: GeneralPreferences(
        autoApproveLowRisk: autoApproveLowRisk,
        claudeCommand: claudeCommand,
        claudePath: claudePath,
        defaultWorkingDirectory: defaultWorkingDirectory,
        appendSystemPrompt: appendSystemPrompt,
        systemPrompt: systemPrompt,
        showDetailedPermissionInfo: showDetailedPermissionInfo,
        permissionRequestTimeout: permissionRequestTimeout,
        permissionTimeoutEnabled: permissionTimeoutEnabled,
        maxConcurrentPermissionRequests: maxConcurrentPermissionRequests
      )
    )
    
    persistentManager.savePreferences(persistent)
    self.persistentPreferences = persistent
    ClaudeCodeLogger.shared.preferences("Created initial persistent preferences")
  }
  
  /// Reconcile tools when new tools are discovered
  public func reconcileTools(with discoveryService: MCPToolsDiscoveryService) {
    ClaudeCodeLogger.shared.preferences("Starting tool reconciliation")
    
    // Create discovered tools structure
    let discovered = DiscoveredTools.from(discoveryService: discoveryService)
    
    // Reconcile with existing preferences
    let reconciled = reconciler.reconcile(
      discoveredTools: discovered,
      storedPreferences: persistentPreferences
    )
    
    // Update from reconciled preferences
    self.persistentPreferences = reconciled
    
    // Update current state from reconciled preferences
    self.allowedTools = buildAllowedToolsList(from: reconciled.toolPreferences)
    self.mcpServerTools = buildMCPServerTools(from: reconciled.toolPreferences)
    self.selectedMCPTools = buildSelectedMCPTools(from: reconciled.toolPreferences)
    
    // Save reconciled state
    persistentManager.savePreferences(reconciled)
    
    ClaudeCodeLogger.shared.preferences("Tool reconciliation completed")
  }
}
