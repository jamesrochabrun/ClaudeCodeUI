import Foundation

// MARK: - SimplifiedSessionManager

public final class SimplifiedSessionManager: SimplifiedSessionManagerProtocol {
  
  public init(
    claudeCodeStorage: SessionStorageProtocol,
    appsRepoRootPath: String?,
  ) {
    self.claudeCodeStorage = claudeCodeStorage
    self.appsRepoRootPath = appsRepoRootPath
  }
    
  @MainActor
  public func startNewSession(chatViewModel: ChatViewModel) {
    
    // Clear any existing conversation but preserve working directory
    chatViewModel.clearConversation()
    
    // Don't call chatViewModel.startNewSession() as it clears the project path
    // Instead, just ensure the working directory is set correctly
    if let projectPath = appsRepoRootPath {
      chatViewModel.refreshProjectPath() // This will update from settings storage
    } else {
      // [SessionManager] ⚠️ Started new session without project path")
    }
  }
  
  public func restoreSession(session: StoredSession, chatViewModel: ChatViewModel) async {
    // Logger.info("[SessionManager] Attempting to restore session '\(session.id)' with \(session.messages.count) messages")
    
    // Use the working directory from the session storage or fallback to the default
    let workingDirectory = appsRepoRootPath
    
    await MainActor.run {
      // Inject the session into the chat view model with the correct working directory
      chatViewModel.injectSession(
        sessionId: session.id,
        messages: session.messages,
        workingDirectory: workingDirectory,
      )
    }
  }
  
  public func loadAvailableSessions() async throws -> [StoredSession] {
    // Load sessions directly from our dedicated Claude Code storage
    let sessions = try await claudeCodeStorage.getAllSessions()
    if !sessions.isEmpty {
      let sessionIds = sessions.map { $0.id }.joined(separator: ", ")
    } else {
    }
    
    return sessions
  }
  
  public func deleteSession(sessionId: String) async throws {
    try await claudeCodeStorage.deleteSession(id: sessionId)
  }
    
  private let claudeCodeStorage: SessionStorageProtocol
  private let appsRepoRootPath: String?
  
}
