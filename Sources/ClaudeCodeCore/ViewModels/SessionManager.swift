//
//  SessionManager.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 6/8/2025.
//

import Foundation
import ClaudeCodeSDK

/// Manages Claude conversation sessions
@MainActor
@Observable
final class SessionManager {
  private(set) var currentSessionId: String?
  private(set) var sessions: [StoredSession] = []
  private(set) var isLoadingSessions: Bool = false
  private(set) var sessionsError: Error?
  
  private let sessionStorage: SessionStorageProtocol
  
  init(sessionStorage: SessionStorageProtocol) {
    self.sessionStorage = sessionStorage
  }
  
  func startNewSession(id: String, firstMessage: String, workingDirectory: String? = nil) {
    // Log if we're replacing an existing session
    if let existingId = currentSessionId {
      ClaudeCodeLogger.shared.session("SessionManager.startNewSession - Replacing existing session \(existingId) with new session \(id)")
    } else {
      ClaudeCodeLogger.shared.session("SessionManager.startNewSession - Starting fresh session \(id)")
    }

    currentSessionId = id
    ClaudeCodeLogger.shared.session("SessionManager.startNewSession - currentSessionId set to: \(id), firstMessage: \(firstMessage), workingDirectory: \(workingDirectory ?? "nil")")

    // Save to storage
    Task {
      do {
        try await sessionStorage.saveSession(id: id, firstMessage: firstMessage, workingDirectory: workingDirectory)
        // Refresh sessions list
        await fetchSessions()
      } catch {
        // Handle error silently
      }
    }
  }
  
  func clearSession() {
    let previousId = currentSessionId
    currentSessionId = nil
    ClaudeCodeLogger.shared.session("SessionManager.clearSession - Cleared session. Previous: \(previousId ?? "nil")")
  }
  
  var hasActiveSession: Bool {
    currentSessionId != nil
  }
  
  func selectSession(id: String) {
    // Don't check if session exists in array - trust the caller
    // Sessions might not be loaded yet when resuming
    let previousId = currentSessionId
    currentSessionId = id

    if previousId != id {
      ClaudeCodeLogger.shared.session("SessionManager.selectSession - Switched from session \(previousId ?? "nil") to \(id)")
    } else {
      ClaudeCodeLogger.shared.session("SessionManager.selectSession - Selected same session: \(id)")
    }
  }
  
  /// Updates the current session ID to match what Claude is using.
  ///
  /// This method is called when Claude's streaming response contains a different
  /// session ID than what we expected. This situation typically occurs after:
  /// - Stream interruptions or cancellations
  /// - Network issues
  /// - Claude's internal session management decisions
  ///
  /// By updating our local session ID to match Claude's, we maintain conversation
  /// continuity and prevent creating multiple separate message threads.
  ///
  /// - Parameter id: The new session ID from Claude
  func updateCurrentSession(id: String) {
    let previousId = currentSessionId
    currentSessionId = id
    ClaudeCodeLogger.shared.session("SessionManager.updateCurrentSession - Updated session ID from \(previousId ?? "nil") to \(id) (Claude's ID)")

    // Persist the new session ID to storage
    if let oldId = previousId {
      ClaudeCodeLogger.shared.session("SessionManager.updateCurrentSession - Calling updateSessionId in storage: oldId=\(oldId), newId=\(id)")
      Task {
        do {
          try await sessionStorage.updateSessionId(oldId: oldId, newId: id)
          ClaudeCodeLogger.shared.session("SessionManager.updateCurrentSession - Successfully updated session ID in storage")
        } catch {
          ClaudeCodeLogger.shared.session("SessionManager.updateCurrentSession - ERROR: Failed to update session ID in storage: \(error)")
        }
      }
    } else {
      ClaudeCodeLogger.shared.session("SessionManager.updateCurrentSession - No previous ID to update")
    }
  }
  
  func updateLastAccessed(id: String) {
    Task {
      do {
        try await sessionStorage.updateLastAccessed(id: id)
      } catch {
        // Failed to update last accessed
      }
    }
  }
  
  /// Fetches all available sessions from storage
  func fetchSessions() async {
    isLoadingSessions = true
    sessionsError = nil
    
    do {
      sessions = try await sessionStorage.getAllSessions()
      isLoadingSessions = false
    } catch {
      sessions = []
      sessionsError = error
      isLoadingSessions = false
    }
  }
  
  /// Deletes a session
  func deleteSession(id: String) async {
    do {
      try await sessionStorage.deleteSession(id: id)
      await fetchSessions()
      
      // Clear current session if it was deleted
      if currentSessionId == id {
        currentSessionId = nil
      }
    } catch {
      sessionsError = error
    }
  }
}
