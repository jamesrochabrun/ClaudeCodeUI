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
    print("[zizou] SimplifiedSessionManager.startNewSession - Starting new session with workingDirectory: \(workingDirectory ?? "nil")")

    // Clear any existing conversation
    chatViewModel.clearConversation()

    // Use provided directory, or fall back to global preference
    let directoryToUse = workingDirectory ?? globalPreferences.defaultWorkingDirectory
    print("[zizou] SimplifiedSessionManager.startNewSession - Using directory: \(directoryToUse.isEmpty ? "<empty>" : directoryToUse)")

    if !directoryToUse.isEmpty {
      chatViewModel.claudeClient.configuration.workingDirectory = directoryToUse
      chatViewModel.projectPath = directoryToUse
      chatViewModel.settingsStorage.setProjectPath(directoryToUse)
    }

    // Note: Actual session saving happens when the first message is sent
    // and Claude provides a session ID through the StreamProcessor
    print("[zizou] SimplifiedSessionManager.startNewSession - Session will be created when first message is sent")
  }
  
  public func restoreSession(session: StoredSession, chatViewModel: ChatViewModel) async {
    print("[zizou] SimplifiedSessionManager.restoreSession - Restoring session \(session.id) with \(session.messages.count) messages")
    await MainActor.run {
      // Use the session's working directory, or fall back to global preference
      let workingDirectory = session.workingDirectory ?? globalPreferences.defaultWorkingDirectory
      print("[zizou] SimplifiedSessionManager.restoreSession - Using workingDirectory: \(workingDirectory.isEmpty ? "<empty>" : workingDirectory)")

      // Inject the session into the chat view model with the correct working directory
      chatViewModel.injectSession(
        sessionId: session.id,
        messages: session.messages,
        workingDirectory: workingDirectory.isEmpty ? nil : workingDirectory
      )
      print("[zizou] SimplifiedSessionManager.restoreSession - Session injection complete")
    }
  }
  
  public func loadAvailableSessions() async throws -> [StoredSession] {
    print("[zizou] SimplifiedSessionManager.loadAvailableSessions - Loading sessions from storage")
    // Load sessions directly from our dedicated Claude Code storage
    let sessions = try await claudeCodeStorage.getAllSessions()
    if !sessions.isEmpty {
      let sessionIds = sessions.map { $0.id }.joined(separator: ", ")
      print("[zizou] SimplifiedSessionManager.loadAvailableSessions - Loaded \(sessions.count) sessions: [\(sessionIds)]")
    } else {
      print("[zizou] SimplifiedSessionManager.loadAvailableSessions - No sessions found")
    }

    return sessions
  }
  
  public func deleteSession(sessionId: String) async throws {
    print("[zizou] SimplifiedSessionManager.deleteSession - Deleting session: \(sessionId)")
    try await claudeCodeStorage.deleteSession(id: sessionId)
    print("[zizou] SimplifiedSessionManager.deleteSession - Session deleted successfully")
  }
    
  private let claudeCodeStorage: SessionStorageProtocol
  private let globalPreferences: GlobalPreferencesStorage
  
}
