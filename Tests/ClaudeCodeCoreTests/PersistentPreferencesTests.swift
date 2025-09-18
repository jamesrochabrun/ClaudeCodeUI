//
//  PersistentPreferencesTests.swift
//  ClaudeCodeUITests
//
//  Created on 1/18/25.
//

import XCTest
@testable import ClaudeCodeCore

@MainActor
final class PersistentPreferencesTests: XCTestCase {

  var manager: PersistentPreferencesManager!

  override func setUp() async throws {
    await super.setUp()
    manager = PersistentPreferencesManager.shared
    // Clean up any existing preferences for testing
    manager.deleteAllPreferences()
  }

  override func tearDown() async throws {
    // Clean up after tests
    manager.deleteAllPreferences()
    await super.tearDown()
  }

  func testSaveAndLoadPreferences() async throws {
    // Create test preferences
    let toolPrefs = ToolPreferencesContainer(
      claudeCode: [
        "Bash": ToolPreference(isAllowed: true),
        "Read": ToolPreference(isAllowed: true),
        "Write": ToolPreference(isAllowed: false)
      ],
      mcpServers: [
        "approval_server": [
          "approval_prompt": ToolPreference(isAllowed: true)
        ]
      ]
    )

    let generalPrefs = GeneralPreferences(
      autoApproveLowRisk: true,
      claudeCommand: "claude-test",
      defaultWorkingDirectory: "/test/path",
      appendSystemPrompt: "Test prompt"
    )

    let preferences = PersistentPreferences(
      toolPreferences: toolPrefs,
      generalPreferences: generalPrefs
    )

    // Save preferences
    manager.savePreferences(preferences)

    // Load preferences
    let loaded = manager.loadPreferences()

    // Verify loaded preferences match saved
    XCTAssertNotNil(loaded)
    XCTAssertEqual(loaded?.generalPreferences.claudeCommand, "claude-test")
    XCTAssertEqual(loaded?.generalPreferences.defaultWorkingDirectory, "/test/path")
    XCTAssertEqual(loaded?.generalPreferences.appendSystemPrompt, "Test prompt")
    XCTAssertEqual(loaded?.generalPreferences.autoApproveLowRisk, true)

    // Verify tool preferences
    XCTAssertEqual(loaded?.toolPreferences.claudeCode["Bash"]?.isAllowed, true)
    XCTAssertEqual(loaded?.toolPreferences.claudeCode["Write"]?.isAllowed, false)
    XCTAssertEqual(loaded?.toolPreferences.mcpServers["approval_server"]?["approval_prompt"]?.isAllowed, true)
  }

  func testPersistenceAcrossReinitialization() async throws {
    // Create and save preferences
    let preferences = PersistentPreferences(
      generalPreferences: GeneralPreferences(
        claudeCommand: "persistent-test",
        defaultWorkingDirectory: "/persistent/test"
      )
    )

    manager.savePreferences(preferences)

    // Create a new manager instance (simulating app restart)
    let newManager = PersistentPreferencesManager()

    // Load preferences with new manager
    let loaded = newManager.loadPreferences()

    // Verify persistence
    XCTAssertNotNil(loaded)
    XCTAssertEqual(loaded?.generalPreferences.claudeCommand, "persistent-test")
    XCTAssertEqual(loaded?.generalPreferences.defaultWorkingDirectory, "/persistent/test")
  }

  func testToolReconciliation() async throws {
    let reconciler = PreferencesReconciler()

    // Create stored preferences with old tools
    let storedToolPrefs = ToolPreferencesContainer(
      claudeCode: [
        "Read": ToolPreference(isAllowed: true),
        "Write": ToolPreference(isAllowed: false),
        "OldTool": ToolPreference(isAllowed: true) // Will be missing in discovery
      ]
    )

    let stored = PersistentPreferences(
      toolPreferences: storedToolPrefs,
      generalPreferences: GeneralPreferences()
    )

    // Simulate discovered tools (with new tool and without OldTool)
    let discovered = DiscoveredTools(
      claudeCodeTools: ["Read", "Write", "Bash", "NewTool"], // NewTool added, OldTool missing
      mcpServerTools: [:]
    )

    // Reconcile
    let reconciled = reconciler.reconcile(
      discoveredTools: discovered,
      storedPreferences: stored
    )

    // Verify reconciliation results
    // Existing tools keep their preferences
    XCTAssertEqual(reconciled.toolPreferences.claudeCode["Read"]?.isAllowed, true)
    XCTAssertEqual(reconciled.toolPreferences.claudeCode["Write"]?.isAllowed, false)

    // New tools default to appropriate values
    XCTAssertNotNil(reconciled.toolPreferences.claudeCode["NewTool"])
    XCTAssertEqual(reconciled.toolPreferences.claudeCode["Bash"]?.isAllowed, false) // Bash is risky

    // Missing tools are kept but not marked as seen recently
    XCTAssertNotNil(reconciled.toolPreferences.claudeCode["OldTool"])
    XCTAssertEqual(reconciled.toolPreferences.claudeCode["OldTool"]?.isAllowed, true)
  }
}