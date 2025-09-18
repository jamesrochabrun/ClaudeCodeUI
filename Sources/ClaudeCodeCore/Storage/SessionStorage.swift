//
//  SessionStorage.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 6/14/2025.
//

import Foundation

/// Session data stored for each conversation
public struct StoredSession: Codable, Identifiable, Sendable {
  public let id: String
  public let createdAt: Date
  public let firstUserMessage: String
  public var lastAccessedAt: Date
  /// Complete message history for this session
  public var messages: [ChatMessage]
  /// Working directory for this session
  public let workingDirectory: String?

  /// Creates a new StoredSession instance.
  /// - Parameters:
  ///   - id: Unique identifier for the session
  ///   - createdAt: When the session was created
  ///   - firstUserMessage: The first message from the user in this session
  ///   - lastAccessedAt: When the session was last accessed
  ///   - messages: Complete message history for this session
  ///   - workingDirectory: Working directory for this session
  public init(
    id: String,
    createdAt: Date,
    firstUserMessage: String,
    lastAccessedAt: Date,
    messages: [ChatMessage] = [],
    workingDirectory: String? = nil
  ) {
    self.id = id
    self.createdAt = createdAt
    self.firstUserMessage = firstUserMessage
    self.lastAccessedAt = lastAccessedAt
    self.messages = messages
    self.workingDirectory = workingDirectory
  }
  
  /// Computed title based on first user message
  public var title: String {
    let trimmed = firstUserMessage.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      return "New Session"
    }
    // Take first 50 characters of the message
    let maxLength = 50
    if trimmed.count <= maxLength {
      return trimmed
    }
    return String(trimmed.prefix(maxLength)) + "..."
  }
}

/// Protocol for session storage management
public protocol SessionStorageProtocol {
  /// Saves a new session
  func saveSession(id: String, firstMessage: String, workingDirectory: String?) async throws
  
  /// Retrieves all stored sessions
  func getAllSessions() async throws -> [StoredSession]
  
  /// Retrieves a specific session by ID
  func getSession(id: String) async throws -> StoredSession?
  
  /// Updates the last accessed time for a session
  func updateLastAccessed(id: String) async throws
  
  /// Deletes a session
  func deleteSession(id: String) async throws
  
  /// Deletes all sessions
  func deleteAllSessions() async throws
  
  /// Updates messages for a session
  func updateSessionMessages(id: String, messages: [ChatMessage]) async throws
  
  /// Updates the session ID (when Claude returns a new ID for the same conversation)
  func updateSessionId(oldId: String, newId: String) async throws
}

/// No-operation implementation of SessionStorage for direct ChatScreen usage.
/// This implementation doesn't store or load any sessions, avoiding unnecessary overhead.
public actor NoOpSessionStorage: SessionStorageProtocol {
  
  public init() {}
  
  public func saveSession(id: String, firstMessage: String, workingDirectory: String?) async throws {
    // No-op: Don't save anything
  }
  
  public func getAllSessions() async throws -> [StoredSession] {
    // Return empty array - no sessions to load
    return []
  }
  
  public func getSession(id: String) async throws -> StoredSession? {
    // No session exists
    return nil
  }
  
  public func updateLastAccessed(id: String) async throws {
    // No-op: Nothing to update
  }
  
  public func deleteSession(id: String) async throws {
    // No-op: Nothing to delete
  }
  
  public func deleteAllSessions() async throws {
    // No-op: Nothing to delete
  }
  
  public func updateSessionMessages(id: String, messages: [ChatMessage]) async throws {
    // No-op: Don't store messages
  }
  
  public func updateSessionId(oldId: String, newId: String) async throws {
    // No-op: No session to update
  }
}
