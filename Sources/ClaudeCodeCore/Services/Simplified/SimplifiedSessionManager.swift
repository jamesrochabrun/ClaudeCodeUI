import Foundation

// MARK: - SimplifiedSessionManager

public final class SimplifiedSessionManager: SimplifiedSessionManagerProtocol {

  public init(
    claudeCodeStorage: SessionStorageProtocol,
    globalPreferences: GlobalPreferencesStorage
  ) {
    self.claudeCodeStorage = claudeCodeStorage
    self.globalPreferences = globalPreferences
  }
    
  @MainActor
  public func startNewSession(chatViewModel: ChatViewModel, workingDirectory: String? = nil) {
    // Clear any existing conversation
    chatViewModel.clearConversation()

    // Use provided directory, or fall back to global preference
    let directoryToUse = workingDirectory ?? globalPreferences.defaultWorkingDirectory

    if !directoryToUse.isEmpty {
      chatViewModel.claudeClient.configuration.workingDirectory = directoryToUse
      chatViewModel.projectPath = directoryToUse
      chatViewModel.settingsStorage.setProjectPath(directoryToUse)
    }

    // Note: Actual session saving happens when the first message is sent
    // and Claude provides a session ID through the StreamProcessor
  }
  
  public func restoreSession(session: StoredSession, chatViewModel: ChatViewModel) async {
    // Fetch fresh session data from storage to get all messages
    let freshSession: StoredSession
    do {
      if let loadedSession = try await claudeCodeStorage.getSession(id: session.id) {
        freshSession = loadedSession
      } else {
        freshSession = session
      }
    } catch {
      freshSession = session
    }

    await MainActor.run {
      // Use the session's working directory, or fall back to global preference
      let workingDirectory = freshSession.workingDirectory ?? globalPreferences.defaultWorkingDirectory

      // Inject the session into the chat view model with the correct working directory
      chatViewModel.injectSession(
        sessionId: freshSession.id,
        messages: freshSession.messages,
        workingDirectory: workingDirectory.isEmpty ? nil : workingDirectory
      )
    }
  }
  
  public func loadAvailableSessions() async throws -> [StoredSession] {
    // Load sessions directly from our dedicated Claude Code storage
    let sessions = try await claudeCodeStorage.getAllSessions()

    return sessions
  }
  
  public func deleteSession(sessionId: String) async throws {
    try await claudeCodeStorage.deleteSession(id: sessionId)
  }

  public func deleteAllSessions() async throws {
    try await claudeCodeStorage.deleteAllSessions()
  }

  private let claudeCodeStorage: SessionStorageProtocol
  private let globalPreferences: GlobalPreferencesStorage

}
