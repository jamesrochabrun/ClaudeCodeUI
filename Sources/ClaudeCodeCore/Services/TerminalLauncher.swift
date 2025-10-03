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
    - First: Investigate thoroughly (read configs, check paths, test commands)
    - Then: Create a PLAN with 3-5 concrete, numbered steps
    - Wait: Get user approval before executing (you're in plan mode)
    - Execute: One step at a time, explain what each does
    - Test: After each fix, ask user to restart the app and test
    - Iterate: If still broken, ask for new debug report and continue

    CRITICAL: When this session starts, immediately greet the user and begin your investigation.
    Don't wait for user input - start by analyzing the debug report and running diagnostic commands.

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
}
