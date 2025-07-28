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
  private let onSessionChange: ((String) -> Void)?
  private var cancellables = Set<AnyCancellable>()
  private let formatter = DynamicContentFormatter()
  
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
  
  init(messageStore: MessageStore, sessionManager: SessionManager, onSessionChange: ((String) -> Void)? = nil) {
    self.messageStore = messageStore
    self.sessionManager = sessionManager
    self.onSessionChange = onSessionChange
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
      let state = StreamState()
      
      publisher
        .receive(on: DispatchQueue.main)
        .sink(
          receiveCompletion: { [weak self] completion in
            guard let self = self else {
              continuation.resume()
              return
            }
            
            switch completion {
            case .finished:
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
              
              // Clean up any partial messages
              if state.assistantMessageCreated {
                let finalMessageId = state.currentLocalMessageId ?? messageId
                
                // If we have partial content, mark it as incomplete with error indicator
                if !state.contentBuffer.isEmpty {
                  self.messageStore.updateMessage(
                    id: finalMessageId,
                    content: state.contentBuffer + "\n\n⚠️ Response interrupted due to error.",
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
            
            continuation.resume()
            
            // Clean up the subscription
            self.cancellables.removeAll()
          },
          receiveValue: { [weak self] chunk in
            guard let self = self else { return }
            self.processChunk(chunk, messageId: messageId, state: state, firstMessageInSession: firstMessageInSession, onTokenUsageUpdate: onTokenUsageUpdate, onCostUpdate: onCostUpdate)
          }
        )
        .store(in: &cancellables)
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
    // Check if Claude is giving us a different session ID than what we have
    if sessionManager.currentSessionId != initMessage.sessionId {
      if sessionManager.currentSessionId == nil {
        // This is a new conversation
        let firstMessage = firstMessageInSession ?? "New conversation"
        sessionManager.startNewSession(id: initMessage.sessionId, firstMessage: firstMessage)
      } else {
        // Claude has created a new session even though we tried to resume
        // We need to update our session ID to match what Claude is using
        let log = "Claude returned different session ID. Expected: \(sessionManager.currentSessionId ?? "nil"), Got: \(initMessage.sessionId)"
        logger.warning("\(log)")
        sessionManager.updateCurrentSession(id: initMessage.sessionId)
      }
      // Notify settings storage of session change
      onSessionChange?(initMessage.sessionId)
    }
  }
  
  private func handleAssistantMessage(_ message: AssistantMessage, messageId: UUID, state: StreamState, onTokenUsageUpdate: ((Int, Int) -> Void)?) {
    // Process all content in the message - no need to skip based on message ID
    // since different content types (thinking, text, tools) can share the same message ID
    // in the streaming response. Each content type should be processed independently.
    
    // Check if usage data is available in the message
    let usage = message.message.usage
    logger.debug("Assistant message usage - input: \(usage.inputTokens ?? 0), output: \(usage.outputTokens)")
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
        // Mark that we've processed a tool use
        state.hasProcessedToolUse = true
        
        // Check if this is a Task tool starting
        let isTaskTool = toolUse.name == "Task"
        if isTaskTool {
          // Start a new task group
          state.currentTaskGroupId = UUID()
          state.isInTaskExecution = true
          logger.debug("Starting new Task group with ID: \(state.currentTaskGroupId?.uuidString ?? "nil")")
        }
        
        // Extract structured data from tool input
        var parameters: [String: String] = [:]
        var rawParameters: [String: String]? = nil
        
        // Check if this is an Edit or MultiEdit tool
        let isEditTool = toolUse.name == "Edit" || toolUse.name == "MultiEdit"
        if isEditTool {
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
          
          // For Edit tools, also store raw values
          if isEditTool {
            if key == "old_string" || key == "new_string" || key == "file_path" {
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
          
          logger.debug("Key: \(key), formatted value: \(formattedValue)")
        }
        
        // Debug logging
        logger.debug("Tool use: \(toolUse.name), parameters: \(parameters)")
        
        // Also log what formattedDescription returns
        let formattedDesc = toolUse.input.formattedDescription()
        logger.debug("FormattedDescription output: \(formattedDesc)")
        
        let toolMessage = MessageFactory.toolUseMessage(
          toolName: toolUse.name,
          input: toolUse.input.formattedDescription(),
          toolInputData: ToolInputData(parameters: parameters, rawParameters: rawParameters),
          taskGroupId: state.currentTaskGroupId,
          isTaskContainer: isTaskTool
        )
        messageStore.addMessage(toolMessage)
        
      case .toolResult(let toolResult):
        let resultMessage = MessageFactory.toolResultMessage(
          content: toolResult.content,
          isError: toolResult.isError == true,
          taskGroupId: state.currentTaskGroupId
        )
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
      let firstMessage = firstMessageInSession ?? "New conversation"
      sessionManager.startNewSession(id: resultMessage.sessionId, firstMessage: firstMessage)
    }
    
    // Update token usage if available
    if let usage = resultMessage.usage {
      logger.info("Result message usage - input: \(usage.inputTokens), output: \(usage.outputTokens)")
      onTokenUsageUpdate?(usage.inputTokens, usage.outputTokens)
    } else {
      logger.warning("No usage data in result message")
    }
    
    // Update cost
    logger.info("Result message cost: $\(String(format: "%.6f", resultMessage.totalCostUsd))")
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
}
