//
//  StreamingTestUtilities.swift
//  ClaudeCodeUITests
//
//  Helper utilities for streaming tests
//

import Foundation
import XCTest
import Combine
@testable import ClaudeCodeUI

/// Utilities for testing streaming functionality
struct StreamingTestUtilities {
  
  // MARK: - Expectations
  
  /// Waits for messages to appear in the message store
  @MainActor
  static func waitForMessages(
    in store: MessageStore,
    count: Int,
    timeout: TimeInterval = 5.0,
    file: StaticString = #file,
    line: UInt = #line
  ) async throws {
    let startTime = Date()
    
    while store.messages.count < count {
      if Date().timeIntervalSince(startTime) > timeout {
        XCTFail(
          "Timeout waiting for \(count) messages. Got \(store.messages.count)",
          file: file,
          line: line
        )
        throw TestError.timeout
      }
      try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
    }
  }
  
  /// Waits for a specific message content to appear
  @MainActor
  static func waitForMessageContent(
    in store: MessageStore,
    containing text: String,
    timeout: TimeInterval = 5.0,
    file: StaticString = #file,
    line: UInt = #line
  ) async throws -> ChatMessage? {
    let startTime = Date()
    
    while true {
      if let message = store.messages.first(where: { $0.content.contains(text) }) {
        return message
      }
      
      if Date().timeIntervalSince(startTime) > timeout {
        XCTFail(
          "Timeout waiting for message containing '\(text)'",
          file: file,
          line: line
        )
        throw TestError.timeout
      }
      try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
    }
  }
  
  /// Waits for session to be established
  @MainActor
  static func waitForSession(
    in manager: SessionManager,
    timeout: TimeInterval = 5.0,
    file: StaticString = #file,
    line: UInt = #line
  ) async throws {
    let startTime = Date()
    
    while manager.currentSessionId == nil {
      if Date().timeIntervalSince(startTime) > timeout {
        XCTFail(
          "Timeout waiting for session to be established",
          file: file,
          line: line
        )
        throw TestError.timeout
      }
      try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
    }
  }
  
  // MARK: - Assertions
  
  /// Asserts message sequence matches expected pattern
  @MainActor
  static func assertMessageSequence(
    _ messages: [ChatMessage],
    matches expectedSequence: [(role: MessageRole, contentContains: String?)],
    file: StaticString = #file,
    line: UInt = #line
  ) {
    XCTAssertEqual(
      messages.count,
      expectedSequence.count,
      "Message count mismatch",
      file: file,
      line: line
    )
    
    for (index, (message, expected)) in zip(messages, expectedSequence).enumerated() {
      XCTAssertEqual(
        message.role,
        expected.role,
        "Role mismatch at index \(index)",
        file: file,
        line: line
      )
      
      if let expectedContent = expected.contentContains {
        XCTAssertTrue(
          message.content.contains(expectedContent),
          "Content mismatch at index \(index). Expected to contain '\(expectedContent)' but got '\(message.content)'",
          file: file,
          line: line
        )
      }
    }
  }
  
  /// Asserts all message IDs are unique
  @MainActor
  static func assertUniqueMessageIds(
    _ messages: [ChatMessage],
    file: StaticString = #file,
    line: UInt = #line
  ) {
    let ids = messages.map { $0.id }
    let uniqueIds = Set(ids)
    
    XCTAssertEqual(
      ids.count,
      uniqueIds.count,
      "Duplicate message IDs found",
      file: file,
      line: line
    )
  }
  
  /// Asserts no message content was lost (for update bug detection)
  @MainActor
  static func assertNoContentLoss(
    messages: [ChatMessage],
    expectedContent: [String],
    file: StaticString = #file,
    line: UInt = #line
  ) {
    let allContent = messages.map { $0.content }.joined(separator: " ")
    
    for content in expectedContent {
      XCTAssertTrue(
        allContent.contains(content),
        "Expected content '\(content)' was lost",
        file: file,
        line: line
      )
    }
  }
  
  // MARK: - Mock Helpers
  
  /// Creates a delay publisher for testing timing
  static func delayPublisher<T>(
    _ value: T,
    delay: TimeInterval
  ) -> AnyPublisher<T, Never> {
    Just(value)
      .delay(for: .seconds(delay), scheduler: DispatchQueue.main)
      .eraseToAnyPublisher()
  }
  
  /// Combines multiple publishers with delays between them
  static func sequencePublishers<T>(
    _ publishers: [AnyPublisher<T, Error>],
    delayBetween: TimeInterval = 0.1
  ) -> AnyPublisher<T, Error> {
    guard !publishers.isEmpty else {
      return Empty().eraseToAnyPublisher()
    }
    
    var result = publishers[0]
    
    for publisher in publishers.dropFirst() {
      result = result
        .delay(for: .seconds(delayBetween), scheduler: DispatchQueue.main)
        .append(publisher)
        .eraseToAnyPublisher()
    }
    
    return result
  }
  
  // MARK: - Debug Helpers
  
  /// Prints message store state for debugging
  @MainActor
  static func printMessageStore(_ store: MessageStore, label: String = "") {
    print("\n=== Message Store \(label) ===")
    print("Total messages: \(store.messages.count)")
    for (index, message) in store.messages.enumerated() {
      print("\(index): [\(message.role)] \(message.content.prefix(50))...")
    }
    print("========================\n")
  }
  
  /// Captures message store changes over time
  @MainActor
  static func captureMessageChanges(
    store: MessageStore,
    duration: TimeInterval
  ) async -> [(time: TimeInterval, messages: [ChatMessage])] {
    var captures: [(TimeInterval, [ChatMessage])] = []
    let startTime = Date()
    
    while Date().timeIntervalSince(startTime) < duration {
      let currentTime = Date().timeIntervalSince(startTime)
      let currentMessages = store.messages
      captures.append((currentTime, currentMessages))
      try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
    }
    
    return captures
  }
  
  // MARK: - Error Types
  
  enum TestError: Error {
    case timeout
    case unexpectedState(String)
  }
}

// MARK: - Test Extensions

extension ChatMessage {
  /// Creates a test message with minimal required properties
  static func testMessage(
    role: MessageRole,
    content: String,
    isComplete: Bool = true
  ) -> ChatMessage {
    ChatMessage(
      role: role,
      content: content,
      isComplete: isComplete,
      messageType: role == .assistant ? .text : .text
    )
  }
}

extension MessageStore {
  /// Gets messages filtered by role
  @MainActor
  func messages(withRole role: MessageRole) -> [ChatMessage] {
    messages.filter { $0.role == role }
  }
  
  /// Gets the last message with specific role
  @MainActor
  func lastMessage(withRole role: MessageRole) -> ChatMessage? {
    messages.last { $0.role == role }
  }
}