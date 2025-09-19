//
//  MCPConfigurationManager.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 12/19/24.
//

import Foundation
import Observation

@Observable
@MainActor
final class MCPConfigurationManager {
  var configuration: MCPConfiguration
  
  private let configFileName = "mcp-config.json"
  private var configFileURL: URL? {
    // Use Claude Code's default configuration location
    let homeURL = FileManager.default.homeDirectoryForCurrentUser
    return homeURL
      .appendingPathComponent(".config")
      .appendingPathComponent("claude")
      .appendingPathComponent(configFileName)
  }
  
  init() {
    self.configuration = MCPConfiguration()
    loadConfiguration()
  }
  
  // MARK: - File Management
  
  func saveConfiguration() {
    guard let url = configFileURL else {
      print("[MCP] No config file URL available")
      return
    }
    
    do {
      // Create directory if needed
      let directory = url.deletingLastPathComponent()
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      
      // Encode and save
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      let data = try encoder.encode(configuration)
      try data.write(to: url)
      print("[MCP] Configuration saved to: \(url.path)")
      print("[MCP] Servers: \(configuration.mcpServers.keys.joined(separator: ", "))")
    } catch {
      print("[MCP] Failed to save configuration: \(error)")
    }
  }
  
  func loadConfiguration() {
    guard let url = configFileURL,
          FileManager.default.fileExists(atPath: url.path) else {
      // Load default configuration
      loadDefaultConfiguration()
      return
    }
    
    do {
      let data = try Data(contentsOf: url)
      configuration = try JSONDecoder().decode(MCPConfiguration.self, from: data)
    } catch {
      print("Failed to load MCP configuration: \(error)")
      loadDefaultConfiguration()
    }
  }
  
  private func loadDefaultConfiguration() {
    configuration = MCPConfiguration()
  }
  
  func getConfigurationPath() -> String? {
    return configFileURL?.path
  }
  
  // MARK: - Server Management
  
  func addServer(_ server: MCPServerConfig) {
    print("[MCP] Adding server: \(server.name)")
    configuration.mcpServers[server.name] = server
    saveConfiguration()
  }
  
  func removeServer(named name: String) {
    configuration.mcpServers.removeValue(forKey: name)
    saveConfiguration()
  }
  
  func updateServer(_ server: MCPServerConfig) {
    configuration.mcpServers[server.name] = server
    saveConfiguration()
  }
  
  // MARK: - Approval Server Management

  /// Updates the approval server path in the MCP configuration
  /// This ensures the config always points to the bundled or extracted binary
  func updateApprovalServerPath() {
    // First check if ApprovalMCPServer exists in the app bundle (for DMG/Xcode builds)
    if let bundlePath = Bundle.main.path(forResource: "ApprovalMCPServer", ofType: nil),
       FileManager.default.fileExists(atPath: bundlePath) {
      // Update or add the approval server configuration
      updateApprovalServerConfig(path: bundlePath)
      return
    }

    // For Swift Package users, check if it's been extracted to Application Support
    let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let appName = Bundle.main.bundleIdentifier ?? "ClaudeCodeUI"
    let extractedPath = appSupportURL
      .appendingPathComponent(appName)
      .appendingPathComponent("ApprovalMCPServer")
      .path

    if FileManager.default.fileExists(atPath: extractedPath) {
      print("[MCP] Found extracted ApprovalMCPServer at: \(extractedPath)")
      updateApprovalServerConfig(path: extractedPath)
      return
    }

    print("[MCP] ApprovalMCPServer not found in bundle or Application Support - removing from config")
    // Remove approval_server if binary doesn't exist anywhere
    if configuration.mcpServers["approval_server"] != nil {
      configuration.mcpServers.removeValue(forKey: "approval_server")
      saveConfiguration()
    }
  }

  private func updateApprovalServerConfig(path: String) {
    print("[MCP] Configuring ApprovalMCPServer at: \(path)")

    // Check if approval_server already exists and has correct path
    if let existingServer = configuration.mcpServers["approval_server"],
       existingServer.command == path {
      print("[MCP] Approval server already configured with correct path")
      return
    }

    // Update or add the approval_server configuration
    let approvalServer = MCPServerConfig(
      name: "approval_server",
      command: path,
      args: [],
      env: [:]
    )
    configuration.mcpServers["approval_server"] = approvalServer
    print("[MCP] Updated approval_server path in configuration")
    saveConfiguration()
  }

  // MARK: - Export/Import

  func exportConfiguration(to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(configuration)
    try data.write(to: url)
  }

  func importConfiguration(from url: URL) throws {
    let data = try Data(contentsOf: url)
    configuration = try JSONDecoder().decode(MCPConfiguration.self, from: data)
    saveConfiguration()
  }
}
