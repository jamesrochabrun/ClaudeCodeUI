//
//  SessionManagerTests.swift
//  ClaudeCodeUITests
//
//  Created by Assistant on 6/8/2025.
//

import Testing
import Foundation
@testable import ClaudeCodeUI

@MainActor
struct SessionManagerTests {
  
  @Test func testStartNewSession() async throws {
    let manager = SessionManager()
    
    #expect(manager.currentSessionId == nil)
    
    let sessionId = "test-session-123"
    manager.startNewSession(id: sessionId)
    
    #expect(manager.currentSessionId == sessionId)
  }
  
  @Test func testClearSession() async throws {
    let manager = SessionManager()
    
    manager.startNewSession(id: "test-session")
    #expect(manager.currentSessionId != nil)
    
    manager.clearSession()
    #expect(manager.currentSessionId == nil)
  }
  
  @Test func testReplaceSession() async throws {
    let manager = SessionManager()
    
    manager.startNewSession(id: "first-session")
    #expect(manager.currentSessionId == "first-session")
    
    manager.startNewSession(id: "second-session")
    #expect(manager.currentSessionId == "second-session")
  }
}
