//
//  ShellFormatter.swift
//  ClaudeCodeUI
//
//  Created on 1/9/2025.
//

import Foundation

/// Specialized formatter for shell command output
public struct ShellFormatter {
  
  public init() {}
  
  /// Formats shell command for display
  public func formatCommand(_ command: String) -> String {
    // Highlight dangerous commands
    let dangerousCommands = ["rm -rf", "sudo rm", "format", "del /f", "chmod 777"]
    var formattedCommand = command
    
    for dangerous in dangerousCommands {
      if command.lowercased().contains(dangerous) {
        formattedCommand = "⚠️ \(command)"
        break
      }
    }
    
    return formattedCommand
  }
  
  /// Formats shell output with smart truncation and highlighting
  public func formatOutput(_ output: String, command: String? = nil) -> String {
    let cleanOutput = output.formatShellOutput()
    
    // Check for common patterns
    if cleanOutput.isEmpty {
      return "✓ Command completed successfully (no output)"
    }
    
    // Handle errors
    if containsError(cleanOutput) {
      return formatErrorOutput(cleanOutput)
    }
    
    // Format based on command type
    if let cmd = command {
      return formatBasedOnCommand(cmd, output: cleanOutput)
    }
    
    // Default formatting
    return formatDefaultOutput(cleanOutput)
  }
  
  /// Creates a summary of shell output for headers
  public func createOutputSummary(_ output: String) -> String {
    let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
    
    if lines.isEmpty {
      return "no output"
    }
    
    if lines.count == 1 {
      return lines[0].truncateIntelligently(to: 50)
    }
    
    // Check for common patterns
    if output.contains("Successfully") || output.contains("success") {
      return "✓ Success"
    } else if output.contains("Error") || output.contains("failed") {
      return "❌ Error"
    } else if output.contains("Warning") {
      return "⚠️ Warning"
    }
    
    return "\(lines.count) lines"
  }
  
  // MARK: - Private Helpers
  
  private func containsError(_ output: String) -> Bool {
    let errorIndicators = ["error:", "fatal:", "exception:", "failed:", "cannot", "not found", "permission denied"]
    let lowercased = output.lowercased()
    return errorIndicators.contains { lowercased.contains($0) }
  }
  
  private func formatErrorOutput(_ output: String) -> String {
    let lines = output.components(separatedBy: .newlines)
    var errorLines: [String] = []
    
    for line in lines {
      let lowercased = line.lowercased()
      if lowercased.contains("error") || lowercased.contains("fatal") ||
          lowercased.contains("failed") || lowercased.contains("exception") {
        errorLines.append("❌ \(line)")
      } else {
        errorLines.append(line)
      }
    }
    
    return errorLines.joined(separator: "\n").limitToLines(20, maxCharacters: 1000)
  }
  
  private func formatBasedOnCommand(_ command: String, output: String) -> String {
    let cmd = command.lowercased()
    
    // Git commands
    if cmd.starts(with: "git") {
      return formatGitOutput(command: cmd, output: output)
    }
    
    // Package managers
    if cmd.starts(with: "npm") || cmd.starts(with: "yarn") || cmd.starts(with: "pip") {
      return formatPackageManagerOutput(output)
    }
    
    // File system commands
    if cmd.starts(with: "ls") || cmd.starts(with: "dir") || cmd.starts(with: "find") {
      return formatFileListOutput(output)
    }
    
    // Build/test commands
    if cmd.contains("test") || cmd.contains("build") || cmd.contains("compile") {
      return formatBuildOutput(output)
    }
    
    return formatDefaultOutput(output)
  }
  
  private func formatGitOutput(command: String, output: String) -> String {
    // Add icons for git status
    var formatted = output
    
    if command.contains("status") {
      formatted = formatted
        .replacingOccurrences(of: "modified:", with: "📝 modified:")
        .replacingOccurrences(of: "new file:", with: "✨ new file:")
        .replacingOccurrences(of: "deleted:", with: "🗑️ deleted:")
        .replacingOccurrences(of: "renamed:", with: "📛 renamed:")
    }
    
    return formatted.limitToLines(30, maxCharacters: 1500)
  }
  
  private func formatPackageManagerOutput(_ output: String) -> String {
    let lines = output.components(separatedBy: .newlines)
    var formatted: [String] = []
    var packagesInstalled = 0
    
    for line in lines {
      if line.contains("added") && line.contains("packages") {
        packagesInstalled += extractNumber(from: line) ?? 0
      }
      
      // Skip verbose output
      if !line.starts(with: "├─") && !line.starts(with: "└─") && !line.isEmpty {
        formatted.append(line)
      }
    }
    
    if packagesInstalled > 0 {
      formatted.insert("📦 Installed \(packagesInstalled) packages", at: 0)
    }
    
    return formatted.joined(separator: "\n").limitToLines(10, maxCharacters: 500)
  }
  
  private func formatFileListOutput(_ output: String) -> String {
    let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
    
    if lines.count > 20 {
      let truncated = lines.prefix(20).joined(separator: "\n")
      return """
      \(truncated)
      ... and \(lines.count - 20) more files
      """
    }
    
    return output
  }
  
  private func formatBuildOutput(_ output: String) -> String {
    let lines = output.components(separatedBy: .newlines)
    var summary: [String] = []
    var errors = 0
    var warnings = 0
    var testsPass = 0
    var testsFail = 0
    
    for line in lines {
      let lower = line.lowercased()
      
      if lower.contains("error") {
        errors += 1
      } else if lower.contains("warning") {
        warnings += 1
      } else if lower.contains("✓") || lower.contains("pass") {
        testsPass += extractNumber(from: line) ?? 1
      } else if lower.contains("✗") || lower.contains("fail") {
        testsFail += extractNumber(from: line) ?? 1
      }
      
      // Keep important lines
      if lower.contains("success") || lower.contains("complete") ||
          lower.contains("failed") || lower.contains("error") {
        summary.append(line)
      }
    }
    
    // Build summary header
    var header = "Build Summary:\n"
    if errors > 0 {
      header += "❌ \(errors) errors\n"
    }
    if warnings > 0 {
      header += "⚠️ \(warnings) warnings\n"
    }
    if testsPass > 0 || testsFail > 0 {
      header += "🧪 Tests: \(testsPass) passed, \(testsFail) failed\n"
    }
    
    if !summary.isEmpty {
      header += "\n" + summary.joined(separator: "\n")
    }
    
    return header.limitToLines(20, maxCharacters: 1000)
  }
  
  private func formatDefaultOutput(_ output: String) -> String {
    return output.limitToLines(20, maxCharacters: 1000)
  }
  
  private func extractNumber(from string: String) -> Int? {
    let pattern = #"\d+"#
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(in: string, range: NSRange(location: 0, length: string.count)),
          let range = Range(match.range, in: string) else {
      return nil
    }
    
    return Int(string[range])
  }
}
