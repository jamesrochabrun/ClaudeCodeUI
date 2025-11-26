//
//  CommandParser.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 2025-11-05.
//

import Foundation

// MARK: - Command Frontmatter
struct CommandFrontmatter {
  var description: String?
  var argumentHint: String?
  var allowedTools: [String]?
  var model: String?
  var disableModelInvocation: Bool = false
}

// MARK: - Command Parser
public enum CommandParser {

  /// Parse a markdown file and extract command information
  /// - Parameters:
  ///   - filePath: The full path to the markdown file
  ///   - scope: The command scope (user or project)
  /// - Returns: A SlashCommand object or nil if parsing fails
  public static func parse(filePath: String, scope: CommandScope) -> SlashCommand? {
    // Extract command name from file path
    let url = URL(fileURLWithPath: filePath)
    let fileName = url.deletingPathExtension().lastPathComponent

    // Extract namespace from directory structure
    let namespace = extractNamespace(from: filePath, scope: scope)

    // Read file contents
    guard let contents = try? String(contentsOfFile: filePath, encoding: .utf8) else {
      return nil
    }

    // Parse frontmatter and content
    let (frontmatter, _) = parseFrontmatter(from: contents)

    return SlashCommand(
      name: fileName,
      filePath: filePath,
      description: frontmatter.description,
      scope: scope,
      namespace: namespace,
      argumentHint: frontmatter.argumentHint,
      allowedTools: frontmatter.allowedTools,
      model: frontmatter.model,
      disableModelInvocation: frontmatter.disableModelInvocation
    )
  }

  // MARK: - Private Helpers

  /// Extract namespace from the file path
  private static func extractNamespace(from filePath: String, scope: CommandScope) -> String? {
    let commandsDir = scope == .user ? "/.claude/commands/" : "/.claude/commands/"

    // Split path by commands directory
    guard let commandsRange = filePath.range(of: commandsDir) else {
      return nil
    }

    let afterCommands = filePath[commandsRange.upperBound...]
    let components = afterCommands.components(separatedBy: "/")

    // If there are subdirectories before the file, join them as namespace
    if components.count > 1 {
      let namespaceComponents = components.dropLast()
      let namespace = namespaceComponents.joined(separator: "/")
      return namespace.isEmpty ? nil : namespace
    }

    return nil
  }

  /// Parse YAML frontmatter from markdown content
  private static func parseFrontmatter(from content: String) -> (CommandFrontmatter, String) {
    var frontmatter = CommandFrontmatter()
    var contentBody = content

    // Check if content starts with frontmatter delimiter
    let lines = content.components(separatedBy: .newlines)
    guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
      // No frontmatter, use first non-empty line as description
      frontmatter.description = extractFirstLine(from: content)
      return (frontmatter, content)
    }

    // Find the closing delimiter
    var frontmatterLines: [String] = []
    var endIndex = 1
    var foundEnd = false

    for i in 1..<lines.count {
      if lines[i].trimmingCharacters(in: .whitespaces) == "---" {
        endIndex = i
        foundEnd = true
        break
      }
      frontmatterLines.append(lines[i])
    }

    guard foundEnd else {
      // Malformed frontmatter, treat as no frontmatter
      frontmatter.description = extractFirstLine(from: content)
      return (frontmatter, content)
    }

    // Parse frontmatter fields
    for line in frontmatterLines {
      parseFrontmatterLine(line, into: &frontmatter)
    }

    // Extract content body (everything after the closing ---)
    if endIndex + 1 < lines.count {
      let bodyLines = Array(lines[(endIndex + 1)...])
      contentBody = bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

      // If no description in frontmatter, use first line of content
      if frontmatter.description == nil {
        frontmatter.description = extractFirstLine(from: contentBody)
      }
    }

    return (frontmatter, contentBody)
  }

  /// Parse a single frontmatter line
  private static func parseFrontmatterLine(_ line: String, into frontmatter: inout CommandFrontmatter) {
    let trimmed = line.trimmingCharacters(in: .whitespaces)

    // Split by first colon
    guard let colonIndex = trimmed.firstIndex(of: ":") else {
      return
    }

    let key = trimmed[..<colonIndex].trimmingCharacters(in: .whitespaces).lowercased()
    let value = trimmed[trimmed.index(after: colonIndex)...].trimmingCharacters(in: .whitespaces)

    switch key {
    case "description":
      frontmatter.description = value.isEmpty ? nil : value

    case "argument-hint":
      frontmatter.argumentHint = value.isEmpty ? nil : value

    case "allowed-tools":
      // Parse array of tools (comma-separated or YAML array format)
      frontmatter.allowedTools = parseArrayValue(value)

    case "model":
      frontmatter.model = value.isEmpty ? nil : value

    case "disable-model-invocation":
      frontmatter.disableModelInvocation = parseBoolValue(value)

    default:
      break
    }
  }

  /// Parse a boolean value from YAML
  private static func parseBoolValue(_ value: String) -> Bool {
    let normalized = value.lowercased()
    return normalized == "true" || normalized == "yes" || normalized == "1"
  }

  /// Parse an array value from YAML (simplified)
  private static func parseArrayValue(_ value: String) -> [String]? {
    if value.isEmpty {
      return nil
    }

    // Handle simple comma-separated format
    if value.contains(",") {
      let items = value.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
      return items.filter { !$0.isEmpty }
    }

    // Handle YAML array format (basic)
    if value.starts(with: "[") && value.hasSuffix("]") {
      let inner = value.dropFirst().dropLast()
      let items = inner.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
      return items.filter { !$0.isEmpty }
    }

    // Single value
    return [value]
  }

  /// Extract first non-empty line from content as description
  private static func extractFirstLine(from content: String) -> String? {
    let lines = content.components(separatedBy: .newlines)
    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if !trimmed.isEmpty && !trimmed.starts(with: "---") {
        // Limit description length
        return String(trimmed.prefix(200))
      }
    }
    return nil
  }
}
