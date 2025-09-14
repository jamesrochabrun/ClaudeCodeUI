import ClaudeCodeSDK
import Foundation
import SwiftUI

// MARK: - ClaudeCodeContainer

public struct ClaudeCodeContainer: View {
  
  // MARK: Lifecycle
  
  public init(
    claudeCodeConfiguration: ClaudeCodeConfiguration,
    uiConfiguration: UIConfiguration)
  {
    self.claudeCodeConfiguration = claudeCodeConfiguration
    self.uiConfiguration = uiConfiguration
    customStorage = SimplifiedClaudeCodeSQLiteStorage()
    // SessionManager will be initialized in initializeClaudeCodeUI with proper globalPreferences
    sessionManager = SimplifiedSessionManager(
      claudeCodeStorage: customStorage,
      globalPreferences: GlobalPreferencesStorage() // Temporary, will be replaced
    )
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
  
  // MARK: Private
  
  @State private var sessionManager: SimplifiedSessionManagerProtocol
  @State private var isInitialized = false
  @State private var chatViewModel: ClaudeCodeCore.ChatViewModel?
  @State private var globalPreferences: GlobalPreferencesStorage?
  @State private var claudeCodeDeps: ClaudeCodeCore.DependencyContainer?
  
  @State private var showSessionPicker = false
  @State private var availableSessions: [StoredSession] = []
  @State private var isLoadingSessions = false
  @State private var sessionLoadError: Error?
  @State private var currentSessionId: String?
  
  @State private var showDeleteConfirmation = false
  @State private var sessionToDelete: StoredSession?
  
  private func initializeClaudeCodeUI() async {
    let globalPrefs = GlobalPreferencesStorage()

    // Now create the proper session manager with global preferences
    sessionManager = SimplifiedSessionManager(
      claudeCodeStorage: customStorage,
      globalPreferences: globalPrefs
    )

    let deps = ClaudeCodeCore.DependencyContainer(
      globalPreferences: globalPrefs,
      customSessionStorage: customStorage,
    )

    let config = claudeCodeConfiguration

    let claudeClient = ClaudeCodeClient(configuration: config)
    
    let viewModel = ClaudeCodeCore.ChatViewModel(
      claudeClient: claudeClient,
      sessionStorage: customStorage,
      settingsStorage: deps.settingsStorage,
      globalPreferences: globalPrefs,
      customPermissionService: deps.customPermissionService,
      onSessionChange: { newSessionId in
        Task { @MainActor in
          currentSessionId = newSessionId
          await loadAvailableSessions()
        }
      },
    )
    
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
          print("[zizou] ClaudeCodeContainer - onShowSessionPicker triggered. availableSessions.count: \(availableSessions.count)")
          if availableSessions.isEmpty {
            print("[zizou] ClaudeCodeContainer - Sessions empty, loading...")
            await loadAvailableSessions()
          }
          showSessionPicker = true
          print("[zizou] ClaudeCodeContainer - showSessionPicker set to true")
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
        print("[zizou] ClaudeCodeContainer - onStartNewSession with workingDirectory: \(workingDirectory ?? "nil")")
        sessionManager.startNewSession(chatViewModel: chatViewModel, workingDirectory: workingDirectory)
        showSessionPicker = false
      },
      onRestoreSession: { session in
        Task {
          print("[zizou] ClaudeCodeContainer - onRestoreSession for session: \(session.id)")
          await sessionManager.restoreSession(session: session, chatViewModel: chatViewModel)
          await MainActor.run {
            showSessionPicker = false
            print("[zizou] ClaudeCodeContainer - Session restored, picker closed")
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
        Text("Are you sure you want to delete the session \"\(session.firstUserMessage)\"? This action cannot be undone.")
      }
    }
  }
  
  private func loadAvailableSessions() async {
    print("[zizou] ClaudeCodeContainer.loadAvailableSessions - Starting to load sessions")
    await MainActor.run {
      isLoadingSessions = true
      sessionLoadError = nil
    }

    do {
      var sessions = try await sessionManager.loadAvailableSessions()
      print("[zizou] ClaudeCodeContainer.loadAvailableSessions - Loaded \(sessions.count) sessions from manager")

      // Check if current session exists and update its message count from in-memory store
      if let currentId = await MainActor.run { currentSessionId } {
        if let index = sessions.firstIndex(where: { $0.id == currentId }) {
          // Update the message count for current session from MessageStore
          if let viewModel = await MainActor.run { chatViewModel } {
            let currentMessages = await MainActor.run { viewModel.getCurrentMessages() }
            var updatedSession = sessions[index]
            updatedSession.messages = currentMessages
            sessions[index] = updatedSession
            print("[zizou] ClaudeCodeContainer.loadAvailableSessions - Updated current session \(currentId) with \(currentMessages.count) in-memory messages")
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
            print("[zizou] ClaudeCodeContainer.loadAvailableSessions - Added current session \(currentId) with \(currentMessages.count) messages")
          }
        }
      }

      await MainActor.run {
        availableSessions = sessions
        isLoadingSessions = false
        print("[zizou] ClaudeCodeContainer.loadAvailableSessions - Set availableSessions to \(sessions.count) sessions")
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
}
