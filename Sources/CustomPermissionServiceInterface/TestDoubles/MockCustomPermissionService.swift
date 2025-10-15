import Foundation
import Combine
import ClaudeCodeSDK

/// Mock implementation of CustomPermissionService for testing
@MainActor
public final class MockCustomPermissionService: CustomPermissionService {
  public var autoApproveToolCalls: Bool = false {
    didSet {
      autoApproveSubject.send(autoApproveToolCalls)
    }
  }
  
  private let autoApproveSubject = PassthroughSubject<Bool, Never>()
  public var autoApprovePublisher: AnyPublisher<Bool, Never> {
    autoApproveSubject.eraseToAnyPublisher()
  }

  // Callback for conversation pause (matching the protocol requirement)
  public var onConversationShouldPause: ((String, String) -> Void)?

  // Test configuration
  public var shouldApprove: Bool = true
  public var shouldTimeout: Bool = false
  public var shouldThrowError: Bool = false
  public var customResponse: ApprovalResponse?
  public var simulatedDelay: TimeInterval = 0
  
  // Tracking for tests
  public private(set) var requestApprovalCallCount = 0
  public private(set) var lastRequest: ApprovalRequest?
  public private(set) var cancelAllRequestsCallCount = 0
  public private(set) var getApprovalStatusCallCount = 0
  public private(set) var setupMCPToolCallCount = 0
  public private(set) var processMCPToolCallCount = 0

  private var approvalStatuses: [String: ApprovalStatus] = [:]
  private var mcpHandlers: [String: (ApprovalRequest) async throws -> ApprovalResponse] = [:]

  public init() {}

  public func requestApproval(for request: ApprovalRequest) async throws -> ApprovalResponse {
    requestApprovalCallCount += 1
    lastRequest = request
    
    if simulatedDelay > 0 {
      try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
    }
    
    if shouldThrowError {
      throw CustomPermissionError.processingError("Mock error")
    }
    
    if shouldTimeout {
      throw CustomPermissionError.requestTimedOut
    }
    
    if let customResponse = customResponse {
      approvalStatuses[request.toolUseId] = customResponse.behavior == .allow ?
        .approved(customResponse) : .denied(customResponse)
      return customResponse
    }
    
    let response = ApprovalResponse(
      behavior: shouldApprove ? .allow : .deny,
      updatedInput: shouldApprove ? request.inputAsAny : nil,
      message: shouldApprove ? "Mock approval" : "Mock denial"
    )
    
    approvalStatuses[request.toolUseId] = shouldApprove ?
      .approved(response) : .denied(response)
    
    return response
  }
  
  public func cancelAllRequests() {
    cancelAllRequestsCallCount += 1
    
    // Mark all pending requests as cancelled
    for (key, status) in approvalStatuses {
      if case .pending = status {
        approvalStatuses[key] = .cancelled
      }
    }
  }
  
  public func getApprovalStatus(for toolUseId: String) -> ApprovalStatus? {
    getApprovalStatusCallCount += 1
    return approvalStatuses[toolUseId]
  }
  
  public func setupMCPTool(toolName: String, handler: @escaping (ApprovalRequest) async throws -> ApprovalResponse) {
    setupMCPToolCallCount += 1
    mcpHandlers[toolName] = handler
  }
  
  public func processMCPToolCall(_ toolCallData: [String: Any]) async throws -> String {
    processMCPToolCallCount += 1
    
    guard let toolName = toolCallData["tool_name"] as? String,
          let input = toolCallData["input"] as? [String: Any],
          let toolUseId = toolCallData["tool_use_id"] as? String else {
      throw CustomPermissionError.invalidRequest("Missing required fields in tool call data")
    }
    
    let request = ApprovalRequest(toolName: toolName, anyInput: input, toolUseId: toolUseId)
    let response = try await requestApproval(for: request)
    
    // Convert to JSON string as expected by MCP
    let responseDict: [String: Any] = [
      "behavior": response.behavior.rawValue,
      "updatedInput": response.updatedInput ?? input,
      "message": response.message ?? ""
    ]
    
    let jsonData = try JSONSerialization.data(withJSONObject: responseDict)
    return String(data: jsonData, encoding: .utf8) ?? "{}"
  }
  
  // Test helper methods
  public func reset() {
    requestApprovalCallCount = 0
    lastRequest = nil
    cancelAllRequestsCallCount = 0
    getApprovalStatusCallCount = 0
    setupMCPToolCallCount = 0
    processMCPToolCallCount = 0

    shouldApprove = true
    shouldTimeout = false
    shouldThrowError = false
    customResponse = nil
    simulatedDelay = 0
    autoApproveToolCalls = false

    approvalStatuses.removeAll()
    mcpHandlers.removeAll()
  }
  
  public func setApprovalStatus(for toolUseId: String, status: ApprovalStatus) {
    approvalStatuses[toolUseId] = status
  }
}
