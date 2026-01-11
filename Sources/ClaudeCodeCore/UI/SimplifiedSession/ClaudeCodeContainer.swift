import ClaudeCodeSDK
import Foundation
import SwiftUI

// MARK: - ClaudeCodeContainer

public struct ClaudeCodeContainer: View {
  
  // MARK: Lifecycle
  
  public init(
    claudeCodeConfiguration: ClaudeCodeConfiguration,
    uiConfiguration: UIConfiguration,
    onUserMessageSent: ((String, [TextSelection]?, [FileAttachment]?) -> Void)? = nil)
  {
    self.claudeCodeConfiguration = claudeCodeConfiguration
    self.uiConfiguration = uiConfiguration
    self.onUserMessageSent = onUserMessageSent
    customStorage = SimplifiedClaudeCodeSQLiteStorage()
    // SessionManager will be initialized in initializeClaudeCodeUI with proper globalPreferences
    sessionManager = SimplifiedSessionManager(
      claudeCodeStorage: customStorage,
      globalPreferences: GlobalPreferencesStorage() // Temporary, will be replaced
    )
    ClaudeCodeLogger.shared.configure(enableDebugLogging: claudeCodeConfiguration.enableDebugLogging)
  }
  
  // MARK: Public
  
  public var body: some View {
    Group {
      if let error = initializationError {
        errorMessageView(error)
      } else if
        isInitialized,
        let chatViewModel,
        let globalPreferences,
        let claudeCodeDeps
      {
        if showSessionPicker {
          sessionPickerView(chatViewModel: chatViewModel)
            .environment(globalPreferences)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          chatInterface(chatViewModel: chatViewModel, globalPreferences: globalPreferences, claudeCodeDeps: claudeCodeDeps)
        }
        
      } else {
        ProgressView("Initializing...")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .task {
      do {
        try await initializeClaudeCodeUI()
      } catch {
        initializationError = error
      }
    }
  }
  
  // MARK: Internal
  
  let customStorage: SessionStorageProtocol
  let claudeCodeConfiguration: ClaudeCodeConfiguration
  let uiConfiguration: UIConfiguration
  let onUserMessageSent: ((String, [TextSelection]?, [FileAttachment]?) -> Void)?
  
  // MARK: Private
  
  @State private var sessionManager: SimplifiedSessionManagerProtocol
  @State private var isInitialized = false
  @State private var chatViewModel: ChatViewModel?
  @State private var globalPreferences: GlobalPreferencesStorage?
  @State private var claudeCodeDeps: DependencyContainer?
  
  @State private var showSessionPicker = false
  @State private var availableSessions: [StoredSession] = []
  @State private var isLoadingSessions = false
  @State private var sessionLoadError: Error?
  @State private var currentSessionId: String?
  
  @State private var showDeleteConfirmation = false
  @State private var sessionToDelete: StoredSession?
  @State private var showDeleteAllConfirmation = false
  @State private var deleteAllError: Error?
  @State private var showDeleteAllError = false
  @State private var initializationError: Error?

  // CLI Session Monitoring
  @State private var cliSessionMonitorService: CLISessionMonitorService?
  @State private var cliSessionsViewModel: CLISessionsViewModel?
  
  private func initializeClaudeCodeUI() async throws {
    
    let globalPrefs = GlobalPreferencesStorage()
    
    // Update MCP configuration to ensure approval server path is correct
    await MainActor.run {
      let mcpConfigManager = MCPConfigurationManager()
      mcpConfigManager.updateApprovalServerPath()
      
      // Ensure the MCP config path is set in global preferences
      if globalPrefs.mcpConfigPath.isEmpty {
        if let configPath = mcpConfigManager.getConfigurationPath() {
          globalPrefs.mcpConfigPath = configPath
          ClaudeCodeLogger.shared.log(.container, "[ClaudeCodeContainer] Set MCP config path to: \(configPath)")
        }
      }
    }
    
    // Always sync command lock state with configuration
    // This ensures proper behavior when config changes between custom and default
    if claudeCodeConfiguration.command != "claude" {
      // Custom command from config - lock the field
      globalPrefs.claudeCommand = claudeCodeConfiguration.command
      globalPrefs.isClaudeCommandFromConfig = true
    } else {
      // Default "claude" from config - unlock field and allow user override
      // Only reset to "claude" if it was previously locked from config
      if globalPrefs.isClaudeCommandFromConfig {
        globalPrefs.claudeCommand = "claude"
      }
      globalPrefs.isClaudeCommandFromConfig = false
    }
    
    // Now create the proper session manager with global preferences
    sessionManager = SimplifiedSessionManager(
      claudeCodeStorage: customStorage,
      globalPreferences: globalPrefs
    )
    
    let deps = ClaudeCodeCore.DependencyContainer(
      globalPreferences: globalPrefs,
      customSessionStorage: customStorage,
    )
    
    var config = claudeCodeConfiguration
    // Use the command from global preferences (which may have been updated above)
    // This ensures we respect both injected config AND user preferences
    config.command = globalPrefs.claudeCommand

    // If the configuration has disallowedTools set, merge them with preferences
    if let configDisallowedTools = config.disallowedTools, !configDisallowedTools.isEmpty {
      // Merge configuration's disallowed tools with preferences
      let combinedDisallowedTools = Set(configDisallowedTools).union(Set(globalPrefs.disallowedTools))
      globalPrefs.disallowedTools = Array(combinedDisallowedTools)
    }

    // CRITICAL: Set working directory BEFORE creating client so backend is initialized with correct directory
    // Priority: 1) Global preferences (user's explicit selection), 2) Config default, 3) Home directory fallback
    let workingDirectory: String
    if !globalPrefs.defaultWorkingDirectory.isEmpty {
      // User has explicitly set a working directory in preferences
      workingDirectory = globalPrefs.defaultWorkingDirectory
      ClaudeCodeLogger.shared.log(.container, "[ClaudeCodeContainer] Using working directory from preferences: \(workingDirectory)")
    } else if let configPath = claudeCodeConfiguration.workingDirectory, !configPath.isEmpty {
      // Config provides a default working directory (but don't save to preferences - let user explicitly set it)
      workingDirectory = configPath
      ClaudeCodeLogger.shared.log(.container, "[ClaudeCodeContainer] Using working directory from config: \(workingDirectory)")
    } else {
      // Fallback to home directory if no working directory is configured
      workingDirectory = NSHomeDirectory()
      ClaudeCodeLogger.shared.log(.container, "[ClaudeCodeContainer] No working directory set, using home directory: \(workingDirectory)")
    }

    // Apply working directory to config before creating client
    config.workingDirectory = workingDirectory

    let claudeClient = try ClaudeCodeClient(configuration: config)

    let viewModel = ClaudeCodeCore.ChatViewModel(
      claudeClient: claudeClient,
      sessionStorage: customStorage,
      settingsStorage: deps.settingsStorage,
      globalPreferences: globalPrefs,
      customPermissionService: deps.customPermissionService,
      systemPromptPrefix: uiConfiguration.initialAdditionalSystemPromptPrefix,
      onSessionChange: { newSessionId in
        Task { @MainActor in
          currentSessionId = newSessionId
          await loadAvailableSessions()
        }
      },
      onUserMessageSent: onUserMessageSent
    )

    // Set working directory in view model and settings storage
    viewModel.projectPath = workingDirectory
    deps.settingsStorage.setProjectPath(workingDirectory)
    
    // Apply stored claudePath from preferences to ensure it persists across app restarts
    viewModel.updateClaudeCommand(from: globalPrefs)
    
    // Initialize CLI session monitoring
    let monitorService = CLISessionMonitorService()
    let cliViewModel = CLISessionsViewModel(monitorService: monitorService, claudeClient: claudeClient)

    await MainActor.run {
      chatViewModel = viewModel
      globalPreferences = globalPrefs
      claudeCodeDeps = deps
      cliSessionMonitorService = monitorService
      cliSessionsViewModel = cliViewModel
      isInitialized = true
    }

    await loadAvailableSessions()
  }
  
  private func chatInterface(
    chatViewModel: ClaudeCodeCore.ChatViewModel,
    globalPreferences: GlobalPreferencesStorage,
    claudeCodeDeps: ClaudeCodeCore.DependencyContainer,
  ) -> some View {
    ChatInterfaceView(
      chatViewModel: chatViewModel,
      globalPreferences: globalPreferences,
      claudeCodeDeps: claudeCodeDeps,
      availableSessions: availableSessions,
      uiConfig: uiConfiguration,
      onShowSessionPicker: {
        Task {
          // Always load fresh sessions when showing picker to ensure accurate message counts
          await loadAvailableSessions()
          showSessionPicker = true
        }
      },
    )
  }
  
  private func sessionPickerView(chatViewModel: ClaudeCodeCore.ChatViewModel) -> some View {
    SessionPickerView(
      chatViewModel: chatViewModel,
      isLoadingSessions: isLoadingSessions,
      sessionLoadError: sessionLoadError,
      availableSessions: availableSessions,
      currentSessionId: currentSessionId,
      globalPreferences: globalPreferences,
      cliSessionsViewModel: cliSessionsViewModel,
      onCancel: {
        showSessionPicker = false
      },
      onTryAgain: {
        Task {
          await loadAvailableSessions()
        }
      },
      onStartNewSession: { workingDirectory in
        sessionManager.startNewSession(chatViewModel: chatViewModel, workingDirectory: workingDirectory)
        showSessionPicker = false
        // Reload sessions after starting new session to keep list updated
        Task {
          await loadAvailableSessions()
        }
      },
      onRestoreSession: { session in
        Task {
          await sessionManager.restoreSession(session: session, chatViewModel: chatViewModel)
          
          // Reload sessions to get fresh data after restoration
          await loadAvailableSessions()
          
          await MainActor.run {
            showSessionPicker = false
          }
        }
      },
      onDeleteSession: { session in
        sessionToDelete = session
        showDeleteConfirmation = true
      },
      onDeleteAll: {
        showDeleteAllConfirmation = true
      }
    )
    .alert("Delete Session", isPresented: $showDeleteConfirmation) {
      Button("Cancel", role: .cancel) {
        sessionToDelete = nil
      }
      Button("Delete", role: .destructive) {
        if let session = sessionToDelete {
          Task {
            await deleteSession(session)
          }
        }
      }
    } message: {
      if let session = sessionToDelete {
        Text("Are you sure you want to delete the session \"\(session.firstUserMessage.truncateIntelligently(to: 100))\"? This action cannot be undone.")
      }
    }
    .alert("Delete All Sessions", isPresented: $showDeleteAllConfirmation) {
      Button("Cancel", role: .cancel) { }
      Button("Delete All", role: .destructive) {
        Task {
          await deleteAllSessions()
        }
      }
    } message: {
      if availableSessions.count > 10 {
        Text("You are about to delete \(availableSessions.count) sessions. This is a large number and they won't be recovered. Are you absolutely sure?")
      } else {
        Text("You are about to delete \(availableSessions.count) session\(availableSessions.count == 1 ? "" : "s"). They won't be recovered. Are you sure?")
      }
    }
    .alert("Failed to Delete Sessions", isPresented: $showDeleteAllError) {
      Button("OK", role: .cancel) {
        deleteAllError = nil
      }
    } message: {
      if let error = deleteAllError {
        Text("An error occurred while deleting sessions: \(error.localizedDescription)")
      }
    }
  }
  
  private func errorMessageView(_ error: Error) -> some View {
    VStack(spacing: 16) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 48))
        .foregroundStyle(.red)
      
      Text("Initialization Failed")
        .font(.title2)
        .fontWeight(.semibold)
      
      Text(error.localizedDescription)
        .font(.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal)
      
      Button("Retry") {
        initializationError = nil
        isInitialized = false
        Task {
          do {
            try await initializeClaudeCodeUI()
          } catch {
            initializationError = error
          }
        }
      }
      .buttonStyle(.borderedProminent)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
  }
  
  private func loadAvailableSessions() async {
    await MainActor.run {
      isLoadingSessions = true
      sessionLoadError = nil
    }
    
    do {
      var sessions = try await sessionManager.loadAvailableSessions()
      
      // Check if current session exists and update its message count from in-memory store
      if let currentId = await MainActor.run(body: { currentSessionId }) {
        if let index = sessions.firstIndex(where: { $0.id == currentId }) {
          // Update the message count for current session from MessageStore
          if let viewModel = await MainActor.run(body: { chatViewModel }) {
            let currentMessages = await MainActor.run { viewModel.getCurrentMessages() }
            var updatedSession = sessions[index]
            updatedSession.messages = currentMessages
            sessions[index] = updatedSession
          }
        } else {
          // Current session not in database yet, create placeholder
          if let viewModel = await MainActor.run(body: { chatViewModel }) {
            let currentMessages = await MainActor.run { viewModel.getCurrentMessages() }
            let firstMessage = currentMessages.first?.content ?? "Current Session"
            let currentSession = StoredSession(
              id: currentId,
              createdAt: Date(),
              firstUserMessage: firstMessage,
              lastAccessedAt: Date(),
              messages: currentMessages,
              workingDirectory: await MainActor.run { viewModel.projectPath }
            )
            sessions.insert(currentSession, at: 0)
          }
        }
      }
      
      await MainActor.run {
        availableSessions = sessions
        isLoadingSessions = false
      }
    } catch {
      await MainActor.run {
        sessionLoadError = error
        isLoadingSessions = false
      }
    }
  }
  
  private func deleteSession(_ session: StoredSession) async {
    do {
      // Check if we're deleting the current session
      if session.id == currentSessionId {
        await MainActor.run {
          currentSessionId = nil
        }
        // Also clear the chat interface if needed
        if let viewModel = chatViewModel {
          await MainActor.run {
            viewModel.clearConversation()
          }
        }
      }
      
      try await sessionManager.deleteSession(sessionId: session.id)
      
      await loadAvailableSessions()
      
      await MainActor.run {
        sessionToDelete = nil
      }
    } catch {
      await MainActor.run {
        sessionToDelete = nil
      }
    }
  }

  private func deleteAllSessions() async {
    do {
      // Clear current session since we're deleting all
      await MainActor.run {
        currentSessionId = nil
      }

      // Clear the chat interface
      if let viewModel = chatViewModel {
        await MainActor.run {
          viewModel.clearConversation()
        }
      }

      try await sessionManager.deleteAllSessions()

      await loadAvailableSessions()
    } catch {
      // Show error alert to user
      await MainActor.run {
        deleteAllError = error
        showDeleteAllError = true
      }
      ClaudeCodeLogger.shared.log(.container, "[ClaudeCodeContainer] Error deleting all sessions: \(error.localizedDescription)")
    }
  }
}
