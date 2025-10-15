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
    
    public init(permissionService: CustomPermissionService) {
        self.permissionService = permissionService
        setupNotificationListeners()
        logger.info("ApprovalBridge initialized and ready for IPC requests")
    }
    
    deinit {
        notificationCenter.removeObserver(self)
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
        
        logger.info("ApprovalBridge listening for approval requests")
    }
    
    /// Handle incoming approval request from MCP server
    @objc private func handleApprovalRequest(_ notification: Notification) {
        logger.info("Received approval request via IPC")
        
        guard let userInfo = notification.userInfo,
              let requestData = userInfo["request"] as? Data else {
            logger.error("Invalid approval request format")
            sendErrorResponse("Invalid request format")
            return
        }
        
        do {
            // Decode the approval request
            let decoder = JSONDecoder()
            let ipcRequest = try decoder.decode(IPCRequest.self, from: requestData)
            
            logger.info("Processing approval request for tool: \\(ipcRequest.toolName), ID: \\(ipcRequest.toolUseId)")
            
            // Process the request asynchronously on main actor for UI updates
            Task { @MainActor in
                await processApprovalRequest(ipcRequest)
            }
            
        } catch {
            logger.error("Failed to decode approval request: \\(error)")
            sendErrorResponse("Failed to decode request: \\(error.localizedDescription)")
        }
    }
    
    /// Process the approval request using CustomPermissionService
    @MainActor
    private func processApprovalRequest(_ ipcRequest: IPCRequest) async {
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
            
            // Request approval through the permission service (this will show UI)
            let response = try await permissionService.requestApproval(for: approvalRequest)
            
            // Send response back to MCP server
            let ipcResponse = IPCResponse(
                toolUseId: ipcRequest.toolUseId,
                behavior: response.behavior.rawValue,
                updatedInput: response.updatedInputAsAny ?? ipcRequest.input,
                message: response.message ?? "Processed by ApprovalBridge"
            )
            
            sendApprovalResponse(ipcResponse)
            
            logger.info("Approval request processed successfully for \\(ipcRequest.toolUseId)")
            
        } catch {
            logger.error("Failed to process approval request for \\(ipcRequest.toolUseId): \\(error)")
            
            let errorResponse = IPCResponse(
                toolUseId: ipcRequest.toolUseId,
                behavior: "deny",
                updatedInput: ipcRequest.input,
                message: "Approval processing failed: \\(error.localizedDescription)"
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
            
            logger.info("Sent approval response for \\(response.toolUseId): \\(response.behavior)")
            
        } catch {
            logger.error("Failed to send approval response: \\(error)")
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