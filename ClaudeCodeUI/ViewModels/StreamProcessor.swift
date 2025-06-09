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
class StreamProcessor {
  private let logger = Logger(subsystem: "com.ClaudeCodeUI.ClaudeChat", category: "StreamProcessor")
  private let messageStore: MessageStore
  private let sessionManager: SessionManager
  private var cancellables = Set<AnyCancellable>()
  
  // Stream state holder
  private class StreamState {
    var contentBuffer = ""
    var assistantMessageCreated = false
    var processedMessageIds = Set<String>()  // Track processed message IDs to avoid duplicates
  }
  
  init(messageStore: MessageStore, sessionManager: SessionManager) {
    self.messageStore = messageStore
    self.sessionManager = sessionManager
  }
  
  func processStream(
    _ publisher: AnyPublisher<ResponseChunk, Error>,
    messageId: UUID
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
                // Check if the content is just "(no content)"
                if state.contentBuffer == "(no content)" {
                  self.messageStore.removeMessage(id: messageId)
                  self.logger.debug("Removed assistant message with only '(no content)' placeholder")
                } else {
                  self.messageStore.updateMessage(
                    id: messageId,
                    content: state.contentBuffer,
                    isComplete: true
                  )
                  self.logger.debug("Updated assistant message as complete")
                }
              } else if state.assistantMessageCreated && state.contentBuffer.isEmpty {
                // Remove empty assistant message
                self.messageStore.removeMessage(id: messageId)
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
            self.processChunk(chunk, messageId: messageId, state: state)
          }
        )
        .store(in: &cancellables)
    }
  }
  
  private func processChunk(_ chunk: ResponseChunk, messageId: UUID, state: StreamState) {
    switch chunk {
    case .initSystem(let initMessage):
      handleInitSystem(initMessage)
      
    case .assistant(let message):
      handleAssistantMessage(message, messageId: messageId, state: state)
      
    case .user(let userMessage):
      handleUserMessage(userMessage)
      
    case .result(let resultMessage):
      handleResult(resultMessage)
    }
  }
  
  private func handleInitSystem(_ initMessage: InitSystemMessage) {
    if sessionManager.currentSessionId == nil {
      sessionManager.startNewSession(id: initMessage.sessionId)
      logger.debug("Started new session: \(initMessage.sessionId)")
    } else {
      logger.debug("Continuing with new session ID: \(initMessage.sessionId)")
    }
  }
  
  private func handleAssistantMessage(_ message: AssistantMessage, messageId: UUID, state: StreamState) {
    // Check if we've already processed this exact message ID to avoid duplicates
    if let messageId = message.message.id {
      if state.processedMessageIds.contains(messageId) {
        logger.debug("Skipping duplicate assistant message with ID: \(messageId)")
        return
      }
      
      // Mark this message as processed
      state.processedMessageIds.insert(messageId)
    }
    
    for content in message.message.content {
      switch content {
      case .text(let textContent, _):
        logger.debug("Received text content: '\(textContent)' (length: \(textContent.count))")
        
        state.contentBuffer += textContent
        
        // Create/update assistant message
        if !textContent.isEmpty {
          if !state.assistantMessageCreated {
            let assistantMessage = MessageFactory.assistantMessage(
              id: messageId,
              content: state.contentBuffer,
              isComplete: false
            )
            messageStore.addMessage(assistantMessage)
            state.assistantMessageCreated = true
            logger.debug("Created assistant message with content: '\(state.contentBuffer.prefix(50))...'")
          } else {
            messageStore.updateMessage(
              id: messageId,
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
  
  private func handleResult(_ resultMessage: ResultMessage) {
    sessionManager.startNewSession(id: resultMessage.sessionId)
    logger.info("Completed response for session: \(resultMessage.sessionId)")
  }
}
