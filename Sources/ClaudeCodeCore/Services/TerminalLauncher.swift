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

  /// NEW: Launches Doctor by executing reproduction command (headless), capturing session, then resuming in Terminal
  /// - Parameters:
  ///   - reproductionCommand: The full command from terminalReproductionCommand
  ///   - systemPrompt: The doctor system prompt
  /// - Returns: An error if launching fails, nil on success
  public static func launchDoctorByExecutingCommand(
    reproductionCommand: String,
    systemPrompt: String
  ) async -> Error? {
    // Resolve the claude executable path and extract working directory
    let (preparedCommand, workingDir, resolveError) = prepareCommandWithResolvedClaudePath(reproductionCommand)
    if let err = resolveError {
      return err
    }

    // Launch Terminal with a script that executes command, captures output, and auto-resumes with context
    // This runs everything in Terminal (has TTY) - no headless execution needed
    return launchTerminalWithCaptureAndResume(
      command: preparedCommand,
      workingDir: workingDir,
      originalCommand: reproductionCommand,
      systemPrompt: systemPrompt
    )
  }

  // MARK: - Private helpers for Doctor flow

  /// Launches Terminal with a script that runs command, captures output, and auto-resumes with context
  private static func launchTerminalWithCaptureAndResume(
    command: String,
    workingDir: String?,
    originalCommand: String,
    systemPrompt: String
  ) -> Error? {
    // Extract claude executable path from prepared command for use in resume
    // The command may be like: echo "..." | "/path/to/claude" args...
    let claudePath: String
    if let match = command.range(of: #"\"([^\"]+/claude[^\"]*)\"|\s(/[^\s]+/claude)"#, options: .regularExpression) {
      let matched = String(command[match])
      claudePath = matched.replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespaces)
    } else {
      // Fallback to finding claude executable
      claudePath = findClaudeExecutable(command: "claude", additionalPaths: nil) ?? "claude"
    }

    // Write files to avoid quoting hell
    let tempDir = NSTemporaryDirectory()
    let promptPath = (tempDir as NSString).appendingPathComponent("doctor_prompt_\(UUID().uuidString).txt")
    let originalCmdPath = (tempDir as NSString).appendingPathComponent("doctor_original_cmd_\(UUID().uuidString).txt")

    do {
      try systemPrompt.write(toFile: promptPath, atomically: true, encoding: .utf8)
      try originalCommand.write(toFile: originalCmdPath, atomically: true, encoding: .utf8)
    } catch {
      return NSError(domain: "TerminalLauncher", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to write temp files: \(error.localizedDescription)"])
    }

    // Escape paths for shell
    let escapedPromptPath = promptPath.replacingOccurrences(of: "'", with: "'\\''")
    let escapedOriginalCmdPath = originalCmdPath.replacingOccurrences(of: "'", with: "'\\''")
    let escapedClaudePath = claudePath.replacingOccurrences(of: "'", with: "'\\''")

    // Build cd prefix if needed
    let cdPrefix: String
    if let dir = workingDir, !dir.isEmpty {
      let escapedDir = dir.replacingOccurrences(of: "'", with: "'\\''")
      cdPrefix = "cd '\(escapedDir)'\n"
    } else {
      cdPrefix = ""
    }

    // Build context message content
    let contextHeader = """
    DOCTOR CONTEXT: Previous command execution output for debugging.

    Reproduction Command:
    """

    let contextFooter = """

    Captured Output (stdout + stderr):
    $OUTPUT

    Please analyze this output versus the debug report in your system prompt and propose a plan to fix any issues.
    """

    // Create Terminal script that captures command output and auto-resumes
    let scriptPath = (tempDir as NSString).appendingPathComponent("doctor_\(UUID().uuidString).command")
    let scriptContent = """
    #!/bin/bash -l

    echo "═══════════════════════════════════════"
    echo "ClaudeCodeUI Doctor - Executing Command"
    echo "═══════════════════════════════════════"
    echo ""

    \(cdPrefix)
    # Execute reproduction command and capture all output
    echo "Running: $(cat '\(escapedOriginalCmdPath)')"
    echo ""
    OUTPUT=$(\(command) 2>&1)
    EXIT_CODE=$?

    echo ""
    echo "═══════════════════════════════════════"
    echo "Command Completed (exit code: $EXIT_CODE)"
    echo "═══════════════════════════════════════"
    echo ""

    # Extract session ID from output (first line should be JSON with session_id)
    SESSION_ID=$(echo "$OUTPUT" | head -20 | grep -o '"session_id":"[^"]*"' | head -1 | cut -d'"' -f4)

    if [ -z "$SESSION_ID" ]; then
      echo "❌ ERROR: Could not extract session_id from command output"
      echo ""
      echo "Output preview:"
      echo "$OUTPUT" | head -20
      echo ""
      echo "Press Enter to close..."
      read
      exit 1
    fi

    echo "✅ Captured session: $SESSION_ID"
    echo ""
    echo "═══════════════════════════════════════"
    echo "Launching Doctor Session..."
    echo "═══════════════════════════════════════"
    echo ""

    # Build context message
    {
      echo "\(contextHeader)"
      cat '\(escapedOriginalCmdPath)'
      echo "\(contextFooter)"
    } > /tmp/doctor_context_$$.txt

    # Pipe context into resumed session with doctor prompt
    cat /tmp/doctor_context_$$.txt | '\(escapedClaudePath)' -r "$SESSION_ID" --append-system-prompt "$(cat '\(escapedPromptPath)')" --permission-mode plan

    # Cleanup
    rm -f '\(escapedPromptPath)' '\(escapedOriginalCmdPath)' /tmp/doctor_context_$$.txt
    """

    do {
      try scriptContent.write(toFile: scriptPath, atomically: true, encoding: .utf8)
      let attributes = [FileAttributeKey.posixPermissions: 0o755]
      try FileManager.default.setAttributes(attributes, ofItemAtPath: scriptPath)

      let url = URL(fileURLWithPath: scriptPath)
      NSWorkspace.shared.open(url)

      // Cleanup script after delay
      DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
        try? FileManager.default.removeItem(atPath: scriptPath)
      }

      return nil
    } catch {
      return NSError(domain: "TerminalLauncher", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to launch Terminal: \(error.localizedDescription)"])
    }
  }

  /// Returns a tuple of (preparedCommand, workingDir, error)
  /// Replaces the first occurrence of the claude command with its resolved absolute path,
  /// preserving all quoting and piping. Also extracts the working directory from an initial `cd` if present.
  private static func prepareCommandWithResolvedClaudePath(_ reproductionCommand: String) -> (String, String?, Error?) {
    // Extract working directory if the command starts with: cd "..." && ...
    var workingDir: String?
    var remaining = reproductionCommand

    if reproductionCommand.hasPrefix("cd ") {
      // Expect format: cd "<path>" && <rest>
      // Find the first '&&' separator safely
      if let rangeOfAnd = reproductionCommand.range(of: " && ") {
        let cdPart = String(reproductionCommand[..<rangeOfAnd.lowerBound])
        remaining = String(reproductionCommand[rangeOfAnd.upperBound...])

        // cdPart should be: cd "<path>"
        if let firstQuote = cdPart.firstIndex(of: "\"") {
          let afterFirst = cdPart.index(after: firstQuote)
          if let secondQuote = cdPart[afterFirst...].firstIndex(of: "\"") {
            workingDir = String(cdPart[afterFirst..<secondQuote])
          }
        }
      }
    }

    // At this point, `remaining` is either the original command or the part after the leading cd &&
    // If the command is of the form: echo "..." | <cmd> ..., we must preserve the echo prefix for execution,
    // but identify the CLI token from the part after the pipe.
    var leadingPrefix = ""
    var commandPortion = remaining
    if commandPortion.hasPrefix("echo ") {
      if let pipeRange = commandPortion.range(of: " | ") {
        leadingPrefix = String(commandPortion[..<pipeRange.upperBound]) // includes the trailing pipe+space
        commandPortion = String(commandPortion[pipeRange.upperBound...])
      }
    }

    // Identify the command token (first whitespace-delimited token)
    let trimmed = commandPortion.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let endOfCmd = trimmed.firstIndex(where: { $0.isWhitespace }) ?? trimmed.endIndex as String.Index?, !trimmed.isEmpty else {
      return (reproductionCommand, workingDir, NSError(domain: "TerminalLauncher", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unable to parse command token from reproduction command"]))
    }
    let cmdToken = String(trimmed[..<endOfCmd])

    // Resolve the executable path
    guard let resolvedPath = findClaudeExecutable(command: cmdToken, additionalPaths: nil) else {
      return (reproductionCommand, workingDir, NSError(domain: "TerminalLauncher", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find '\(cmdToken)' command. Please ensure Claude Code CLI is installed or configure its path in preferences. "]))
    }

    // Replace only the first occurrence of cmdToken in the commandPortion
    guard let tokenRangeInPortion = commandPortion.range(of: cmdToken) else {
      return (reproductionCommand, workingDir, NSError(domain: "TerminalLauncher", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to locate command token in reproduction command"]))
    }
    var replacedPortion = commandPortion
    replacedPortion.replaceSubrange(tokenRangeInPortion, with: "\"\(resolvedPath)\"")

    // Rebuild the full command with any leading parts preserved
    let prepared: String
    if reproductionCommand.hasPrefix("cd "), let rangeOfAnd = reproductionCommand.range(of: " && ") {
      let prefix = String(reproductionCommand[..<rangeOfAnd.lowerBound])
      prepared = prefix + " && " + leadingPrefix + replacedPortion
    } else {
      prepared = leadingPrefix + replacedPortion
    }

    return (prepared, workingDir, nil)
  }
}
