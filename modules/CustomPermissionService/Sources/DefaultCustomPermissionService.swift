import ClaudeCodeSDK
import Combine
import CustomPermissionServiceInterface
import Foundation
import SwiftUI

// MARK: - DefaultCustomPermissionService

/// Default implementation of CustomPermissionService
@MainActor
public final class DefaultCustomPermissionService: CustomPermissionService, ObservableObject {
  
  // MARK: Lifecycle
  
  public init(configuration: PermissionConfiguration = .default) {
    self.configuration = configuration
    // Default to false for auto-approval to ensure UI shows
    autoApproveToolCalls = UserDefaults.standard.object(forKey: "AutoApproveToolCalls") as? Bool ?? false
  }
  
  // MARK: Public
  
  // Toast UI state management
  @Published public var currentToastRequest: ApprovalRequest?
  @Published public var isToastVisible = false
  
  @Published public var autoApproveToolCalls = false {
    didSet {
      // Persist the setting
      UserDefaults.standard.set(autoApproveToolCalls, forKey: "AutoApproveToolCalls")
    }
  }
  
  public var autoApprovePublisher: AnyPublisher<Bool, Never> {
    $autoApproveToolCalls.eraseToAnyPublisher()
  }
  
  public func requestApproval(for request: ApprovalRequest, timeout: TimeInterval = 240) async throws -> ApprovalResponse {
    // Check if auto-approval is enabled
    if autoApproveToolCalls {
      return ApprovalResponse(
        behavior: .allow,
        updatedInput: request.inputAsAny,
        message: "Auto-approved"
      )
    }
    
    // Check if auto-approval is enabled for low-risk operations
    if
      configuration.autoApproveLowRisk,
      let context = request.context,
      context.riskLevel == .low
    {
      return ApprovalResponse(
        behavior: .allow,
        updatedInput: request.inputAsAny,
        message: "Auto-approved (low risk)"
      )
    }
    
    // Check concurrent request limit
    guard pendingRequests.count < configuration.maxConcurrentRequests else {
      throw CustomPermissionError.processingError("Too many concurrent permission requests")
    }
    
    return try await withCheckedThrowingContinuation { continuation in
      let pendingRequest = PendingRequest(
        request: request,
        continuation: continuation,
        timeoutTask: Task {
          try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
          await self.handleTimeout(for: request.toolUseId)
        }
      )
      
      pendingRequests[request.toolUseId] = pendingRequest
      
      // Show the approval toast
      Task { @MainActor in
        self.showApprovalToast(for: request)
      }
    }
  }
  
  public func cancelAllRequests() {
    for (toolUseId, pendingRequest) in pendingRequests {
      pendingRequest.timeoutTask.cancel()
      pendingRequest.continuation.resume(throwing: CustomPermissionError.requestCancelled)
    }
    pendingRequests.removeAll()
    
    // Hide any active toast
    hideToast()
  }
  
  public func getApprovalStatus(for toolUseId: String) -> ApprovalStatus? {
    if pendingRequests[toolUseId] != nil {
      return .pending
    }
    return nil
  }
  
  public func setupMCPTool(toolName: String, handler: @escaping (ApprovalRequest) async throws -> ApprovalResponse) {
    mcpHandlers[toolName] = handler
  }
  
  public func processMCPToolCall(_ toolCallData: [String: Any]) async throws -> String {
    print("[CustomPermissionService] Processing MCP tool call with data: \(toolCallData)")
    
    guard
      let toolName = toolCallData["tool_name"] as? String,
      let input = toolCallData["input"] as? [String: Any],
      let toolUseId = toolCallData["tool_use_id"] as? String
    else {
      throw CustomPermissionError.invalidRequest("Missing required fields: tool_name, input, or tool_use_id")
    }
    
    print("[CustomPermissionService] Tool: \(toolName), ID: \(toolUseId)")
    
    // Create context based on tool name and input
    let context = createContextForTool(toolName: toolName, input: input)
    
    let request = ApprovalRequest(
      toolName: toolName,
      anyInput: input,
      toolUseId: toolUseId,
      context: context
    )
    
    let response = try await requestApproval(for: request, timeout: configuration.defaultTimeout)
    
    // Convert to the JSON format expected by Claude Code SDK
    let responseDict: [String: Any] = [
      "behavior": response.behavior.rawValue,
      "updatedInput": response.updatedInputAsAny ?? input,
      "message": response.message ?? "",
    ]
    
    let jsonData = try JSONSerialization.data(withJSONObject: responseDict, options: [])
    return String(data: jsonData, encoding: .utf8) ?? "{}"
  }
  
  public func approveCurrentToast() {
    currentToastCallbacks?.approve()
  }
  
  public func denyCurrentToast() {
    currentToastCallbacks?.deny()
  }
  
  // MARK: Private
  
  private let configuration: PermissionConfiguration
  private var pendingRequests: [String: PendingRequest] = [:]
  private var mcpHandlers: [String: (ApprovalRequest) async throws -> ApprovalResponse] = [:]
  
  private var currentToastCallbacks: (approve: () -> Void, deny: () -> Void)?
  
  // MARK: - Private Methods
  
  @MainActor
  private func showApprovalToast(for request: ApprovalRequest) {
    // Set up toast callbacks
    currentToastCallbacks = (
      approve: { [weak self] in
        Task {
          await self?.handleApproval(for: request.toolUseId, updatedInput: nil)
        }
      },
      deny: { [weak self] in
        Task {
          await self?.handleDenial(for: request.toolUseId, reason: "Denied by user")
        }
      }
    )
    
    // Show the toast
    currentToastRequest = request
    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
      isToastVisible = true
    }
    
    // Auto-hide after 30 seconds if no action taken
    Task {
      try await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
      await MainActor.run {
        if currentToastRequest?.toolUseId == request.toolUseId {
          handleToastTimeout(for: request.toolUseId)
        }
      }
    }
  }
  
  private func hideToast() {
    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
      isToastVisible = false
    }
    
    // Clear after animation completes
    Task {
      try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
      await MainActor.run {
        currentToastRequest = nil
        currentToastCallbacks = nil
      }
    }
  }
  
  private func handleApproval(for toolUseId: String, updatedInput: [String: Any]?) async {
    guard let pendingRequest = pendingRequests.removeValue(forKey: toolUseId) else { return }
    
    pendingRequest.timeoutTask.cancel()
    
    let response = ApprovalResponse(
      behavior: .allow,
      updatedInput: updatedInput ?? pendingRequest.request.inputAsAny,
      message: "Approved by user"
    )
    
    pendingRequest.continuation.resume(returning: response)
    
    // Hide the toast
    await MainActor.run {
      hideToast()
    }
  }
  
  private func handleDenial(for toolUseId: String, reason: String) async {
    guard let pendingRequest = pendingRequests.removeValue(forKey: toolUseId) else { return }
    
    pendingRequest.timeoutTask.cancel()
    
    let response = ApprovalResponse(
      behavior: .deny,
      updatedInput: nil,
      message: reason
    )
    
    pendingRequest.continuation.resume(returning: response)
    
    // Hide the toast
    await MainActor.run {
      hideToast()
    }
  }
  
  private func handleTimeout(for toolUseId: String) async {
    guard let pendingRequest = pendingRequests.removeValue(forKey: toolUseId) else { return }
    
    pendingRequest.continuation.resume(throwing: CustomPermissionError.requestTimedOut)
    
    // Hide the toast
    await MainActor.run {
      hideToast()
    }
  }
  
  private func handleToastTimeout(for toolUseId: String) {
    Task {
      await handleTimeout(for: toolUseId)
    }
  }
  
  private func createContextForTool(toolName: String, input: [String: Any]) -> ApprovalContext {
    // Analyze the tool name and input to determine risk level and context
    let riskLevel: RiskLevel
    let isSensitive: Bool
    let description: String?
    var affectedResources: [String] = []
    
    switch toolName.lowercased() {
    case let name where name.contains("delete") || name.contains("remove"):
      riskLevel = .high
      isSensitive = true
      description = "This operation will delete or remove data"
      
    case let name where name.contains("write") || name.contains("edit") || name.contains("modify"):
      riskLevel = .medium
      isSensitive = false
      description = "This operation will modify files or data"
      
    case let name where name.contains("read") || name.contains("get") || name.contains("list"):
      riskLevel = .low
      isSensitive = false
      description = "This operation will read data without modifications"
      
    case let name where name.contains("bash") || name.contains("shell") || name.contains("exec"):
      riskLevel = .critical
      isSensitive = true
      description = "This operation will execute shell commands"
      
    default:
      riskLevel = .medium
      isSensitive = false
      description = "Tool operation: \(toolName)"
    }
    
    // Extract file paths from input
    for (key, value) in input {
      if key.lowercased().contains("file") || key.lowercased().contains("path") {
        if let stringValue = value as? String {
          affectedResources.append(stringValue)
        } else if let arrayValue = value as? [String] {
          affectedResources.append(contentsOf: arrayValue)
        }
      }
    }
    
    return ApprovalContext(
      description: description,
      riskLevel: riskLevel,
      isSensitive: isSensitive,
      affectedResources: affectedResources
    )
  }
}

// MARK: - PendingRequest

private struct PendingRequest {
  let request: ApprovalRequest
  let continuation: CheckedContinuation<ApprovalResponse, Error>
  let timeoutTask: Task<Void, Error>
}

// MARK: - PromptWindowDelegate

private class PromptWindowDelegate: NSObject, NSWindowDelegate {
  
  // MARK: Lifecycle
  
  init(onClose: @escaping () async -> Void) {
    self.onClose = onClose
  }
  
  // MARK: Internal
  
  func windowShouldClose(_: NSWindow) -> Bool {
    Task {
      await onClose()
    }
    return true
  }
  
  // MARK: Private
  
  private let onClose: () async -> Void
  
}
