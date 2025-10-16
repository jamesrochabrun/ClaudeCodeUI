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
      if
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
      await initializeClaudeCodeUI()
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
  
  private func initializeClaudeCodeUI() async {

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

    let claudeClient = ClaudeCodeClient(configuration: config)
    
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
      onUserMessageSent: onUserMessageSent,
      onSelectWorkingDirectory: { @MainActor in
        // Show directory picker when recovery action is triggered
        selectWorkingDirectory(for: viewModel, claudeClient: claudeClient, settingsStorage: deps.settingsStorage)
      }
    )

    // Initialize global preference from configuration if not already set
    // This allows configuration to suggest a default path on first launch
    // Once set, user's global preference takes precedence (won't be overridden by config changes)
    if globalPrefs.defaultWorkingDirectory.isEmpty,
       let configPath = claudeCodeConfiguration.workingDirectory,
       !configPath.isEmpty {
      globalPrefs.defaultWorkingDirectory = configPath
    }

    // Set the default working directory from global preferences on app launch
    if !globalPrefs.defaultWorkingDirectory.isEmpty {
      claudeClient.configuration.workingDirectory = globalPrefs.defaultWorkingDirectory
      viewModel.projectPath = globalPrefs.defaultWorkingDirectory
      deps.settingsStorage.setProjectPath(globalPrefs.defaultWorkingDirectory)
    }

    // Apply stored claudePath from preferences to ensure it persists across app restarts
    viewModel.updateClaudeCommand(from: globalPrefs)

    await MainActor.run {
      chatViewModel = viewModel
      globalPreferences = globalPrefs
      claudeCodeDeps = deps
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
  }
  
  private func loadAvailableSessions() async {
    await MainActor.run {
      isLoadingSessions = true
      sessionLoadError = nil
    }

    do {
      var sessions = try await sessionManager.loadAvailableSessions()

      // Check if current session exists and update its message count from in-memory store
      if let currentId = await MainActor.run { currentSessionId } {
        if let index = sessions.firstIndex(where: { $0.id == currentId }) {
          // Update the message count for current session from MessageStore
          if let viewModel = await MainActor.run { chatViewModel } {
            let currentMessages = await MainActor.run { viewModel.getCurrentMessages() }
            var updatedSession = sessions[index]
            updatedSession.messages = currentMessages
            sessions[index] = updatedSession
          }
        } else {
          // Current session not in database yet, create placeholder
          if let viewModel = await MainActor.run { chatViewModel } {
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

  private func selectWorkingDirectory(
    for viewModel: ChatViewModel,
    claudeClient: ClaudeCode,
    settingsStorage: SettingsStorage
  ) {
    #if os(macOS)
    let openPanel = NSOpenPanel()
    openPanel.title = "Select Working Directory"
    openPanel.message = "Choose a working directory for Claude Code"
    openPanel.canChooseFiles = false
    openPanel.canChooseDirectories = true
    openPanel.allowsMultipleSelection = false
    openPanel.canCreateDirectories = true

    // Set initial directory to current working directory if it exists
    if !viewModel.projectPath.isEmpty, FileManager.default.fileExists(atPath: viewModel.projectPath) {
      openPanel.directoryURL = URL(fileURLWithPath: viewModel.projectPath)
    }

    openPanel.begin { response in
      guard response == .OK, let url = openPanel.url else { return }

      let selectedPath = url.path

      // Update all necessary components with the new path
      viewModel.projectPath = selectedPath
      claudeClient.configuration.workingDirectory = selectedPath
      settingsStorage.setProjectPath(selectedPath)

      // If there's an active session, save the path for that session too
      if let sessionId = viewModel.activeSessionId {
        settingsStorage.setProjectPath(selectedPath, forSessionId: sessionId)
      }

      ClaudeCodeLogger.shared.log(.container, "[ClaudeCodeContainer] Updated working directory to: \(selectedPath)")
    }
    #endif
  }
}
