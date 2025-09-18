//
//  PreferencesReconciler.swift
//  ClaudeCodeUI
//
//  Created on 1/18/25.
//

import Foundation
import os.log

/// Handles intelligent reconciliation of tool preferences when tools are discovered
/// Manages tool renames, additions, and removals while preserving user intent
@MainActor
public final class PreferencesReconciler {
  
  private let logger = Logger(subsystem: "com.claudecode.ui", category: "PreferencesReconciler")
  
  public init() {}
  
  /// Reconcile discovered tools with stored preferences
  /// - Parameters:
  ///   - discoveredTools: Tools discovered from Claude CLI and MCP servers
  ///   - storedPreferences: Previously stored tool preferences
  /// - Returns: Updated preferences container with reconciled tools
  public func reconcile(
    discoveredTools: DiscoveredTools,
    storedPreferences: PersistentPreferences?
  ) -> PersistentPreferences {
    
    logger.info("[PREF-DEBUG] PreferencesReconciler: Starting reconciliation")
    logger.info("[PREF-DEBUG]   - Discovered Claude tools: \(discoveredTools.claudeCodeTools.sorted())")
    logger.info("[PREF-DEBUG]   - Has stored preferences: \(storedPreferences != nil)")
    
    // Start with stored preferences or create new ones
    var preferences = storedPreferences ?? PersistentPreferences()
    
    // Update version and timestamp
    preferences = PersistentPreferences(
      version: preferences.version,
      lastUpdated: Date(),
      toolPreferences: reconcileToolPreferences(
        discovered: discoveredTools,
        stored: preferences.toolPreferences
      ),
      generalPreferences: preferences.generalPreferences
    )
    
    logger.info("[PREF-DEBUG] PreferencesReconciler: Reconciliation completed")
    logger.info("[PREF-DEBUG]   - Total tools in preferences: \(preferences.toolPreferences.claudeCode.count)")
    let allowedTools = preferences.toolPreferences.claudeCode.filter { $1.isAllowed }.map { $0.key }.sorted()
    logger.info("[PREF-DEBUG]   - Allowed tools: \(allowedTools)")
    return preferences
  }
  
  /// Reconcile tool preferences for all sources
  private func reconcileToolPreferences(
    discovered: DiscoveredTools,
    stored: ToolPreferencesContainer
  ) -> ToolPreferencesContainer {
    
    var container = ToolPreferencesContainer()
    
    // Reconcile Claude Code built-in tools
    container.claudeCode = reconcileClaudeCodeTools(
      discovered: discovered.claudeCodeTools,
      stored: stored.claudeCode
    )
    
    // Reconcile MCP server tools
    container.mcpServers = reconcileMCPTools(
      discovered: discovered.mcpServerTools,
      stored: stored.mcpServers
    )
    
    return container
  }
  
  /// Reconcile Claude Code built-in tools
  private func reconcileClaudeCodeTools(
    discovered: [String],
    stored: [String: ToolPreference]
  ) -> [String: ToolPreference] {
    
    var reconciled: [String: ToolPreference] = [:]
    
    // Process each discovered tool
    for toolName in discovered {
      if var existingPref = stored[toolName] {
        // Tool exists in storage - update last seen
        existingPref.markAsSeen()
        reconciled[toolName] = existingPref
        logger.info("[PREF-DEBUG] Tool '\(toolName)' found in storage, allowed: \(existingPref.isAllowed)")
      } else {
        // Check for possible renames using similarity matching
        let renamedFrom = findPossibleRename(
          toolName: toolName,
          in: stored,
          threshold: 0.8
        )
        
        if let oldName = renamedFrom,
           var oldPref = stored[oldName] {
          // Likely a renamed tool - preserve preference
          oldPref.addPreviousName(oldName)
          oldPref.markAsSeen()
          reconciled[toolName] = oldPref
          logger.info("[PREF-DEBUG] Tool '\(toolName)' appears to be renamed from '\(oldName)'")
        } else {
          // New tool - create default preference
          let defaultAllowed = isDefaultAllowed(toolName: toolName)
          reconciled[toolName] = ToolPreference.defaultForNewTool(
            isAllowed: defaultAllowed
          )
          logger.info("[PREF-DEBUG] NEW TOOL '\(toolName)' discovered, defaulting to allowed: \(defaultAllowed)")
        }
      }
    }
    
    // Mark missing tools (in storage but not discovered)
    for (storedName, storedPref) in stored {
      if !discovered.contains(storedName) && !reconciled.values.contains(where: { $0.previousNames.contains(storedName) }) {
        // Tool is missing - keep in storage but don't mark as seen
        reconciled[storedName] = storedPref
        logger.info("[PREF-DEBUG] Tool '\(storedName)' is missing from discovery but keeping in storage")
      }
    }
    
    return reconciled
  }
  
  /// Reconcile MCP server tools
  private func reconcileMCPTools(
    discovered: [String: [String]],
    stored: [String: [String: ToolPreference]]
  ) -> [String: [String: ToolPreference]] {
    
    var reconciled: [String: [String: ToolPreference]] = [:]
    
    // Process each discovered server
    for (serverName, discoveredTools) in discovered {
      let storedServerTools = stored[serverName] ?? [:]
      var reconciledServerTools: [String: ToolPreference] = [:]
      
      // Process each tool in the server
      for toolName in discoveredTools {
        if var existingPref = storedServerTools[toolName] {
          // Tool exists - update last seen
          existingPref.markAsSeen()
          reconciledServerTools[toolName] = existingPref
          logger.debug("MCP tool '\(serverName)__\(toolName)' found, allowed: \(existingPref.isAllowed)")
        } else {
          // New MCP tool - default to disallowed for safety
          reconciledServerTools[toolName] = ToolPreference.defaultForNewTool(isAllowed: false)
          logger.info("New MCP tool '\(serverName)__\(toolName)' discovered, defaulting to disallowed")
        }
      }
      
      // Keep missing tools in storage
      for (storedName, storedPref) in storedServerTools {
        if !discoveredTools.contains(storedName) {
          reconciledServerTools[storedName] = storedPref
          logger.info("MCP tool '\(serverName)__\(storedName)' is missing from discovery")
        }
      }
      
      reconciled[serverName] = reconciledServerTools
    }
    
    // Keep preferences for servers that are no longer connected
    for (serverName, serverTools) in stored {
      if reconciled[serverName] == nil {
        reconciled[serverName] = serverTools
        logger.info("MCP server '\(serverName)' not discovered, keeping stored preferences")
      }
    }
    
    return reconciled
  }
  
  /// Find possible rename match using string similarity
  private func findPossibleRename(
    toolName: String,
    in stored: [String: ToolPreference],
    threshold: Double
  ) -> String? {
    
    // Skip if tool name is too short for meaningful comparison
    guard toolName.count > 3 else { return nil }
    
    let lowercasedTool = toolName.lowercased()
    
    for (storedName, _) in stored {
      let lowercasedStored = storedName.lowercased()
      
      // Check for common rename patterns
      if isLikelyRename(from: lowercasedStored, to: lowercasedTool) {
        return storedName
      }
      
      // Calculate similarity score
      let similarity = calculateSimilarity(lowercasedStored, lowercasedTool)
      if similarity >= threshold {
        return storedName
      }
    }
    
    return nil
  }
  
  /// Check for common rename patterns
  private func isLikelyRename(from oldName: String, to newName: String) -> Bool {
    // Common rename patterns
    let patterns: [(old: String, new: String)] = [
      ("_", ""),           // Snake case to camel case
      ("read", "readfile"),
      ("write", "writefile"),
      ("exec", "execute"),
      ("del", "delete"),
      ("rm", "remove")
    ]
    
    for pattern in patterns {
      if oldName.contains(pattern.old) && newName.contains(pattern.new) {
        return true
      }
      if oldName.contains(pattern.new) && newName.contains(pattern.old) {
        return true
      }
    }
    
    return false
  }
  
  /// Calculate string similarity using Levenshtein distance
  private func calculateSimilarity(_ s1: String, _ s2: String) -> Double {
    let distance = levenshteinDistance(s1, s2)
    let maxLength = max(s1.count, s2.count)
    guard maxLength > 0 else { return 1.0 }
    return 1.0 - (Double(distance) / Double(maxLength))
  }
  
  /// Calculate Levenshtein distance between two strings
  private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
    let m = s1.count
    let n = s2.count
    
    guard m > 0 else { return n }
    guard n > 0 else { return m }
    
    var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
    
    for i in 0...m {
      matrix[i][0] = i
    }
    
    for j in 0...n {
      matrix[0][j] = j
    }
    
    let s1Array = Array(s1)
    let s2Array = Array(s2)
    
    for i in 1...m {
      for j in 1...n {
        let cost = s1Array[i-1] == s2Array[j-1] ? 0 : 1
        matrix[i][j] = min(
          matrix[i-1][j] + 1,      // Deletion
          matrix[i][j-1] + 1,      // Insertion
          matrix[i-1][j-1] + cost  // Substitution
        )
      }
    }
    
    return matrix[m][n]
  }
  
  /// Determine if a tool should be allowed by default
  private func isDefaultAllowed(toolName: String) -> Bool {
    // Safe tools that can be allowed by default
    let safeTools = [
      "Read", "Grep", "Glob", "LS", "WebSearch",
      "TodoWrite", "ExitPlanMode", "exit_plan_mode"
    ]
    
    // Check if it's a known safe tool
    if safeTools.contains(toolName) {
      return true
    }
    
    // Tools containing certain keywords should default to disallowed
    let riskyKeywords = ["bash", "exec", "write", "edit", "delete", "remove", "kill"]
    let lowercased = toolName.lowercased()
    
    for keyword in riskyKeywords {
      if lowercased.contains(keyword) {
        return false
      }
    }
    
    // Default to disallowed for unknown tools
    return false
  }
}

/// Container for discovered tools from various sources
public struct DiscoveredTools {
  public let claudeCodeTools: [String]
  public let mcpServerTools: [String: [String]]
  
  public init(
    claudeCodeTools: [String] = [],
    mcpServerTools: [String: [String]] = [:]
  ) {
    self.claudeCodeTools = claudeCodeTools
    self.mcpServerTools = mcpServerTools
  }
  
  /// Create from MCPToolsDiscoveryService data
  @MainActor
  public static func from(discoveryService: MCPToolsDiscoveryService) -> DiscoveredTools {
    DiscoveredTools(
      claudeCodeTools: discoveryService.claudeCodeTools,
      mcpServerTools: discoveryService.mcpServerTools
    )
  }
}
