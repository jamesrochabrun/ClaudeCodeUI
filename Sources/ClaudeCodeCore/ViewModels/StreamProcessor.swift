//
//  StreamProcessor.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 6/8/2025.
//
import Foundation
import Combine
import ClaudeCodeSDK
import SwiftAnthropic
import os.log


/// Processes Claude's streaming responses
@MainActor
final class StreamProcessor {
  private let logger = Logger(subsystem: "com.ClaudeCodeUI.ClaudeChat", category: "StreamProcessor")
  private let messageStore: MessageStore
  private let sessionManager: SessionManager
  private let globalPreferences: GlobalPreferencesStorage?
  private let onSessionChange: ((String) -> Void)?
  private var cancellables = Set<AnyCancellable>()
  private let formatter = DynamicContentFormatter()
  private var getCurrentWorkingDirectory: (() -> String?)?
  
  // Track active continuation for proper cleanup
  private var activeContinuation: CheckedContinuation<Void, Never>?
  
  // Track pending session ID during streaming (only commit on success)
  private var pendingSessionId: String?
  
  /// Gets the currently active session ID (pending or current)
  /// Returns the pending session ID if streaming is in progress, otherwise the current session ID
  var activeSessionId: String? {
    pendingSessionId ?? sessionManager.currentSessionId
  }
  
  // Stream state holder
  private class StreamState {
    var contentBuffer = ""
    var assistantMessageCreated = false
    var currentMessageId: String?
    var currentLocalMessageId: UUID?
    var hasProcessedToolUse = false  // Track if we've seen a tool use
    var currentTaskGroupId: UUID?    // Track the current task group
    var isInTaskExecution = false    // Track if we're currently in a Task execution
  }
  
  init(messageStore: MessageStore, sessionManager: SessionManager, globalPreferences: GlobalPreferencesStorage? = nil, onSessionChange: ((String) -> Void)? = nil, getCurrentWorkingDirectory: (() -> String?)? = nil) {
    self.messageStore = messageStore
    self.sessionManager = sessionManager
    self.globalPreferences = globalPreferences
    self.onSessionChange = onSessionChange
    self.getCurrentWorkingDirectory = getCurrentWorkingDirectory
  }
  
  /// Cancels the current stream processing
  func cancelStream() {
    // Discard any pending session ID since the stream was cancelled
    if let pending = pendingSessionId {
      // Discarding pending session ID since stream was cancelled
      pendingSessionId = nil
    }
    
    // Cancel all active subscriptions
    cancellables.forEach { $0.cancel() }
    cancellables.removeAll()
    
    // Resume any active continuation to prevent leaks
    if let continuation = activeContinuation {
      continuation.resume()
      activeContinuation = nil
    }
  }
  
  func processStream(
    _ publisher: AnyPublisher<ResponseChunk, Error>,
    messageId: UUID,
    firstMessageInSession: String? = nil,
    onError: ((Error) -> Void)? = nil,
    onTokenUsageUpdate: ((Int, Int) -> Void)? = nil,
    onCostUpdate: ((Double) -> Void)? = nil
  ) async {
    await withCheckedContinuation { continuation in
      // Store the continuation for cancellation handling
      self.activeContinuation = continuation
      
      let state = StreamState()
      
      // Set up a timeout to detect if no data is received
      var timeoutTask: Task<Void, Never>?
      var hasReceivedData = false
      var subscription: AnyCancellable?
      
      timeoutTask = Task { [weak self] in
        try? await Task.sleep(nanoseconds: 25_000_000_000) // 25 seconds
        if !hasReceivedData && !Task.isCancelled {
          guard let self = self else { return }
          self.logger.error("Stream timeout - no data received within 5 seconds")
          
          // Cancel the stream subscription to prevent completion handler from running
          subscription?.cancel()
          self.cancellables.removeAll()
          
          // Clear any pending session ID since the stream timed out
          if let pending = self.pendingSessionId {
            ClaudeCodeLogger.shared.stream("Timeout occurred - discarding pending session ID: \(pending)")
            self.pendingSessionId = nil
          }
          
          // Clear the active continuation reference before resuming
          self.activeContinuation = nil
          
          // Call error handler and resume continuation
          onError?(ClaudeCodeError.timeout(5.0))
          continuation.resume()
        }
      }
      
      subscription = publisher
        .receive(on: DispatchQueue.main)
        .sink(
          receiveCompletion: { [weak self] completion in
            timeoutTask?.cancel() // Cancel timeout on completion
            guard let self = self else {
              continuation.resume()
              return
            }
            
            switch completion {
            case .finished:
              // Check if we received any data at all
              if !hasReceivedData && !state.assistantMessageCreated {
                self.logger.error("Stream finished without receiving any data - treating as error")
                let error = ClaudeCodeError.executionFailed("Process terminated without sending any data. Check your Claude CLI configuration and MCP settings.")
                if let onError = onError {
                  onError(error)
                }
              }
              
              // Commit the pending session ID now that stream completed successfully
              if let pending = self.pendingSessionId {
                ClaudeCodeLogger.shared.stream("Stream finished. Committing pending session ID: \(pending)")
                self.sessionManager.updateCurrentSession(id: pending)
                self.onSessionChange?(pending)
                self.pendingSessionId = nil
              } else {
                ClaudeCodeLogger.shared.stream("Stream finished. No pending session ID to commit")
              }
              
              // End any active task execution
              state.isInTaskExecution = false
              state.currentTaskGroupId = nil
              
              if state.assistantMessageCreated && !state.contentBuffer.isEmpty {
                let finalMessageId = state.currentLocalMessageId ?? messageId
                // Check if the content is just "(no content)"
                if state.contentBuffer == "(no content)" {
                  self.messageStore.removeMessage(id: finalMessageId)
                } else {
                  self.messageStore.updateMessage(
                    id: finalMessageId,
                    content: state.contentBuffer,
                    isComplete: true
                  )
                }
              } else if state.assistantMessageCreated && state.contentBuffer.isEmpty {
                // Remove empty assistant message
                let finalMessageId = state.currentLocalMessageId ?? messageId
                self.messageStore.removeMessage(id: finalMessageId)
              }
            case .failure(let error):
              self.logger.error("Stream failed with error: \(error.localizedDescription)")
              
              // Discard pending session ID since stream failed
              if let pending = self.pendingSessionId {
                // Discarding pending session ID since stream failed
                self.pendingSessionId = nil
              }
              
              // Clean up any partial messages
              if state.assistantMessageCreated {
                let finalMessageId = state.currentLocalMessageId ?? messageId
                
                // If we have partial content, mark it as incomplete with error indicator
                if !state.contentBuffer.isEmpty {
                  self.messageStore.updateMessage(
                    id: finalMessageId,
                    content: state.contentBuffer + "\n\nResponse interrupted due to error.",
                    isComplete: true
                  )
                } else {
                  // Remove empty message if no content was received
                  self.messageStore.removeMessage(id: finalMessageId)
                }
              }
              
              // Call the error handler if provided
              onError?(error)
            }
            
            // Clear the active continuation reference
            self.activeContinuation = nil
            continuation.resume()
            
            // Clean up the subscription
            self.cancellables.removeAll()
          },
          receiveValue: { [weak self] chunk in
            hasReceivedData = true // Mark that we received data
            timeoutTask?.cancel() // Cancel timeout when data arrives
            guard let self = self else { return }
            self.processChunk(chunk, messageId: messageId, state: state, firstMessageInSession: firstMessageInSession, onTokenUsageUpdate: onTokenUsageUpdate, onCostUpdate: onCostUpdate)
          }
        )
      
      if let subscription = subscription {
        subscription.store(in: &cancellables)
      }
    }
  }
  
  private func processChunk(_ chunk: ResponseChunk, messageId: UUID, state: StreamState, firstMessageInSession: String?, onTokenUsageUpdate: ((Int, Int) -> Void)?, onCostUpdate: ((Double) -> Void)?) {
    switch chunk {
    case .initSystem(let initMessage):
      handleInitSystem(initMessage, firstMessageInSession: firstMessageInSession)
      
    case .assistant(let message):
      handleAssistantMessage(message, messageId: messageId, state: state, onTokenUsageUpdate: onTokenUsageUpdate)
      
    case .user(let userMessage):
      handleUserMessage(userMessage, state: state)
      
    case .result(let resultMessage):
      handleResult(resultMessage, firstMessageInSession: firstMessageInSession, onTokenUsageUpdate: onTokenUsageUpdate, onCostUpdate: onCostUpdate)
    }
  }
  
  /// Handles initialization system messages from Claude's streaming response.
  ///
  /// This method is crucial for maintaining session continuity. It handles two scenarios:
  /// 1. Starting a new conversation when no session exists
  /// 2. Updating our local session ID when Claude returns a different one
  ///
  /// The second scenario often occurs after stream interruptions or when Claude's internal
  /// session management creates a new session. By updating our local session ID to match
  /// Claude's, we ensure subsequent messages use the correct session and avoid creating
  /// multiple separate conversations.
  ///
  /// - Parameters:
  ///   - initMessage: The initialization message containing Claude's session ID
  ///   - firstMessageInSession: Optional first message text for new sessions
  private func handleInitSystem(_ initMessage: InitSystemMessage, firstMessageInSession: String?) {
    // Parse and store discovered tools if available
    let tools = initMessage.tools
    if !tools.isEmpty {
      // Only process if tools have changed since last discovery
      if MCPToolsDiscoveryService.shared.shouldUpdateTools(from: tools) {
        let mcpServers = initMessage.mcpServers.map { (name: $0.name, status: $0.status) }
        MCPToolsDiscoveryService.shared.parseToolsFromInitMessage(tools: tools, mcpServers: mcpServers)

        // Reconcile discovered tools with stored preferences
        if let preferences = globalPreferences {
          preferences.reconcileTools(with: MCPToolsDiscoveryService.shared)
        }

        logger.info("Discovered tools from init message: \(tools.count) tools (hash changed)")
      } else {
        // Tools haven't changed, skip expensive operations
        logger.debug("Tools unchanged (hash match), skipping reconciliation")
      }
    }
    
    // Check if Claude is giving us a different session ID than what we have
    if sessionManager.currentSessionId != initMessage.sessionId {
      if sessionManager.currentSessionId == nil {
        // This is a new conversation - can update immediately since there's no previous session
        let firstMessage = firstMessageInSession ?? "New conversation"
        ClaudeCodeLogger.shared.stream("handleInit - Starting NEW session with ID: \(initMessage.sessionId)")
        let log = "Starting new session with ID: \(initMessage.sessionId)"
        logger.info("\(log)")
        let workingDirectory = getCurrentWorkingDirectory?()
        sessionManager.startNewSession(id: initMessage.sessionId, firstMessage: firstMessage, workingDirectory: workingDirectory)
        // Notify settings storage of session change
        onSessionChange?(initMessage.sessionId)
      } else {
        // Claude has created a new session ID in the chain
        // DON'T update immediately - wait for successful completion
        // Store as pending - will only commit if stream completes successfully
        ClaudeCodeLogger.shared.stream("handleInit - Claude returned different session ID. Current: \(sessionManager.currentSessionId ?? "nil"), New: \(initMessage.sessionId). Setting as pending...")
        
        // Check if this is likely a restored session scenario
        // In restored sessions, Claude doesn't know about our local session ID
        let isLikelyRestoredSession = sessionManager.currentSessionId != nil
        if isLikelyRestoredSession {
          ClaudeCodeLogger.shared.stream("handleInit - WARNING: This appears to be a restored session. Claude doesn't recognize our local ID.")
        }
        
        pendingSessionId = initMessage.sessionId
        let log = "Session chain pending: '\(sessionManager.currentSessionId ?? "nil")' → '\(initMessage.sessionId)'"
        logger.debug("\(log)")
      }
    } else {
      // Session IDs match as expected
      ClaudeCodeLogger.shared.stream("handleInit - Session ID confirmed (match): \(initMessage.sessionId)")
      let log = "Session ID confirmed: \(initMessage.sessionId)"
      logger.debug("\(log)")
    }
  }
  
  private func handleAssistantMessage(_ message: AssistantMessage, messageId: UUID, state: StreamState, onTokenUsageUpdate: ((Int, Int) -> Void)?) {
    // Process all content in the message - no need to skip based on message ID
    // since different content types (thinking, text, tools) can share the same message ID
    // in the streaming response. Each content type should be processed independently.
    
    // Check if usage data is available in the message
    let usage = message.message.usage
    // Log usage data if needed for debugging
    // logger.debug("Assistant message usage - input: \(usage.inputTokens ?? 0), output: \(usage.outputTokens)")
    if let inputTokens = usage.inputTokens {
      onTokenUsageUpdate?(inputTokens, usage.outputTokens)
    }
    
    // Check if we need to create a new message after tool use
    if state.hasProcessedToolUse && containsTextContent(message) {
      // Reset state to create a new assistant message after tool interaction
      state.assistantMessageCreated = false
      state.contentBuffer = ""
      state.currentLocalMessageId = nil
      state.hasProcessedToolUse = false
      // End task execution when we see text content
      state.isInTaskExecution = false
      state.currentTaskGroupId = nil
    }
    
    // For multi-part responses, we want to treat all assistant messages in a single
    // streaming session as one continuous message, regardless of the message IDs
    // sent by the API. This prevents multiple answer bubbles for multi-question prompts.
    
    let currentId = message.message.id
    if let msgId = currentId {
      // Only set the message ID if we haven't seen any message ID yet
      // This ensures we maintain a single message throughout the stream
      if state.currentMessageId == nil {
        state.currentMessageId = msgId
        state.currentLocalMessageId = messageId  // Use the provided messageId instead of creating new ones
      } else if state.currentLocalMessageId == nil {
        // We need a new local message ID after tool use
        state.currentLocalMessageId = UUID()
      }
    }
    
    // Track if content changed for duplicate detection
    var contentChanged = false
    
    for content in message.message.content {
      switch content {
      case .text(let textContent, _):
        // Only add content if it's not already in the buffer (prevents duplicate chunks)
        if !state.contentBuffer.contains(textContent) {
          state.contentBuffer += textContent
          contentChanged = true
        } else {
          continue
        }
        
        // Create/update assistant message only if content changed
        if !textContent.isEmpty {
          // Always use the same message ID throughout the streaming session
          // This ensures all content goes into a single message bubble
          let messageIdToUse = state.currentLocalMessageId ?? messageId
          
          if !state.assistantMessageCreated {
            let assistantMessage = MessageFactory.assistantMessage(
              id: messageIdToUse,
              content: state.contentBuffer,
              isComplete: false
            )
            messageStore.addMessage(assistantMessage)
            state.assistantMessageCreated = true
          } else if contentChanged {
            messageStore.updateMessage(
              id: messageIdToUse,
              content: state.contentBuffer,
              isComplete: false
            )
          }
        }
        
      case .toolUse(let toolUse):
        ClaudeCodeLogger.shared.stream("Handling toolUse: \(toolUse.name)")

        // Check for ExitPlanMode tool
        if toolUse.name == "ExitPlanMode" || toolUse.name == "exit_plan_mode" {
          handleExitPlanMode(toolUse, state: state)
          return
        }

        // Mark that we've processed a tool use
        state.hasProcessedToolUse = true

        // Check if this is a Task tool starting
        let isTaskTool = toolUse.name == "Task"
        if isTaskTool {
          // Start a new task group
          state.currentTaskGroupId = UUID()
          state.isInTaskExecution = true
          // Track task group for UI grouping
        }
        
        // Extract structured data from tool input
        var parameters: [String: String] = [:]
        var rawParameters: [String: String]? = nil
        
        // Check if this is an Edit, MultiEdit, or Write tool
        let needsRawParams = toolUse.name == "Edit" || toolUse.name == "MultiEdit" || toolUse.name == "Write"
        if needsRawParams {
          rawParameters = [:]
        }
        
        // Since toolUse.input is [String: MessageResponse.Content.DynamicContent],
        // we need to extract the actual values from DynamicContent
        for (key, dynamicContent) in toolUse.input {
          // Special handling for todos to preserve the formatted list
          let formattedValue: String
          if key == "todos" {
            formattedValue = formatter.formatForTodos(dynamicContent)
          } else {
            formattedValue = formatter.format(dynamicContent)
          }
          parameters[key] = formattedValue
          
          // For tools that need raw parameters
          if needsRawParams {
            if toolUse.name == "Write" && (key == "file_path" || key == "content") {
              rawParameters?[key] = formattedValue
            } else if (toolUse.name == "Edit" || toolUse.name == "MultiEdit") && (key == "old_string" || key == "new_string" || key == "file_path") {
              rawParameters?[key] = formattedValue
            } else if key == "edits" && toolUse.name == "MultiEdit" {
              // For MultiEdit's edits array, convert to JSON
              if case .array(let editsArray) = dynamicContent {
                let jsonEdits = editsArray.compactMap { item -> [String: String]? in
                  guard case .dictionary(let dict) = item else { return nil }
                  var stringDict: [String: String] = [:]
                  for (k, v) in dict {
                    if case .string(let str) = v {
                      stringDict[k] = str
                    }
                  }
                  return stringDict.isEmpty ? nil : stringDict
                }
                
                // Convert to JSON string
                if let jsonData = try? JSONSerialization.data(withJSONObject: jsonEdits),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                  rawParameters?[key] = jsonString
                } else {
                  rawParameters?[key] = formattedValue
                }
              } else {
                rawParameters?[key] = formattedValue
              }
            }
          }
          
          // Formatted value extracted for parameters
        }
        
        // Get formatted description for display
        let formattedDesc = toolUse.input.formattedDescription()
        
        let toolMessage = MessageFactory.toolUseMessage(
          toolName: toolUse.name,
          input: toolUse.input.formattedDescription(),
          toolInputData: ToolInputData(parameters: parameters, rawParameters: rawParameters),
          taskGroupId: state.currentTaskGroupId,
          isTaskContainer: isTaskTool
        )
        ClaudeCodeLogger.shared.stream("Creating tool message: type=\(toolMessage.messageType), toolName=\(toolMessage.toolName ?? "nil"), isTaskContainer=\(toolMessage.isTaskContainer)")
        messageStore.addMessage(toolMessage)
        
      case .toolResult(let toolResult):
        ClaudeCodeLogger.shared.stream("Handling toolResult")
        let resultMessage = MessageFactory.toolResultMessage(
          content: toolResult.content,
          isError: toolResult.isError == true,
          taskGroupId: state.currentTaskGroupId
        )
        ClaudeCodeLogger.shared.stream("Creating tool result message")
        messageStore.addMessage(resultMessage)
        
      case .thinking(let thinking):
        let thinkingMessage = MessageFactory.thinkingMessage(content: thinking.thinking)
        messageStore.addMessage(thinkingMessage)
        
      case .serverToolUse:
        break
        
      case .webSearchToolResult(let searchResult):
        let searchMessage = MessageFactory.webSearchMessage(resultCount: searchResult.content.count)
        messageStore.addMessage(searchMessage)
      }
    }
  }
  
  private func handleUserMessage(_ userMessage: UserMessage, state: StreamState) {
    for content in userMessage.message.content {
      switch content {
      case .text(let textContent, _):
        logger.debug("User text content: \(textContent)")
        
      case .toolResult(let toolResult):
        let resultMessage = MessageFactory.toolResultMessage(
          content: toolResult.content,
          isError: toolResult.isError == true,
          taskGroupId: state.currentTaskGroupId
        )
        messageStore.addMessage(resultMessage)
        
      default:
        break
      }
    }
  }
  
  private func handleResult(_ resultMessage: ResultMessage, firstMessageInSession: String?, onTokenUsageUpdate: ((Int, Int) -> Void)?, onCostUpdate: ((Double) -> Void)?) {
    if sessionManager.currentSessionId == nil {
      ClaudeCodeLogger.shared.stream("handleResult - No current session, starting new with ID: \(resultMessage.sessionId)")
      let firstMessage = firstMessageInSession ?? "New conversation"
      let workingDirectory = getCurrentWorkingDirectory?()
      sessionManager.startNewSession(id: resultMessage.sessionId, firstMessage: firstMessage, workingDirectory: workingDirectory)
    } else {
      ClaudeCodeLogger.shared.stream("handleResult - Result received for session: \(resultMessage.sessionId), current: \(sessionManager.currentSessionId ?? "nil")")
    }
    
    // Update token usage if available
    if let usage = resultMessage.usage {
      let log = "Token usage - input: \(usage.inputTokens), output: \(usage.outputTokens)"
      logger.info("\(log)")
      onTokenUsageUpdate?(usage.inputTokens, usage.outputTokens)
    } else {
      // No usage data in result message
    }
    
    // Update cost
    onCostUpdate?(resultMessage.totalCostUsd)
  }
  
  /// Checks if an assistant message contains text content
  private func containsTextContent(_ message: AssistantMessage) -> Bool {
    for content in message.message.content {
      if case .text(_, _) = content {
        return true
      }
    }
    return false
  }

  private func handleExitPlanMode(_ toolUse: MessageResponse.Content.ToolUse, state: StreamState) {
    ClaudeCodeLogger.shared.stream("Handling ExitPlanMode tool")

    // Extract the plan content from tool parameters
    var parameters: [String: String] = [:]
    var planContent = ""

    // Process the input dictionary to extract plan content
    for (key, dynamicContent) in toolUse.input {
      if key == "plan" {
        planContent = formatter.format(dynamicContent)
        parameters[key] = planContent
      }
    }

    // Get reference to ChatViewModel to show plan approval
    if let getter = getParentViewModel, let viewModel = getter() {
      Task { @MainActor in
        viewModel.handlePlanApproval(planContent: planContent, toolUseId: toolUse.id)
      }
    }

    // Create a tool message for the UI using the same pattern as other tools
    let toolMessage = MessageFactory.toolUseMessage(
      toolName: "ExitPlanMode",
      input: planContent.isEmpty ? "Plan approval requested" : planContent,
      toolInputData: ToolInputData(parameters: parameters, rawParameters: nil),
      taskGroupId: state.currentTaskGroupId,
      isTaskContainer: false
    )
    messageStore.addMessage(toolMessage)

    // Mark that we processed a tool use
    state.hasProcessedToolUse = true
  }

  // Callback to get parent view model - needs to be set during initialization
  private var getParentViewModel: (() -> ChatViewModel?)?

  func setParentViewModel(_ getter: @escaping () -> ChatViewModel?) {
    self.getParentViewModel = getter
  }
}
