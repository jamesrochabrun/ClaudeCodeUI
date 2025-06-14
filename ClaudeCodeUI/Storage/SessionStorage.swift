//
//  SessionStorage.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 6/14/2025.
//

import Foundation

/// Session data stored for each conversation
public struct StoredSession: Codable, Identifiable {
  public let id: String
  public let createdAt: Date
  public let firstUserMessage: String
  public var lastAccessedAt: Date
  
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
  func saveSession(id: String, firstMessage: String) async throws
  
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
}

/// UserDefaults-based implementation of SessionStorage
public actor UserDefaultsSessionStorage: SessionStorageProtocol {
  private let userDefaults: UserDefaults
  private let storageKey = "com.claudecodeui.sessions"
  
  public init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults
  }
  
  public func saveSession(id: String, firstMessage: String) async throws {
    var sessions = try await getAllSessionsInternal()
    
    // Check if session already exists
    if sessions.contains(where: { $0.id == id }) {
      return
    }
    
    let newSession = StoredSession(
      id: id,
      createdAt: Date(),
      firstUserMessage: firstMessage,
      lastAccessedAt: Date()
    )
    
    sessions.append(newSession)
    try saveSessionsInternal(sessions)
  }
  
  public func getAllSessions() async throws -> [StoredSession] {
    return try await getAllSessionsInternal()
      .sorted(by: { $0.lastAccessedAt > $1.lastAccessedAt })
  }
  
  public func getSession(id: String) async throws -> StoredSession? {
    let sessions = try await getAllSessionsInternal()
    return sessions.first(where: { $0.id == id })
  }
  
  public func updateLastAccessed(id: String) async throws {
    var sessions = try await getAllSessionsInternal()
    
    guard let index = sessions.firstIndex(where: { $0.id == id }) else {
      return
    }
    
    sessions[index].lastAccessedAt = Date()
    try saveSessionsInternal(sessions)
  }
  
  public func deleteSession(id: String) async throws {
    var sessions = try await getAllSessionsInternal()
    sessions.removeAll(where: { $0.id == id })
    try saveSessionsInternal(sessions)
  }
  
  public func deleteAllSessions() async throws {
    userDefaults.removeObject(forKey: storageKey)
  }
  
  // MARK: - Private Methods
  
  private func getAllSessionsInternal() async throws -> [StoredSession] {
    guard let data = userDefaults.data(forKey: storageKey) else {
      return []
    }
    
    let decoder = JSONDecoder()
    do {
      return try decoder.decode([StoredSession].self, from: data)
    } catch {
      // If decoding fails, return empty array and clear corrupted data
      userDefaults.removeObject(forKey: storageKey)
      return []
    }
  }
  
  private func saveSessionsInternal(_ sessions: [StoredSession]) throws {
    let encoder = JSONEncoder()
    let data = try encoder.encode(sessions)
    userDefaults.set(data, forKey: storageKey)
  }
}
