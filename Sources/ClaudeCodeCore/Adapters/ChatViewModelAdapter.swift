//
//  ChatViewModelAdapter.swift
//  ClaudeCodeCore
//
//  Adapter to make ChatViewModel conform to ClaudeCodeExecutor protocol
//  This enables dependency inversion - CodeWhisper depends on protocols, not concrete types
//

import Foundation
import ClaudeCodeSDK
import CCCustomPermissionService
import SwiftAnthropic
import MCP
import CodeWhisper

/// Adapter that wraps ChatViewModel to conform to ClaudeCodeExecutor protocol
/// This allows ChatViewModel to be used as an executor by protocol-dependent code
@MainActor
public final class ChatViewModelAdapter: ClaudeCodeExecutor {
  
  // MARK: - Properties
  
  private let chatViewModel: ChatViewModel
  
  // MARK: - ClaudeCodeExecutor Protocol Properties
  
  public var isExecuting: Bool {
    chatViewModel.isLoading
  }
  
  public var messages: [CodeWhisper.CodeExecutionMessage] {
    chatViewModel.messages.map { chatMessage in
      // Map ChatMessage to CodeExecutionMessage
      let messageType: CodeWhisper.MessageType
      switch chatMessage.messageType {
      case .thinking:
        messageType = .thinking
      case .toolUse:
        messageType = .toolUse(toolName: chatMessage.toolName ?? "Unknown")
      case .toolResult:
        messageType = .toolResult
      case .toolError:
        messageType = .toolError
      case .text:
        messageType = .text
      case .webSearch:
        messageType = .webSearch
      case .toolDenied:
        messageType = .toolDenied
      case .codeExecution:
        messageType = .codeExecution
      case .askUserQuestion:
        messageType = .text  // Map to text for voice mode display
      }
      
      let messageRole: CodeWhisper.MessageRole
      switch chatMessage.role {
      case .user:
        messageRole = .user
      case .assistant:
        messageRole = .assistant
      default:
        // Map all other roles (system, toolUse, toolResult, approved, denied, etc.) to system
        messageRole = .system
      }
      
      return CodeWhisper.CodeExecutionMessage(
        id: chatMessage.id,
        type: messageType,
        role: messageRole,
        content: chatMessage.content,
        timestamp: chatMessage.timestamp,
        toolName: chatMessage.toolName
      )
    }
  }
  
  public var workingDirectory: String? {
    get { chatViewModel.projectPath }
    set { chatViewModel.projectPath = newValue ?? "" }
  }

  public var permissionMode: CodeWhisper.ExecutorPermissionMode {
    get {
      switch chatViewModel.permissionMode {
      case .bypassPermissions:
        return .bypassPermissions
      default:
        return .default
      }
    }
    set {
      chatViewModel.permissionMode = newValue == .bypassPermissions ? .bypassPermissions : .default
    }
  }

  // MARK: - Initialization
  
  public init(chatViewModel: ChatViewModel) {
    self.chatViewModel = chatViewModel
  }
  
  /// Convenience initializer that creates a ChatViewModel with standard configuration
  public init(configuration: CodeWhisper.ClaudeCodeExecutorConfiguration) throws {
    // Create ClaudeCode client configuration
    var claudeConfig = ClaudeCodeConfiguration.withNvmSupport()
    claudeConfig.workingDirectory = configuration.workingDirectory
    claudeConfig.enableDebugLogging = configuration.enableDebugLogging
    claudeConfig.additionalPaths = configuration.additionalPaths
    
    // Create Claude Code client
    let claudeClient = try ClaudeCodeClient(configuration: claudeConfig)
    
    // Create dependencies
    let sessionStorage = NoOpSessionStorage()
    let settingsStorage = SettingsStorageManager()
    let globalPreferences = GlobalPreferencesStorage()
    let permissionService = DefaultCustomPermissionService()
    
    // MCP server configuration is handled separately in ClaudeCodeUI
    // Not setting it here to avoid conflicts
    
    // Create ChatViewModel
    let viewModel = ChatViewModel(
      claudeClient: claudeClient,
      sessionStorage: sessionStorage,
      settingsStorage: settingsStorage,
      globalPreferences: globalPreferences,
      customPermissionService: permissionService,
      systemPromptPrefix: configuration.systemPromptPrefix,
      shouldManageSessions: false,
      onSessionChange: nil,
      onUserMessageSent: nil
    )
    
    // Set permission mode
    let permissionMode: ClaudeCodeSDK.PermissionMode = configuration.permissionMode == .bypassPermissions ? .bypassPermissions : .default
    viewModel.permissionMode = permissionMode
    
    // Set working directory
    if let workingDir = configuration.workingDirectory {
      viewModel.projectPath = workingDir
      settingsStorage.setProjectPath(workingDir)
    }
    
    self.chatViewModel = viewModel
  }
  
  // MARK: - ClaudeCodeExecutor Protocol Methods
  
  public func initialize(configuration: CodeWhisper.ClaudeCodeExecutorConfiguration) async throws {
    // Update configuration if needed
    if let workingDir = configuration.workingDirectory {
      chatViewModel.projectPath = workingDir
    }
    
    // Update permission mode
    let permissionMode: ClaudeCodeSDK.PermissionMode = configuration.permissionMode == .bypassPermissions ? .bypassPermissions : .default
    chatViewModel.permissionMode = permissionMode
  }
  
  public func executeTask(_ task: String, context: CodeWhisper.TaskContext?) async throws -> CodeWhisper.ClaudeCodeResult {
    // Convert TaskContext to ChatViewModel parameters
    var attachments: [FileAttachment]? = nil
    
    if let images = context?.images, !images.isEmpty {
      var processedAttachments: [FileAttachment] = []
      
      for imageData in images {
        // Create temporary file for image
        let tempURL = FileManager.default.temporaryDirectory
          .appendingPathComponent(UUID().uuidString)
          .appendingPathExtension("png")
        
        do {
          try imageData.data.write(to: tempURL)
          let attachment = FileAttachment(url: tempURL, isTemporary: true)
          // Process the attachment to convert image and set state to .ready
          await AttachmentProcessor().process(attachment)
          processedAttachments.append(attachment)
        } catch {
          print("Failed to write image to temp file: \(error)")
        }
      }
      
      if !processedAttachments.isEmpty {
        attachments = processedAttachments
      }
    }
    
    let hiddenContext = context?.additionalInfo
    
    // Send message
    chatViewModel.sendMessage(
      task,
      context: nil,
      hiddenContext: hiddenContext,
      codeSelections: nil,
      attachments: attachments
    )
    
    // Wait for completion
    return try await waitForCompletion()
  }
  
  public func cancelTask() {
    chatViewModel.cancelRequest()
  }
  
  public func reset() {
    // ChatViewModel doesn't have a reset method, but we can clear messages
    // This would need to be implemented in ChatViewModel if needed
  }
  
  // MARK: - Private Methods
  
  private func waitForCompletion() async throws -> CodeWhisper.ClaudeCodeResult {
    // Poll until isLoading becomes false
    var pollAttempts = 0
    let maxPollAttempts = 2400 // 2 minutes with 50ms intervals
    
    while chatViewModel.isLoading && pollAttempts < maxPollAttempts {
      try await Task.sleep(for: .milliseconds(50))
      pollAttempts += 1
    }
    
    if pollAttempts >= maxPollAttempts {
      throw ClaudeCodeExecutorError.timeout
    }
    
    // Get final result
    let resultContent = chatViewModel.messages
      .filter { $0.role == .assistant && $0.messageType == .text }
      .last?
      .content ?? ""
    
    let tokenUsage = CodeWhisper.TokenUsage(
      inputTokens: chatViewModel.currentInputTokens,
      outputTokens: chatViewModel.currentOutputTokens
    )
    
    return CodeWhisper.ClaudeCodeResult(
      content: resultContent,
      messages: messages,
      tokenUsage: tokenUsage,
      success: chatViewModel.errorInfo == nil
    )
  }
}

// MARK: - Errors

public enum ClaudeCodeExecutorError: LocalizedError {
  case timeout
  case notInitialized
  
  public var errorDescription: String? {
    switch self {
    case .timeout:
      return "Execution timed out after 2 minutes"
    case .notInitialized:
      return "Executor not initialized"
    }
  }
}

// MARK: - Notes
//
// All protocol types (ClaudeCodeExecutor, ClaudeCodeExecutorConfiguration, etc.)
// are imported from the CodeWhisper package.
// They are defined in: CodeWhisper/Sources/CodeWhisper/Protocols/ClaudeCodeExecutor.swift
