//
//  DisallowedToolsExample.swift
//  ClaudeCodeUI
//
//  Created on 1/24/25.
//
//  This example demonstrates how to configure disallowed tools
//  in the ClaudeCode SDK to prevent Claude from using specific tools.
//

import Foundation
import ClaudeCodeSDK
import ClaudeCodeCore

// MARK: - Example 1: Configure disallowed tools through ClaudeCodeConfiguration

func configureDisallowedToolsViaConfiguration() {
  // Create a configuration with disallowed tools
  let config = ClaudeCodeConfiguration(
    command: "claude",
    workingDirectory: nil,
    environment: [:],
    enableDebugLogging: false,
    additionalPaths: [],
    commandSuffix: nil,
    disallowedTools: ["Bash", "Write", "Edit", "MultiEdit"]  // These tools will be disallowed
  )

  // Initialize the client with this configuration
  let client = ClaudeCodeClient(configuration: config)

  // When the client runs commands, it will pass --disallowedTools flag
  // with the specified tools, preventing Claude from using them
  print("Configured client with disallowed tools: \(config.disallowedTools ?? [])")
}

// MARK: - Example 2: Configure disallowed tools through GlobalPreferencesStorage

@MainActor
func configureDisallowedToolsViaPreferences() {
  // Initialize global preferences
  let globalPrefs = GlobalPreferencesStorage()

  // Set disallowed tools - these will be persisted
  globalPrefs.disallowedTools = ["Bash", "KillShell", "SlashCommand"]

  print("Set disallowed tools in preferences: \(globalPrefs.disallowedTools)")

  // These preferences will be automatically used when ChatViewModel
  // creates options for sending messages to Claude
}

// MARK: - Example 3: Programmatically configure disallowed tools in ClaudeCodeOptions

func configureDisallowedToolsInOptions() {
  // Create options for a Claude Code session
  var options = ClaudeCodeOptions()

  // Configure disallowed tools
  options.disallowedTools = ["Write", "Edit", "MultiEdit", "NotebookEdit"]

  // Configure allowed tools (if needed)
  options.allowedTools = ["Read", "Grep", "Glob", "WebSearch"]

  // When these options are passed to the client, Claude will be restricted
  // from using the disallowed tools
  print("Options configured with disallowed tools: \(options.disallowedTools ?? [])")

  // The options will generate command line arguments like:
  // --disallowedTools "Write,Edit,MultiEdit,NotebookEdit"
  let commandArgs = options.toCommandArgs()
  print("Generated command args: \(commandArgs.joined(separator: " "))")
}

// MARK: - Example 4: Merge configuration and preferences

@MainActor
func mergeDisallowedToolsFromMultipleSources() {
  // Configuration from app initialization
  let config = ClaudeCodeConfiguration(
    disallowedTools: ["Bash", "KillShell"]  // App-level restrictions
  )

  // User preferences
  let globalPrefs = GlobalPreferencesStorage()
  globalPrefs.disallowedTools = ["Write", "Edit"]  // User-defined restrictions

  // When ClaudeCodeContainer initializes, it merges these:
  // The container will combine both sets of disallowed tools
  // Result: ["Bash", "KillShell", "Write", "Edit"]

  print("Config disallowed tools: \(config.disallowedTools ?? [])")
  print("Preferences disallowed tools: \(globalPrefs.disallowedTools)")
}

// MARK: - Use Cases

/*
 Common use cases for disallowing tools:

 1. **Security Restrictions**:
    - Disallow "Bash" to prevent command execution
    - Disallow "Write", "Edit", "MultiEdit" to prevent file modifications
    - Disallow "KillShell" to prevent process termination

 2. **Read-Only Mode**:
    - Only allow read operations: ["Read", "Grep", "Glob", "WebSearch"]
    - Disallow all write operations: ["Write", "Edit", "MultiEdit", "NotebookEdit", "TodoWrite"]

 3. **Limited Functionality**:
    - Disallow web access: ["WebSearch", "WebFetch"]
    - Disallow system commands: ["Bash", "BashOutput", "KillShell", "SlashCommand"]

 4. **Custom Workflows**:
    - Allow only specific tools needed for a particular workflow
    - Disallow everything else to maintain focus
*/