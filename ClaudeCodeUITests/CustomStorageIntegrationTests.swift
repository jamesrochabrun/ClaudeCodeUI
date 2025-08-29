//
//  CustomStorageIntegrationTests.swift
//  ClaudeCodeUITests
//
//  Created by Claude Code Integration on 8/29/2025.
//

import XCTest
import SwiftUI
import ClaudeCodeSDK
@testable import ClaudeCodeCore

/// Test suite for custom storage integration functionality
class CustomStorageIntegrationTests: XCTestCase {
  
  var globalPreferences: GlobalPreferencesStorage!
  var mockStorage: MockSessionStorage!
  
  override func setUp() {
    super.setUp()
    globalPreferences = GlobalPreferencesStorage()
    mockStorage = MockSessionStorage()
  }
  
  override func tearDown() {
    globalPreferences = nil
    mockStorage = nil
    super.tearDown()
  }
  
  // MARK: - DependencyContainer Tests
  
  func testDependencyContainerWithCustomStorage() async throws {
    // Given
    let customSessionStorage = MockSessionStorage()
    await customSessionStorage.saveSession(id: "test-session", firstMessage: "Hello")
    
    // When
    let container = DependencyContainer(
      globalPreferences: globalPreferences,
      customSessionStorage: customSessionStorage
    )
    
    // Then
    XCTAssertTrue(container.sessionStorage === customSessionStorage, 
                 "DependencyContainer should use the provided custom storage")
    
    // Verify the storage works
    let sessions = try await container.sessionStorage.getAllSessions()
    XCTAssertEqual(sessions.count, 1)
    XCTAssertEqual(sessions.first?.id, "test-session")
    XCTAssertEqual(sessions.first?.firstUserMessage, "Hello")
  }
  
  func testDependencyContainerWithoutCustomStorage() {
    // Given
    
    // When
    let container = DependencyContainer(globalPreferences: globalPreferences)
    
    // Then
    XCTAssertTrue(container.sessionStorage is UserDefaultsSessionStorage || 
                 container.sessionStorage is ClaudeNativeStorageAdapter,
                 "DependencyContainer should use default storage when no custom storage provided")
  }
  
  // MARK: - RootView Tests
  
  func testRootViewWithCustomDependencies() async throws {
    // Given
    let customSessionStorage = MockSessionStorage()
    await customSessionStorage.saveSession(id: "test-session", firstMessage: "Custom dependency test")
    
    let container = DependencyContainer(
      globalPreferences: globalPreferences,
      customSessionStorage: customSessionStorage
    )
    
    let configuration = ClaudeCodeAppConfiguration.default
    
    // When
    let rootView = RootView(
      sessionId: "test-session",
      configuration: configuration,
      dependencies: container
    )
    
    // Then
    // Test that the RootView can be created with custom dependencies
    XCTAssertNotNil(rootView)
    
    // Verify the storage is accessible and contains our test data
    let sessions = try await container.sessionStorage.getAllSessions()
    XCTAssertEqual(sessions.count, 1)
    XCTAssertEqual(sessions.first?.firstUserMessage, "Custom dependency test")
  }
  
  // MARK: - StoredSession Tests
  
  func testStoredSessionPublicInitializer() {
    // Given
    let id = "test-session"
    let createdAt = Date()
    let firstMessage = "Test message"
    let lastAccessed = Date()
    let messages = [
      ChatMessage(
        role: .user,
        content: "Hello",
        messageType: .text
      )
    ]
    
    // When
    let session = StoredSession(
      id: id,
      createdAt: createdAt,
      firstUserMessage: firstMessage,
      lastAccessedAt: lastAccessed,
      messages: messages
    )
    
    // Then
    XCTAssertEqual(session.id, id)
    XCTAssertEqual(session.createdAt, createdAt)
    XCTAssertEqual(session.firstUserMessage, firstMessage)
    XCTAssertEqual(session.lastAccessedAt, lastAccessed)
    XCTAssertEqual(session.messages.count, 1)
    XCTAssertEqual(session.messages.first?.content, "Hello")
  }
  
  // MARK: - Full Integration Test
  
  func testCustomStorageFullWorkflow() async throws {
    // Given
    let customStorage = MockSessionStorage()
    let container = DependencyContainer(
      globalPreferences: globalPreferences,
      customSessionStorage: customStorage
    )
    
    // When: Create a session with messages
    let sessionId = "integration-test-session"
    let firstMessage = "Integration test message"
    
    try await container.sessionStorage.saveSession(id: sessionId, firstMessage: firstMessage)
    
    let messages = [
      ChatMessage(role: .user, content: firstMessage, messageType: .text),
      ChatMessage(role: .assistant, content: "Hello! How can I help?", messageType: .text)
    ]
    
    try await container.sessionStorage.updateSessionMessages(id: sessionId, messages: messages)
    
    // Then: Verify the complete workflow
    let retrievedSession = try await container.sessionStorage.getSession(id: sessionId)
    XCTAssertNotNil(retrievedSession)
    XCTAssertEqual(retrievedSession?.id, sessionId)
    XCTAssertEqual(retrievedSession?.firstUserMessage, firstMessage)
    XCTAssertEqual(retrievedSession?.messages.count, 2)
    XCTAssertEqual(retrievedSession?.messages.first?.content, firstMessage)
    XCTAssertEqual(retrievedSession?.messages.last?.content, "Hello! How can I help?")
  }
  
  // MARK: - Error Handling Tests
  
  func testCustomStorageErrorHandling() async {
    // Given
    let customStorage = MockSessionStorage()
    customStorage.errorToThrow = NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
    
    let container = DependencyContainer(
      globalPreferences: globalPreferences,
      customSessionStorage: customStorage
    )
    
    // When/Then
    do {
      try await container.sessionStorage.saveSession(id: "test", firstMessage: "test")
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertEqual((error as NSError).localizedDescription, "Test error")
    }
  }
}