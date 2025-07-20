import Foundation
import SwiftUI
import Combine
import ClaudeCodeSDK
import CustomPermissionServiceInterface

/// Default implementation of CustomPermissionService
@MainActor
public final class DefaultCustomPermissionService: CustomPermissionService, ObservableObject {
    
    @Published public var autoApproveToolCalls: Bool = false {
        didSet {
            // Persist the setting
            UserDefaults.standard.set(autoApproveToolCalls, forKey: "AutoApproveToolCalls")
        }
    }
    
    public var autoApprovePublisher: AnyPublisher<Bool, Never> {
        $autoApproveToolCalls.eraseToAnyPublisher()
    }
    
    private let configuration: PermissionConfiguration
    private var pendingRequests: [String: PendingRequest] = [:]
    private var mcpHandlers: [String: (ApprovalRequest) async throws -> ApprovalResponse] = [:]
    
    // UI state management
    @Published private var activePrompt: ApprovalPromptState?
    private var currentPromptWindow: NSWindow?
    
    public init(configuration: PermissionConfiguration = .default) {
        self.configuration = configuration
        self.autoApproveToolCalls = UserDefaults.standard.bool(forKey: "AutoApproveToolCalls")
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
        if configuration.autoApproveLowRisk,
           let context = request.context,
           context.riskLevel == .low {
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
            
            // Show the approval prompt
            Task { @MainActor in
                await self.showApprovalPrompt(for: request)
            }
        }
    }
    
    public func cancelAllRequests() {
        for (toolUseId, pendingRequest) in pendingRequests {
            pendingRequest.timeoutTask.cancel()
            pendingRequest.continuation.resume(throwing: CustomPermissionError.requestCancelled)
        }
        pendingRequests.removeAll()
        
        // Close any active prompt window
        currentPromptWindow?.close()
        currentPromptWindow = nil
        activePrompt = nil
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
        guard let toolName = toolCallData["tool_name"] as? String,
              let input = toolCallData["input"] as? [String: Any],
              let toolUseId = toolCallData["tool_use_id"] as? String else {
            throw CustomPermissionError.invalidRequest("Missing required fields: tool_name, input, or tool_use_id")
        }
        
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
            "message": response.message ?? ""
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: responseDict, options: [])
        return String(data: jsonData, encoding: .utf8) ?? "{}"
    }
    
    // MARK: - Private Methods
    
    private func showApprovalPrompt(for request: ApprovalRequest) async {
        let promptState = ApprovalPromptState(
            request: request,
            onApprove: { [weak self] modifiedInput in
                await self?.handleApproval(for: request.toolUseId, updatedInput: modifiedInput)
            },
            onDeny: { [weak self] reason in
                await self?.handleDenial(for: request.toolUseId, reason: reason)
            }
        )
        
        activePrompt = promptState
        
        // Create and show the prompt window
        let contentView = ApprovalPromptView(state: promptState)
        let hostingController = NSHostingController(rootView: contentView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Permission Request"
        window.contentViewController = hostingController
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.level = .modalPanel
        
        // Handle window closing
        let windowDelegate = PromptWindowDelegate { [weak self] in
            await self?.handleDenial(for: request.toolUseId, reason: "Window closed by user")
        }
        window.delegate = windowDelegate
        
        currentPromptWindow = window
        
        // Keep a reference to the delegate to prevent deallocation
        objc_setAssociatedObject(window, "delegate", windowDelegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
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
        
        // Close the prompt window
        currentPromptWindow?.close()
        currentPromptWindow = nil
        activePrompt = nil
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
        
        // Close the prompt window
        currentPromptWindow?.close()
        currentPromptWindow = nil
        activePrompt = nil
    }
    
    private func handleTimeout(for toolUseId: String) async {
        guard let pendingRequest = pendingRequests.removeValue(forKey: toolUseId) else { return }
        
        pendingRequest.continuation.resume(throwing: CustomPermissionError.requestTimedOut)
        
        // Close the prompt window
        await MainActor.run {
            currentPromptWindow?.close()
            currentPromptWindow = nil
            activePrompt = nil
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

// MARK: - Supporting Types

private struct PendingRequest {
    let request: ApprovalRequest
    let continuation: CheckedContinuation<ApprovalResponse, Error>
    let timeoutTask: Task<Void, Error>
}

private class PromptWindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () async -> Void
    
    init(onClose: @escaping () async -> Void) {
        self.onClose = onClose
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        Task {
            await onClose()
        }
        return true
    }
}

