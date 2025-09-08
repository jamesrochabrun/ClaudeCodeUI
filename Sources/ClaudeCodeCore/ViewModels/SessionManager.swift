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
  private(set) var previousSessionId: String?  // Track previous valid session for fallback
  private(set) var sessions: [StoredSession] = []
  private(set) var isLoadingSessions: Bool = false
  private(set) var sessionsError: Error?
  
  private let sessionStorage: SessionStorageProtocol
  
  init(sessionStorage: SessionStorageProtocol) {
    self.sessionStorage = sessionStorage
  }
  
  func startNewSession(id: String, firstMessage: String) {
    // Log if we're replacing an existing session
    if let existingId = currentSessionId {
      print("🔄 Replacing session '\(existingId)' with new session '\(id)'")
      // Don't set previous when starting fresh
    }
    
    currentSessionId = id
    print("✅ New session started: \(id)")
    
    // Save to storage
    Task {
      do {
        try await sessionStorage.saveSession(id: id, firstMessage: firstMessage)
        // Refresh sessions list
        await fetchSessions()
      } catch {
        // Handle error silently for now
        print("Failed to save session: \(error)")
      }
    }
  }
  
  func clearSession() {
    previousSessionId = currentSessionId  // Save as previous before clearing
    currentSessionId = nil
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
      print("🔄 Session switched from '\(previousId ?? "nil")' to '\(id)'")
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
    // Save the previous session ID for potential fallback
    if let current = currentSessionId, current != id {
      previousSessionId = current
      print("📌 Saving previous session ID for fallback: '\(current)'")
    }
    
    // Update the current session ID when Claude returns a different one
    currentSessionId = id
    print("🔄 Session ID chain updated: '\(previousSessionId ?? "nil")' → '\(id)'")
    
    // Persist the new session ID to storage
    if let oldId = previousSessionId {
      Task {
        do {
          try await sessionStorage.updateSessionId(oldId: oldId, newId: id)
          print("✅ Persisted new session ID '\(id)' to storage")
        } catch {
          print("❌ Failed to update session ID in storage: \(error)")
        }
      }
    }
  }
  
  /// Reverts to the previous session ID (used when current session is invalid)
  func revertToPreviousSession() -> String? {
    guard let previous = previousSessionId else {
      print("⚠️ No previous session ID to revert to")
      return nil
    }
    
    print("🔙 Reverting from phantom session '\(currentSessionId ?? "nil")' to previous session '\(previous)'")
    currentSessionId = previous
    previousSessionId = nil  // Clear to avoid double revert
    return previous
  }
  
  func updateLastAccessed(id: String) {
    Task {
      do {
        try await sessionStorage.updateLastAccessed(id: id)
      } catch {
        print("Failed to update last accessed: \(error)")
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
