//
//  BackwardCompatibilityTests.swift
//  ClaudeCodeUI
//
//  Created on 1/25/25.
//

import XCTest
@testable import ClaudeCodeCore
import Foundation

@MainActor
final class BackwardCompatibilityTests: XCTestCase {

  func testGeneralPreferencesDecodesWithoutDisallowedTools() throws {
    // Simulate old preferences JSON without disallowedTools field
    let oldPreferencesJSON = """
    {
      "autoApproveLowRisk": true,
      "claudeCommand": "claude",
      "claudePath": "/usr/local/bin/claude",
      "defaultWorkingDirectory": "/Users/test",
      "appendSystemPrompt": "Be helpful",
      "systemPrompt": "You are an assistant",
      "showDetailedPermissionInfo": false,
      "permissionRequestTimeout": 7200.0,
      "permissionTimeoutEnabled": true,
      "maxConcurrentPermissionRequests": 10
    }
    """

    let data = oldPreferencesJSON.data(using: .utf8)!
    let decoder = JSONDecoder()

    // This should not throw even though disallowedTools is missing
    let preferences = try decoder.decode(GeneralPreferences.self, from: data)

    // Verify all fields were decoded correctly
    XCTAssertEqual(preferences.autoApproveLowRisk, true)
    XCTAssertEqual(preferences.claudeCommand, "claude")
    XCTAssertEqual(preferences.claudePath, "/usr/local/bin/claude")
    XCTAssertEqual(preferences.defaultWorkingDirectory, "/Users/test")
    XCTAssertEqual(preferences.appendSystemPrompt, "Be helpful")
    XCTAssertEqual(preferences.systemPrompt, "You are an assistant")
    XCTAssertEqual(preferences.showDetailedPermissionInfo, false)
    XCTAssertEqual(preferences.permissionRequestTimeout, 7200.0)
    XCTAssertEqual(preferences.permissionTimeoutEnabled, true)
    XCTAssertEqual(preferences.maxConcurrentPermissionRequests, 10)

    // The missing field should have the default value
    XCTAssertEqual(preferences.disallowedTools, [])
  }

  func testGeneralPreferencesDecodesWithDisallowedTools() throws {
    // New preferences JSON with disallowedTools field
    let newPreferencesJSON = """
    {
      "autoApproveLowRisk": true,
      "claudeCommand": "claude",
      "claudePath": "/usr/local/bin/claude",
      "defaultWorkingDirectory": "/Users/test",
      "appendSystemPrompt": "Be helpful",
      "systemPrompt": "You are an assistant",
      "showDetailedPermissionInfo": false,
      "permissionRequestTimeout": 7200.0,
      "permissionTimeoutEnabled": true,
      "maxConcurrentPermissionRequests": 10,
      "disallowedTools": ["Bash", "Write"]
    }
    """

    let data = newPreferencesJSON.data(using: .utf8)!
    let decoder = JSONDecoder()

    let preferences = try decoder.decode(GeneralPreferences.self, from: data)

    // Verify disallowedTools was decoded correctly
    XCTAssertEqual(preferences.disallowedTools, ["Bash", "Write"])
  }

  func testGeneralPreferencesDecodesWithPartialFields() throws {
    // Minimal preferences JSON with only some fields
    let minimalJSON = """
    {
      "claudeCommand": "custom-claude"
    }
    """

    let data = minimalJSON.data(using: .utf8)!
    let decoder = JSONDecoder()

    let preferences = try decoder.decode(GeneralPreferences.self, from: data)

    // Verify the provided field
    XCTAssertEqual(preferences.claudeCommand, "custom-claude")

    // Verify all other fields have defaults
    XCTAssertEqual(preferences.autoApproveLowRisk, false)
    XCTAssertEqual(preferences.claudePath, "")
    XCTAssertEqual(preferences.defaultWorkingDirectory, "")
    XCTAssertEqual(preferences.appendSystemPrompt, "")
    XCTAssertEqual(preferences.systemPrompt, "")
    XCTAssertEqual(preferences.showDetailedPermissionInfo, true)
    XCTAssertEqual(preferences.permissionRequestTimeout, 3600.0)
    XCTAssertEqual(preferences.permissionTimeoutEnabled, false)
    XCTAssertEqual(preferences.maxConcurrentPermissionRequests, 5)
    XCTAssertEqual(preferences.disallowedTools, [])
  }

  func testGeneralPreferencesDecodesEmptyJSON() throws {
    // Empty JSON object
    let emptyJSON = "{}"

    let data = emptyJSON.data(using: .utf8)!
    let decoder = JSONDecoder()

    let preferences = try decoder.decode(GeneralPreferences.self, from: data)

    // Verify all fields have defaults
    XCTAssertEqual(preferences.autoApproveLowRisk, false)
    XCTAssertEqual(preferences.claudeCommand, "claude")
    XCTAssertEqual(preferences.claudePath, "")
    XCTAssertEqual(preferences.defaultWorkingDirectory, "")
    XCTAssertEqual(preferences.appendSystemPrompt, "")
    XCTAssertEqual(preferences.systemPrompt, "")
    XCTAssertEqual(preferences.showDetailedPermissionInfo, true)
    XCTAssertEqual(preferences.permissionRequestTimeout, 3600.0)
    XCTAssertEqual(preferences.permissionTimeoutEnabled, false)
    XCTAssertEqual(preferences.maxConcurrentPermissionRequests, 5)
    XCTAssertEqual(preferences.disallowedTools, [])
  }

  func testPersistentPreferencesDecodesWithoutFields() throws {
    // Simulate old PersistentPreferences JSON
    let oldPersistentJSON = """
    {
      "version": "1.0",
      "lastUpdated": "2025-01-24T12:00:00Z",
      "toolPreferences": {
        "claudeCode": {},
        "mcpServers": {}
      },
      "generalPreferences": {
        "claudeCommand": "claude",
        "autoApproveLowRisk": true
      }
    }
    """

    let data = oldPersistentJSON.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let persistent = try decoder.decode(PersistentPreferences.self, from: data)

    // Verify it decoded successfully
    XCTAssertEqual(persistent.version, "1.0")
    XCTAssertNotNil(persistent.lastUpdated)
    XCTAssertNotNil(persistent.toolPreferences)
    XCTAssertNotNil(persistent.generalPreferences)

    // Verify generalPreferences has defaults for missing fields including disallowedTools
    XCTAssertEqual(persistent.generalPreferences.disallowedTools, [])
    XCTAssertEqual(persistent.generalPreferences.claudeCommand, "claude")
    XCTAssertEqual(persistent.generalPreferences.autoApproveLowRisk, true)
  }

  func testPersistentPreferencesDecodesWithMinimalJSON() throws {
    // Minimal PersistentPreferences
    let minimalJSON = """
    {}
    """

    let data = minimalJSON.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let persistent = try decoder.decode(PersistentPreferences.self, from: data)

    // Verify all fields have defaults
    XCTAssertEqual(persistent.version, "1.0")
    XCTAssertNotNil(persistent.lastUpdated)
    XCTAssertNotNil(persistent.toolPreferences)
    XCTAssertNotNil(persistent.generalPreferences)
    XCTAssertEqual(persistent.generalPreferences.disallowedTools, [])
  }

  func testRealWorldOldPreferencesFile() throws {
    // This simulates a real preferences file from before the disallowedTools field was added
    let realWorldJSON = """
    {
      "version": "1.0",
      "lastUpdated": "2025-01-20T15:30:45Z",
      "toolPreferences": {
        "claudeCode": {
          "Bash": {"isAllowed": true, "lastSeen": "2025-01-20T15:30:45Z"},
          "Write": {"isAllowed": false, "lastSeen": "2025-01-20T15:30:45Z"},
          "Edit": {"isAllowed": false, "lastSeen": "2025-01-20T15:30:45Z"},
          "Read": {"isAllowed": true, "lastSeen": "2025-01-20T15:30:45Z"}
        },
        "mcpServers": {
          "example-server": {
            "tool1": {"isAllowed": true, "lastSeen": "2025-01-20T15:30:45Z"}
          }
        }
      },
      "generalPreferences": {
        "autoApproveLowRisk": true,
        "claudeCommand": "/opt/homebrew/bin/claude",
        "claudePath": "",
        "defaultWorkingDirectory": "/Users/johndoe/projects",
        "appendSystemPrompt": "Always use Swift 5.9 features",
        "systemPrompt": "You are a Swift expert",
        "showDetailedPermissionInfo": true,
        "permissionRequestTimeout": 3600.0,
        "permissionTimeoutEnabled": false,
        "maxConcurrentPermissionRequests": 5
      }
    }
    """

    let data = realWorldJSON.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    // This should succeed even without disallowedTools
    let persistent = try decoder.decode(PersistentPreferences.self, from: data)

    // Verify all data was preserved
    XCTAssertEqual(persistent.version, "1.0")
    XCTAssertEqual(persistent.generalPreferences.autoApproveLowRisk, true)
    XCTAssertEqual(persistent.generalPreferences.claudeCommand, "/opt/homebrew/bin/claude")
    XCTAssertEqual(persistent.generalPreferences.defaultWorkingDirectory, "/Users/johndoe/projects")
    XCTAssertEqual(persistent.generalPreferences.systemPrompt, "You are a Swift expert")

    // disallowedTools should be empty array by default
    XCTAssertEqual(persistent.generalPreferences.disallowedTools, [])

    // Tool preferences should be intact
    XCTAssertEqual(persistent.toolPreferences.claudeCode["Bash"]?.isAllowed, true)
    XCTAssertEqual(persistent.toolPreferences.claudeCode["Write"]?.isAllowed, false)
    XCTAssertNotNil(persistent.toolPreferences.mcpServers["example-server"])
  }
}