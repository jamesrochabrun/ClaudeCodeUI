//
//  MCPToolsDiscoveryService.swift
//  ClaudeCodeUI
//
//  Created on 1/12/2025.
//

import Foundation
import os.log

/// Service responsible for discovering available tools from MCP servers
@MainActor
public final class MCPToolsDiscoveryService {
  
  private let logger = Logger(subsystem: "com.claudecode.ui", category: "MCPToolsDiscovery")
  
  /// Singleton instance
  public static let shared = MCPToolsDiscoveryService()
  
  /// Storage for discovered MCP tools by server
  private(set) var mcpServerTools: [String: [String]] = [:]
  
  /// Storage for Claude Code built-in tools
  private(set) var claudeCodeTools: [String] = []

  /// Hash of last discovered tools to detect changes
  private var lastDiscoveredToolsHash: String?

  /// Track if initial discovery has been performed
  private var hasPerformedInitialDiscovery = false

  private init() {}
  
  /// Parse and store tools from the system init message
  /// - Parameters:
  ///   - tools: Array of all available tool names from the init message
  ///   - mcpServers: Array of connected MCP servers (optional, for validation)
  public func parseToolsFromInitMessage(tools: [String], mcpServers: [(name: String, status: String)]? = nil) {
    logger.info("Parsing \(tools.count) tools from init message")
    
    // Clear existing data
    mcpServerTools.removeAll()
    claudeCodeTools.removeAll()
    
    // Separate MCP tools from Claude Code tools
    for tool in tools {
      if tool.hasPrefix("mcp__") {
        // Parse MCP tool: mcp__<server>__<tool_name>
        let components = tool.split(separator: "__")
        if components.count >= 3 {
          let serverName = String(components[1])
          let toolName = components[2...].joined(separator: "__") // Handle tools with __ in their name
          
          if mcpServerTools[serverName] == nil {
            mcpServerTools[serverName] = []
          }
          mcpServerTools[serverName]?.append(toolName)
        }
      } else {
        // Claude Code built-in tool
        claudeCodeTools.append(tool)
      }
    }
    
    // Log discovery results
    for (server, serverTools) in mcpServerTools {
      logger.info("MCP Server '\(server)': \(serverTools.count) tools")
    }
    
    // Log connected servers if provided
    if let servers = mcpServers {
      for server in servers {
        logger.info("MCP Server '\(server.name)' status: \(server.status)")
      }
    }
  }
  
  /// Get all available tools (both Claude Code built-in and MCP tools)
  public func getAllAvailableTools() -> [String: [String]] {
    var allTools: [String: [String]] = [:]
    
    // Add Claude Code built-in tools (use discovered ones if available)
    if !claudeCodeTools.isEmpty {
      allTools["Claude Code"] = claudeCodeTools
    }
    
    // Add discovered MCP tools
    for (server, tools) in mcpServerTools {
      allTools[server] = tools
    }
    
    return allTools
  }
  
  /// Update discovered tools for a specific server
  public func updateTools(for server: String, tools: [String]) {
    mcpServerTools[server] = tools
    logger.info("Updated tools for server \(server): \(tools.count) tools")
  }
  
  /// Clear all discovered tools
  public func clearDiscoveredTools() {
    mcpServerTools.removeAll()
    logger.info("Cleared all discovered MCP tools")
  }
  
  /// Remove tools for a specific server
  public func removeToolsForServer(_ serverName: String) {
    if mcpServerTools.removeValue(forKey: serverName) != nil {
      logger.info("Removed tools for server: \(serverName)")
    }
  }
  
  /// Check if tools have been discovered
  public var hasDiscoveredTools: Bool {
    !mcpServerTools.isEmpty
  }

  /// Compute a deterministic hash of the tools list
  private func computeToolsHash(from tools: [String]) -> String {
    // Sort tools for deterministic hash regardless of order
    let sortedTools = tools.sorted().joined(separator: "|")
    return String(sortedTools.hashValue)
  }

  /// Check if tools have changed since last discovery
  /// - Parameter tools: The new list of tools from init message
  /// - Returns: true if tools have changed and should be processed
  public func shouldUpdateTools(from tools: [String]) -> Bool {
    let currentHash = computeToolsHash(from: tools)
    let hasChanged = currentHash != lastDiscoveredToolsHash

    if hasChanged {
      lastDiscoveredToolsHash = currentHash
      hasPerformedInitialDiscovery = true
    }

    return hasChanged
  }

  /// Reset discovery state to force re-discovery on next init
  public func resetDiscoveryState() {
    lastDiscoveredToolsHash = nil
    hasPerformedInitialDiscovery = false
    mcpServerTools.removeAll()
    claudeCodeTools.removeAll()
    logger.info("Reset tool discovery state - will re-discover on next init")
  }
}
