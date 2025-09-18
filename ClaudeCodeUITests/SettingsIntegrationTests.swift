//
//  SettingsIntegrationTests.swift
//  ClaudeCodeUITests
//
//  Created on 12/19/24.
//

import XCTest
@testable import ClaudeCodeCore


@MainActor
final class SettingsIntegrationTests: XCTestCase {
    
    var globalPreferences: GlobalPreferencesStorage!
    var settingsStorage: SettingsStorageManager!
    var appearanceSettings: AppearanceSettings!
    
    override func setUp() async throws {
        try await super.setUp()
        // Clear all UserDefaults
        clearAllUserDefaults()
        
        globalPreferences = GlobalPreferencesStorage()
        settingsStorage = SettingsStorageManager()
        appearanceSettings = AppearanceSettings()
    }
    
    override func tearDown() async throws {
        globalPreferences = nil
        settingsStorage = nil
        appearanceSettings = nil
        try await super.tearDown()
    }
    
    private func clearAllUserDefaults() {
        // Clear global preferences
        UserDefaults.standard.removeObject(forKey: "global.maxTurns")
        UserDefaults.standard.removeObject(forKey: "global.systemPrompt")
        UserDefaults.standard.removeObject(forKey: "global.appendSystemPrompt")
        UserDefaults.standard.removeObject(forKey: "global.allowedTools")
        UserDefaults.standard.removeObject(forKey: "global.mcpConfigPath")
        
        // Clear settings storage
        UserDefaults.standard.removeObject(forKey: "projectPath")
        
        // Clear appearance settings
        UserDefaults.standard.removeObject(forKey: "colorScheme")
        UserDefaults.standard.removeObject(forKey: "fontSize")
    }
    
    // MARK: - Cross-Storage Independence Tests
    
    func testStorageIndependence() {
        // Set values in each storage
        globalPreferences.maxTurns = 100
        settingsStorage.setProjectPath("/test/path")
        appearanceSettings.colorScheme = "dark"
        appearanceSettings.fontSize = 16.0
        
        // Create new instances
        let newGlobal = GlobalPreferencesStorage()
        let newSettings = SettingsStorageManager()
        let newAppearance = AppearanceSettings()
        
        // Verify each storage maintains its own values
        XCTAssertEqual(newGlobal.maxTurns, 100)
        XCTAssertEqual(newSettings.projectPath, "/test/path")
        XCTAssertEqual(newAppearance.colorScheme, "dark")
        XCTAssertEqual(newAppearance.fontSize, 16.0)
    }
    
    // MARK: - Full App Settings Scenario Tests
    
    func testTypicalUserWorkflow() {
        // User opens app for first time - verify defaults
        XCTAssertEqual(globalPreferences.maxTurns, 50)
        XCTAssertEqual(appearanceSettings.colorScheme, "system")
        XCTAssertEqual(appearanceSettings.fontSize, 12.0)
        XCTAssertEqual(settingsStorage.projectPath, "")
        
        // User configures global settings
        globalPreferences.maxTurns = 75
        globalPreferences.allowedTools = ["Bash", "Read", "Edit"]
        
        // User sets appearance
        appearanceSettings.colorScheme = "dark"
        appearanceSettings.fontSize = 14.0
        
        // User starts a session with a project
        let projectPath = "/Users/test/MyProject"
        settingsStorage.setProjectPath(projectPath)
        
        // Simulate app restart - create new instances
        let newGlobal = GlobalPreferencesStorage()
        let newAppearance = AppearanceSettings()
        let newSettings = SettingsStorageManager()
        
        // Verify all settings persisted correctly
        XCTAssertEqual(newGlobal.maxTurns, 75)
        XCTAssertEqual(newGlobal.allowedTools, ["Bash", "Read", "Edit"])
        XCTAssertEqual(newAppearance.colorScheme, "dark")
        XCTAssertEqual(newAppearance.fontSize, 14.0)
        XCTAssertEqual(newSettings.projectPath, projectPath)
    }
    
    func testMultipleSessionsWorkflow() {
        let session1 = "project-a-session"
        let session2 = "project-b-session"
        let path1 = "/Users/test/ProjectA"
        let path2 = "/Users/test/ProjectB"
        
        // Configure global settings once
        globalPreferences.systemPrompt = "Be helpful"
        
        // Work on first project
        settingsStorage.setProjectPath(path1)
        settingsStorage.setProjectPath(path1, forSessionId: session1)
        
        // Switch to second project
        settingsStorage.setProjectPath(path2)
        settingsStorage.setProjectPath(path2, forSessionId: session2)
        
        // Verify session-specific paths
        XCTAssertEqual(settingsStorage.getProjectPath(forSessionId: session1), path1)
        XCTAssertEqual(settingsStorage.getProjectPath(forSessionId: session2), path2)
        
        // Verify global settings remain unchanged
        XCTAssertEqual(globalPreferences.systemPrompt, "Be helpful")
    }
    
    // MARK: - MCP Configuration Tests
    
    func testMCPConfigurationWorkflow() {
        let mcpPath = "/Users/test/.config/claude/mcp-config.json"
        
        // Set MCP configuration path
        globalPreferences.setMcpConfigPath(mcpPath)
        XCTAssertEqual(globalPreferences.mcpConfigPath, mcpPath)
        
        // Verify it persists
        let newGlobal = GlobalPreferencesStorage()
        XCTAssertEqual(newGlobal.mcpConfigPath, mcpPath)
        
        // Test clearing MCP path
        newGlobal.mcpConfigPath = ""
        XCTAssertEqual(newGlobal.mcpConfigPath, "")
    }
    
    // MARK: - Reset Functionality Tests
    
    func testGlobalResetDoesNotAffectOtherStorages() {
        // Set values in all storages
        globalPreferences.maxTurns = 100
        settingsStorage.setProjectPath("/test/path")
        appearanceSettings.colorScheme = "dark"
        
        // Reset only global preferences
        globalPreferences.resetToDefaults()
        
        // Verify only global preferences were reset
        XCTAssertEqual(globalPreferences.maxTurns, 50)
        
        // Verify other storages unchanged
        XCTAssertEqual(settingsStorage.projectPath, "/test/path")
        XCTAssertEqual(appearanceSettings.colorScheme, "dark")
    }

}
