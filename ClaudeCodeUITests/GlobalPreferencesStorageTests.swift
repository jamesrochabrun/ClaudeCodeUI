//
//  GlobalPreferencesStorageTests.swift
//  ClaudeCodeUITests
//
//  Created on 12/19/24.
//

import XCTest
@testable import ClaudeCodeUI

@MainActor
final class GlobalPreferencesStorageTests: XCTestCase {
    
    var storage: GlobalPreferencesStorage!
    let testDefaults = UserDefaults(suiteName: "com.test.globalpreferences")!
    
    override func setUp() async throws {
        try await super.setUp()
        // Clear all global preferences keys from standard UserDefaults
        let keys = [
            "global.maxTurns",
            "global.systemPrompt",
            "global.appendSystemPrompt",
            "global.allowedTools",
            "global.mcpConfigPath"
        ]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        UserDefaults.standard.synchronize()
        
        // Clear test defaults
        testDefaults.removePersistentDomain(forName: "com.test.globalpreferences")
        storage = GlobalPreferencesStorage()
    }
    
    override func tearDown() async throws {
        storage = nil
        try await super.tearDown()
    }
    
    // MARK: - Max Turns Tests
    
    func testMaxTurnsDefaultValue() {
        XCTAssertEqual(storage.maxTurns, 50, "Max turns should default to 50")
    }
    
    func testMaxTurnsPersistence() {
        let testValue = 100
        storage.maxTurns = testValue
        
        let newStorage = GlobalPreferencesStorage()
        XCTAssertEqual(newStorage.maxTurns, testValue, "Max turns should persist")
    }
    
    // MARK: - System Prompt Tests
    
    func testSystemPromptDefaultValue() {
        XCTAssertEqual(storage.systemPrompt, "", "System prompt should default to empty string")
    }
    
    func testSystemPromptPersistence() {
        let testPrompt = "Test system prompt"
        storage.systemPrompt = testPrompt
        
        let newStorage = GlobalPreferencesStorage()
        XCTAssertEqual(newStorage.systemPrompt, testPrompt, "System prompt should persist")
    }
    
    // MARK: - Append System Prompt Tests
    
    func testAppendSystemPromptDefaultValue() {
        XCTAssertEqual(storage.appendSystemPrompt, "", "Append system prompt should default to empty string")
    }
    
    func testAppendSystemPromptPersistence() {
        let testPrompt = "Test append prompt"
        storage.appendSystemPrompt = testPrompt
        
        let newStorage = GlobalPreferencesStorage()
        XCTAssertEqual(newStorage.appendSystemPrompt, testPrompt, "Append system prompt should persist")
    }
    
    // MARK: - Allowed Tools Tests
    
    func testAllowedToolsDefaultValue() {
        let expectedTools = ["Bash", "LS", "Read", "WebFetch", "Batch", "TodoRead/Write", "Glob", "Grep", "Edit", "MultiEdit", "Write", "NotebookRead", "NotebookEdit", "WebSearch", "Task"]
        XCTAssertEqual(storage.allowedTools, expectedTools, "Allowed tools should have correct defaults")
    }
    
    func testAllowedToolsPersistence() {
        let testTools = ["Tool1", "Tool2", "Tool3"]
        storage.allowedTools = testTools
        
        let newStorage = GlobalPreferencesStorage()
        XCTAssertEqual(newStorage.allowedTools, testTools, "Allowed tools should persist")
    }
    
    // MARK: - MCP Config Path Tests
    
    func testMcpConfigPathDefaultValue() {
        XCTAssertEqual(storage.mcpConfigPath, "", "MCP config path should default to empty string")
    }
    
    func testMcpConfigPathPersistence() {
        let testPath = "/test/path/to/config.json"
        storage.mcpConfigPath = testPath
        
        let newStorage = GlobalPreferencesStorage()
        XCTAssertEqual(newStorage.mcpConfigPath, testPath, "MCP config path should persist")
    }
    
    func testSetMcpConfigPathProtocolMethod() {
        let testPath = "/test/protocol/path.json"
        storage.setMcpConfigPath(testPath)
        XCTAssertEqual(storage.mcpConfigPath, testPath, "setMcpConfigPath should update the property")
    }
    
    // MARK: - Reset Tests
    
    func testResetToDefaults() {
        // Set custom values
        storage.maxTurns = 100
        storage.systemPrompt = "Custom prompt"
        storage.appendSystemPrompt = "Custom append"
        storage.allowedTools = ["CustomTool"]
        storage.mcpConfigPath = "/custom/path"
        
        // Reset
        storage.resetToDefaults()
        
        // Verify all values are back to defaults
        XCTAssertEqual(storage.maxTurns, 50)
        XCTAssertEqual(storage.systemPrompt, "")
        XCTAssertEqual(storage.appendSystemPrompt, "")
        XCTAssertEqual(storage.allowedTools, ["Bash", "LS", "Read", "WebFetch", "Batch", "TodoRead/Write", "Glob", "Grep", "Edit", "MultiEdit", "Write", "NotebookRead", "NotebookEdit", "WebSearch", "Task"])
        XCTAssertEqual(storage.mcpConfigPath, "")
    }
}
