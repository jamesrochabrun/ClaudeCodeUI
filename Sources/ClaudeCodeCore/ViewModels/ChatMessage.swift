//
//  ChatMessage.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 5/25/25.
//

import Foundation

/// Represents a single message in the chat conversation
///
/// ChatMessage encapsulates all the information needed to display and manage
/// messages in the chat interface, including tool interactions and streaming states.
public struct ChatMessage: Identifiable, Equatable, Codable {
  /// Unique identifier for the message
  public var id: UUID
  
  /// The role of the message sender (user, assistant, tool, etc.)
  public var role: MessageRole
  
  /// The text content of the message
  public var content: String
  
  /// When the message was created
  public var timestamp: Date
  
  /// Whether the message has finished streaming/processing
  /// - Note: Used primarily for assistant messages during streaming
  public var isComplete: Bool
  
  /// The type of message content (text, tool use, tool result, etc.)
  public var messageType: MessageType
  
  /// Name of the tool if this message is related to tool usage
  /// - Note: Used for tool use, tool result, and tool error messages
  public var toolName: String?
  
  /// Structured data about tool inputs for enhanced UI display
  /// - Note: Only populated for tool use messages to show parameters in collapsible headers
  public var toolInputData: ToolInputData?
  
  /// Whether this message represents an error state
  public var isError: Bool
  
  /// Code selections associated with this message (for user messages)
  public var codeSelections: [TextSelection]?
  
  /// File attachments associated with this message (images, PDFs, etc.)
  public var attachments: [StoredAttachment]?
  
  /// Whether this message was cancelled by the user
  public var wasCancelled: Bool
  
  /// Identifier for grouping related task messages together
  /// - Note: Messages with the same taskGroupId belong to the same Task execution
  public var taskGroupId: UUID?
  
  /// Whether this message is a Task tool that contains other tool executions
  /// - Note: Only true for the initial Task tool message that starts a group
  public var isTaskContainer: Bool

  /// The approval status for plan messages (ExitPlanMode tool)
  /// - Note: Used to track whether a plan has been approved, denied, or approved with auto-accept
  public var planApprovalStatus: PlanApprovalStatus?
  
  public init(
    id: UUID = UUID(),
    role: MessageRole,
    content: String,
    timestamp: Date = Date(),
    isComplete: Bool = true,
    messageType: MessageType = .text,
    toolName: String? = nil,
    toolInputData: ToolInputData? = nil,
    isError: Bool = false,
    codeSelections: [TextSelection]? = nil,
    attachments: [StoredAttachment]? = nil,
    wasCancelled: Bool = false,
    taskGroupId: UUID? = nil,
    isTaskContainer: Bool = false,
    planApprovalStatus: PlanApprovalStatus? = nil
  ) {
    self.id = id
    self.role = role
    self.content = content
    self.timestamp = timestamp
    self.isComplete = isComplete
    self.messageType = messageType
    self.toolName = toolName
    self.toolInputData = toolInputData
    self.isError = isError
    self.codeSelections = codeSelections
    self.attachments = attachments
    self.wasCancelled = wasCancelled
    self.taskGroupId = taskGroupId
    self.isTaskContainer = isTaskContainer
    self.planApprovalStatus = planApprovalStatus
  }
  
  public static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
    return lhs.content == rhs.content &&
    lhs.id == rhs.id &&
    lhs.isComplete == rhs.isComplete &&
    lhs.messageType == rhs.messageType &&
    lhs.toolName == rhs.toolName &&
    lhs.toolInputData == rhs.toolInputData &&
    lhs.isError == rhs.isError &&
    lhs.codeSelections == rhs.codeSelections &&
    lhs.attachments == rhs.attachments &&
    lhs.wasCancelled == rhs.wasCancelled &&
    lhs.taskGroupId == rhs.taskGroupId &&
    lhs.isTaskContainer == rhs.isTaskContainer &&
    lhs.planApprovalStatus == rhs.planApprovalStatus
  }
}

/// Defines the type of content in a message
public enum MessageType: String, Codable {
  /// Regular text message from user or assistant
  case text
  /// Tool invocation message showing tool name and parameters
  case toolUse
  /// Result returned from a tool execution
  case toolResult
  /// Error returned from a failed tool execution
  case toolError
  /// Tool execution denied by user
  case toolDenied
  /// Assistant's internal reasoning/thinking process
  case thinking
  /// Web search results
  case webSearch
  /// Code execution results
  case codeExecution
}

/// Defines who sent the message or what generated it
public enum MessageRole: String, Codable {
  /// Message from the user
  case user
  /// Message from Claude assistant
  case assistant
  /// System-generated message
  case system
  /// Tool invocation indicator
  case toolUse
  /// Tool execution result
  case toolResult
  /// Tool execution error
  case toolError
  /// Tool execution denied by user
  case toolDenied
  /// Assistant's thinking process
  case thinking
}

/// Structured data extracted from tool inputs for enhanced UI display
///
/// ToolInputData serves as a bridge between the raw tool input parameters
/// (which come from Claude's API as complex nested structures) and the UI
/// layer that needs to display them in a user-friendly way.
///
/// Primary purposes:
/// 1. Store simplified key-value pairs extracted from complex DynamicContent
/// 2. Provide smart parameter extraction for collapsible message headers
/// 3. Special handling for complex parameters like todo lists
///
/// Example: For a TodoWrite tool with 5 todos (2 completed), instead of showing
/// the raw JSON, it displays "TodoWrite(2/5 completed)" in the header.
public struct ToolInputData: Equatable, Codable {
  /// Simplified key-value representation of tool parameters
  /// - Note: Complex nested structures are flattened to strings for display
  public let parameters: [String: String]
  
  /// Raw parameter values for tools that need special processing (e.g., Edit tool diffs)
  /// - Note: Stores unformatted values that can be used for specialized visualizations
  public let rawParameters: [String: String]?
  
  public init(parameters: [String: String], rawParameters: [String: String]? = nil) {
    self.parameters = parameters
    self.rawParameters = rawParameters
  }
  
  /// Extracts the most important parameters for display in collapsible headers
  /// - Returns: An array of up to 3 key parameters, with special formatting for todos
  public var keyParameters: [(key: String, value: String)] {
    // Special handling for todos parameter
    if let todosValue = parameters["todos"] {
      // Count completed vs total todos
      var completedCount = 0
      var totalCount = 0
      
      // Parse the todos string to count statuses
      let lines = todosValue.split(separator: "\n")
      for line in lines {
        if line.contains("[✓]") {
          completedCount += 1
          totalCount += 1
        } else if line.contains("[ ]") {
          totalCount += 1
        }
      }
      
      if totalCount > 0 {
        return [(key: "todos", value: "\(completedCount)/\(totalCount) completed")]
      }
    }
    
    // Common parameters to prioritize
    let priorityKeys = ["file_path", "command", "pattern", "query", "path", "url", "name"]
    
    var result: [(key: String, value: String)] = []
    
    // Add priority parameters first
    for key in priorityKeys {
      if let value = parameters[key] {
        result.append((key: key, value: value))
      }
    }
    
    // Add remaining parameters
    for (key, value) in parameters {
      if !priorityKeys.contains(key) && result.count < 3 {
        result.append((key: key, value: value))
      }
    }
    
    return result
  }
}

/// Status of plan approval for ExitPlanMode tool messages
public enum PlanApprovalStatus: String, Codable {
  case approved
  case approvedWithAutoAccept
  case denied
}

/// Simplified attachment data for storage
public struct StoredAttachment: Codable, Equatable, Identifiable {
  public let id: UUID
  public let fileName: String
  public let filePath: String
  public let type: String
  
  public init(id: UUID = UUID(), fileName: String, filePath: String, type: String) {
    self.id = id
    self.fileName = fileName
    self.filePath = filePath
    self.type = type
  }
}
