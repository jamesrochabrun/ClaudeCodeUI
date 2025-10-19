//
//  ToolDisplayFormatter.swift
//  ClaudeCodeUI
//
//  Created on 1/9/2025.
//

import Foundation
import SwiftUI

/// Main formatter that handles tool request and response formatting
@MainActor
public struct ToolDisplayFormatter {
  
  /// Encapsulates formatted content with metadata
  public struct ToolContentFormatter {
    public let formattedContent: String
    public let toolName: String
    public let toolType: ToolType?
    public let isError: Bool
    public let contentType: ContentType
    
    public enum ContentType {
      case plainText
      case markdown
      case diff
      case todos
      case searchResults
      case error
    }
  }
  
  private let toolRegistry = ToolRegistry.shared
  
  public init() {}
  
  /// Returns the appropriate formatter for a given tool
  private func formatter(for tool: ToolType) -> ToolFormatterProtocol {
    switch ClaudeCodeTool(rawValue: tool.identifier) {
    case .bash:
      return BashToolFormatter()
    case .edit, .multiEdit:
      return EditToolFormatter()
    case .read, .write, .ls:
      return FileToolFormatter()
    case .grep, .glob:
      return SearchFormatter()
    case .webFetch, .webSearch:
      return WebToolFormatter()
    case .todoWrite:
      return TodoFormatter()
    case .notebookRead, .notebookEdit:
      return NotebookToolFormatter()
    case .task:
      return TaskToolFormatter()
    case .exitPlanMode:
      return PlainTextToolFormatter()
    case .askUserQuestion:
      return AskUserQuestionFormatter()
    default:
      // Check format type as fallback
      switch tool.formatType {
      case .json:
        return JSONToolFormatter()
      case .shell:
        return BashToolFormatter()
      case .code:
        return FileToolFormatter()
      case .todos:
        return TodoFormatter()
      case .searchResults:
        return SearchFormatter()
      case .webContent:
        return WebToolFormatter()
      default:
        return PlainTextToolFormatter()
      }
    }
  }
  
  /// Formats tool response after execution
  public func toolResponseMessage(
    toolName: String,
    arguments: String,
    result: String?,
    isError: Bool
  ) -> ToolContentFormatter? {
    
    let tool = toolRegistry.tool(for: toolName)
    
    // Handle errors first
    guard !isError else {
      var errorContent = "❌ Tool \(toolName) failed"
      if let result = result {
        errorContent = """
        ❌ Error in \(toolName):
        \(result.limitToLines(20))
        """
      }
      return ToolContentFormatter(
        formattedContent: errorContent,
        toolName: toolName,
        toolType: tool,
        isError: true,
        contentType: .error
      )
    }
    
    guard let result = result else {
      return nil
    }
    
    // Format based on tool type
    let (content, contentType) = formatToolOutput(tool: tool, result: result)
    
    return ToolContentFormatter(
      formattedContent: content,
      toolName: toolName,
      toolType: tool,
      isError: false,
      contentType: contentType
    )
  }
  
  /// Formats tool request header for display
  public func toolRequestHeader(
    toolName: String,
    arguments: String
  ) -> ToolContentFormatter {
    let tool = toolRegistry.tool(for: toolName)
    var headerText = toolName
    
    // Extract key parameters for header
    if let params = extractKeyParameters(tool: tool, arguments: arguments) {
      headerText += "(\(params))"
    }
    
    return ToolContentFormatter(
      formattedContent: headerText,
      toolName: toolName,
      toolType: tool,
      isError: false,
      contentType: .plainText
    )
  }
  
  /// Formats tool request header for display with ToolInputData
  public func toolRequestHeader(
    toolName: String,
    toolInputData: ToolInputData?
  ) -> ToolContentFormatter {
    // Extract arguments from ToolInputData
    let arguments = extractArguments(from: toolInputData)
    return toolRequestHeader(toolName: toolName, arguments: arguments)
  }
  
  /// Formats tool request message with arguments
  public func toolRequestMessage(
    toolName: String,
    arguments: String
  ) -> ToolContentFormatter? {
    let tool = toolRegistry.tool(for: toolName)
    
    // Format arguments based on tool type
    let formattedArgs = formatToolArguments(tool: tool, arguments: arguments)
    
    // Don't create message for empty arguments
    if formattedArgs.isEmpty || formattedArgs == "{}" || formattedArgs == "[]" {
      return nil
    }
    
    // Wrap in markdown code block
    let markdownArgs = """
  ```json
  \(formattedArgs)
  ```
  """
    
    return ToolContentFormatter(
      formattedContent: markdownArgs,
      toolName: toolName,
      toolType: tool,
      isError: false,
      contentType: .markdown
    )
  }
  
  // MARK: - Private Formatting Methods
  
  private func formatToolOutput(tool: ToolType?, result: String) -> (String, ToolContentFormatter.ContentType) {
    guard let tool = tool else {
      // Unknown tool - use default formatter
      let defaultFormatter = PlainTextToolFormatter()
      return defaultFormatter.formatOutput(result, tool: MCPTool(identifier: "unknown"))
    }
    
    let toolFormatter = formatter(for: tool)
    return toolFormatter.formatOutput(result, tool: tool)
  }
  
  private func formatToolArguments(tool: ToolType?, arguments: String) -> String {
    guard let tool = tool else {
      // Unknown tool - use default formatting
      return arguments.formatJSON()
    }
    
    let toolFormatter = formatter(for: tool)
    return toolFormatter.formatArguments(arguments, tool: tool)
  }
  
  
  private func extractKeyParameters(tool: ToolType?, arguments: String) -> String? {
    guard let tool = tool else {
      return nil
    }
    
    let toolFormatter = formatter(for: tool)
    return toolFormatter.extractKeyParameters(arguments, tool: tool)
  }
  
  /// Extracts arguments as JSON string from ToolInputData
  private func extractArguments(from toolInputData: ToolInputData?) -> String {
    guard let toolInputData = toolInputData else {
      return "{}"
    }
    
    // Convert parameters to JSON
    if let data = try? JSONSerialization.data(withJSONObject: toolInputData.parameters, options: []),
       let json = String(data: data, encoding: .utf8) {
      return json
    }
    
    return "{}"
  }
}
