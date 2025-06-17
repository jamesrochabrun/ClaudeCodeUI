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
    firstMessageInSession: String? = nil
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
              self.logger.debug("Stream completed successfully")
              if state.assistantMessageCreated && !state.contentBuffer.isEmpty {
                let finalMessageId = state.currentLocalMessageId ?? messageId
                // Check if the content is just "(no content)"
                if state.contentBuffer == "(no content)" {
                  self.messageStore.removeMessage(id: finalMessageId)
                  self.logger.debug("Removed assistant message with only '(no content)' placeholder")
                } else {
                  self.messageStore.updateMessage(
                    id: finalMessageId,
                    content: state.contentBuffer,
                    isComplete: true
                  )
                  self.logger.debug("Updated assistant message as complete")
                }
              } else if state.assistantMessageCreated && state.contentBuffer.isEmpty {
                // Remove empty assistant message
                let finalMessageId = state.currentLocalMessageId ?? messageId
                self.messageStore.removeMessage(id: finalMessageId)
                self.logger.debug("Removed empty assistant message")
              }
            case .failure(let error):
              self.logger.error("Stream failed: \(error.localizedDescription)")
            }
            
            self.logger.debug("Resuming continuation")
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
  
  private func handleInitSystem(_ initMessage: InitSystemMessage, firstMessageInSession: String?) {
    if sessionManager.currentSessionId == nil {
      let firstMessage = firstMessageInSession ?? "New conversation"
      sessionManager.startNewSession(id: initMessage.sessionId, firstMessage: firstMessage)
      logger.debug("Started new session: \(initMessage.sessionId)")
      // Notify settings storage of new session
      onSessionChange?(initMessage.sessionId)
    } else {
      logger.debug("Continuing with new session ID: \(initMessage.sessionId)")
    }
  }
  
  private func handleAssistantMessage(_ message: AssistantMessage, messageId: UUID, state: StreamState) {
    // Process all content in the message - no need to skip based on message ID
    // since different content types (thinking, text, tools) can share the same message ID
    // in the streaming response. Each content type should be processed independently.
    
    let currentId = message.message.id
    if let msgId = currentId {
      logger.debug("Processing assistant message with ID: \(msgId)")
      
      // Reset content buffer if this is a new message ID
      if state.currentMessageId != msgId {
        state.contentBuffer = ""
        state.assistantMessageCreated = false
        state.currentMessageId = msgId
        state.currentLocalMessageId = UUID()
        logger.debug("New message ID detected, resetting content buffer")
      }
    }
    
    // Track if content changed for duplicate detection
    var contentChanged = false
    
    for content in message.message.content {
      switch content {
      case .text(let textContent, _):
        logger.debug("Received text content: '\(textContent)' (length: \(textContent.count))")
        
        // Only add content if it's not already in the buffer (prevents duplicate chunks)
        if !state.contentBuffer.contains(textContent) {
          state.contentBuffer += textContent
          contentChanged = true
          logger.debug("Added new content to buffer")
        } else {
          logger.debug("Skipping duplicate text content chunk")
          continue
        }
        
        // Create/update assistant message only if content changed
        if !textContent.isEmpty {
          // Use the local UUID for this specific Claude message
          let messageIdToUse = state.currentLocalMessageId ?? messageId
          
          if !state.assistantMessageCreated {
            let assistantMessage = MessageFactory.assistantMessage(
              id: messageIdToUse,
              content: state.contentBuffer,
              isComplete: false
            )
            messageStore.addMessage(assistantMessage)
            state.assistantMessageCreated = true
            logger.debug("Created assistant message with content: '\(state.contentBuffer.prefix(50))...'")
          } else if contentChanged {
            messageStore.updateMessage(
              id: messageIdToUse,
              content: state.contentBuffer,
              isComplete: false
            )
            logger.debug("Updated assistant message with content: '\(state.contentBuffer.prefix(50))...'")
          }
        }
        
      case .toolUse(let toolUse):
        let toolMessage = MessageFactory.toolUseMessage(
          toolName: toolUse.name,
          input: toolUse.input.formattedDescription()
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
    
    if state.contentBuffer.isEmpty && !state.assistantMessageCreated {
      logger.debug("Assistant message contained no text content (likely only tool use)")
    }
  }
  
  private func handleUserMessage(_ userMessage: UserMessage) {
    logger.info("Received user message in stream for session: \(userMessage.sessionId)")
    
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
        logger.debug("Received other content type in user message")
      }
    }
  }
  
  private func handleResult(_ resultMessage: ResultMessage, firstMessageInSession: String?) {
    if sessionManager.currentSessionId == nil {
      let firstMessage = firstMessageInSession ?? "New conversation"
      sessionManager.startNewSession(id: resultMessage.sessionId, firstMessage: firstMessage)
    }
    logger.info("Completed response for session: \(resultMessage.sessionId)")
  }
}
