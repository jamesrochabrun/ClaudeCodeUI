import ClaudeCodeSDK
import Combine
import CCCustomPermissionServiceInterface
import Foundation
import SwiftUI
import Observation
import os.log

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

  // Timer for tracking toast display duration
  private var toastDisplayStartTime: Date?
  private var toastTimer: Timer?

  // Callback for when conversation should be paused due to approval timeout
  public var onConversationShouldPause: ((String, String) -> Void)?  // (toolUseId, sessionId)

  // Callback for resuming conversation after user responds to paused approval
  public var onResumeAfterTimeout: ((Bool, String) -> Void)?  // (approved, toolName)

  // Storage for paused approvals that can be resumed later
  // Key is tool signature (toolName + key parameters), value is approval decision
  private var pausedApprovals: [String: (request: ApprovalRequest, approved: Bool?)] = [:]

  public func requestApproval(for request: ApprovalRequest) async throws -> ApprovalResponse {
    // CHECK: Is this a previously paused approval that user responded to?
    let toolSignature = createToolSignature(for: request)
    if let paused = pausedApprovals[toolSignature], let approved = paused.approved {
      logger.info("Auto-handling paused approval. Tool: \(request.toolName), Signature: \(toolSignature), Approved: \(approved)")
      pausedApprovals.removeValue(forKey: toolSignature) // Clear cache

      if approved {
        return ApprovalResponse(
          behavior: .allow,
          updatedInput: request.inputAsAny,
          message: "Previously approved by user after timeout"
        )
      } else {
        return ApprovalResponse(
          behavior: .deny,
          updatedInput: nil,
          message: "Previously denied by user after timeout"
        )
      }
    }

    // Check if auto-approval is enabled
    // IMPORTANT: Never auto-approve AskUserQuestion - user must provide actual answers
    if autoApproveToolCalls && request.toolName != "AskUserQuestion" {
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
    // Stop any active timer
    stopToastTimer()

    // Check if current toast is paused - if so, preserve it
    let hasPausedToast: Bool
    if let currentRequest = currentToastRequest {
      let toolSignature = createToolSignature(for: currentRequest)
      hasPausedToast = pausedApprovals[toolSignature] != nil
    } else {
      hasPausedToast = false
    }

    for (_, pendingRequest) in pendingRequests {
      pendingRequest.continuation.resume(throwing: CustomPermissionError.requestCancelled)
    }
    pendingRequests.removeAll()

    // Clear the queue
    approvalQueue.removeAll()
    currentProcessingRequest = nil

    // Only hide toast and clear paused approvals if there's no paused toast
    if !hasPausedToast {
      pausedApprovals.removeAll()
      hideToast()
    } else {
      logger.info("Preserving paused toast after cancellation")
    }
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
    logger.info("Processing MCP tool call with data: \(String(describing: toolCallData))")

    guard
      let toolName = toolCallData["tool_name"] as? String,
      let input = toolCallData["input"] as? [String: Any],
      let toolUseId = toolCallData["tool_use_id"] as? String
    else {
      throw CustomPermissionError.invalidRequest("Missing required fields: tool_name, input, or tool_use_id")
    }

    logger.info("Tool: \(toolName), ID: \(toolUseId)")
    
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

  // Logger for permission service
  private let logger = Logger(subsystem: "com.claudecodeui.permission", category: "CustomPermissionService")
  
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

    // Start timer for timeout detection (if configured)
    if let timeoutThreshold = configuration.approvalTimeoutThreshold {
      startToastTimer(for: request, threshold: timeoutThreshold)
    }

    // Note: Toast will remain visible until:
    // - User approves/denies the request
    // - The request is cancelled via cancelAllRequests()
    // - Timeout threshold is reached (conversation pauses, toast stays visible)
  }
  
  private func hideToast() {
    // Stop the timer when hiding toast
    stopToastTimer()

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

  @MainActor
  private func startToastTimer(for request: ApprovalRequest, threshold: TimeInterval) {
    // Record when toast was displayed
    toastDisplayStartTime = Date()

    // Cancel any existing timer
    stopToastTimer()

    // Create a single-shot timer that fires exactly at threshold
    toastTimer = Timer.scheduledTimer(withTimeInterval: threshold, repeats: false) { [weak self] _ in
      guard let self = self else { return }
      self.logger.info("Approval timeout threshold (\(threshold, privacy: .public)s) reached")
      Task { @MainActor in
        await self.handleToastTimeout(for: request)
      }
    }
  }

  @MainActor
  private func stopToastTimer() {
    toastTimer?.invalidate()
    toastTimer = nil
    toastDisplayStartTime = nil
  }

  @MainActor
  private func handleToastTimeout(for request: ApprovalRequest) async {
    // Stop the timer
    stopToastTimer()

    // Remove from pending requests and complete its continuation
    // This prevents the request from blocking and allows clean cancellation
    if let pendingRequest = pendingRequests.removeValue(forKey: request.toolUseId) {
      pendingRequest.continuation.resume(throwing: CustomPermissionError.requestCancelled)
      logger.info("Removed pending request for \(request.toolUseId) due to timeout")
    }

    // Store this approval for later resumption using tool signature
    let toolSignature = createToolSignature(for: request)
    pausedApprovals[toolSignature] = (request: request, approved: nil)
    logger.info("Stored paused approval with signature: \(toolSignature)")

    // Notify that conversation should be paused
    if let callback = onConversationShouldPause {
      logger.info("Notifying to pause conversation for tool: \(request.toolName)")
      callback(request.toolUseId, "")
    } else {
      logger.warning("No pause callback set, timeout will not pause conversation")
    }

    // IMPORTANT: We do NOT call hideToast() here!
    // Toast stays visible so user can still approve/deny later
    logger.info("Toast will remain visible - user can still respond")
  }

  private func handleApproval(for toolUseId: String, updatedInput: [String: Any]?) async {
    // Check if this is a paused approval (timeout occurred)
    if let pendingRequest = pendingRequests.removeValue(forKey: toolUseId) {
      // Normal approval flow (no timeout)
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
    } else if let currentRequest = currentToastRequest {
      // This is a paused approval - user approved after timeout
      let toolSignature = createToolSignature(for: currentRequest)

      if pausedApprovals[toolSignature] != nil {
        logger.info("User approved paused request. Tool: \(currentRequest.toolName), Signature: \(toolSignature)")

        // Update the paused approval with user's decision
        pausedApprovals[toolSignature]?.approved = true

        // Hide the toast
        await MainActor.run {
          hideToast()
        }

        // Notify ChatViewModel to resume conversation
        onResumeAfterTimeout?(true, currentRequest.toolName)
      }
    }
  }

  private func handleDenial(for toolUseId: String, reason: String) async {
    // Check if this is a paused approval (timeout occurred)
    if let pendingRequest = pendingRequests.removeValue(forKey: toolUseId) {
      // Normal denial flow (no timeout)
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
    } else if let currentRequest = currentToastRequest {
      // This is a paused approval - user denied after timeout
      let toolSignature = createToolSignature(for: currentRequest)

      if pausedApprovals[toolSignature] != nil {
        logger.info("User denied paused request. Tool: \(currentRequest.toolName), Signature: \(toolSignature)")

        // Update the paused approval with user's decision
        pausedApprovals[toolSignature]?.approved = false

        // Hide the toast
        await MainActor.run {
          hideToast()
        }

        // Notify ChatViewModel to resume conversation
        onResumeAfterTimeout?(false, currentRequest.toolName)
      }
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

  /// Creates a unique signature for a tool request based on tool name and key parameters
  /// This is used to match re-requested tools after timeout with the original user decision
  private func createToolSignature(for request: ApprovalRequest) -> String {
    let toolName = request.toolName
    let input = request.inputAsAny

    // Extract key parameters based on tool type
    var keyParams: [String] = []

    switch toolName.lowercased() {
    case let name where name.contains("edit") || name.contains("write"):
      // For file operations, include file path
      if let filePath = input["file_path"] as? String {
        keyParams.append("file:\(filePath)")
      }

    case let name where name.contains("bash") || name.contains("shell") || name.contains("exec"):
      // For shell commands, include the command
      if let command = input["command"] as? String {
        // Only include first 50 chars to avoid huge signatures
        let truncated = String(command.prefix(50))
        keyParams.append("cmd:\(truncated)")
      }

    case let name where name.contains("read") || name.contains("get"):
      // For read operations, include path
      if let path = input["path"] as? String {
        keyParams.append("path:\(path)")
      } else if let filePath = input["file_path"] as? String {
        keyParams.append("file:\(filePath)")
      }

    default:
      // For other tools, include first parameter if it's a string
      if let firstKey = input.keys.first,
         let firstValue = input[firstKey] as? String {
        let truncated = String(firstValue.prefix(50))
        keyParams.append("\(firstKey):\(truncated)")
      }
    }

    // Create signature: toolName + key parameters
    let signature = keyParams.isEmpty ? toolName : "\(toolName)|\(keyParams.joined(separator: "|"))"
    return signature
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
