import Foundation
import Combine
import CCCustomPermissionService
import CCCustomPermissionServiceInterface
import os.log
import AppKit

/// Bridge service that handles IPC communication between MCP server and main ClaudeCodeUI app
/// Allows the standalone MCP server to trigger approval dialogs in the main app UI
@MainActor
public final class ApprovalBridge: ObservableObject {
  private let logger = Logger(subsystem: "com.claudecodeui", category: "ApprovalBridge")
  private let permissionService: CustomPermissionService
  private let notificationCenter = DistributedNotificationCenter.default()
  
  // Notification names for IPC
  private static let approvalRequestNotification = "ClaudeCodeUIApprovalRequest"
  private static let approvalResponseNotification = "ClaudeCodeUIApprovalResponse"
  
  // Timeout for approval requests (prevent hanging indefinitely)
  private let approvalTimeout: TimeInterval = 60.0  // 60 seconds
  
  // Track processed request IDs to prevent duplicate processing (keep for 5 minutes)
  private var processedRequestIds: Set<String> = []
  private var lastCleanupTime = Date()
  private let cleanupInterval: TimeInterval = 300.0  // 5 minutes
  
  // Track active approval tasks for cancellation
  private var activeApprovalTasks: [String: Task<Void, Never>] = [:]
  
  public init(permissionService: CustomPermissionService) {
    self.permissionService = permissionService
    setupNotificationListeners()
    logger.info("ApprovalBridge initialized and ready for IPC requests")
  }
  
  deinit {
    notificationCenter.removeObserver(self)
    // Cancel all active approval tasks
    activeApprovalTasks.values.forEach { $0.cancel() }
    activeApprovalTasks.removeAll()
  }
  
  /// Reset the approval bridge state - useful for recovery from error states
  @MainActor
  public func resetState() {
    logger.info("ApprovalBridge Resetting ApprovalBridge state")
    
    // Cancel all active tasks
    activeApprovalTasks.values.forEach { $0.cancel() }
    activeApprovalTasks.removeAll()
    
    // Clear processed IDs
    processedRequestIds.removeAll()
    lastCleanupTime = Date()
    
    logger.info("ApprovalBridge state reset complete")
  }
  
  /// Set up distributed notification listeners for IPC
  private func setupNotificationListeners() {
    // IMPORTANT: Use .deliverImmediately to ensure notifications are received even when
    // the ClaudeCodeUI app is in the background or not the active app. Without this,
    // ICP approval requests would be suspended until the user manually activates the app.
    notificationCenter.addObserver(
      self,
      selector: #selector(handleApprovalRequest(_:)),
      name: NSNotification.Name(Self.approvalRequestNotification),
      object: nil,
      suspensionBehavior: .deliverImmediately
    )
    
    logger.info("ApprovalBridge ApprovalBridge listening for approval requests")
  }
  
  /// Handle incoming approval request from MCP server
  @objc private func handleApprovalRequest(_ notification: Notification) {
    logger.info("ApprovalBridge Received approval request via IPC")
    
    // Cleanup old processed IDs periodically
    cleanupProcessedRequestIds()
    
    guard let userInfo = notification.userInfo,
          let requestData = userInfo["request"] as? Data else {
      logger.error("ApprovalBridge Invalid approval request format")
      sendErrorResponse("Invalid request format")
      return
    }
    
    do {
      // Decode the approval request
      let decoder = JSONDecoder()
      let ipcRequest = try decoder.decode(IPCRequest.self, from: requestData)
      
      logger.info("ApprovalBridge Processing approval request for tool: \(ipcRequest.toolName), ID: \(ipcRequest.toolUseId)")
      
      // Check if we've already processed this request (deduplication)
      if processedRequestIds.contains(ipcRequest.toolUseId) {
        logger.warning("ApprovalBridge Duplicate approval request detected for ID: \(ipcRequest.toolUseId), ignoring")
        return
      }
      
      // Mark as processed
      processedRequestIds.insert(ipcRequest.toolUseId)
      
      // Process the request asynchronously on main actor for UI updates
      let task = Task { @MainActor in
        await processApprovalRequest(ipcRequest)
      }
      
      // Track the task for potential cancellation
      activeApprovalTasks[ipcRequest.toolUseId] = task
      
    } catch {
      logger.error("ApprovalBridge Failed to decode approval request: \(error)")
      sendErrorResponse("Failed to decode request: \(error.localizedDescription)")
    }
  }
  
  /// Cleanup old processed request IDs to prevent memory growth
  private func cleanupProcessedRequestIds() {
    let now = Date()
    if now.timeIntervalSince(lastCleanupTime) > cleanupInterval {
      let log = "ApprovalBridge Cleaning up processed request IDs (count: \(processedRequestIds.count))"
      logger.info("\(log)")
      processedRequestIds.removeAll()
      lastCleanupTime = now
    }
  }
  
  /// Process the approval request using CustomPermissionService
  @MainActor
  private func processApprovalRequest(_ ipcRequest: IPCRequest) async {
    // Cleanup task from tracking when done
    defer {
      activeApprovalTasks.removeValue(forKey: ipcRequest.toolUseId)
    }
    
    do {
      // IMPORTANT: Activate the app to ensure toast visibility when triggered via notifications.
      // When ICP requests come via DistributedNotificationCenter from background processes,
      // the app may not be active/focused, so the toast alerts won't be visible to the user.
      // This activation strategy mirrors the cmd+i shortcut behavior in KeyboardShortcutManager.
      NSRunningApplication.current.activate()
      
      // Ensure window comes to front after a brief delay
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        // Find and activate the key window to ensure proper focus
        if let keyWindow = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first {
          keyWindow.makeKeyAndOrderFront(nil)
        }
      }
      
      // Create ApprovalRequest from IPC request
      let approvalRequest = ApprovalRequest(
        toolName: ipcRequest.toolName,
        anyInput: ipcRequest.input,
        toolUseId: ipcRequest.toolUseId,
        context: createContext(for: ipcRequest.toolName, input: ipcRequest.input)
      )
      
      // Request approval with timeout to prevent hanging indefinitely
      let response: ApprovalResponse
      
      do {
        response = try await withThrowingTaskGroup(of: ApprovalResponse.self) { group in
          // Task 1: Actual approval request
          group.addTask {
            try await self.permissionService.requestApproval(for: approvalRequest)
          }
          
          // Task 2: Timeout watchdog
          group.addTask {
            try await Task.sleep(nanoseconds: UInt64(self.approvalTimeout * 1_000_000_000))
            throw CustomPermissionError.requestTimedOut
          }
          
          // Return the first result (either approval or timeout)
          let result = try await group.next()!
          
          // Cancel the other task
          group.cancelAll()
          
          return result
        }
      } catch is CancellationError {
        // Task was cancelled - treat as denial
        logger.warning("ApprovalBridge Approval request cancelled for \(ipcRequest.toolUseId)")
        throw CustomPermissionError.requestCancelled
      } catch let error as CustomPermissionError {
        // Timeout or other custom permission error
        logger.error("ApprovalBridge Approval request error for \(ipcRequest.toolUseId): \(error.localizedDescription)")
        throw error
      }
      
      // Send response back to MCP server
      let ipcResponse = IPCResponse(
        toolUseId: ipcRequest.toolUseId,
        behavior: response.behavior.rawValue,
        updatedInput: response.updatedInputAsAny ?? ipcRequest.input,
        message: response.message ?? "Processed by ApprovalBridge"
      )
      
      sendApprovalResponse(ipcResponse)
      
      logger.info("ApprovalBridge Approval request processed successfully for \(ipcRequest.toolUseId)")
      
    } catch let error as CustomPermissionError {
      // Handle custom permission errors with better context
      logger.error("ApprovalBridge Permission error for \(ipcRequest.toolUseId): \(error.localizedDescription)")
      
      let contextualMessage: String
      switch error {
      case .requestTimedOut:
        contextualMessage = "Approval request timed out after \\(Int(approvalTimeout)) seconds. The approval dialog may not have been visible or the system was unresponsive."
      case .requestCancelled:
        contextualMessage = "Approval request was cancelled. This may occur if the conversation was stopped or the approval system was reset."
      case .invalidRequest(let details):
        contextualMessage = "Invalid approval request: \(details)"
      case .processingError(let details):
        contextualMessage = "Error processing approval: \(details)"
      case .mcpIntegrationError(let details):
        contextualMessage = "MCP integration error: \(details)"
      }
      
      let errorResponse = IPCResponse(
        toolUseId: ipcRequest.toolUseId,
        behavior: "deny",
        updatedInput: ipcRequest.input,
        message: contextualMessage
      )
      
      sendApprovalResponse(errorResponse)
      
    } catch {
      // Handle other unexpected errors
      logger.error("ApprovalBridge Unexpected error processing approval for \(ipcRequest.toolUseId): \\(error)")
      
      let errorResponse = IPCResponse(
        toolUseId: ipcRequest.toolUseId,
        behavior: "deny",
        updatedInput: ipcRequest.input,
        message: "Approval processing failed: \(error.localizedDescription). If this persists, try resetting the approval system."
      )
      
      sendApprovalResponse(errorResponse)
    }
  }
  
  /// Create context for approval request based on tool name and input
  private func createContext(for toolName: String, input: [String: Any]) -> ApprovalContext {
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
      description = "Tool operation: \\(toolName)"
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
  
  /// Send approval response back to MCP server
  private func sendApprovalResponse(_ response: IPCResponse) {
    do {
      let encoder = JSONEncoder()
      let responseData = try encoder.encode(response)
      
      let userInfo = ["response": responseData]
      
      notificationCenter.post(
        name: NSNotification.Name(Self.approvalResponseNotification),
        object: nil,
        userInfo: userInfo
      )
      
      logger.info("ApprovalBridge Sent approval response for \(response.toolUseId): \(response.behavior)")
      
    } catch {
      logger.error("ApprovalBridge Failed to send approval response: \(error)")
    }
  }
  
  /// Send error response to MCP server
  private func sendErrorResponse(_ message: String) {
    let errorResponse = IPCResponse(
      toolUseId: "unknown",
      behavior: "deny",
      updatedInput: [:],
      message: message
    )
    
    sendApprovalResponse(errorResponse)
  }
}

// MARK: - IPC Data Models

/// Request sent from MCP server to main app
private struct IPCRequest: Codable {
  let toolName: String
  let input: [String: Any]
  let toolUseId: String
  
  enum CodingKeys: String, CodingKey {
    case toolName = "tool_name"
    case input
    case toolUseId = "tool_use_id"
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    toolName = try container.decode(String.self, forKey: .toolName)
    toolUseId = try container.decode(String.self, forKey: .toolUseId)
    
    // Decode input as flexible JSON
    let inputContainer = try container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .input)
    var inputDict: [String: Any] = [:]
    
    for key in inputContainer.allKeys {
      if let stringValue = try? inputContainer.decode(String.self, forKey: key) {
        inputDict[key.stringValue] = stringValue
      } else if let intValue = try? inputContainer.decode(Int.self, forKey: key) {
        inputDict[key.stringValue] = intValue
      } else if let doubleValue = try? inputContainer.decode(Double.self, forKey: key) {
        inputDict[key.stringValue] = doubleValue
      } else if let boolValue = try? inputContainer.decode(Bool.self, forKey: key) {
        inputDict[key.stringValue] = boolValue
      }
    }
    
    input = inputDict
  }
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(toolName, forKey: .toolName)
    try container.encode(toolUseId, forKey: .toolUseId)
    
    // Encode input - simplified for now
    var inputContainer = container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .input)
    for (key, value) in input {
      let codingKey = DynamicCodingKey(stringValue: key)!
      if let stringValue = value as? String {
        try inputContainer.encode(stringValue, forKey: codingKey)
      } else if let intValue = value as? Int {
        try inputContainer.encode(intValue, forKey: codingKey)
      } else if let doubleValue = value as? Double {
        try inputContainer.encode(doubleValue, forKey: codingKey)
      } else if let boolValue = value as? Bool {
        try inputContainer.encode(boolValue, forKey: codingKey)
      }
    }
  }
}

/// Response sent from main app to MCP server
private struct IPCResponse: Codable {
  let toolUseId: String
  let behavior: String
  let updatedInput: [String: Any]
  let message: String
  
  enum CodingKeys: String, CodingKey {
    case toolUseId = "tool_use_id"
    case behavior
    case updatedInput = "updated_input"
    case message
  }
  
  init(toolUseId: String, behavior: String, updatedInput: [String: Any], message: String) {
    self.toolUseId = toolUseId
    self.behavior = behavior
    self.updatedInput = updatedInput
    self.message = message
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    toolUseId = try container.decode(String.self, forKey: .toolUseId)
    behavior = try container.decode(String.self, forKey: .behavior)
    message = try container.decode(String.self, forKey: .message)
    
    // Decode updatedInput as flexible JSON
    let inputContainer = try container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .updatedInput)
    var inputDict: [String: Any] = [:]
    
    for key in inputContainer.allKeys {
      if let stringValue = try? inputContainer.decode(String.self, forKey: key) {
        inputDict[key.stringValue] = stringValue
      } else if let intValue = try? inputContainer.decode(Int.self, forKey: key) {
        inputDict[key.stringValue] = intValue
      } else if let doubleValue = try? inputContainer.decode(Double.self, forKey: key) {
        inputDict[key.stringValue] = doubleValue
      } else if let boolValue = try? inputContainer.decode(Bool.self, forKey: key) {
        inputDict[key.stringValue] = boolValue
      }
    }
    
    updatedInput = inputDict
  }
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(toolUseId, forKey: .toolUseId)
    try container.encode(behavior, forKey: .behavior)
    try container.encode(message, forKey: .message)
    
    // Encode updatedInput - simplified for now
    var inputContainer = container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .updatedInput)
    for (key, value) in updatedInput {
      let codingKey = DynamicCodingKey(stringValue: key)!
      if let stringValue = value as? String {
        try inputContainer.encode(stringValue, forKey: codingKey)
      } else if let intValue = value as? Int {
        try inputContainer.encode(intValue, forKey: codingKey)
      } else if let doubleValue = value as? Double {
        try inputContainer.encode(doubleValue, forKey: codingKey)
      } else if let boolValue = value as? Bool {
        try inputContainer.encode(boolValue, forKey: codingKey)
      }
    }
  }
}

/// Dynamic coding key for flexible JSON encoding/decoding
private struct DynamicCodingKey: CodingKey {
  var stringValue: String
  var intValue: Int?
  
  init?(stringValue: String) {
    self.stringValue = stringValue
    self.intValue = nil
  }
  
  init?(intValue: Int) {
    self.stringValue = String(intValue)
    self.intValue = intValue
  }
}
