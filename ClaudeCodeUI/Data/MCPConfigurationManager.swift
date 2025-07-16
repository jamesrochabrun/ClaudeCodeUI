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
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
      .appendingPathComponent("ClaudeCodeUI")
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
