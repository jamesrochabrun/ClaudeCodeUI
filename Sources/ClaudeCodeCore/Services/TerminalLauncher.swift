//
//  TerminalLauncher.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 12/24/24.
//

import Foundation
import AppKit
import ClaudeCodeSDK

/// Helper object to handle launching Terminal with Claude sessions
public struct TerminalLauncher {
  
  /// Launches Terminal with a Claude session resume command
  /// - Parameters:
  ///   - sessionId: The session ID to resume
  ///   - claudeClient: The Claude client with configuration
  ///   - projectPath: The project path to change to before resuming
  /// - Returns: An error if launching fails, nil on success
  public static func launchTerminalWithSession(
    _ sessionId: String,
    claudeClient: ClaudeCode,
    projectPath: String
  ) -> Error? {
    // Get the claude command from configuration
    let claudeCommand = claudeClient.configuration.command ?? "claude"
    
    // Find the full path to the claude executable
    guard let claudeExecutablePath = findClaudeExecutable(
      command: claudeCommand,
      additionalPaths: claudeClient.configuration.additionalPaths
    ) else {
      return NSError(
        domain: "TerminalLauncher",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Could not find '\(claudeCommand)' command. Please ensure Claude Code CLI is installed."]
      )
    }
    
    // Escape paths for shell
    let escapedPath = projectPath.replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
    let escapedClaudePath = claudeExecutablePath.replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
    let escapedSessionId = sessionId.replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
    
    // Construct the command
    var command = ""
    if !projectPath.isEmpty {
      command = "cd \"\(escapedPath)\" && \"\(escapedClaudePath)\" -r \"\(escapedSessionId)\""
    } else {
      command = "\"\(escapedClaudePath)\" -r \"\(escapedSessionId)\""
    }
    
    // Create a temporary script file
    let tempDir = NSTemporaryDirectory()
    let scriptPath = (tempDir as NSString).appendingPathComponent("claude_resume_\(UUID().uuidString).command")
    
    // Create the script content
    let scriptContent = """
    #!/bin/bash
    \(command)
    """
    
    do {
      // Write the script to file
      try scriptContent.write(toFile: scriptPath, atomically: true, encoding: .utf8)
      
      // Make it executable
      let attributes = [FileAttributeKey.posixPermissions: 0o755]
      try FileManager.default.setAttributes(attributes, ofItemAtPath: scriptPath)
      
      // Open the script with Terminal
      let url = URL(fileURLWithPath: scriptPath)
      NSWorkspace.shared.open(url)
      
      // Clean up the script file after a delay
      DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
        try? FileManager.default.removeItem(atPath: scriptPath)
      }
      
      return nil
    } catch {
      return NSError(
        domain: "TerminalLauncher",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Failed to launch Terminal: \(error.localizedDescription)"]
      )
    }
  }


  /// Finds the full path to the Claude executable
  /// - Parameters:
  ///   - command: The command name to search for (e.g., "claude")
  ///   - additionalPaths: Additional paths to search from configuration
  /// - Returns: The full path to the executable if found, nil otherwise
  public static func findClaudeExecutable(
    command: String,
    additionalPaths: [String]?
  ) -> String? {
    let fileManager = FileManager.default
    let homeDir = NSHomeDirectory()
    
    // Default search paths
    let defaultPaths = [
      "/usr/local/bin",
      "/opt/homebrew/bin",
      "/usr/bin",
      "\(homeDir)/.claude/local",
      "\(homeDir)/.nvm/current/bin",
      "\(homeDir)/.nvm/versions/node/v22.16.0/bin",
      "\(homeDir)/.nvm/versions/node/v20.11.1/bin",
      "\(homeDir)/.nvm/versions/node/v18.19.0/bin"
    ]
    
    // Combine additional paths with default paths
    let allPaths = (additionalPaths ?? []) + defaultPaths
    
    // Search for the command in all paths
    for path in allPaths {
      let fullPath = "\(path)/\(command)"
      if fileManager.fileExists(atPath: fullPath) {
        return fullPath
      }
    }
    
    // Fallback: try using 'which' command
    let task = Process()
    task.launchPath = "/usr/bin/which"
    task.arguments = [command]
    
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = Pipe()
    
    do {
      try task.run()
      task.waitUntilExit()
      
      if task.terminationStatus == 0 {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty {
          return path
        }
      }
    } catch {
      // Ignore errors from which command
    }
    
    return nil
  }

  /// NEW: Launches Doctor by executing reproduction command and resuming session
  /// - Parameters:
  ///   - reproductionCommand: The full command from terminalReproductionCommand
  ///   - systemPrompt: The doctor system prompt
  /// - Returns: An error if launching fails, nil on success
  public static func launchDoctorByExecutingCommand(
    reproductionCommand: String,
    systemPrompt: String
  ) async -> Error? {
    let tempDir = NSTemporaryDirectory()

    // Write the command to a file (avoids all escaping issues)
    let commandPath = (tempDir as NSString).appendingPathComponent("doctor_cmd_\(UUID().uuidString).sh")
    let promptPath = (tempDir as NSString).appendingPathComponent("doctor_prompt_\(UUID().uuidString).txt")
    let scriptPath = (tempDir as NSString).appendingPathComponent("doctor_launch_\(UUID().uuidString).command")

    do {
      try reproductionCommand.write(toFile: commandPath, atomically: true, encoding: .utf8)
      try systemPrompt.write(toFile: promptPath, atomically: true, encoding: .utf8)
    } catch {
      return NSError(
        domain: "TerminalLauncher",
        code: 3,
        userInfo: [NSLocalizedDescriptionKey: "Failed to write files: \(error.localizedDescription)"]
      )
    }

    // Create the launcher script
    let scriptContent = """
    #!/bin/bash

    echo "Executing command to capture session..."
    echo ""

    # Source shell profile to get proper PATH
    if [ -f ~/.zshrc ]; then
      source ~/.zshrc
    elif [ -f ~/.bash_profile ]; then
      source ~/.bash_profile
    elif [ -f ~/.bashrc ]; then
      source ~/.bashrc
    fi

    # Execute the command from file and capture output (source it to keep environment)
    OUTPUT=$(source '\(commandPath)' 2>&1)

    # Extract session ID from first line (JSON format)
    SESSION_ID=$(echo "$OUTPUT" | head -1 | grep -o '"session_id":"[^"]*"' | cut -d'"' -f4)

    if [ -n "$SESSION_ID" ]; then
      echo "Session captured: $SESSION_ID"
      echo "Launching Doctor session..."
      echo ""

      # Extract claude path from the command file
      CLAUDE_PATH=$(grep -o '[^ ]*claude' '\(commandPath)' | grep '^/' | head -1)

      if [ -z "$CLAUDE_PATH" ]; then
        CLAUDE_PATH="claude"
      fi

      # Resume the session with doctor prompt
      "$CLAUDE_PATH" -r "$SESSION_ID" --append-system-prompt "$(cat '\(promptPath)')" --permission-mode plan
    else
      echo "ERROR: Could not extract session ID"
      echo ""
      echo "Command output:"
      echo "$OUTPUT"
      echo ""
      echo "Press Enter to close..."
      read
    fi

    # Clean up
    rm -f '\(commandPath)' '\(promptPath)'
    """

    do {
      try scriptContent.write(toFile: scriptPath, atomically: true, encoding: .utf8)
      let attributes = [FileAttributeKey.posixPermissions: 0o755]
      try FileManager.default.setAttributes(attributes, ofItemAtPath: scriptPath)

      let url = URL(fileURLWithPath: scriptPath)
      NSWorkspace.shared.open(url)

      DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
        try? FileManager.default.removeItem(atPath: scriptPath)
      }

      return nil
    } catch {
      return NSError(
        domain: "TerminalLauncher",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Failed to launch: \(error.localizedDescription)"]
      )
    }
  }
}
