//
//  ChatViewModel.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 5/25/25.
//

import ClaudeCodeSDK
import Foundation
import os.log
import CustomPermissionService
import CustomPermissionServiceInterface

@Observable
@MainActor
public final class ChatViewModel {
  
  // MARK: - Dependencies
  
  var claudeClient: ClaudeCode
  let sessionManager: SessionManager
  let sessionStorage: SessionStorageProtocol
  let settingsStorage: SettingsStorage
  let globalPreferences: GlobalPreferencesStorage
  let customPermissionService: CustomPermissionService
  private let onSessionChange: ((String) -> Void)?
  
  private let streamProcessor: StreamProcessor
  private let messageStore = MessageStore()
  private var firstMessageInSession: String?
  
  // Session isolation: track if we're in the middle of switching sessions
  private var isSwitchingSession = false
  
  // Stream cancellation: track if user cancelled the current stream
  private var isCancelled = false
  
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
  public var error: Error?
  
  /// Current project path (observable)
  public private(set) var projectPath: String = ""
  
  /// Streaming metrics
  public private(set) var streamingStartTime: Date?
  public private(set) var currentInputTokens: Int = 0
  public private(set) var currentOutputTokens: Int = 0
  public private(set) var currentCostUSD: Double = 0.0
  
  /// Tracks whether a session has started (first message sent)
  public private(set) var hasSessionStarted: Bool = false
  
  
  // MARK: - Initialization
  
  init(
    claudeClient: ClaudeCode,
    sessionStorage: SessionStorageProtocol,
    settingsStorage: SettingsStorage,
    globalPreferences: GlobalPreferencesStorage,
    customPermissionService: CustomPermissionService,
    onSessionChange: ((String) -> Void)? = nil)
  {
    self.claudeClient = claudeClient
    self.sessionStorage = sessionStorage
    self.settingsStorage = settingsStorage
    self.globalPreferences = globalPreferences
    self.customPermissionService = customPermissionService
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
  /// - Parameters:
  ///   - text: The message text to send
  ///   - context: Optional context to include with the message
  ///   - hiddenContext: Optional hidden context to send to API but not display
  ///   - codeSelections: Optional code selections to display in UI
  ///   - attachments: Optional file attachments (images, PDFs, etc.)
  public func sendMessage(_ text: String, context: String? = nil, hiddenContext: String? = nil, codeSelections: [TextSelection]? = nil, attachments: [FileAttachment]? = nil) {
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    
    // Reset cancellation flag for new message
    isCancelled = false
    
    // Store first message if this is a new session
    if sessionManager.currentSessionId == nil {
      firstMessageInSession = text
    }
    
    // Build message content for display (just the user's text)
    let displayContent = text
    
    // Build message content for API (with all context and attachments)
    var apiContentParts: [String] = [text]
    
    // Add image paths to the message text for Claude Code
    if let attachments = attachments, !attachments.isEmpty,
       let imagePaths = AttachmentProcessor.formatImagePathsForMessage(attachments) {
      apiContentParts.insert(imagePaths, at: 1)
    }
    
    // Add context if present
    if let context = context, !context.isEmpty {
      apiContentParts.append("--- Context ---\n\(context)")
    }
    
    // Add hidden context if present
    if let hiddenContext = hiddenContext, !hiddenContext.isEmpty {
      apiContentParts.append(hiddenContext)
    }
    
    // Add attachments metadata in XML format
    if let attachments = attachments, !attachments.isEmpty {
      let attachmentContent = AttachmentProcessor.formatAttachmentsForXML(attachments)
      if !attachmentContent.isEmpty {
        apiContentParts.append(attachmentContent)
      }
    }
    
    let apiContent = apiContentParts.joined(separator: "\n\n")
    
    // Add user message with code selections and attachments for UI display
    let userMessage = MessageFactory.userMessage(content: displayContent, codeSelections: codeSelections, attachments: attachments)
    messageStore.addMessage(userMessage)
    
    // Clear any previous errors
    error = nil
    
    // Store the message ID for potential assistant response
    let assistantId = UUID()
    currentMessageId = assistantId
    
    // Set loading state and initialize streaming metrics
    isLoading = true
    streamingStartTime = Date()
    currentInputTokens = 0
    currentOutputTokens = 0
    currentCostUSD = 0.0
    
    // Track session start
    if !hasSessionStarted {
      hasSessionStarted = true
      // Path will be saved when the session is created in StreamProcessor
    }
    
    // Start conversation
    Task {
      do {
        if let sessionId = sessionManager.currentSessionId {
          logger.debug("Continuing conversation with session: \(sessionId)")
          try await continueConversation(sessionId: sessionId, prompt: apiContent, messageId: assistantId)
        } else {
          logger.debug("No current session, starting new conversation")
          try await startNewConversation(prompt: apiContent, messageId: assistantId)
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
    hasSessionStarted = false
  }
  
  /// Starts a new session without affecting the current session
  public func startNewSession() {
    // Save current session messages before starting new
    Task {
      await saveCurrentSessionMessages()
      
      // After saving, clear the UI to prepare for new session
      await MainActor.run {
        // Clear only the local state to prepare for a new session
        self.messageStore.clear()
        self.currentMessageId = nil
        self.error = nil
        self.firstMessageInSession = nil
        self.hasSessionStarted = false
        
        // Clear the current path to force user to select a new one
        self.settingsStorage.clearProjectPath()
        self.claudeClient.configuration.workingDirectory = nil
        self.projectPath = ""
        
        // Clear the session manager's current session
        self.sessionManager.clearSession()
        
        // A new session will be created when the user sends their first message
        // Claude will provide the session ID
      }
    }
  }
  
  /// Saves the current session's messages to storage
  private func saveCurrentSessionMessages() async {
    guard let sessionId = currentSessionId else { return }
    
    let messages = messageStore.getAllMessages()
    do {
      try await sessionStorage.updateSessionMessages(id: sessionId, messages: messages)
      logger.debug("Saved \(messages.count) messages for current session \(sessionId)")
    } catch {
      logger.error("Failed to save messages for session \(sessionId): \(error)")
    }
  }
  
  /// Cancels any ongoing requests
  public func cancelRequest() {
    // Set cancellation flag instead of terminating the process
    isCancelled = true
    
    // Cancel the stream subscription only (not the process)
    streamProcessor.cancelStream()
    
    // Clean up UI state
    isLoading = false
    streamingStartTime = nil
    
    // Simply mark the last message as cancelled
    let messages = messageStore.getAllMessages()
    if let lastMessage = messages.last {
      messageStore.markMessageAsCancelled(id: lastMessage.id)
    }
  }
  
  /// Updates token usage from streaming response
  public func updateTokenUsage(inputTokens: Int, outputTokens: Int) {
    logger.info("Updating token usage - input: \(inputTokens), output: \(outputTokens)")
    currentInputTokens = inputTokens
    currentOutputTokens = outputTokens
  }
  
  /// Updates cost from streaming response
  public func updateCost(_ costUSD: Double) {
    logger.info("Updating cost: $\(String(format: "%.6f", costUSD))")
    currentCostUSD = costUSD
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
    
    // Load and set the session's stored path
    if let sessionPath = settingsStorage.getProjectPath(forSessionId: sessionId) {
      // Update ClaudeClient configuration
      claudeClient.configuration.workingDirectory = sessionPath
      // Update the observable project path
      projectPath = sessionPath
      logger.debug("Loaded path '\(sessionPath)' for selected session '\(sessionId)'")
    } else {
      // No stored path for this session
      claudeClient.configuration.workingDirectory = nil
      projectPath = ""
      logger.debug("No stored path for selected session '\(sessionId)'")
    }
    
    // We would load previous messages here if we had that capability
    // For now, we're just switching to the session
    
    // Clear any errors
    error = nil
  }
  
  /// Resumes an existing session with optional initial prompt
  public func resumeSession(id: String, initialPrompt: String? = nil) async {
    // Ensure sessions are loaded and validate
    guard await validateSessionExists(id: id) else { return }
    
    logger.debug("Resuming session: \(id)")
    
    // Prepare session for resumption
    prepareSessionForResumption(id: id)
    
    // Load messages for this session
    do {
      if let session = try await sessionStorage.getSession(id: id) {
        messageStore.loadMessages(session.messages)
        logger.debug("Loaded \(session.messages.count) messages for session \(id)")
      }
    } catch {
      logger.error("Failed to load messages for session \(id): \(error)")
    }
    
    // Setup for conversation resumption
    let assistantId = UUID()
    setupConversationResumption(assistantId: assistantId, initialPrompt: initialPrompt)
    
    // Resume the conversation
    await performSessionResumption(id: id, initialPrompt: initialPrompt, assistantId: assistantId)
  }
  
  /// Deletes a session
  public func deleteSession(id: String) async {
    // If deleting the current session, clear the chat interface and working directory
    if currentSessionId == id {
      clearConversation()
      // Clear the working directory as well
      settingsStorage.clearProjectPath()
      claudeClient.configuration.workingDirectory = nil
      projectPath = ""
    }
    
    // Delete from storage
    await sessionManager.deleteSession(id: id)
  }
  
  /// Switches to a different session in the same window
  public func switchToSession(_ sessionId: String) async {
    // If switching to the same session, do nothing
    guard sessionId != currentSessionId else { return }
    
    // Prevent concurrent session switches
    guard !isSwitchingSession else {
      logger.warning("Already switching sessions, ignoring switch to \(sessionId)")
      return
    }
    
    isSwitchingSession = true
    defer { isSwitchingSession = false }
    
    logger.debug("Switching to session: \(sessionId)")
    
    // Cancel any ongoing requests first
    if isLoading {
      cancelRequest()
      // Small delay to ensure cancellation completes
      try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
    }
    
    // Save current session messages before switching
    if let currentId = currentSessionId {
      let currentMessages = messageStore.getAllMessages()
      do {
        try await sessionStorage.updateSessionMessages(id: currentId, messages: currentMessages)
        logger.debug("Saved \(currentMessages.count) messages for session \(currentId)")
      } catch {
        logger.error("Failed to save messages for session \(currentId): \(error)")
      }
    }
    
    // Clear current conversation
    clearConversation()
    
    // Resume the selected session
    await resumeSession(id: sessionId)
  }
  
  // MARK: - Session Resumption Helpers
  
  private func validateSessionExists(id: String) async -> Bool {
    // First ensure sessions are loaded
    if sessions.isEmpty {
      await loadSessions()
    }
    
    // Verify the session exists
    guard sessions.contains(where: { $0.id == id }) else {
      logger.error("Session \(id) not found in stored sessions")
      return false
    }
    
    return true
  }
  
  private func prepareSessionForResumption(id: String) {
    // Clear current messages
    messageStore.clear()
    
    // Set the session ID BEFORE any async operations
    sessionManager.selectSession(id: id)
    
    // Notify settings storage of session change
    onSessionChange?(id)
    
    // Load and set the session's stored path
    if let sessionPath = settingsStorage.getProjectPath(forSessionId: id) {
      // Update ClaudeClient configuration
      claudeClient.configuration.workingDirectory = sessionPath
      // Update the observable project path
      projectPath = sessionPath
      logger.debug("Loaded path '\(sessionPath)' for resumed session '\(id)'")
    } else {
      // No stored path for this session
      claudeClient.configuration.workingDirectory = nil
      projectPath = ""
      logger.debug("No stored path for resumed session '\(id)'")
    }
    
    // Clear any errors
    error = nil
    
    // Mark session as already started since we're resuming
    hasSessionStarted = true
    
    // Update last accessed time
    sessionManager.updateLastAccessed(id: id)
  }
  
  private func setupConversationResumption(assistantId: UUID, initialPrompt: String?) {
    // Only set loading state if we have a prompt to send
    if let prompt = initialPrompt, !prompt.isEmpty {
      isLoading = true
      currentMessageId = assistantId
      
      // Add the user message
      let userMessage = MessageFactory.userMessage(content: prompt)
      messageStore.addMessage(userMessage)
    } else {
      // Just switching sessions, no loading state
      currentMessageId = nil
    }
  }
  
  private func performSessionResumption(id: String, initialPrompt: String?, assistantId: UUID) async {
    // Only make API call if there's an actual prompt to send
    guard let prompt = initialPrompt, !prompt.isEmpty else {
      // Just switch to the session without making an API call
      logger.debug("Switching to session \(id) without sending a message")
      
      // Mark as not loading since we're not making an API call
      await MainActor.run {
        self.isLoading = false
        self.streamingStartTime = nil
      }
      return
    }
    
    do {
      // Resume the conversation with the provided prompt
      let options = createOptions()
      let result = try await claudeClient.resumeConversation(
        sessionId: id,
        prompt: prompt,
        outputFormat: .streamJson,
        options: options
      )
      
      await processResult(result, messageId: assistantId)
    } catch {
      await handleSessionResumptionError(error, sessionId: id)
    }
  }
  
  private func handleSessionResumptionError(_ error: Error, sessionId: String) async {
    logger.error("Failed to resume session \(sessionId): \(error.localizedDescription)")
    
    await MainActor.run {
      self.isLoading = false
      self.streamingStartTime = nil
      
      // Check if it's a "conversation not found" error
      let errorMessage = error.localizedDescription.lowercased()
      if errorMessage.contains("no conversation") || errorMessage.contains("not found") {
        // Session exists in our storage but not in Claude
        // This is expected after app restart - Claude sessions don't persist
        logger.info("Session \(sessionId) exists locally but not in Claude. Continuing with local history.")
        self.error = nil
        
        // Keep the session active with its message history
        // User can continue the conversation, and Claude will create a new backend session
      } else {
        // Some other error
        self.handleError(error)
      }
    }
  }
  
  // MARK: - Private Methods
  
  private func startNewConversation(prompt: String, messageId: UUID) async throws {
    let options = createOptions()
    
    let result = try await claudeClient.runSinglePrompt(
      prompt: prompt,
      outputFormat: .streamJson,
      options: options
    )
    
    await processResult(result, messageId: messageId)
  }
  
  private func continueConversation(sessionId: String, prompt: String, messageId: UUID) async throws {
    let options = createOptions()
    
    do {
      let result = try await claudeClient.resumeConversation(
        sessionId: sessionId,
        prompt: prompt,
        outputFormat: .streamJson,
        options: options
      )
      
      // Pass the expected session ID to handle mismatches
      await processResult(result, messageId: messageId)
    } catch {
      // Check if it's a session not found error
      let errorMessage = error.localizedDescription.lowercased()
      if errorMessage.contains("no conversation") || errorMessage.contains("not found") {
        logger.info("Claude doesn't recognize session \(sessionId), starting new conversation")
        
        // Start a new conversation instead
        try await startNewConversation(prompt: prompt, messageId: messageId)
      } else {
        throw error
      }
    }
  }
  
  private func createOptions() -> ClaudeCodeOptions {
    var options = ClaudeCodeOptions()
    
    // Start with the allowed tools from preferences
    var allowedTools = globalPreferences.allowedTools
    
    // Always ensure the approval tool is in the allowed list
    let approvalToolName = "mcp__approval_server__approval_prompt"
    if !allowedTools.contains(approvalToolName) {
      print("[ChatViewModel] Adding approval tool to allowed tools: \(approvalToolName)")
      allowedTools.append(approvalToolName)
    }
    
    options.allowedTools = allowedTools
    options.maxTurns = globalPreferences.maxTurns
    if !globalPreferences.systemPrompt.isEmpty {
      options.systemPrompt = globalPreferences.systemPrompt
    }
    if !globalPreferences.appendSystemPrompt.isEmpty {
      options.appendSystemPrompt = globalPreferences.appendSystemPrompt
    }
    
    // Configure MCP with custom permission service integration
    let mcpHelper = ApprovalMCPHelper(permissionService: customPermissionService)
    
    if !globalPreferences.mcpConfigPath.isEmpty {
      print("[MCP] Setting mcpConfigPath in options: \(globalPreferences.mcpConfigPath)")
      options.mcpConfigPath = globalPreferences.mcpConfigPath
      
      // Also configure approval tool integration
      mcpHelper.configureOptions(&options)
    } else {
      print("[MCP] No mcpConfigPath found in settings, configuring approval tool only")
      // Configure just the approval tool
      mcpHelper.configureOptions(&options)
    }
    
    print("[CustomPermission] Custom permission service integration configured")
    print("[ChatViewModel] Final allowed tools: \(options.allowedTools ?? [])")
    return options
  }
  
  private func processResult(_ result: ClaudeCodeResult, messageId: UUID) async {
    switch result {
    case .stream(let publisher):
      await streamProcessor.processStream(
        publisher,
        messageId: messageId,
        firstMessageInSession: firstMessageInSession,
        onError: { [weak self] error in
          Task { @MainActor in
            self?.handleError(error)
          }
        },
        onTokenUsageUpdate: { [weak self] inputTokens, outputTokens in
          Task { @MainActor in
            self?.updateTokenUsage(inputTokens: inputTokens, outputTokens: outputTokens)
          }
        },
        onCostUpdate: { [weak self] costUSD in
          Task { @MainActor in
            self?.updateCost(costUSD)
          }
        }
      )
      await MainActor.run {
        self.isLoading = false
        self.streamingStartTime = nil
        // Clear first message after it's been saved
        self.firstMessageInSession = nil
      }
      
      // Save messages after streaming completes
      await saveCurrentSessionMessages()
      
    default:
      await MainActor.run {
        error = NSError(
          domain: "ChatViewModel",
          code: 1001,
          userInfo: [NSLocalizedDescriptionKey: "Unexpected response format"]
        )
        isLoading = false
        streamingStartTime = nil
      }
    }
  }
  
  
  func handleError(_ error: Error) {
    logger.error("handleError called with: \(error.localizedDescription)")
    self.error = error
    self.isLoading = false
    self.streamingStartTime = nil
    
    // Remove incomplete assistant message if there was an error
    if let currentMessageId = currentMessageId {
      messageStore.removeMessage(id: currentMessageId)
    }
  }
}

