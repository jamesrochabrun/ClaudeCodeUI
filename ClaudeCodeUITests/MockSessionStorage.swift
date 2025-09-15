//
//  TestMocks.swift
//  ClaudeCodeUITests
//
//  Shared mock objects for testing
//

import Foundation
import ClaudeCodeSDK
@testable import ClaudeCodeUI
@testable import ClaudeCodeCore

// MARK: - Mock Session Storage

class MockSessionStorage: SessionStorageProtocol {
  var sessions: [StoredSession] = []
  var errorToThrow: Error?
  
  func saveSession(id: String, firstMessage: String, workingDirectory: String?) async throws {
    if let error = errorToThrow { throw error }
    if sessions.contains(where: { $0.id == id }) {
      return
    }
    let session = StoredSession(
      id: id,
      createdAt: Date(),
      firstUserMessage: firstMessage,
      lastAccessedAt: Date(),
      messages: [],
      workingDirectory: workingDirectory
    )
    sessions.append(session)
  }
  
  func getAllSessions() async throws -> [StoredSession] {
    if let error = errorToThrow { throw error }
    return sessions.sorted(by: { $0.lastAccessedAt > $1.lastAccessedAt })
  }
  
  func getSession(id: String) async throws -> StoredSession? {
    if let error = errorToThrow { throw error }
    return sessions.first { $0.id == id }
  }
  
  func updateLastAccessed(id: String) async throws {
    if let error = errorToThrow { throw error }
    if let index = sessions.firstIndex(where: { $0.id == id }) {
      var session = sessions[index]
      session.lastAccessedAt = Date()
      sessions[index] = session
    }
  }
  
  func deleteSession(id: String) async throws {
    if let error = errorToThrow { throw error }
    sessions.removeAll { $0.id == id }
  }
  
  func deleteAllSessions() async throws {
    if let error = errorToThrow { throw error }
    sessions.removeAll()
  }
  
  func updateSessionMessages(id: String, messages: [ChatMessage]) async throws {
    if let error = errorToThrow { throw error }
    if let index = sessions.firstIndex(where: { $0.id == id }) {
      var session = sessions[index]
      session.messages = messages
      session.lastAccessedAt = Date()
      sessions[index] = session
    }
  }
  
  func updateSessionId(oldId: String, newId: String) async throws {
    if let error = errorToThrow { throw error }
    if let index = sessions.firstIndex(where: { $0.id == oldId }) {
      let session = sessions[index]
      let newSession = StoredSession(
        id: newId,
        createdAt: session.createdAt,
        firstUserMessage: session.firstUserMessage,
        lastAccessedAt: Date(),
        messages: session.messages,
        workingDirectory: session.workingDirectory
      )
      sessions[index] = newSession
    }
  }
}