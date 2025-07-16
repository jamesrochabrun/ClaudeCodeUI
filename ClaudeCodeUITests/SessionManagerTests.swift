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
    let sessionStorage = UserDefaultsSessionStorage()
    let manager = SessionManager(sessionStorage: sessionStorage)
    
    #expect(manager.currentSessionId == nil)
    #expect(manager.hasActiveSession == false)
    
    let sessionId = "test-session-123"
    let firstMessage = "Hello, Claude!"
    manager.startNewSession(id: sessionId, firstMessage: firstMessage)
    
    #expect(manager.currentSessionId == sessionId)
    #expect(manager.hasActiveSession == true)
    
    // Wait a bit for async save
    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    
    // Verify session was saved to storage
    let savedSession = try await sessionStorage.getSession(id: sessionId)
    #expect(savedSession != nil)
    #expect(savedSession?.firstUserMessage == firstMessage)
  }
  
  @Test func testClearSession() async throws {
    let sessionStorage = UserDefaultsSessionStorage()
    let manager = SessionManager(sessionStorage: sessionStorage)
    
    // Start a session first
    let sessionId = "test-session-to-clear"
    manager.startNewSession(id: sessionId, firstMessage: "Test message")
    #expect(manager.currentSessionId == sessionId)
    #expect(manager.hasActiveSession == true)
    
    // Clear the session
    manager.clearSession()
    
    // Verify session is cleared
    #expect(manager.currentSessionId == nil)
    #expect(manager.hasActiveSession == false)
    
    // Note: clearSession() doesn't delete from storage, just clears current
    // The session should still exist in storage
    try await Task.sleep(nanoseconds: 100_000_000)
    let savedSession = try await sessionStorage.getSession(id: sessionId)
    #expect(savedSession != nil, "Session should still exist in storage after clearing")
  }
  
  @Test func testReplaceSession() async throws {
    let sessionStorage = UserDefaultsSessionStorage()
    let manager = SessionManager(sessionStorage: sessionStorage)
    
    // Start first session
    let firstId = "first-session"
    let firstMessage = "First conversation"
    manager.startNewSession(id: firstId, firstMessage: firstMessage)
    #expect(manager.currentSessionId == firstId)
    
    // Replace with second session
    let secondId = "second-session"
    let secondMessage = "Second conversation"
    manager.startNewSession(id: secondId, firstMessage: secondMessage)
    #expect(manager.currentSessionId == secondId)
    
    // Wait for async saves
    try await Task.sleep(nanoseconds: 100_000_000)
    
    // Verify both sessions exist in storage
    let firstSession = try await sessionStorage.getSession(id: firstId)
    let secondSession = try await sessionStorage.getSession(id: secondId)
    
    #expect(firstSession != nil, "First session should still exist")
    #expect(firstSession?.firstUserMessage == firstMessage)
    #expect(secondSession != nil, "Second session should exist")
    #expect(secondSession?.firstUserMessage == secondMessage)
  }
}
