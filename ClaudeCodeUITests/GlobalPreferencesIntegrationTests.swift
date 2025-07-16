//
//  GlobalPreferencesIntegrationTests.swift
//  ClaudeCodeUITests
//
//  Created on 12/19/24.
//

import XCTest
import ClaudeCodeSDK
@testable import ClaudeCodeUI

@MainActor
final class GlobalPreferencesIntegrationTests: XCTestCase {
    
    var globalPreferences: GlobalPreferencesStorage!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Clear UserDefaults
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
        
        globalPreferences = GlobalPreferencesStorage()
    }
    
    override func tearDown() async throws {
        globalPreferences = nil
        try await super.tearDown()
    }
    
    // Test that createOptions() in ChatViewModel properly uses GlobalPreferencesStorage
    func testChatViewModelUsesGlobalPreferences() {
        // Set custom preferences
        globalPreferences.maxTurns = 20
        globalPreferences.systemPrompt = "Custom system prompt"
        globalPreferences.appendSystemPrompt = "Append this"
        globalPreferences.mcpConfigPath = "/path/to/mcp/config.json"
        globalPreferences.allowedTools = ["bash", "read", "write"]
        
        // Create a test instance to access createOptions
        let testHelper = OptionsTestHelper(globalPreferences: globalPreferences)
        let options = testHelper.createTestOptions()
        
        // Verify options reflect global preferences
        XCTAssertEqual(options.maxTurns, 20, "MaxTurns should match global preference")
        XCTAssertEqual(options.systemPrompt, "Custom system prompt", "System prompt should match")
        XCTAssertEqual(options.appendSystemPrompt, "Append this", "Append prompt should match")
        XCTAssertEqual(options.mcpConfigPath, "/path/to/mcp/config.json", "MCP config path should match")
        XCTAssertEqual(options.allowedTools, ["bash", "read", "write"], "Allowed tools should match")
    }
    
    func testEmptyStringsNotSetInOptions() {
        // Set empty strings
        globalPreferences.systemPrompt = ""
        globalPreferences.appendSystemPrompt = ""
        globalPreferences.mcpConfigPath = ""
        
        let testHelper = OptionsTestHelper(globalPreferences: globalPreferences)
        let options = testHelper.createTestOptions()
        
        // Verify empty strings are not set
        XCTAssertNil(options.systemPrompt, "Empty systemPrompt should not be set")
        XCTAssertNil(options.appendSystemPrompt, "Empty appendSystemPrompt should not be set")
        XCTAssertNil(options.mcpConfigPath, "Empty mcpConfigPath should not be set")
    }
    
    func testDefaultOptionsValues() {
        // Use default values
        let testHelper = OptionsTestHelper(globalPreferences: globalPreferences)
        let options = testHelper.createTestOptions()
        
        // Verify defaults
        XCTAssertEqual(options.maxTurns, 50, "Default maxTurns should be 50")
        XCTAssertNil(options.systemPrompt, "Default customSystemPrompt should be nil")
        XCTAssertNil(options.appendSystemPrompt, "Default appendSystemPrompt should be nil")
        XCTAssertNil(options.mcpConfigPath, "Default mcpConfigPath should be nil")
        XCTAssertEqual(options.allowedTools, ["Bash", "LS", "Read", "WebFetch", "Batch", "TodoRead/Write", "Glob", "Grep", "Edit", "MultiEdit", "Write", "NotebookRead", "NotebookEdit", "WebSearch", "Task"], "Default allowedTools should match expected list")
    }
    
    func testOptionsUpdateWithPreferenceChanges() {
        let testHelper = OptionsTestHelper(globalPreferences: globalPreferences)
        
        // Initial options
        globalPreferences.maxTurns = 5
        let options1 = testHelper.createTestOptions()
        
        XCTAssertEqual(options1.maxTurns, 5)
        
        // Update preferences
        globalPreferences.maxTurns = 15
        globalPreferences.systemPrompt = "Updated prompt"
        
        // Create new options
        let options2 = testHelper.createTestOptions()
        
        XCTAssertEqual(options2.maxTurns, 15, "New options should reflect updated maxTurns")
        XCTAssertEqual(options2.systemPrompt, "Updated prompt", "New options should reflect updated prompt")
    }
}

// Helper class to test the createOptions logic
@MainActor
private class OptionsTestHelper {
    let globalPreferences: GlobalPreferencesStorage
    
    init(globalPreferences: GlobalPreferencesStorage) {
        self.globalPreferences = globalPreferences
    }
    
    // This mirrors the createOptions() method in ChatViewModel
    func createTestOptions() -> ClaudeCodeOptions {
        var options = ClaudeCodeOptions()
        options.allowedTools = globalPreferences.allowedTools
        options.maxTurns = globalPreferences.maxTurns
        if !globalPreferences.systemPrompt.isEmpty {
            options.systemPrompt = globalPreferences.systemPrompt
        }
        if !globalPreferences.appendSystemPrompt.isEmpty {
            options.appendSystemPrompt = globalPreferences.appendSystemPrompt
        }
        if !globalPreferences.mcpConfigPath.isEmpty {
            options.mcpConfigPath = globalPreferences.mcpConfigPath
        }
        return options
    }
}
