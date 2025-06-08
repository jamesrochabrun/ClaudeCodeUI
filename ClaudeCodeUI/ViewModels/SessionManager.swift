//
//  SessionManager.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 6/8/2025.
//

import Foundation

/// Manages Claude conversation sessions
@MainActor
@Observable
class SessionManager {
  private(set) var currentSessionId: String?
  
  func startNewSession(id: String) {
    currentSessionId = id
  }
  
  func clearSession() {
    currentSessionId = nil
  }
  
  var hasActiveSession: Bool {
    currentSessionId != nil
  }
}
