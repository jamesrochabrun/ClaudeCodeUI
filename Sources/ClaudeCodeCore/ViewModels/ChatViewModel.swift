//
//  ChatViewModel.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 5/25/25.
//

import ClaudeCodeSDK
import Foundation
import os.log
import CCCustomPermissionService
import CCCustomPermissionServiceInterface

@Observable
@MainActor
public final class ChatViewModel {
  
  // MARK: - Dependencies
  
  // Problem, row is not collapsing on deny /approve
  
  /// The Claude API client for sending messages and receiving responses from Claude
  var claudeClient: ClaudeCode
  
  /// Manages chat sessions including creation, selection, and lifecycle
  let sessionManager: SessionManager
  
  /// Protocol for persisting session data to disk (messages, metadata)
  let sessionStorage: SessionStorageProtocol
  
  /// Stores application settings like project paths and session-specific configurations
  let settingsStorage: SettingsStorage
  
  /// Global user preferences including allowed tools, max turns, and system prompts
  let globalPreferences: GlobalPreferencesStorage
  
  /// Service for handling custom tool permission requests and user approvals
  let customPermissionService: CustomPermissionService
  
  /// Optional callback invoked when session changes, used for external state synchronization
  private let onSessionChange: ((String) -> Void)?
  
  /// Controls whether this view model should manage sessions (load, save, switch, etc.)
  /// Set to false when using ChatScreen directly without RootView to avoid unnecessary session operations
  public let shouldManageSessions: Bool
  
  private let streamProcessor: StreamProcessor
  private let messageStore = MessageStore()
  private var firstMessageInSession: String?
  
  // Session isolation: track if we're in the middle of switching sessions
  private var isSwitchingSession = false
  
  // Stream cancellation: track if user cancelled the current stream
  private var isCancelled = false
  
  // Track expansion states for each message to persist across view recreations
  var messageExpansionStates: [UUID: Bool] = [:]
  
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
  
  /// Active session ID (includes pending session during streaming)
  /// This returns the session ID that Claude is actively using, which may be
  /// different from currentSessionId during streaming operations
  var activeSessionId: String? {
    streamProcessor.activeSessionId
  }

  /// Returns all messages currently in memory
  public func getCurrentMessages() -> [ChatMessage] {
    messageStore.getAllMessages()
  }
  
  /// Loading state
  public private(set) var isLoading: Bool = false
  
  /// Error state
  public var error: Error?
  
  /// Current project path (observable)
  public var projectPath: String = ""
  
  /// Streaming metrics
  public private(set) var streamingStartTime: Date?
  public private(set) var currentInputTokens: Int = 0
  public private(set) var currentOutputTokens: Int = 0
  public private(set) var currentCostUSD: Double = 0.0
  
  /// Tracks whether a session has started (first message sent)
  public private(set) var hasSessionStarted: Bool = false
  
  /// Check if debug logging is enabled from the Claude client configuration
  private var isDebugEnabled: Bool {
    claudeClient.configuration.enableDebugLogging
  }
  
  
  // MARK: - Initialization
  
  /// Creates a new ChatViewModel instance.
  /// - Parameters:
  ///   - claudeClient: The Claude client for API communication
  ///   - sessionStorage: Storage protocol for managing sessions
  ///   - settingsStorage: Storage for application settings
  ///   - globalPreferences: Global preferences storage
  ///   - customPermissionService: Service for custom permission management
  ///   - shouldManageSessions: Whether to manage sessions (load, save, switch). Default is true for backward compatibility.
  ///                           Set to false when using ChatScreen directly without session management needs.
  ///   - onSessionChange: Optional callback when session changes
  public init(
    claudeClient: ClaudeCode,
    sessionStorage: SessionStorageProtocol,
    settingsStorage: SettingsStorage,
    globalPreferences: GlobalPreferencesStorage,
    customPermissionService: CustomPermissionService,
    shouldManageSessions: Bool = true,
    onSessionChange: ((String) -> Void)? = nil)
  {
    self.claudeClient = claudeClient
    self.sessionStorage = sessionStorage
    self.settingsStorage = settingsStorage
    self.globalPreferences = globalPreferences
    self.customPermissionService = customPermissionService
    self.shouldManageSessions = shouldManageSessions
    self.onSessionChange = onSessionChange
    self.sessionManager = SessionManager(sessionStorage: sessionStorage)
    self.streamProcessor = StreamProcessor(
      messageStore: messageStore,
      sessionManager: sessionManager,
      globalPreferences: globalPreferences,
      onSessionChange: onSessionChange,
      getCurrentWorkingDirectory: {
        claudeClient.configuration.workingDirectory
      }
    )
    
    // Only load sessions if we're managing them (e.g., when used with RootView)
    // Skip loading when using ChatScreen directly to avoid wasteful operations
    if shouldManageSessions {
      Task {
        await loadSessions()
      }
    }
    
    // Initialize project path
    self.projectPath = settingsStorage.projectPath
  }
  
  /// Updates the project path when settings change
  public func refreshProjectPath() {
    projectPath = settingsStorage.projectPath
  }

  /// Updates the Claude command when global preferences change
  public func updateClaudeCommand(from globalPreferences: GlobalPreferencesStorage) {
    claudeClient.configuration.command = globalPreferences.claudeCommand
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

    ClaudeCodeLogger.shared.chat("sendMessage - Sending message. Current session: \(currentSessionId ?? "nil"), hasSessionStarted: \(hasSessionStarted)")

    // Reset cancellation flag for new message
    isCancelled = false

    // Store first message if this is a new session
    if sessionManager.currentSessionId == nil {
      ClaudeCodeLogger.shared.chat("sendMessage - No current session, storing as firstMessageInSession")
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
          try await continueConversation(sessionId: sessionId, prompt: apiContent, messageId: assistantId)
        } else {
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
    ClaudeCodeLogger.shared.chat("clearConversation - Clearing conversation. Current session: \(currentSessionId ?? "nil"), messages: \(messageStore.getAllMessages().count)")
    messageStore.clear()
    sessionManager.clearSession()
    currentMessageId = nil
    error = nil
    firstMessageInSession = nil
    hasSessionStarted = false
    ClaudeCodeLogger.shared.chat("clearConversation - Conversation cleared")
  }
  
  /// Starts a new session without affecting the current session
  public func startNewSession() {
    ClaudeCodeLogger.shared.chat("startNewSession - Starting new session. Current: \(currentSessionId ?? "nil")")
    // Save current session messages before starting new
    Task {
      await saveCurrentSessionMessages()

      // After saving, clear the UI to prepare for new session
      await MainActor.run {
        ClaudeCodeLogger.shared.chat("startNewSession - Clearing UI for new session")
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
    // Only save if we're managing sessions
    guard shouldManageSessions, let sessionId = currentSessionId else {
      ClaudeCodeLogger.shared.chat("saveCurrentSessionMessages - Skipped. shouldManageSessions=\(shouldManageSessions), sessionId=\(currentSessionId ?? "nil")")
      return
    }

    let messages = messageStore.getAllMessages()
    ClaudeCodeLogger.shared.chat("saveCurrentSessionMessages - Saving \(messages.count) messages for session \(sessionId)")
    // Log message types
    for (index, msg) in messages.enumerated() {
      ClaudeCodeLogger.shared.chat("saveCurrentSessionMessages - Message[\(index)]: role=\(msg.role), type=\(msg.messageType), toolName=\(msg.toolName ?? "nil")")
    }
    do {
      try await sessionStorage.updateSessionMessages(id: sessionId, messages: messages)
      ClaudeCodeLogger.shared.chat("saveCurrentSessionMessages - Successfully saved \(messages.count) messages")
      if isDebugEnabled {
        let log = "Saved \(messages.count) messages for current session \(sessionId)"
        logger.debug("\(log)")
      }
    } catch {
      ClaudeCodeLogger.shared.chat("saveCurrentSessionMessages - ERROR: Failed to save messages: \(error)")
      logger.error("Failed to save messages for session \(sessionId): \(error)")
    }
  }
  
  /// Cancels any ongoing requests
  public func cancelRequest() {
    // Set cancellation flag
    isCancelled = true
    
    // IMPORTANT: Terminate the Claude Code subprocess first
    claudeClient.cancel()
    
    // Cancel the stream subscription
    streamProcessor.cancelStream()
    
    // Cancel any pending tool approval requests
    customPermissionService.cancelAllRequests()
    
    // Clean up UI state
    isLoading = false
    streamingStartTime = nil
    
    // Mark the last message as cancelled
    let messages = messageStore.getAllMessages()
    if let lastMessage = messages.last {
      messageStore.markMessageAsCancelled(id: lastMessage.id)
    }
  }
  
  /// Updates token usage from streaming response
  public func updateTokenUsage(inputTokens: Int, outputTokens: Int) {
    if isDebugEnabled {
      let log = "Updating token usage - input: \(inputTokens), output: \(outputTokens)"
      logger.info("\(log)")
    }
    currentInputTokens = inputTokens
    currentOutputTokens = outputTokens
  }
  
  /// Updates cost from streaming response
  public func updateCost(_ costUSD: Double) {
    if isDebugEnabled {
      let log = "Updating cost: $\(String(format: "%.6f", costUSD))"
      logger.info("\(log)")
    }
    currentCostUSD = costUSD
  }
  
  /// Loads all available sessions
  public func loadSessions() async {
    // Only fetch sessions if we're managing them
    guard shouldManageSessions else { return }
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
      if isDebugEnabled {
        let log = "Loaded path '\(sessionPath)' for selected session '\(sessionId)'"
        logger.debug("\(log)")
      }
    } else {
      // No stored path for this session
      claudeClient.configuration.workingDirectory = nil
      projectPath = ""
      if isDebugEnabled {
        let log = "No stored path for selected session '\(sessionId)'"
        logger.debug("\(log)")
      }
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
    
    if isDebugEnabled {
      let log = "Resuming session: \(id)"
      logger.debug("\(log)")
    }
    
    // Prepare session for resumption
    prepareSessionForResumption(id: id)
    
    // Load messages for this session
    do {
      if let session = try await sessionStorage.getSession(id: id) {
        messageStore.loadMessages(session.messages)
        if isDebugEnabled {
          let log = "Loaded \(session.messages.count) messages for session \(id)"
          logger.debug("\(log)")
        }
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
  
  /// Injects a session with messages from an external source (e.g., database)
  /// This is designed for apps that manage their own message storage
  /// - Parameters:
  ///   - sessionId: The session ID to use for Claude CLI
  ///   - messages: The chat history to display in the UI
  ///   - workingDirectory: Optional working directory for this session
  /// - Note: The messages are displayed in UI, but Claude CLI won't have the context
  ///         unless it already knows about this sessionId
  public func injectSession(sessionId: String, messages: [ChatMessage], workingDirectory: String? = nil) {
    ClaudeCodeLogger.shared.chat("injectSession - Injecting session \(sessionId) with \(messages.count) messages, workingDirectory: \(workingDirectory ?? "nil")")
    // Set up the session
    sessionManager.selectSession(id: sessionId)
    onSessionChange?(sessionId)

    // Set working directory if provided
    if let dir = workingDirectory {
      ClaudeCodeLogger.shared.chat("injectSession - Setting working directory to: \(dir)")
      claudeClient.configuration.workingDirectory = dir
      projectPath = dir
      settingsStorage.setProjectPath(dir)
    }

    // Load the messages into the UI
    messageStore.loadMessages(messages)
    ClaudeCodeLogger.shared.chat("injectSession - Loaded \(messages.count) messages into MessageStore")

    // Mark as active session
    hasSessionStarted = true
    error = nil
    
    if isDebugEnabled {
      let log = "Injected session '\(sessionId)' with \(messages.count) messages"
      logger.info("\(log)")
    }
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
    // Only switch if we're managing sessions
    guard shouldManageSessions else { return }
    
    // If switching to the same session, do nothing
    guard sessionId != currentSessionId else { return }
    
    // Prevent concurrent session switches
    guard !isSwitchingSession else {
      logger.warning("Already switching sessions, ignoring switch to \(sessionId)")
      return
    }
    
    isSwitchingSession = true
    defer { isSwitchingSession = false }
    
    if isDebugEnabled {
      let log = "Switching to session: \(sessionId)"
      logger.debug("\(log)")
    }
    
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
        if isDebugEnabled {
          let log = "Saved \(currentMessages.count) messages for session \(currentId)"
          logger.debug("\(log)")
        }
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
    // Skip validation if not managing sessions
    guard shouldManageSessions else { return false }
    
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
      if isDebugEnabled {
        let log = "Loaded path '\(sessionPath)' for resumed session '\(id)'"
        logger.debug("\(log)")
      }
    } else {
      // No stored path for this session
      claudeClient.configuration.workingDirectory = nil
      projectPath = ""
      if isDebugEnabled {
        let log = "No stored path for resumed session '\(id)'"
        logger.debug("\(log)")
      }
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
    // Ensure we're resuming the correct session
    if id != sessionManager.currentSessionId {
      if isDebugEnabled {
        let log = "Switching to resume session '\(id)'"
        logger.info("\(log)")
      }
      // Update to match the requested session
      sessionManager.selectSession(id: id)
    }
    
    // Only make API call if there's an actual prompt to send
    guard let prompt = initialPrompt, !prompt.isEmpty else {
      // Just switch to the session without making an API call
      if isDebugEnabled {
        let log = "Switched to session \(id) without sending a message"
        logger.debug("\(log)")
      }
      
      // Mark as not loading since we're not making an API call
      await MainActor.run {
        self.isLoading = false
        self.streamingStartTime = nil
      }
      return
    }
    
    if isDebugEnabled {
      let log = "📤 Resuming session '\(id)' after app relaunch with new message"
      logger.info("\(log)")
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
        if isDebugEnabled {
          let log = "Session \(sessionId) exists locally but not in Claude. Continuing with local history."
          logger.info("\(log)")
        }
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
    // Log if we're starting fresh when there's already a session
    if let existingId = sessionManager.currentSessionId {
      let log = "Starting new conversation while session '\(existingId)' exists"
      logger.warning("\(log)")
    }
    
    if isDebugEnabled {
      logger.info("Starting new conversation")
    }
    
    let options = createOptions()
    
    let result = try await claudeClient.runSinglePrompt(
      prompt: prompt,
      outputFormat: .streamJson,
      options: options
    )
    
    await processResult(result, messageId: messageId)
  }
  
  private func continueConversation(sessionId: String, prompt: String, messageId: UUID) async throws {
    if isDebugEnabled {
      let log = "Continuing session '\(sessionId)'"
      logger.debug("\(log)")
    }
    
    let options = createOptions()
    
    do {
      let result = try await claudeClient.resumeConversation(
        sessionId: sessionId,
        prompt: prompt,
        outputFormat: .streamJson,
        options: options
      )
      
      await processResult(result, messageId: messageId)
    } catch {
      // Check if it's a session not found error
      let errorMessage = error.localizedDescription.lowercased()
      if errorMessage.contains("no conversation") || errorMessage.contains("not found") {
        if isDebugEnabled {
          logger.info("Session not found, starting new conversation")
        }
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
      if isDebugEnabled {
        let log = "Adding approval tool to allowed tools: \(approvalToolName)"
        logger.debug("\(log)")
      }
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
      if isDebugEnabled {
        let log = "Setting mcpConfigPath in options: \(globalPreferences.mcpConfigPath)"
        logger.debug("\(log)")
      }
      options.mcpConfigPath = globalPreferences.mcpConfigPath
      
      // Also configure approval tool integration
      mcpHelper.configureOptions(&options)
    } else {
      if isDebugEnabled {
        logger.debug("No mcpConfigPath found in settings, configuring approval tool only")
      }
      // Configure just the approval tool
      mcpHelper.configureOptions(&options)
    }
    
    if isDebugEnabled {
      logger.debug("Custom permission service integration configured")
      let finalToolsLog = "Final allowed tools: \(options.allowedTools ?? [])"
      logger.debug("\(finalToolsLog)")
    }
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
    logger.error("Error: \(error.localizedDescription)")
    
    self.error = error
    self.isLoading = false
    self.streamingStartTime = nil
    
    // Remove incomplete assistant message if there was an error
    if let currentMessageId = currentMessageId {
      messageStore.removeMessage(id: currentMessageId)
    }
  }
}

