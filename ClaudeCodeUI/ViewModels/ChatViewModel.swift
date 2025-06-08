//
//  ChatViewModel.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 5/25/25.
//

import ClaudeCodeSDK
import Foundation
import os.log

@Observable
@MainActor
public class ChatViewModel {
  
  // MARK: - Dependencies
  
  private let claudeClient: ClaudeCode
  private let messageStore = MessageStore()
  private let sessionManager = SessionManager()
  private let streamProcessor: StreamProcessor
  
  private let logger = Logger(subsystem: "com.yourcompany.ClaudeChat", category: "ChatViewModel")
  private var currentMessageId: UUID?
  
  // MARK: - Published Properties
  
  /// All messages in the conversation
  var messages: [ChatMessage] {
    messageStore.messages
  }
  
  /// Loading state
  public private(set) var isLoading: Bool = false
  
  /// Error state
  public private(set) var error: Error?
  
  /// Allowed tools for Claude
  let allowedTools = ["Bash", "LS", "Read", "WebFetch", "Batch", "TodoRead/Write", "Glob", "Grep", "Edit", "MultiEdit"]
  
  
  // MARK: - Initialization
  
  public init(claudeClient: ClaudeCode) {
    self.claudeClient = claudeClient
    self.streamProcessor = StreamProcessor(
      messageStore: messageStore,
      sessionManager: sessionManager
    )
  }
  
  // MARK: - Public Methods
  
  /// Sends a new message to Claude
  /// - Parameter text: The message text to send
  public func sendMessage(_ text: String) {
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    
    // Add user message
    let userMessage = MessageFactory.userMessage(content: text)
    messageStore.addMessage(userMessage)
    
    // Clear any previous errors
    error = nil
    
    // Store the message ID for potential assistant response
    let assistantId = UUID()
    currentMessageId = assistantId
    
    // Set loading state
    isLoading = true
    
    // Start conversation
    Task {
      do {
        if let sessionId = sessionManager.currentSessionId {
          try await continueConversation(sessionId: sessionId, prompt: text, messageId: assistantId)
        } else {
          try await startNewConversation(prompt: text, messageId: assistantId)
        }
      } catch {
        await MainActor.run {
          self.handleError(error)
        }
      }
    }
  }
  
  /// Clears the conversation history and starts a new session
  public func clearConversation() {
    messageStore.clear()
    sessionManager.clearSession()
    currentMessageId = nil
    error = nil
  }
  
  /// Cancels any ongoing requests
  public func cancelRequest() {
    claudeClient.cancel()
    isLoading = false
  }
  
  // MARK: - Private Methods
  
  private func startNewConversation(prompt: String, messageId: UUID) async throws {
    logger.debug("Starting new conversation with prompt: '\(prompt)' (length: \(prompt.count))")
    
    let options = createOptions()
    
    logger.debug("Calling runSinglePrompt with prompt: '\(prompt)'")
    
    let result = try await claudeClient.runSinglePrompt(
      prompt: prompt,
      outputFormat: .streamJson,
      options: options
    )
    
    await processResult(result, messageId: messageId)
  }
  
  private func continueConversation(sessionId: String, prompt: String, messageId: UUID) async throws {
    let options = createOptions()
    
    let result = try await claudeClient.resumeConversation(
      sessionId: sessionId,
      prompt: prompt,
      outputFormat: .streamJson,
      options: options
    )
    
    await processResult(result, messageId: messageId)
  }
  
  private func createOptions() -> ClaudeCodeOptions {
    var options = ClaudeCodeOptions()
    options.allowedTools = allowedTools
    options.verbose = true
    return options
  }
  
  private func processResult(_ result: ClaudeCodeResult, messageId: UUID) async {
    switch result {
    case .stream(let publisher):
      logger.debug("Processing stream result")
      await streamProcessor.processStream(publisher, messageId: messageId)
      logger.debug("Stream processing completed, setting isLoading to false")
      await MainActor.run {
        self.isLoading = false
        self.logger.debug("isLoading set to false")
      }
      
    default:
      await MainActor.run {
        logger.error("Expected stream result but got a different format")
        error = NSError(
          domain: "ChatViewModel",
          code: 1001,
          userInfo: [NSLocalizedDescriptionKey: "Unexpected response format"]
        )
        isLoading = false
      }
    }
  }
  
  
  private func handleError(_ error: Error) {
    logger.error("Error: \(error.localizedDescription)")
    self.error = error
    self.isLoading = false
    
    // Remove incomplete assistant message if there was an error
    if let currentMessageId = currentMessageId {
      messageStore.removeMessage(id: currentMessageId)
    }
  }
}
