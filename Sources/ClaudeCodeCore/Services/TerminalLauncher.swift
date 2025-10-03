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

  /// Launches Terminal with a Doctor session by executing command and resuming
  /// - Parameters:
  ///   - command: The terminal reproduction command to execute
  ///   - workingDirectory: Working directory for the command
  ///   - systemPrompt: The doctor system prompt
  /// - Returns: An error if launching fails, nil on success
  public static func launchDoctorWithCommand(
    command: String,
    workingDirectory: String,
    systemPrompt: String
  ) async -> Error? {
    // Write system prompt to temp file
    let tempDir = NSTemporaryDirectory()
    let promptPath = (tempDir as NSString).appendingPathComponent("doctor_prompt_\(UUID().uuidString).txt")

    do {
      try systemPrompt.write(toFile: promptPath, atomically: true, encoding: .utf8)
    } catch {
      return NSError(
        domain: "TerminalLauncher",
        code: 3,
        userInfo: [NSLocalizedDescriptionKey: "Failed to write prompt file: \(error.localizedDescription)"]
      )
    }

    // Write the command to a temp file to avoid escaping issues
    let commandPath = (tempDir as NSString).appendingPathComponent("doctor_command_\(UUID().uuidString).sh")

    do {
      try command.write(toFile: commandPath, atomically: true, encoding: .utf8)
    } catch {
      return NSError(
        domain: "TerminalLauncher",
        code: 4,
        userInfo: [NSLocalizedDescriptionKey: "Failed to write command file: \(error.localizedDescription)"]
      )
    }

    // Create launcher script
    let scriptPath = (tempDir as NSString).appendingPathComponent("doctor_launcher_\(UUID().uuidString).command")
    let scriptContent = """
    #!/bin/bash

    echo "Executing command to capture session..."

    # Execute the command from file and capture output
    OUTPUT=$(bash '\(commandPath)' 2>&1)

    # Extract session ID from first line (JSON format)
    SESSION_ID=$(echo "$OUTPUT" | head -1 | grep -o '"session_id":"[^"]*"' | cut -d'"' -f4)

    if [ -n "$SESSION_ID" ]; then
      echo "Session captured: $SESSION_ID"
      echo "Launching Doctor session..."

      # Extract the claude executable path from the command
      CLAUDE_PATH=$(echo "\(escapedCommand)" | grep -o '/[^ ]*claude' | head -1)

      if [ -z "$CLAUDE_PATH" ]; then
        CLAUDE_PATH="claude"
      fi

      # Resume the session with doctor prompt
      "$CLAUDE_PATH" -r "$SESSION_ID" --append-system-prompt "$(cat '\(promptPath)')" --permission-mode plan
    else
      echo "ERROR: Could not extract session ID from command output"
      echo "Output was:"
      echo "$OUTPUT"
      echo ""
      echo "Press Enter to close..."
      read
    fi

    # Clean up
    rm -f "\(promptPath)"
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
        userInfo: [NSLocalizedDescriptionKey: "Failed to launch Doctor session: \(error.localizedDescription)"]
      )
    }
  }

  /// Launches Terminal with a Doctor debugging session (test-first approach)
  /// - Parameters:
  ///   - claudeClient: The Claude client for running test command
  ///   - command: The command name to use
  ///   - workingDirectory: Working directory for the session
  ///   - systemPrompt: The doctor system prompt
  /// - Returns: An error if launching fails, nil on success
  public static func launchDoctorSessionWithTest(
    claudeClient: ClaudeCode,
    command: String,
    workingDirectory: String,
    systemPrompt: String
  ) async -> Error? {
    // Find the full path to the executable
    guard let claudeExecutablePath = findClaudeExecutable(
      command: command,
      additionalPaths: claudeClient.configuration.additionalPaths
    ) else {
      return NSError(
        domain: "TerminalLauncher",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Could not find '\(command)' command. Please ensure it is installed."]
      )
    }

    // Write system prompt to temp file
    let tempDir = NSTemporaryDirectory()
    let promptPath = (tempDir as NSString).appendingPathComponent("doctor_prompt_\(UUID().uuidString).txt")

    do {
      try systemPrompt.write(toFile: promptPath, atomically: true, encoding: .utf8)
    } catch {
      return NSError(
        domain: "TerminalLauncher",
        code: 3,
        userInfo: [NSLocalizedDescriptionKey: "Failed to write prompt file: \(error.localizedDescription)"]
      )
    }

    // Escape paths
    let escapedClaudePath = claudeExecutablePath.replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
    let escapedWorkDir = workingDirectory.replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")

    // Create script that:
    // 1. Runs a test command to start session
    // 2. Extracts session ID
    // 3. Launches Terminal to resume that session
    let scriptPath = (tempDir as NSString).appendingPathComponent("doctor_launcher_\(UUID().uuidString).command")
    let scriptContent = """
    #!/bin/bash
    cd "\(escapedWorkDir)"

    # Start a test session and capture output
    echo "Starting diagnostic session..."
    SESSION_OUTPUT=$("\(escapedClaudePath)" -p "Hello! I need help debugging my environment. Please start by running diagnostic commands." --append-system-prompt "$(cat '\(promptPath)')" --permission-mode plan 2>&1)

    # Extract session ID (Claude outputs session ID in specific format)
    SESSION_ID=$(echo "$SESSION_OUTPUT" | grep -o "session-[a-zA-Z0-9-]*" | head -1)

    # If we got a session ID, resume it interactively
    if [ -n "$SESSION_ID" ]; then
      echo "Resuming session: $SESSION_ID"
      "\(escapedClaudePath)" -r "$SESSION_ID"
    else
      echo "Could not capture session ID. Starting fresh interactive session..."
      "\(escapedClaudePath)" --append-system-prompt "$(cat '\(promptPath)')" --permission-mode plan
    fi

    # Clean up
    rm -f "\(promptPath)"
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
        userInfo: [NSLocalizedDescriptionKey: "Failed to launch Doctor session: \(error.localizedDescription)"]
      )
    }
  }

  /// Launches Terminal with a Doctor debugging session
  /// - Parameters:
  ///   - command: The command name to use (from preferences)
  ///   - additionalPaths: Additional paths from configuration
  ///   - debugReport: The full debug report to analyze
  /// - Returns: An error if launching fails, nil on success
  public static func launchDoctorSession(
    command: String,
    additionalPaths: [String],
    debugReport: String
  ) -> Error? {
    // Find the full path to the executable
    guard let claudeExecutablePath = findClaudeExecutable(
      command: command,
      additionalPaths: additionalPaths
    ) else {
      return NSError(
        domain: "TerminalLauncher",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Could not find '\(command)' command. Please ensure it is installed."]
      )
    }

    // Escape paths for shell
    let escapedClaudePath = claudeExecutablePath.replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")

    // Create doctor system prompt
    let doctorPrompt = """
    You are a ClaudeCodeUI Debug Doctor. A user is experiencing issues with their macOS app that uses Claude Code.

    CONTEXT - DEBUG REPORT:
    \(debugReport)

    YOUR TASK:
    1. Analyze the debug report and investigate the user's environment
    2. Run diagnostic commands to understand the issue:
       - Compare PATH with 'echo $PATH'
       - Check shell config: 'cat ~/.zshrc | head -50'
       - Test executable: 'which \(command)' and '\(command) --version'
       - Check permissions, environment variables, etc.
    3. Identify the root cause of the issue
    4. Propose fixes in priority order (most likely to work first)

    IMPORTANT WORKFLOW:
    - First: Investigate thoroughly WITHOUT creating a plan - just run diagnostic commands directly:
      * echo $PATH
      * which \(command)
      * cat ~/.zshrc | head -50
      * \(command) --version
      * Compare findings with the debug report
    - Then: After investigation is complete, CREATE A PLAN with 3-5 concrete, numbered steps to fix the issue
    - Wait: Get user approval before executing fixes (you're in plan mode)
    - Execute: One fix at a time, explain what each does
    - Test: After each fix, ask user to restart the app and test
    - Iterate: If still broken, ask for new debug report and continue

    CRITICAL: When this session starts, immediately greet the user and START RUNNING DIAGNOSTIC COMMANDS.
    Do NOT create a plan yet - just investigate first. Only create a plan after you understand the problem.

    Be systematic, clear, and explain your reasoning at each step.
    Remember: You're debugging why commands work in Terminal but fail in the macOS app.
    """

    // Write prompt to a temp file
    let tempDir = NSTemporaryDirectory()
    let promptPath = (tempDir as NSString).appendingPathComponent("claude_doctor_prompt_\(UUID().uuidString).txt")
    let scriptPath = (tempDir as NSString).appendingPathComponent("claude_doctor_\(UUID().uuidString).command")

    // Write the prompt to the temp file
    do {
      try doctorPrompt.write(toFile: promptPath, atomically: true, encoding: .utf8)
    } catch {
      return NSError(
        domain: "TerminalLauncher",
        code: 3,
        userInfo: [NSLocalizedDescriptionKey: "Failed to write prompt file: \(error.localizedDescription)"]
      )
    }

    // Construct the doctor command - start interactive session with system prompt from file
    let homeDir = NSHomeDirectory()
    let scriptContent = """
    #!/bin/bash
    cd "\(homeDir)"
    "\(escapedClaudePath)" --append-system-prompt "$(cat '\(promptPath)')" --permission-mode plan
    rm -f "\(promptPath)"
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
        userInfo: [NSLocalizedDescriptionKey: "Failed to launch Doctor session: \(error.localizedDescription)"]
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

    # Execute the command from file and capture output
    OUTPUT=$(bash '\(commandPath)' 2>&1)

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
