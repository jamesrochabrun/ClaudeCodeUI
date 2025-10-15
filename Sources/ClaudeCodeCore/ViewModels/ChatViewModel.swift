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
  var customPermissionService: CustomPermissionService
  
  /// Optional callback invoked when session changes, used for external state synchronization
  private let onSessionChange: ((String) -> Void)?

  /// Optional callback invoked when a user message is sent, used for external logging
  private let onUserMessageSent: ((String, [TextSelection]?, [FileAttachment]?) -> Void)?
  
  /// Controls whether this view model should manage sessions (load, save, switch, etc.)
  /// Set to false when using ChatScreen directly without RootView to avoid unnecessary session operations
  public let shouldManageSessions: Bool

  /// Optional system prompt prefix that gets prepended to the additional system prompt
  private let systemPromptPrefix: String?

  private let streamProcessor: StreamProcessor
  private let messageStore = MessageStore()
  private var firstMessageInSession: String?
  
  // Session isolation: track if we're in the middle of switching sessions
  private var isSwitchingSession = false
  
  // Stream cancellation: track if user cancelled the current stream
  private var isCancelled = false
  
  // Track expansion states for each message to persist across view recreations
  var messageExpansionStates: [UUID: Bool] = [:]

  // Plan approval is now handled inline via InlinePlanApprovalView

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
  
  /// Error state with detailed information
  public var errorInfo: ErrorInfo?

  /// Error queue for multiple errors
  public var errorQueue: [ErrorInfo] = []
  
  /// Current project path (observable)
  public var projectPath: String = ""
  
  /// Streaming metrics
  public private(set) var streamingStartTime: Date?
  public private(set) var currentInputTokens: Int = 0
  public private(set) var currentOutputTokens: Int = 0
  public private(set) var currentCostUSD: Double = 0.0
  
  /// Tracks whether a session has started (first message sent)
  public private(set) var hasSessionStarted: Bool = false

  /// Current permission mode for this chat session (runtime state only, not persisted)
  public var permissionMode: ClaudeCodeSDK.PermissionMode = .default

  /// Check if debug logging is enabled from the Claude client configuration
  var isDebugEnabled: Bool {
    claudeClient.configuration.enableDebugLogging
  }

  /// Returns a terminal command that can be copied and pasted to reproduce the last execution
  var terminalReproductionCommand: String? {
    guard let commandInfo = claudeClient.lastExecutedCommandInfo else {
      return nil
    }

    var parts: [String] = []

    // Add working directory change if present
    if let workingDir = commandInfo.workingDirectory {
      let escapedPath = workingDir
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
      parts.append("cd \"\(escapedPath)\"")
    }

    // Add stdin content if present
    if let stdin = commandInfo.stdinContent, !stdin.isEmpty {
      let escapedStdin = stdin
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "$", with: "\\$")
        .replacingOccurrences(of: "`", with: "\\`")
      parts.append("echo \"\(escapedStdin)\" | \(commandInfo.commandString)")
    } else {
      parts.append(commandInfo.commandString)
    }

    return parts.joined(separator: " && ")
  }

  /// Generates MCP configuration diagnostics for debug reporting
  private func generateMCPDiagnostics() -> String {
    var diagnostics = "\nMCP CONFIGURATION:"

    // Check MCP config file
    let configPath = globalPreferences.mcpConfigPath
    diagnostics += "\nConfig File: \(configPath)"

    let configExists = FileManager.default.fileExists(atPath: configPath)

    // Try to load and validate config
    let mcpManager = MCPConfigurationManager()
    let configValid = configExists && !mcpManager.configuration.mcpServers.isEmpty

    if !configExists {
      diagnostics += "\nConfig Status: ✗ Not found"
    } else if configValid {
      diagnostics += "\nConfig Status: ✓ Exists and valid"
      let serverNames = mcpManager.configuration.mcpServers.keys.sorted().joined(separator: ", ")
      diagnostics += "\nConfigured Servers: \(mcpManager.configuration.mcpServers.count) (\(serverNames))"
    } else {
      diagnostics += "\nConfig Status: ✗ Exists but empty or invalid"
    }

    // Check approval server binary
    diagnostics += "\n\nAPPROVAL SERVER:"

    let bundlePath = Bundle.main.path(forResource: "ApprovalMCPServer", ofType: nil)
    let binaryExists = bundlePath != nil && FileManager.default.fileExists(atPath: bundlePath!)

    if let path = bundlePath {
      diagnostics += "\nBinary Path: \(path)"
      diagnostics += "\nBinary Status: \(binaryExists ? "✓ Exists" : "✗ Not found")"
    } else {
      diagnostics += "\nBinary Path: Not in bundle"
      diagnostics += "\nBinary Status: ✗ Not found"
    }

    // Check if approval server is configured in MCP
    if let approvalServer = mcpManager.configuration.mcpServers["approval_server"] {
      diagnostics += "\nConfigured in MCP: ✓ Yes"
      diagnostics += "\nConfigured Path: \(approvalServer.command)"

      // Check if configured path matches bundled path
      if let bundled = bundlePath {
        if approvalServer.command == bundled {
          diagnostics += "\nPath Match: ✓ Matches bundled binary"
        } else {
          diagnostics += "\nPath Match: ✗ Mismatch"
          diagnostics += "\n  Expected (bundled): \(bundled)"
          diagnostics += "\n  Actual (configured): \(approvalServer.command)"
        }
      }
    } else {
      diagnostics += "\nConfigured in MCP: ✗ No"
      if binaryExists {
        diagnostics += "\n⚠️  Binary exists but not configured - run 'Repair' in settings"
      }
    }

    return diagnostics
  }

  /// Returns a complete debug report with all command execution details
  var fullDebugReport: String? {
    guard let commandInfo = claudeClient.lastExecutedCommandInfo else {
      return nil
    }

    // Detect the actual executable path
    let commandName = commandInfo.commandString.components(separatedBy: " ").first ?? ""
    let resolvedExecutable = TerminalLauncher.findClaudeExecutable(
      command: commandName,
      additionalPaths: claudeClient.configuration.additionalPaths
    )

    var report = """
    === CLAUDE CODE DEBUG REPORT ===

    TERMINAL REPRODUCTION COMMAND:
    \(terminalReproductionCommand ?? "N/A")

    COMMAND DETAILS:
    Command: \(commandInfo.commandString)
    Resolved Executable: \(resolvedExecutable ?? "Not found - check PATH and shell aliases")
    Working Directory: \(commandInfo.workingDirectory ?? "None")
    Stdin Content: \(commandInfo.stdinContent ?? "None")
    Executed At: \(commandInfo.executedAt)
    Method: \(commandInfo.method)
    Output Format: \(commandInfo.outputFormat)

    SHELL CONFIGURATION:
    Shell Executable: \(commandInfo.shellExecutable)
    Shell Arguments: \(commandInfo.shellArguments.joined(separator: " "))

    ENVIRONMENT:
    PATH:
    """

    // Add PATH directories
    let pathDirs = commandInfo.pathEnvironment.split(separator: ":")
    for dir in pathDirs {
      report += "\n  - \(dir)"
    }

    report += "\n\nEnvironment Variables: \(commandInfo.environment.count) set"

    // Add some key environment variables if present
    let keyVars = ["NODE_ENV", "HOME", "USER", "SHELL"]
    var foundVars: [String] = []
    for key in keyVars {
      if let value = commandInfo.environment[key] {
        foundVars.append("\(key)=\(value)")
      }
    }
    if !foundVars.isEmpty {
      report += "\nKey Variables:\n  " + foundVars.joined(separator: "\n  ")
    }

    // Add MCP diagnostics
    report += "\n"
    report += generateMCPDiagnostics()

    report += "\n\n=== END DEBUG REPORT ==="

    return report
  }


  // MARK: - Initialization
  
  /// Creates a new ChatViewModel instance.
  /// - Parameters:
  ///   - claudeClient: The Claude client for API communication
  ///   - sessionStorage: Storage protocol for managing sessions
  ///   - settingsStorage: Storage for application settings
  ///   - globalPreferences: Global preferences storage
  ///   - customPermissionService: Service for custom permission management
  ///   - systemPromptPrefix: Optional prefix to prepend to the additional system prompt
  ///   - shouldManageSessions: Whether to manage sessions (load, save, switch). Default is true for backward compatibility.
  ///                           Set to false when using ChatScreen directly without session management needs.
  ///   - onSessionChange: Optional callback when session changes
  public init(
    claudeClient: ClaudeCode,
    sessionStorage: SessionStorageProtocol,
    settingsStorage: SettingsStorage,
    globalPreferences: GlobalPreferencesStorage,
    customPermissionService: CustomPermissionService,
    systemPromptPrefix: String? = nil,
    shouldManageSessions: Bool = true,
    onSessionChange: ((String) -> Void)? = nil,
    onUserMessageSent: ((String, [TextSelection]?, [FileAttachment]?) -> Void)? = nil)
  {
    self.claudeClient = claudeClient
    self.sessionStorage = sessionStorage
    self.settingsStorage = settingsStorage
    self.globalPreferences = globalPreferences
    self.customPermissionService = customPermissionService
    self.systemPromptPrefix = systemPromptPrefix
    self.shouldManageSessions = shouldManageSessions
    self.onSessionChange = onSessionChange
    self.onUserMessageSent = onUserMessageSent
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

    // Set up error handler for SessionManager after all properties are initialized
    self.sessionManager.setErrorHandler { [weak self] error, operation in
      self?.handleError(error, operation: operation)
    }

    // Set up parent reference for StreamProcessor
    self.streamProcessor.setParentViewModel { [weak self] in
      return self
    }

    // Wire up approval timeout callback
    self.customPermissionService.onConversationShouldPause = { [weak self] toolUseId, _ in
      Task { @MainActor in
        await self?.handleApprovalTimeout(toolUseId: toolUseId)
      }
    }

    // Wire up resume after timeout callback
    self.customPermissionService.onResumeAfterTimeout = { [weak self] approved, toolName in
      Task { @MainActor in
        await self?.resumeAfterApprovalTimeout(approved: approved, toolName: toolName)
      }
    }

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

    // Add manual Claude path if specified
    if !globalPreferences.claudePath.isEmpty {
      // Validate that the file exists
      if FileManager.default.fileExists(atPath: globalPreferences.claudePath) {
        let url = URL(fileURLWithPath: globalPreferences.claudePath)
        let directory = url.deletingLastPathComponent().path

        // Insert at the beginning for highest priority (if not already present)
        if !claudeClient.configuration.additionalPaths.contains(directory) {
          claudeClient.configuration.additionalPaths.insert(directory, at: 0)
        }
      }
    }
  }
  
  // MARK: - Public Methods
  /// Retries the last user message with all its original data
  public func retryLastMessage() {
    guard let lastUserMessage = messages.last(where: { $0.role == .user }) else { return }

    // Extract the original data from the stored message
    let text = lastUserMessage.content
    let codeSelections = lastUserMessage.codeSelections

    // Convert stored attachments back to FileAttachments
    let attachments: [FileAttachment]? = lastUserMessage.attachments?.compactMap { stored in
      // Create FileAttachment from the stored file path
      let fileURL = URL(fileURLWithPath: stored.filePath)
      let attachment = FileAttachment(url: fileURL)
      // Set the state to ready since we're just referencing the file path
      attachment.state = .ready(content: .image(path: stored.filePath, base64URL: "", thumbnailBase64: nil))
      return attachment
    }

    // Note: We lose context and hiddenContext on retry since they weren't stored
    // This is acceptable as the context was likely from clipboard/Xcode at the time
    sendMessage(text, context: nil, hiddenContext: nil, codeSelections: codeSelections, attachments: attachments)
  }

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

    // Invoke the callback for user message logging
    onUserMessageSent?(displayContent, codeSelections, attachments)

    // Clear any previous errors
    errorInfo = nil
    
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
          self.handleError(error, operation: .apiCall)
        }
      }
    }
  }
  
  /// Clears the conversation history and starts a new session
  public func clearConversation() {
    messageStore.clear()
    sessionManager.clearSession()
    currentMessageId = nil
    errorInfo = nil
    errorQueue.removeAll()
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
        self.errorInfo = nil
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
      return
    }

    let messages = messageStore.getAllMessages()
    do {
      try await sessionStorage.updateSessionMessages(id: sessionId, messages: messages)
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

  /// Handles approval timeout by pausing the conversation
  /// Called by permission service when approval toast has been visible too long
  private func handleApprovalTimeout(toolUseId: String) async {
    logger.info("Pausing conversation due to approval timeout for tool: \(toolUseId)")

    // Cancel the current request
    // This will:
    // 1. Terminate the Claude Code subprocess
    // 2. Clean up the stream
    // 3. Leave the conversation in a clean state (pending tool call is discarded by Claude)
    cancelRequest()

    // Note: The toast remains visible (not hidden)
    // When user approves/denies later, we'll resume the session
  }

  /// Resumes conversation after approval timeout with user's decision
  /// - Parameters:
  ///   - approved: Whether the user approved or denied the tool
  ///   - toolName: Name of the tool that was approved/denied
  public func resumeAfterApprovalTimeout(approved: Bool, toolName: String) async {
    guard let sessionId = currentSessionId else {
      logger.warning("Cannot resume after approval timeout: no active session")
      return
    }

    logger.info("Resuming session \(sessionId) after approval timeout. Tool: \(toolName), Approved: \(approved)")

    // Send a generic message to Claude asking it to continue
    // We don't mention the specific tool - Claude will re-request it if needed
    let prompt = "Please continue with the previous task."

    // Set up loading state
    await MainActor.run {
      self.isLoading = true
      self.streamingStartTime = Date()
      self.currentInputTokens = 0
      self.currentOutputTokens = 0
      self.currentCostUSD = 0.0
    }

    let assistantId = UUID()
    await MainActor.run {
      self.currentMessageId = assistantId
    }

    // Resume the conversation
    do {
      let options = createOptions()
      let result = try await claudeClient.resumeConversation(
        sessionId: sessionId,
        prompt: prompt,
        outputFormat: .streamJson,
        options: options
      )

      await processResult(result, messageId: assistantId)
    } catch {
      await handleSessionResumptionError(error, sessionId: sessionId)
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
      // Validate the path still exists (important for worktrees that might be deleted)
      if FileManager.default.fileExists(atPath: sessionPath) {
        // For worktree validation, we'll do a simplified check without async
        // Just validate that the .git file/directory exists
        let gitPath = (sessionPath as NSString).appendingPathComponent(".git")
        if FileManager.default.fileExists(atPath: gitPath) {
          // Update ClaudeClient configuration
          claudeClient.configuration.workingDirectory = sessionPath
          // Update the observable project path
          projectPath = sessionPath
          if isDebugEnabled {
            let log = "Loaded path '\(sessionPath)' for selected session '\(sessionId)'"
            logger.debug("\(log)")
          }
        } else {
          // Git directory no longer exists
          handleInvalidPath(sessionPath, sessionId: sessionId)
        }
      } else {
        // Path no longer exists
        handleInvalidPath(sessionPath, sessionId: sessionId)
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
    errorInfo = nil
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
    // Set up the session
    sessionManager.selectSession(id: sessionId)
    onSessionChange?(sessionId)

    // Set working directory if provided
    if let dir = workingDirectory {
      claudeClient.configuration.workingDirectory = dir
      projectPath = dir
      settingsStorage.setProjectPath(dir)
    }

    // Load the messages into the UI
    messageStore.loadMessages(messages)

    // Mark as active session
    hasSessionStarted = true
    errorInfo = nil
    
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

      // Apply default working directory if available
      let defaultDirectory = globalPreferences.defaultWorkingDirectory
      if !defaultDirectory.isEmpty {
        claudeClient.configuration.workingDirectory = defaultDirectory
        projectPath = defaultDirectory
        settingsStorage.setProjectPath(defaultDirectory)
      } else {
        // Only clear if no default is set
        settingsStorage.clearProjectPath()
        claudeClient.configuration.workingDirectory = nil
        projectPath = ""
      }
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
    errorInfo = nil
    
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
        self.errorInfo = nil
        
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

    // Only add approval tool if the approval server exists in MCP config
    let approvalToolName = "mcp__approval_server__approval_prompt"

    // Always check if approval server is configured (it might be auto-added on app launch)
    let configManager = MCPConfigurationManager()
    if configManager.configuration.mcpServers["approval_server"] != nil {
      // Approval server is configured, add the tool if not already present
      if !allowedTools.contains(approvalToolName) {
        if isDebugEnabled {
          let log = "Adding approval tool to allowed tools: \(approvalToolName)"
          logger.debug("\(log)")
        }
        allowedTools.append(approvalToolName)
      }
    } else {
      if isDebugEnabled {
        logger.debug("Approval server not configured in MCP - skipping approval tool")
      }

      // Show error to user with recovery option
      let configError = NSError(
        domain: "MCPConfiguration",
        code: 1001,
        userInfo: [NSLocalizedDescriptionKey: "Approval server not configured in MCP"]
      )

      let errorInfo = ErrorInfo(
        error: configError,
        severity: .warning,
        context: "MCP Approval Tool",
        recoverySuggestion: "The approval server is not configured. Tool approvals won't work until this is fixed. Click 'Fix' to repair the configuration.",
        operation: .configuration,
        recoveryAction: { [weak self] in
          // Re-run the config update
          let mcpConfigManager = MCPConfigurationManager()
          mcpConfigManager.updateApprovalServerPath()

          // Check if it worked
          if mcpConfigManager.configuration.mcpServers["approval_server"] != nil {
            // The config was updated successfully
            self?.logger.info("MCP approval server configuration repaired successfully")

            // Clear any existing errors and show success
            self?.errorQueue.removeAll { $0.displayMessage.contains("Approval server") }
          } else {
            // Still couldn't configure - binary might be missing
            let binaryError = NSError(
              domain: "MCPConfiguration",
              code: 1002,
              userInfo: [NSLocalizedDescriptionKey: "ApprovalMCPServer binary not found in app bundle. Please rebuild the app."]
            )
            self?.errorQueue.append(ErrorInfo(
              error: binaryError,
              severity: .error,
              context: "MCP Approval Tool",
              recoverySuggestion: "The approval server binary is missing. Rebuild the app with Xcode to bundle it.",
              operation: .configuration
            ))
          }
        }
      )
      errorQueue.append(errorInfo)
    }

    // Configure chat options with global preferences
    options.allowedTools = allowedTools
    options.disallowedTools = globalPreferences.disallowedTools

    // Apply user-defined system prompt if provided
    if !globalPreferences.systemPrompt.isEmpty {
      options.systemPrompt = globalPreferences.systemPrompt
    }

    // Combine system prompt prefix with user's additional system prompt
    var combinedAppendPrompt = systemPromptPrefix ?? ""
    if !combinedAppendPrompt.isEmpty && !globalPreferences.appendSystemPrompt.isEmpty {
      combinedAppendPrompt += "\n"  // Add line break between prefix and user prompt
    }
    combinedAppendPrompt += globalPreferences.appendSystemPrompt

    if !combinedAppendPrompt.isEmpty {
      options.appendSystemPrompt = combinedAppendPrompt
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
    
    // Set the permission mode for this chat session
    options.permissionMode = permissionMode

    if isDebugEnabled {
      logger.debug("Custom permission service integration configured")
      let log = "Permission mode: \(self.permissionMode.rawValue)"
      logger.debug("\(log)")
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
            self?.handleError(error, operation: .streaming)
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
        let error = NSError(
          domain: "ChatViewModel",
          code: 1001,
          userInfo: [NSLocalizedDescriptionKey: "Unexpected response format"]
        )
        self.handleError(error, operation: .streaming)
      }
    }
  }
  
  
  @MainActor
  func handleError(_ error: Error, operation: ErrorOperation = .general) {
    logger.error("Error: \(error.localizedDescription)")

    // Create detailed error info based on operation type
    var errorInfo: ErrorInfo
    switch operation {
    case .sessionManagement:
      errorInfo = ErrorInfo.sessionError(error)
    case .streaming:
      errorInfo = ErrorInfo.streamingError(error)
    case .apiCall:
      errorInfo = ErrorInfo.apiError(error)
    case .fileOperation:
      errorInfo = ErrorInfo.fileError(error)
    default:
      errorInfo = ErrorInfo(
        error: error,
        severity: .error,
        context: "Operation failed",
        recoverySuggestion: "Please try again or check your settings.",
        operation: operation
      )
    }

    // For notInstalled errors, enhance with the actual command being used
    if let claudeError = error as? ClaudeCodeError,
       case .notInstalled = claudeError {
      let actualCommand = globalPreferences.claudeCommand
      if isDebugEnabled {
        logger.debug("[DEBUG] Command configured: '\(actualCommand)'")
      }

      // Check if it looks like a typo
      if actualCommand != "claude" && actualCommand.contains("cl") {
        errorInfo = ErrorInfo(
          error: error,
          severity: .critical,
          context: "Command '\(actualCommand)' Not Found",
          recoverySuggestion: "The command '\(actualCommand)' was not found. This looks like a typo - did you mean 'claude'? Check your Settings > Claude Command.",
          operation: .configuration
        )
      } else if actualCommand == "claude" {
        // It's the correct command name, so probably not installed
        errorInfo = ErrorInfo(
          error: error,
          severity: .critical,
          context: "Claude Not Installed",
          recoverySuggestion: "Claude command-line tool is not installed. Run: npm install -g @anthropic/claude-code",
          operation: .configuration
        )
      } else {
        // Some other command name
        errorInfo = ErrorInfo(
          error: error,
          severity: .critical,
          context: "Command '\(actualCommand)' Not Found",
          recoverySuggestion: "The command '\(actualCommand)' was not found in PATH. Check your Settings > Claude Command.",
          operation: .configuration
        )
      }
    }

    self.errorInfo = errorInfo
    self.errorQueue.append(errorInfo)
    self.isLoading = false
    self.streamingStartTime = nil

    // Remove incomplete assistant message if there was an error
    if let currentMessageId = currentMessageId {
      messageStore.removeMessage(id: currentMessageId)
    }
  }

  // MARK: - Worktree Support Helpers

  /// Handles the case when a path is no longer valid
  private func handleInvalidPath(_ path: String, sessionId: String) {
    claudeClient.configuration.workingDirectory = nil
    projectPath = ""

    let errorMessage = "The directory '\(path)' no longer exists or is invalid. Please select a new working directory."
    logger.warning("\(errorMessage)")

    // Create a generic execution failed error since we don't have invalidPath
    let error = ClaudeCodeError.executionFailed("Invalid path: \(path)")

    errorInfo = ErrorInfo(
      error: error,
      severity: .warning,
      context: "Directory Not Found",
      recoverySuggestion: errorMessage,
      operation: .sessionManagement
    )
  }

  // MARK: - Plan Approval

  /// Updates the plan approval status for a specific message
  public func updatePlanApprovalStatus(messageId: UUID, status: PlanApprovalStatus) {
    messageStore.updatePlanApprovalStatus(id: messageId, status: status)
  }
}

