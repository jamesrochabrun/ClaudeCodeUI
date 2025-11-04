//
//  BackendDetector.swift
//  ClaudeCodeUI
//
//  Created by Claude on 2025-11-03.
//

import Foundation
import Security

/// Utility class for detecting Agent SDK requirements
public class BackendDetector {

  /// Check if Node.js is installed
  public static func isNodeInstalled() -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    process.arguments = ["node"]
    process.standardOutput = Pipe()
    process.standardError = Pipe()

    do {
      try process.run()
      process.waitUntilExit()
      return process.terminationStatus == 0
    } catch {
      return false
    }
  }

  /// Get Node.js version if installed
  public static func getNodeVersion() -> String? {
    guard isNodeInstalled() else { return nil }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["node", "--version"]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()

    do {
      try process.run()
      process.waitUntilExit()

      if process.terminationStatus == 0 {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let version = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return version
      }
    } catch {
      return nil
    }

    return nil
  }

  /// Check if Agent SDK package is installed globally
  public static func isAgentSDKInstalled() -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["npm", "list", "-g", "@anthropic-ai/claude-agent-sdk"]
    process.standardOutput = Pipe()
    process.standardError = Pipe()

    do {
      try process.run()
      process.waitUntilExit()
      // npm list returns 0 if package is found
      return process.terminationStatus == 0
    } catch {
      return false
    }
  }

  /// Check if Claude CLI is authenticated (via macOS Keychain)
  public static func isClaudeAuthenticated() -> Bool {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "Claude Safe Storage",
      kSecAttrAccount as String: "Claude Key",
      kSecReturnData as String: false
    ]

    let status = SecItemCopyMatching(query as CFDictionary, nil)
    return status == errSecSuccess
  }

  /// Get setup commands for Agent SDK
  public static func getSetupCommands() -> String {
    return """
    # Install Node.js (if not installed)
    brew install node

    # Install Agent SDK package
    npm install -g @anthropic-ai/claude-agent-sdk

    # Authenticate with Claude (if not already logged in)
    claude login
    """
  }

  /// Check all requirements and return status summary
  public static func checkAllRequirements() -> (node: Bool, agentSDK: Bool, auth: Bool) {
    return (
      node: isNodeInstalled(),
      agentSDK: isAgentSDKInstalled(),
      auth: isClaudeAuthenticated()
    )
  }
}
