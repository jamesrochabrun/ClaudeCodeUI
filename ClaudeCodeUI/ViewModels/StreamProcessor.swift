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
    onError: ((Error) -> Void)? = nil
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
            self.processChunk(chunk, messageId: messageId, state: state, firstMessageInSession: firstMessageInSession)
          }
        )
        .store(in: &cancellables)
    }
  }
  
  private func processChunk(_ chunk: ResponseChunk, messageId: UUID, state: StreamState, firstMessageInSession: String?) {
    switch chunk {
    case .initSystem(let initMessage):
      handleInitSystem(initMessage, firstMessageInSession: firstMessageInSession)
      
    case .assistant(let message):
      handleAssistantMessage(message, messageId: messageId, state: state)
      
    case .user(let userMessage):
      handleUserMessage(userMessage)
      
    case .result(let resultMessage):
      handleResult(resultMessage, firstMessageInSession: firstMessageInSession)
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
  
  private func handleAssistantMessage(_ message: AssistantMessage, messageId: UUID, state: StreamState) {
    // Process all content in the message - no need to skip based on message ID
    // since different content types (thinking, text, tools) can share the same message ID
    // in the streaming response. Each content type should be processed independently.
    
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
        // Extract structured data from tool input
        var parameters: [String: String] = [:]
        
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
          toolInputData: ToolInputData(parameters: parameters)
        )
        messageStore.addMessage(toolMessage)
        
      case .toolResult(let toolResult):
        let resultMessage = MessageFactory.toolResultMessage(
          content: toolResult.content,
          isError: toolResult.isError == true
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
  
  private func handleUserMessage(_ userMessage: UserMessage) {
    for content in userMessage.message.content {
      switch content {
      case .text(let textContent, _):
        logger.debug("User text content: \(textContent)")
        
      case .toolResult(let toolResult):
        let resultMessage = MessageFactory.toolResultMessage(
          content: toolResult.content,
          isError: toolResult.isError == true
        )
        messageStore.addMessage(resultMessage)
        
      default:
        break
      }
    }
  }
  
  private func handleResult(_ resultMessage: ResultMessage, firstMessageInSession: String?) {
    if sessionManager.currentSessionId == nil {
      let firstMessage = firstMessageInSession ?? "New conversation"
      sessionManager.startNewSession(id: resultMessage.sessionId, firstMessage: firstMessage)
    }
  }
}
