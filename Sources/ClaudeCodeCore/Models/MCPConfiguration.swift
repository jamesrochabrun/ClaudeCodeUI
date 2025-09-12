//
//  MCPConfiguration.swift
//  ClaudeCodeUI
//
//  Created by Claude on 12/19/24.
//

import Foundation

// MARK: - MCP Configuration Models

struct MCPConfiguration: Codable {
  var mcpServers: [String: MCPServerConfig]
  
  init(mcpServers: [String: MCPServerConfig] = [:]) {
    self.mcpServers = mcpServers
  }
  
  // Custom encoding/decoding to handle the server names as dictionary keys
  enum CodingKeys: String, CodingKey {
    case mcpServers
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let serverDict = try container.decode([String: MCPServerConfig.ServerData].self, forKey: .mcpServers)
    
    // Convert ServerData to MCPServerConfig with names
    self.mcpServers = serverDict.reduce(into: [:]) { result, pair in
      result[pair.key] = MCPServerConfig(
        name: pair.key,
        command: pair.value.command ?? "",
        args: pair.value.args ?? [],
        env: pair.value.env,
        url: nil  // URL is not decoded from MCP config
      )
    }
  }
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    
    // Convert MCPServerConfig to ServerData for encoding
    let serverDict = mcpServers.reduce(into: [String: MCPServerConfig.ServerData]()) { result, pair in
      result[pair.key] = MCPServerConfig.ServerData(
        command: pair.value.command.isEmpty ? nil : pair.value.command,
        args: pair.value.args.isEmpty ? nil : pair.value.args,
        env: pair.value.env
        // Note: url is not encoded as it's not a valid MCP field
      )
    }
    
    try container.encode(serverDict, forKey: .mcpServers)
  }
}

struct MCPServerConfig: Identifiable {
  var id: String { name }
  let name: String
  var command: String
  var args: [String]
  var env: [String: String]?
  var url: String?
  
  init(name: String, command: String = "", args: [String] = [], env: [String: String]? = nil, url: String? = nil) {
    self.name = name
    self.command = command
    self.args = args
    self.env = env
    self.url = url
  }
  
  // Inner struct for JSON encoding/decoding
  struct ServerData: Codable {
    let command: String?
    let args: [String]?
    let env: [String: String]?
    // Note: url is not included in encoding/decoding as it's not a valid MCP field
  }
}

// MARK: - Predefined MCP Servers

extension MCPServerConfig {
  static let predefinedServers = [
    MCPServerConfig(
      name: "approval_server",
      command: "/Users/jamesrochabrun/Desktop/git/ClaudeCodeUI/modules/ApprovalMCPServer/.build/arm64-apple-macosx/debug/ApprovalMCPServer",
      args: []
    ),
    MCPServerConfig(
      name: "XcodeBuildMCP",
      command: "npx",
      args: ["-y", "xcodebuildmcp@latest"]
    )
  ]
}
