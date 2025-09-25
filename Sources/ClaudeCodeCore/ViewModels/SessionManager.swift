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
  private var errorHandler: ((Error, ErrorOperation) -> Void)?

  init(sessionStorage: SessionStorageProtocol) {
    self.sessionStorage = sessionStorage
  }

  func setErrorHandler(_ handler: @escaping (Error, ErrorOperation) -> Void) {
    self.errorHandler = handler
  }
  
  func startNewSession(id: String, firstMessage: String, workingDirectory: String? = nil) {
    currentSessionId = id

    // Save to storage with worktree detection
    Task {
      do {
        // Detect worktree information if working directory is provided
        var branchName: String? = nil
        var isWorktree = false

        if let dir = workingDirectory {
          if let worktreeInfo = await GitWorktreeDetector.detectWorktreeInfo(for: dir) {
            branchName = worktreeInfo.branch
            isWorktree = worktreeInfo.isWorktree
          }
        }

        try await sessionStorage.saveSession(
          id: id,
          firstMessage: firstMessage,
          workingDirectory: workingDirectory,
          branchName: branchName,
          isWorktree: isWorktree
        )
        // Refresh sessions list
        await fetchSessions()
      } catch {
        // Surface error to user
        errorHandler?(error, .sessionManagement)
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

    // Persist the new session ID to storage
    if let oldId = previousId {
      Task {
        do {
          try await sessionStorage.updateSessionId(oldId: oldId, newId: id)
        } catch {
          ClaudeCodeLogger.shared.session("SessionManager.updateCurrentSession - ERROR: Failed to update session ID in storage: \(error)")
          errorHandler?(error, .sessionManagement)
        }
      }
    }
  }
  
  func updateLastAccessed(id: String) {
    Task {
      do {
        try await sessionStorage.updateLastAccessed(id: id)
      } catch {
        // Log but don't surface - this is non-critical
        ClaudeCodeLogger.shared.session("SessionManager.updateLastAccessed - Failed to update: \(error)")
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
