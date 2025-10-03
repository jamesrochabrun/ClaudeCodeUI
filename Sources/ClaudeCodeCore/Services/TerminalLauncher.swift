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
    // Step 1: Prepare execution by resolving the actual claude executable and working directory
    let (preparedCommand, workingDir, resolveError) = prepareCommandWithResolvedClaudePath(reproductionCommand)
    if let err = resolveError {
      return err
    }

    // Step 2: Execute the command headlessly and capture combined output
    let (output, executionError) = executeHeadless(command: preparedCommand)
    if let err = executionError {
      return err
    }

    // Step 3: Extract session_id from the first non-empty line of output
    guard let sessionId = extractSessionId(from: output) else {
      // Include a preview of output for debugging
      let preview = output.split(separator: "\n").prefix(20).joined(separator: "\n")
      return NSError(
        domain: "TerminalLauncher",
        code: 4,
        userInfo: [NSLocalizedDescriptionKey: "Could not extract session_id from output. First lines:\n\(preview)"]
      )
    }

    // Step 4: Launch Terminal to resume the session with doctor prompt in plan mode, passing captured output as context
    if let launchError = resumeSessionInTerminal(
      sessionId: sessionId,
      workingDir: workingDir,
      systemPrompt: systemPrompt,
      usePlanMode: true,
      capturedOutput: output,
      originalCommand: reproductionCommand
    ) {
      return launchError
    }

    return nil
  }

  // MARK: - Private helpers for Doctor flow

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

  /// Executes the given command via login shell, capturing stdout and stderr together
  private static func executeHeadless(command: String) -> (String, Error?) {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/zsh")
    // -l for login shell, -c to run the command; set -o pipefail to better surface errors
    task.arguments = ["-lc", "set -o pipefail; \(command)"]
    task.environment = ProcessInfo.processInfo.environment

    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe

    do {
      try task.run()
    } catch {
      return ("", NSError(domain: "TerminalLauncher", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to start process: \(error.localizedDescription)"]))
    }

    task.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""

    // If process failed, still return output but include error
    if task.terminationStatus != 0 {
      return (output, NSError(domain: "TerminalLauncher", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Command exited with status \(task.terminationStatus). Output:\n\(output)"]))
    }

    return (output, nil)
  }

  /// Parses the first non-empty line as JSON and extracts session_id; falls back to regex
  private static func extractSessionId(from output: String) -> String? {
    // First non-empty line
    guard let firstLine = output.split(separator: "\n", omittingEmptySubsequences: true).first else { return nil }

    // Try JSON decode
    if let data = String(firstLine).data(using: .utf8) {
      if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
         let sessionId = json["session_id"] as? String, !sessionId.isEmpty {
        return sessionId
      }
    }

    // Fallback regex search in the entire output
    let pattern = #"\"session_id\"\s*:\s*\"([^\"]+)\""#
    if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
      let range = NSRange(location: 0, length: (output as NSString).length)
      if let match = regex.firstMatch(in: output, options: [], range: range), match.numberOfRanges >= 2 {
        let r = match.range(at: 1)
        let sessionId = (output as NSString).substring(with: r)
        if !sessionId.isEmpty { return sessionId }
      }
    }
    return nil
  }

  /// Builds a context message containing the command execution details for the doctor to analyze
  private static func buildDoctorContextMessage(
    originalCommand: String,
    workingDir: String?,
    capturedOutput: String
  ) -> String {
    var lines: [String] = []
    lines.append("DOCTOR CONTEXT: Previous command execution output for debugging.")
    lines.append("")
    if let wd = workingDir, !wd.isEmpty {
      lines.append("Working Directory:")
      lines.append(wd)
      lines.append("")
    }
    lines.append("Reproduction Command:")
    lines.append(originalCommand)
    lines.append("")
    lines.append("Captured Output (stdout + stderr):")
    lines.append(capturedOutput)
    lines.append("")
    lines.append("Please analyze this output versus the debug report in your system prompt and propose a plan to fix any issues.")
    return lines.joined(separator: "\n")
  }

  /// Launches Terminal.app with a small script that resumes the captured session with the doctor prompt and initial context
  private static func resumeSessionInTerminal(
    sessionId: String,
    workingDir: String?,
    systemPrompt: String,
    usePlanMode: Bool,
    capturedOutput: String,
    originalCommand: String
  ) -> Error? {
    // Resolve the claude executable for the resume step
    let claudeCommand = "claude"
    guard let claudeExecutablePath = findClaudeExecutable(command: claudeCommand, additionalPaths: nil) else {
      return NSError(
        domain: "TerminalLauncher",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Could not find 'claude' command for resume. Please ensure CLI is installed."]
      )
    }

    // Escape
    let escapedClaude = claudeExecutablePath.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    let escapedSession = sessionId.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")

    // Build context message with captured output
    let contextMessage = buildDoctorContextMessage(
      originalCommand: originalCommand,
      workingDir: workingDir,
      capturedOutput: capturedOutput
    )

    // Write prompt and context to temp files to avoid huge quoting issues
    let tempDir = NSTemporaryDirectory()
    let promptPath = (tempDir as NSString).appendingPathComponent("doctor_prompt_\(UUID().uuidString).txt")
    let contextPath = (tempDir as NSString).appendingPathComponent("doctor_context_\(UUID().uuidString).txt")
    do {
      try systemPrompt.write(toFile: promptPath, atomically: true, encoding: .utf8)
      try contextMessage.write(toFile: contextPath, atomically: true, encoding: .utf8)
    } catch {
      return NSError(domain: "TerminalLauncher", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to write prompt/context files: \(error.localizedDescription)"])
    }

    let escapedPromptPath = promptPath.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    let escapedContextPath = contextPath.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    let cdPrefix: String = {
      if let dir = workingDir, !dir.isEmpty {
        let escapedDir = dir.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return "cd \"\(escapedDir)\" && "
      }
      return ""
    }()

    let permissionArg = usePlanMode ? " --permission-mode plan" : ""
    // Pipe the context message as first user input to provide execution output to Claude
    let resumeCommand = "\(cdPrefix)cat \"\(escapedContextPath)\" | \"\(escapedClaude)\" -r \"\(escapedSession)\" --append-system-prompt \"$(cat \"\(escapedPromptPath)\")\"\(permissionArg)"

    // Write a small .command script and open it
    let scriptPath = (tempDir as NSString).appendingPathComponent("doctor_launch_\(UUID().uuidString).command")
    let scriptContent = """
    #!/bin/bash -l
    \(resumeCommand)
    """

    do {
      try scriptContent.write(toFile: scriptPath, atomically: true, encoding: .utf8)
      let attributes = [FileAttributeKey.posixPermissions: 0o755]
      try FileManager.default.setAttributes(attributes, ofItemAtPath: scriptPath)

      let url = URL(fileURLWithPath: scriptPath)
      NSWorkspace.shared.open(url)

      // Cleanup temp files later
      DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
        try? FileManager.default.removeItem(atPath: scriptPath)
        try? FileManager.default.removeItem(atPath: promptPath)
        try? FileManager.default.removeItem(atPath: contextPath)
      }
      return nil
    } catch {
      return NSError(domain: "TerminalLauncher", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to launch Terminal: \(error.localizedDescription)"])
    }
  }
}
