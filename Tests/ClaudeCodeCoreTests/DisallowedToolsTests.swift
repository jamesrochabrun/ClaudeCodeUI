//
//  DisallowedToolsTests.swift
//  ClaudeCodeUI
//
//  Created on 1/24/25.
//

import XCTest
@testable import ClaudeCodeCore
import ClaudeCodeSDK

@MainActor
final class DisallowedToolsTests: XCTestCase {

  func testDisallowedToolsPropertyExists() {
    // Test that GlobalPreferencesStorage has disallowedTools property
    let globalPrefs = GlobalPreferencesStorage()
    XCTAssertNotNil(globalPrefs.disallowedTools)
    // Should be empty by default (no tools disallowed initially)
    XCTAssertTrue(globalPrefs.disallowedTools.isEmpty)
  }

  func testDisallowedToolsSavedToPersistence() {
    // Test that disallowedTools can be set and will trigger persistence
    let globalPrefs = GlobalPreferencesStorage()

    // Set some disallowed tools
    globalPrefs.disallowedTools = ["Bash", "Write", "Edit"]

    // Verify they were set
    XCTAssertEqual(globalPrefs.disallowedTools, ["Bash", "Write", "Edit"])
  }

  func testClaudeCodeConfigurationSupportsDisallowedTools() {
    // Test that ClaudeCodeConfiguration can be initialized with disallowedTools
    let config = ClaudeCodeConfiguration(
      command: "claude",
      disallowedTools: ["Bash", "Write"]
    )

    XCTAssertNotNil(config.disallowedTools)
    XCTAssertEqual(config.disallowedTools, ["Bash", "Write"])
  }

  func testClaudeCodeOptionsReceivesDisallowedTools() {
    // Test that ClaudeCodeOptions can be configured with disallowedTools
    var options = ClaudeCodeOptions()
    options.disallowedTools = ["Bash", "Write", "Edit"]

    XCTAssertNotNil(options.disallowedTools)
    XCTAssertEqual(options.disallowedTools, ["Bash", "Write", "Edit"])

    // Test that command args include disallowedTools
    let args = options.toCommandArgs()
    XCTAssertTrue(args.contains("--disallowedTools"))
    XCTAssertTrue(args.contains("\"Bash,Write,Edit\""))
  }
}