import Foundation

public protocol SimplifiedSessionManagerProtocol {

  func startNewSession(chatViewModel: ChatViewModel, workingDirectory: String?)

  func restoreSession(session: StoredSession, chatViewModel: ChatViewModel) async

  func loadAvailableSessions() async throws -> [StoredSession]

  func deleteSession(sessionId: String) async throws

  func deleteAllSessions() async throws
}
