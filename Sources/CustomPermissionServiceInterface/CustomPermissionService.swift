import Foundation
import Combine
import ClaudeCodeSDK

/// Service interface for handling custom permission prompts
@MainActor
public protocol CustomPermissionService: Sendable {
  /// Current auto-approval setting
  var autoApproveToolCalls: Bool { get set }

  /// Publisher for auto-approval setting changes
  var autoApprovePublisher: AnyPublisher<Bool, Never> { get }

  /// Callback invoked when conversation should pause due to approval timeout
  /// Parameters: (toolUseId, sessionId)
  var onConversationShouldPause: ((String, String) -> Void)? { get set }

  /// Requests approval for a tool use
  /// - Parameters:
  ///   - request: The approval request with tool details
  /// - Returns: The approval response
  func requestApproval(for request: ApprovalRequest) async throws -> ApprovalResponse
  
  /// Cancels all pending approval requests
  func cancelAllRequests()
  
  /// Gets the current approval status for a specific tool use ID
  /// - Parameter toolUseId: The tool use identifier
  /// - Returns: The approval status if available
  func getApprovalStatus(for toolUseId: String) -> ApprovalStatus?
  
  /// Sets up a custom permission prompt tool for MCP integration
  /// - Parameters:
  ///   - toolName: Name of the MCP tool (typically "approval_prompt")
  ///   - handler: The handler function for processing approval requests
  func setupMCPTool(toolName: String, handler: @escaping (ApprovalRequest) async throws -> ApprovalResponse)
  
  /// Processes an MCP tool call for approval
  /// - Parameter toolCallData: Raw tool call data from MCP
  /// - Returns: JSON-encoded approval response
  func processMCPToolCall(_ toolCallData: [String: Any]) async throws -> String
}

/// Status of an approval request
public enum ApprovalStatus: Sendable {
  case pending
  case approved(ApprovalResponse)
  case denied(ApprovalResponse)
  case timedOut
  case cancelled
}

/// Errors that can occur during permission handling
public enum CustomPermissionError: Error, LocalizedError, Sendable {
  case requestTimedOut
  case requestCancelled
  case invalidRequest(String)
  case processingError(String)
  case mcpIntegrationError(String)
  
  public var errorDescription: String? {
    switch self {
    case .requestTimedOut:
      return "The permission request timed out"
    case .requestCancelled:
      return "The permission request was cancelled"
    case .invalidRequest(let details):
      return "Invalid permission request: \(details)"
    case .processingError(let details):
      return "Error processing permission request: \(details)"
    case .mcpIntegrationError(let details):
      return "MCP integration error: \(details)"
    }
  }
  
  public var recoverySuggestion: String? {
    switch self {
    case .requestTimedOut:
      return "Try the request again or increase the timeout duration"
    case .requestCancelled:
      return "Restart the operation if needed"
    case .invalidRequest:
      return "Check the request parameters and try again"
    case .processingError:
      return "Check the application logs for more details"
    case .mcpIntegrationError:
      return "Verify MCP server configuration and connectivity"
    }
  }
}

/// Configuration for permission behavior
public struct PermissionConfiguration: Codable, Sendable {
  /// Whether to auto-approve low-risk operations
  public let autoApproveLowRisk: Bool

  /// Whether to show detailed information in prompts
  public let showDetailedInfo: Bool

  /// Maximum number of concurrent approval requests
  public let maxConcurrentRequests: Int

  /// Timeout threshold for approval toasts (in seconds)
  /// When a toast is visible for longer than this duration, the conversation will be paused
  /// and the toast will remain visible for user response. If nil, no timeout is applied.
  /// Default: 300 seconds (5 minutes)
  public let approvalTimeoutThreshold: TimeInterval?

  public init(
    autoApproveLowRisk: Bool = false,
    showDetailedInfo: Bool = true,
    maxConcurrentRequests: Int = 5,
    approvalTimeoutThreshold: TimeInterval? = 300.0
  ) {
    self.autoApproveLowRisk = autoApproveLowRisk
    self.showDetailedInfo = showDetailedInfo
    self.maxConcurrentRequests = maxConcurrentRequests
    self.approvalTimeoutThreshold = approvalTimeoutThreshold
  }

  public static let `default` = PermissionConfiguration()
}
