import ClaudeCodeSDK
import Combine
import CCCustomPermissionServiceInterface
import Foundation
import SwiftUI
import Observation

// MARK: - DefaultCustomPermissionService

/// Default implementation of CustomPermissionService
@MainActor
@Observable
public final class DefaultCustomPermissionService: CustomPermissionService {
  
  // MARK: Lifecycle
  
  public init(configuration: PermissionConfiguration = .default) {
    self.configuration = configuration
    // Default to false for auto-approval to ensure UI shows
    let autoApprove = UserDefaults.standard.object(forKey: "AutoApproveToolCalls") as? Bool ?? false
    self.autoApproveToolCalls = autoApprove
    self.autoApproveSubject.send(autoApprove)
  }
  
  // MARK: Public
  
  // Toast UI state management
  public var currentToastRequest: ApprovalRequest?
  public var isToastVisible = false
  
  // Queue for handling multiple concurrent requests
  public var approvalQueue: [ApprovalRequest] = []
  public var currentProcessingRequest: ApprovalRequest?
  
  // Manual publisher for auto-approve changes since @Observable doesn't provide $-prefixed publishers
  private let autoApproveSubject = CurrentValueSubject<Bool, Never>(false)
  
  public var autoApproveToolCalls = false {
    didSet {
      // Persist the setting
      UserDefaults.standard.set(autoApproveToolCalls, forKey: "AutoApproveToolCalls")
      // Update the manual publisher
      autoApproveSubject.send(autoApproveToolCalls)
    }
  }
  
  public var autoApprovePublisher: AnyPublisher<Bool, Never> {
    autoApproveSubject.eraseToAnyPublisher()
  }
  
  public func requestApproval(for request: ApprovalRequest) async throws -> ApprovalResponse {
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
        continuation: continuation
      )

      pendingRequests[request.toolUseId] = pendingRequest

      // Add to queue and process
      Task { @MainActor in
        self.addToApprovalQueue(request)
      }
    }
  }
  
  public func cancelAllRequests() {
    for (_, pendingRequest) in pendingRequests {
      pendingRequest.continuation.resume(throwing: CustomPermissionError.requestCancelled)
    }
    pendingRequests.removeAll()

    // Clear the queue
    approvalQueue.removeAll()
    currentProcessingRequest = nil

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
    
    let response = try await requestApproval(for: request)
    
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

  public func denyCurrentToastWithGuidance(_ guidance: String) {
    currentToastCallbacks?.denyWithGuidance(guidance)
  }
  
  // MARK: Private
  
  private let configuration: PermissionConfiguration
  private var pendingRequests: [String: PendingRequest] = [:]
  private var mcpHandlers: [String: (ApprovalRequest) async throws -> ApprovalResponse] = [:]
  
  private var currentToastCallbacks: (approve: () -> Void, deny: () -> Void, denyWithGuidance: (String) -> Void)?
  
  // MARK: - Private Methods
  
  @MainActor
  private func addToApprovalQueue(_ request: ApprovalRequest) {
    // Check if this request is already in the queue (deduplication)
    if !approvalQueue.contains(where: { $0.toolUseId == request.toolUseId }) &&
       currentProcessingRequest?.toolUseId != request.toolUseId {
      approvalQueue.append(request)
    }
    
    // If no request is currently being processed, start processing
    if currentProcessingRequest == nil {
      processNextInQueue()
    }
  }
  
  @MainActor
  private func processNextInQueue() {
    guard !approvalQueue.isEmpty else {
      currentProcessingRequest = nil
      return
    }
    
    let request = approvalQueue.removeFirst()
    currentProcessingRequest = request
    showApprovalToast(for: request)
  }
  
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
      },
      denyWithGuidance: { [weak self] guidance in
        Task {
          // For Edit tools, provide more detailed feedback
          let reason = "Request denied. User guidance: \(guidance)"
          await self?.handleDenial(for: request.toolUseId, reason: reason)
        }
      }
    )
    
    // Show the toast
    currentToastRequest = request
    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
      isToastVisible = true
    }
    
    // Note: Toast will be hidden when:
    // - User approves/denies the request
    // - The configured timeout expires (handled by the main timeout mechanism)
    // - The request is cancelled
    // We don't auto-hide the toast to respect the user's timeout configuration
  }
  
  private func hideToast() {
    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
      isToastVisible = false
    }
    
    // Process next request after a short delay
    Task {
      try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds (reduced from 0.5)
      await MainActor.run {
        currentToastRequest = nil
        currentToastCallbacks = nil
        currentProcessingRequest = nil
        // Process next in queue if any
        processNextInQueue()
      }
    }
  }
  
  private func handleApproval(for toolUseId: String, updatedInput: [String: Any]?) async {
    guard let pendingRequest = pendingRequests.removeValue(forKey: toolUseId) else { return }

    let response = ApprovalResponse(
      behavior: .allow,
      updatedInput: updatedInput ?? pendingRequest.request.inputAsAny,
      message: "Approved by user"
    )

    pendingRequest.continuation.resume(returning: response)

    // Hide the toast and process next
    await MainActor.run {
      hideToast()
    }
  }

  private func handleDenial(for toolUseId: String, reason: String) async {
    guard let pendingRequest = pendingRequests.removeValue(forKey: toolUseId) else { return }

    let response = ApprovalResponse(
      behavior: .deny,
      updatedInput: nil,
      message: reason
    )

    pendingRequest.continuation.resume(returning: response)

    // Hide the toast and process next
    await MainActor.run {
      hideToast()
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
