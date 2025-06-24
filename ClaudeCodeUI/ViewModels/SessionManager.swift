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
  
  func startNewSession(id: String, firstMessage: String) {
    currentSessionId = id
    
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
    currentSessionId = nil
  }
  
  var hasActiveSession: Bool {
    currentSessionId != nil
  }
  
  func selectSession(id: String) {
    // Don't check if session exists in array - trust the caller
    // Sessions might not be loaded yet when resuming
    currentSessionId = id
  }
  
  func updateCurrentSession(id: String) {
    // Update the current session ID when Claude returns a different one
    currentSessionId = id
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
