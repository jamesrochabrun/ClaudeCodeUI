import Foundation

public protocol SimplifiedSessionManagerProtocol {

  func startNewSession(chatViewModel: ChatViewModel)

  func restoreSession(session: StoredSession, chatViewModel: ChatViewModel) async

  func loadAvailableSessions() async throws -> [StoredSession]

  func deleteSession(sessionId: String) async throws
}
