//
//  MCPConfigurationTests.swift
//  ClaudeCodeUITests
//
//  Created on 12/19/24.
//

import XCTest
@testable import ClaudeCodeCore

@MainActor
final class MCPConfigurationTests: XCTestCase {
  
  var configManager: MCPConfigurationManager!
  var globalPreferences: GlobalPreferencesStorage!
  let testConfigPath = FileManager.default.temporaryDirectory.appendingPathComponent("test-mcp-config.json")
  
  override func setUp() async throws {
    try await super.setUp()
    // Clean up any existing test files
    try? FileManager.default.removeItem(at: testConfigPath)
    
    // Clear UserDefaults
    UserDefaults.standard.removeObject(forKey: "global.mcpConfigPath")
    
    configManager = MCPConfigurationManager()
    globalPreferences = GlobalPreferencesStorage()
  }
  
  override func tearDown() async throws {
    configManager = nil
    globalPreferences = nil
    try? FileManager.default.removeItem(at: testConfigPath)
    try await super.tearDown()
  }
  
  // MARK: - MCPConfiguration Model Tests
  
  func testMCPConfigurationInitialization() {
    let config = MCPConfiguration()
    XCTAssertTrue(config.mcpServers.isEmpty, "New configuration should have no servers")
  }
  
  func testMCPServerConfigCreation() {
    let server = MCPServerConfig(
      name: "test-server",
      command: "npx",
      args: ["-y", "test-package"],
      env: ["API_KEY": "test-key"]
    )
    
    XCTAssertEqual(server.name, "test-server")
    XCTAssertEqual(server.command, "npx")
    XCTAssertEqual(server.args, ["-y", "test-package"])
    XCTAssertEqual(server.env?["API_KEY"], "test-key")
  }
  
  // MARK: - MCPConfigurationManager Tests
  
  func testAddServer() {
    let server = MCPServerConfig(name: "test", command: "npm", args: ["run", "test"])
    configManager.addServer(server)
    
    XCTAssertEqual(configManager.configuration.mcpServers.count, 1)
    XCTAssertNotNil(configManager.configuration.mcpServers["test"])
    XCTAssertEqual(configManager.configuration.mcpServers["test"]?.command, "npm")
  }
  
  func testRemoveServer() {
    let server = MCPServerConfig(name: "to-remove", command: "npx")
    configManager.addServer(server)
    XCTAssertEqual(configManager.configuration.mcpServers.count, 1)
    
    configManager.removeServer(named: "to-remove")
    XCTAssertEqual(configManager.configuration.mcpServers.count, 0)
  }
  
  func testUpdateServer() {
    let server = MCPServerConfig(name: "to-update", command: "old-command")
    configManager.addServer(server)
    
    let updatedServer = MCPServerConfig(name: "to-update", command: "new-command", args: ["--flag"])
    configManager.updateServer(updatedServer)
    
    XCTAssertEqual(configManager.configuration.mcpServers["to-update"]?.command, "new-command")
    XCTAssertEqual(configManager.configuration.mcpServers["to-update"]?.args, ["--flag"])
  }
  
  // MARK: - Persistence Tests
  
  func testConfigurationPersistence() async throws {
    // Add servers
    let server1 = MCPServerConfig(name: "persist1", command: "node")
    let server2 = MCPServerConfig(name: "persist2", command: "python", args: ["-m", "server"])
    
    configManager.addServer(server1)
    configManager.addServer(server2)
    
    // Wait a bit for save to complete
    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    
    // Create new manager instance
    let newManager = MCPConfigurationManager()
    
    // Verify servers persisted
    XCTAssertEqual(newManager.configuration.mcpServers.count, 2)
    XCTAssertNotNil(newManager.configuration.mcpServers["persist1"])
    XCTAssertNotNil(newManager.configuration.mcpServers["persist2"])
  }
  
  // MARK: - JSON Encoding/Decoding Tests
  
  func testMCPConfigurationJSONEncoding() throws {
    var config = MCPConfiguration()
    config.mcpServers["test-server"] = MCPServerConfig(
      name: "test-server",
      command: "npx",
      args: ["-y", "package"],
      env: ["KEY": "value"]
    )
    
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(config)
    let json = String(data: data, encoding: .utf8)!
    
    // Verify JSON structure
    XCTAssertTrue(json.contains("\"mcpServers\""))
    XCTAssertTrue(json.contains("\"test-server\""))
    XCTAssertTrue(json.contains("\"command\" : \"npx\""))
    XCTAssertTrue(json.contains("\"args\""))
    XCTAssertTrue(json.contains("\"env\""))
  }
  
  func testMCPConfigurationJSONDecoding() throws {
    let json = """
        {
          "mcpServers": {
            "decoded-server": {
              "command": "python",
              "args": ["-m", "server", "--port", "8080"],
              "env": {
                "PYTHON_PATH": "/usr/bin/python3"
              }
            }
          }
        }
        """
    
    let data = json.data(using: .utf8)!
    let config = try JSONDecoder().decode(MCPConfiguration.self, from: data)
    
    XCTAssertEqual(config.mcpServers.count, 1)
    let server = config.mcpServers["decoded-server"]
    XCTAssertNotNil(server)
    XCTAssertEqual(server?.command, "python")
    XCTAssertEqual(server?.args, ["-m", "server", "--port", "8080"])
    XCTAssertEqual(server?.env?["PYTHON_PATH"], "/usr/bin/python3")
  }
  
  // MARK: - Predefined Servers Tests
  
  func testPredefinedServers() {
    let predefined = MCPServerConfig.predefinedServers
    
    XCTAssertGreaterThan(predefined.count, 0, "Should have predefined servers")
    
    // Test specific predefined servers
    let xcodeBuild = predefined.first { $0.name == "XcodeBuildMCP" }
    XCTAssertNotNil(xcodeBuild)
    XCTAssertEqual(xcodeBuild?.command, "npx")
    
    let filesystem = predefined.first { $0.name == "filesystem" }
    XCTAssertNotNil(filesystem)
    
    let github = predefined.first { $0.name == "github" }
    XCTAssertNotNil(github)
    XCTAssertNotNil(github?.env?["GITHUB_TOKEN"], "GitHub server should have env variable")
  }
  
  // MARK: - Integration with GlobalPreferences Tests
  
  func testMCPPathIntegration() {
    let testPath = "/test/mcp/config.json"
    
    // Set path through protocol method
    globalPreferences.setMcpConfigPath(testPath)
    XCTAssertEqual(globalPreferences.mcpConfigPath, testPath)
    
    // Verify persistence
    let newPreferences = GlobalPreferencesStorage()
    XCTAssertEqual(newPreferences.mcpConfigPath, testPath)
  }
  
  // MARK: - Export/Import Tests
  
  func testExportConfiguration() throws {
    // Setup configuration
    configManager.addServer(MCPServerConfig(name: "export-test", command: "node"))
    
    // Export
    try configManager.exportConfiguration(to: testConfigPath)
    
    // Verify file exists
    XCTAssertTrue(FileManager.default.fileExists(atPath: testConfigPath.path))
    
    // Read and verify content
    let data = try Data(contentsOf: testConfigPath)
    let imported = try JSONDecoder().decode(MCPConfiguration.self, from: data)
    
    XCTAssertEqual(imported.mcpServers.count, 1)
    XCTAssertNotNil(imported.mcpServers["export-test"])
  }
  
  func testImportConfiguration() throws {
    // Create test configuration file
    let config = MCPConfiguration(mcpServers: [
      "imported": MCPServerConfig(name: "imported", command: "deno", args: ["run"])
    ])
    
    let data = try JSONEncoder().encode(config)
    try data.write(to: testConfigPath)
    
    // Import
    try configManager.importConfiguration(from: testConfigPath)
    
    // Verify
    XCTAssertEqual(configManager.configuration.mcpServers.count, 1)
    XCTAssertNotNil(configManager.configuration.mcpServers["imported"])
    XCTAssertEqual(configManager.configuration.mcpServers["imported"]?.command, "deno")
  }
}
