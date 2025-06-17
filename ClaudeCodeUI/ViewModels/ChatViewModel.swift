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
public final class ChatViewModel {
  
  // MARK: - Dependencies
  
  var claudeClient: ClaudeCode
  let sessionManager: SessionManager
  let sessionStorage: SessionStorageProtocol
  let settingsStorage: SettingsStorage
  private let onSessionChange: ((String) -> Void)?
  
  private let streamProcessor: StreamProcessor
  private let messageStore = MessageStore()
  private var firstMessageInSession: String?
  
  /// Sessions loading state
  public var isLoadingSessions: Bool {
    sessionManager.isLoadingSessions
  }
  
  /// Sessions error state
  public var sessionsError: Error? {
    sessionManager.sessionsError
  }
  
  private let logger = Logger(subsystem: "com.yourcompany.ClaudeChat", category: "ChatViewModel")
  private var currentMessageId: UUID?
  
  // MARK: - Published Properties
  
  /// All messages in the conversation
  var messages: [ChatMessage] {
    messageStore.messages
  }
  
  /// All available sessions
  var sessions: [StoredSession] {
    sessionManager.sessions
  }
  
  /// Current session ID
  var currentSessionId: String? {
    sessionManager.currentSessionId
  }
  
  /// Loading state
  public private(set) var isLoading: Bool = false
  
  /// Error state
  public private(set) var error: Error?
  
  /// Current project path (observable)
  public private(set) var projectPath: String = ""
  
  
  // MARK: - Initialization
  
  init(claudeClient: ClaudeCodeClient, sessionStorage: SessionStorageProtocol, settingsStorage: SettingsStorage, onSessionChange: ((String) -> Void)? = nil) {
    self.claudeClient = claudeClient
    self.sessionStorage = sessionStorage
    self.settingsStorage = settingsStorage
    self.onSessionChange = onSessionChange
    self.sessionManager = SessionManager(sessionStorage: sessionStorage)
    self.streamProcessor = StreamProcessor(
      messageStore: messageStore,
      sessionManager: sessionManager,
      onSessionChange: onSessionChange
    )
    
    // Load sessions on initialization
    Task {
      await loadSessions()
    }
    
    // Initialize project path
    self.projectPath = settingsStorage.projectPath
  }
  
  /// Updates the project path when settings change
  public func refreshProjectPath() {
    projectPath = settingsStorage.projectPath
  }
  
  // MARK: - Public Methods
  
  /// Sends a new message to Claude
  /// - Parameter text: The message text to send
  public func sendMessage(_ text: String) {
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    
    // Store first message if this is a new session
    if sessionManager.currentSessionId == nil {
      firstMessageInSession = text
    }
    
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
          logger.debug("Continuing conversation with session: \(sessionId)")
          try await continueConversation(sessionId: sessionId, prompt: text, messageId: assistantId)
        } else {
          logger.debug("No current session, starting new conversation")
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
    firstMessageInSession = nil
  }
  
  /// Cancels any ongoing requests
  public func cancelRequest() {
    claudeClient.cancel()
    isLoading = false
  }
  
  /// Loads all available sessions
  public func loadSessions() async {
    await sessionManager.fetchSessions()
  }
  
  /// Selects an existing session (without resuming)
  public func selectSession(id: String) {
    guard let sessionId = sessions.first(where: { $0.id == id })?.id else { return }
    
    // Notify settings storage of session change
    onSessionChange?(sessionId)
    
    // Clear current messages
    messageStore.clear()
    
    // Set the session ID
    sessionManager.selectSession(id: sessionId)
    
    // We would load previous messages here if we had that capability
    // For now, we're just switching to the session
    
    // Clear any errors
    error = nil
  }
  
  /// Resumes an existing session with optional initial prompt
  public func resumeSession(id: String, initialPrompt: String? = nil) async {
    // First ensure sessions are loaded
    if sessions.isEmpty {
      await loadSessions()
    }
    
    // Verify the session exists
    guard sessions.contains(where: { $0.id == id }) else {
      logger.error("Session \(id) not found in stored sessions")
      return
    }
    
    logger.debug("Resuming session: \(id)")
    
    // Clear current messages
    messageStore.clear()
    
    // Set the session ID BEFORE any async operations
    sessionManager.selectSession(id: id)
    
    // Notify settings storage of session change
    onSessionChange?(id)
    
    // Clear any errors
    error = nil
    
    // Update last accessed time
    sessionManager.updateLastAccessed(id: id)
    
    // Resume the conversation - even with empty prompt to load history
    isLoading = true
    let assistantId = UUID()
    currentMessageId = assistantId
    
    // If we have an initial prompt, add it as a user message
    if let prompt = initialPrompt {
      let userMessage = MessageFactory.userMessage(content: prompt)
      messageStore.addMessage(userMessage)
    }
    
    do {
      // Resume the conversation with or without a prompt
      let options = createOptions()
      let result = try await claudeClient.resumeConversation(
        sessionId: id,
        prompt: initialPrompt ?? "",
        outputFormat: .streamJson,
        options: options
      )
      
      await processResult(result, messageId: assistantId)
    } catch {
      await MainActor.run {
        self.handleError(error)
      }
    }
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
    options.allowedTools = settingsStorage.getAllowedTools()
    options.verbose = settingsStorage.getVerboseMode()
    options.maxTurns = settingsStorage.getMaxTurns()
    if let systemPrompt = settingsStorage.getSystemPrompt() {
      options.systemPrompt = systemPrompt
    }
    if let appendSystemPrompt = settingsStorage.getAppendSystemPrompt() {
      options.appendSystemPrompt = appendSystemPrompt
    }
    return options
  }
  
  private func processResult(_ result: ClaudeCodeResult, messageId: UUID) async {
    switch result {
    case .stream(let publisher):
      logger.debug("Processing stream result")
      await streamProcessor.processStream(publisher, messageId: messageId, firstMessageInSession: firstMessageInSession)
      logger.debug("Stream processing completed, setting isLoading to false")
      await MainActor.run {
        self.isLoading = false
        self.logger.debug("isLoading set to false")
        // Clear first message after it's been saved
        self.firstMessageInSession = nil
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
