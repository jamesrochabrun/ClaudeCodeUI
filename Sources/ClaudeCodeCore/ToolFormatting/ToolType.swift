//
//  ToolType.swift
//  ClaudeCodeUI
//
//  Created on 1/9/2025.
//

import SwiftUI

/// Protocol defining the structure and behavior of all tools in the system
public protocol ToolType {
  /// Unique identifier for the tool
  var identifier: String { get }
  
  /// Human-readable name for display
  var friendlyName: String { get }
  
  /// SF Symbol name for the tool icon
  var icon: String { get }
  
  /// Whether this tool executes terminal commands
  var isTerminalTool: Bool { get }
  
  /// Whether this tool modifies files
  var isEditTool: Bool { get }
  
  /// The formatting style to use for this tool's output
  var formatType: ToolFormatType { get }
  
  /// Whether this tool requires user approval
  var requiresApproval: Bool { get }
  
  /// Priority parameters to display in headers (order matters)
  var priorityParameters: [String] { get }
}

/// Defines how a tool's output should be formatted
public enum ToolFormatType {
  case plainText
  case code(language: String?)
  case json
  case markdown
  case shell
  case diff
  case todos
  case webContent
  case searchResults
  case fileSystem
}

/// Standard tools available in Claude Code
public enum ClaudeCodeTool: String, ToolType, CaseIterable {
  case task = "Task"
  case bash = "Bash"
  case glob = "Glob"
  case grep = "Grep"
  case ls = "LS"
  case exitPlanMode = "exit_plan_mode"
  case read = "Read"
  case edit = "Edit"
  case multiEdit = "MultiEdit"
  case write = "Write"
  case notebookRead = "NotebookRead"
  case notebookEdit = "NotebookEdit"
  case webFetch = "WebFetch"
  case todoWrite = "TodoWrite"
  case webSearch = "WebSearch"
  
  public var identifier: String { rawValue }
  
  public var friendlyName: String {
    switch self {
    case .task: return "Task Runner"
    case .bash: return "Shell Command"
    case .glob: return "File Pattern Search"
    case .grep: return "Content Search"
    case .ls: return "List Directory"
    case .exitPlanMode: return "Exit Plan Mode"
    case .read: return "Read File"
    case .edit: return "Edit File"
    case .multiEdit: return "Multi-Edit File"
    case .write: return "Write File"
    case .notebookRead: return "Read Notebook"
    case .notebookEdit: return "Edit Notebook"
    case .webFetch: return "Fetch Web Content"
    case .todoWrite: return "Todo List"
    case .webSearch: return "Web Search"
    }
  }
  
  public var icon: String {
    switch self {
    case .task: return "play.circle"
    case .bash: return "terminal"
    case .glob: return "doc.text.magnifyingglass"
    case .grep: return "magnifyingglass"
    case .ls: return "folder"
    case .exitPlanMode: return "checkmark.circle"
    case .read: return "doc.text"
    case .edit: return "pencil"
    case .multiEdit: return "pencil.and.list.clipboard"
    case .write: return "square.and.pencil"
    case .notebookRead: return "book"
    case .notebookEdit: return "book.and.wrench"
    case .webFetch: return "globe"
    case .todoWrite: return "checklist"
    case .webSearch: return "magnifyingglass.circle"
    }
  }
  
  public var isTerminalTool: Bool {
    switch self {
    case .bash: return true
    default: return false
    }
  }
  
  public var isEditTool: Bool {
    switch self {
    case .edit, .multiEdit, .write, .notebookEdit: return true
    default: return false
    }
  }
  
  public var formatType: ToolFormatType {
    switch self {
    case .bash: return .shell
    case .edit, .multiEdit: return .diff
    case .read, .write: return .code(language: nil)
    case .notebookRead, .notebookEdit: return .code(language: "python")
    case .grep, .glob, .ls: return .searchResults
    case .webFetch, .webSearch: return .webContent
    case .todoWrite: return .todos
    case .task: return .markdown
    case .exitPlanMode: return .plainText
    }
  }
  
  public var requiresApproval: Bool {
    switch self {
    case .bash, .write, .edit, .multiEdit, .notebookEdit: return true
    default: return false
    }
  }
  
  public var priorityParameters: [String] {
    switch self {
    case .bash: return ["command", "timeout"]
    case .glob: return ["pattern", "path"]
    case .grep: return ["pattern", "path", "include"]
    case .ls: return ["path", "ignore"]
    case .read: return ["file_path", "offset", "limit"]
    case .edit: return ["file_path", "old_string", "new_string"]
    case .multiEdit: return ["file_path", "edits"]
    case .write: return ["file_path", "content"]
    case .notebookRead: return ["notebook_path", "cell_id"]
    case .notebookEdit: return ["notebook_path", "cell_id", "new_source"]
    case .webFetch: return ["url", "prompt"]
    case .todoWrite: return ["todos"]
    case .webSearch: return ["query", "allowed_domains", "blocked_domains"]
    case .task: return ["description", "prompt"]
    case .exitPlanMode: return ["plan"]
    }
  }
}

/// MCP (Model Context Protocol) tools
public struct MCPTool: ToolType {
  public let identifier: String
  public let friendlyName: String
  public let icon: String
  public let isTerminalTool: Bool
  public let isEditTool: Bool
  public let formatType: ToolFormatType
  public let requiresApproval: Bool
  public let priorityParameters: [String]
  
  public init(
    identifier: String,
    friendlyName: String? = nil,
    icon: String = "wrench.and.screwdriver",
    isTerminalTool: Bool = false,
    isEditTool: Bool = false,
    formatType: ToolFormatType = .plainText,
    requiresApproval: Bool = false,
    priorityParameters: [String] = []
  ) {
    self.identifier = identifier
    self.friendlyName = friendlyName ?? identifier.replacingOccurrences(of: "_", with: " ").capitalized
    self.icon = icon
    self.isTerminalTool = isTerminalTool
    self.isEditTool = isEditTool
    self.formatType = formatType
    self.requiresApproval = requiresApproval
    self.priorityParameters = priorityParameters
  }
}

/// Registry for managing all available tools
@MainActor
public final class ToolRegistry {
  public static let shared = ToolRegistry()
  
  private var tools: [String: ToolType] = [:]
  
  private init() {
    // Register all standard tools
    for tool in ClaudeCodeTool.allCases {
      register(tool)
    }
  }
  
  /// Register a tool in the registry
  public func register(_ tool: ToolType) {
    tools[tool.identifier] = tool
  }
  
  /// Get a tool by its identifier
  public func tool(for identifier: String) -> ToolType? {
    // First check if it's a registered tool
    if let tool = tools[identifier] {
      return tool
    }
    
    // Try to match standard tools (case-insensitive)
    if let standardTool = ClaudeCodeTool.allCases.first(where: {
      $0.identifier.lowercased() == identifier.lowercased()
    }) {
      return standardTool
    }
    
    // If not found, create a generic MCP tool
    return MCPTool(identifier: identifier)
  }
  
  /// Get all registered tools
  public func allTools() -> [ToolType] {
    Array(tools.values)
  }
  
  /// Check if a tool is registered
  public func isRegistered(_ identifier: String) -> Bool {
    tools[identifier] != nil
  }
}
