//
//  ClaudeNativeStorageAdapter.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 8/18/2025.
//

import Foundation
import ClaudeCodeSDK

/// Adapter that bridges ClaudeCodeSDK's native storage with ClaudeCodeUI's SessionStorageProtocol
public actor ClaudeNativeStorageAdapter: SessionStorageProtocol {
  private let nativeStorage: ClaudeNativeSessionStorage
  private var projectPath: String?
  
  /// Cache to map between our session IDs and Claude's native session structure
  private var sessionCache: [String: ClaudeStoredSession] = [:]
  
  /// Cache of all projects and their sessions
  private var allProjectsCache: [(project: String, sessions: [StoredSession])]?
  
  public init(projectPath: String? = nil) {
    self.projectPath = projectPath
    self.nativeStorage = ClaudeNativeSessionStorage()
  }
  
  /// Updates the project path for filtering
  public func setProjectPath(_ path: String?) {
    self.projectPath = path
    // Clear cache when project changes
    sessionCache.removeAll()
    allProjectsCache = nil
  }
  
  // MARK: - SessionStorageProtocol Implementation
  
  public func saveSession(id: String, firstMessage: String) async throws {
    // Native storage is read-only - Claude CLI creates sessions automatically
    // We just need to ensure the session exists in our cache
    await refreshCache()
  }
  
  public func getAllSessions() async throws -> [StoredSession] {
    // If no project path set, return all sessions from all projects
    if let projectPath = projectPath {
      // Refresh cache and get sessions for specific project
      await refreshCache()
      
      let nativeSessions = try await nativeStorage.getSessions(for: projectPath)
      return nativeSessions.map { convertToStoredSession($0) }
        .sorted(by: { $0.lastAccessedAt > $1.lastAccessedAt })
    } else {
      // Return all sessions from all projects
      let allProjects = try await getAllSessionsAcrossProjects()
      return allProjects.flatMap { $0.sessions }
        .sorted(by: { $0.lastAccessedAt > $1.lastAccessedAt })
    }
  }
  
  public func getSession(id: String) async throws -> StoredSession? {
    await refreshCache()
    
    // Try to find the session in native storage
    if let cachedSession = sessionCache[id] {
      return convertToStoredSession(cachedSession)
    }
    
    // If not in cache, refresh and try again
    await refreshCache()
    if let cachedSession = sessionCache[id] {
      return convertToStoredSession(cachedSession)
    }
    
    return nil
  }
  
  public func updateLastAccessed(id: String) async throws {
    // Native storage tracks access automatically via Claude CLI
    // This is a no-op for native storage
  }
  
  public func deleteSession(id: String) async throws {
    // Native storage doesn't support deletion via SDK
    // Sessions are managed by Claude CLI directly
    throw ClaudeNativeStorageError.operationNotSupported("Session deletion is managed by Claude CLI")
  }
  
  public func deleteAllSessions() async throws {
    // Native storage doesn't support bulk deletion via SDK
    throw ClaudeNativeStorageError.operationNotSupported("Bulk session deletion is managed by Claude CLI")
  }
  
  public func updateSessionMessages(id: String, messages: [ChatMessage]) async throws {
    // Native storage is read-only from our perspective
    // Messages are updated by Claude CLI during conversations
    // This is a no-op for native storage
  }
  
  public func updateSessionId(oldId: String, newId: String) async throws {
    // Session ID chaining is handled internally by Claude CLI
    // Update our cache mapping
    if let session = sessionCache[oldId] {
      sessionCache[newId] = session
      // Keep the old mapping as well for continuity
      // Claude may reference either ID
    }
  }
  
  // MARK: - Private Methods
  
  private func refreshCache() async {
    do {
      if let projectPath = projectPath {
        let nativeSessions = try await nativeStorage.getSessions(for: projectPath)
        
        // Build cache of session IDs
        sessionCache.removeAll()
        for session in nativeSessions {
          sessionCache[session.id] = session
          
          // Also cache by the last message's session ID if it differs
          // (handles session chaining scenarios)
          if let lastMessage = session.messages.last,
             lastMessage.sessionId != session.id {
            sessionCache[lastMessage.sessionId] = session
          }
        }
      } else {
        // Cache all projects
        allProjectsCache = try await getAllSessionsAcrossProjects()
        
        // Build session cache from all projects
        sessionCache.removeAll()
        if let allProjects = allProjectsCache {
          for (project, _) in allProjects {
            let nativeSessions = try await nativeStorage.getSessions(for: project)
            for session in nativeSessions {
              sessionCache[session.id] = session
              if let lastMessage = session.messages.last,
                 lastMessage.sessionId != session.id {
                sessionCache[lastMessage.sessionId] = session
              }
            }
          }
        }
      }
    } catch {
      print("Failed to refresh session cache: \(error)")
    }
  }
  
  private func convertToStoredSession(_ nativeSession: ClaudeStoredSession) -> StoredSession {
    // Extract first user message for title
    let firstUserMessage = nativeSession.messages
      .first(where: { $0.role == .user })?
      .content ?? "New Session"
    
    // Convert messages
    let messages = nativeSession.messages.map { nativeMessage in
      ChatMessage(
        id: UUID(uuidString: nativeMessage.id) ?? UUID(),
        role: convertRole(nativeMessage.role),
        content: nativeMessage.content,
        timestamp: nativeMessage.timestamp,
        isComplete: true,
        messageType: .text,
        toolName: nil,
        toolInputData: nil,
        isError: false,
        codeSelections: nil,
        attachments: nil,
        wasCancelled: false,
        taskGroupId: nil,
        isTaskContainer: false
      )
    }
    
    return StoredSession(
      id: nativeSession.id,
      createdAt: nativeSession.createdAt,
      firstUserMessage: firstUserMessage,
      lastAccessedAt: nativeSession.lastAccessedAt,
      messages: messages
    )
  }
  
  private func convertRole(_ role: ClaudeStoredMessage.MessageRole) -> MessageRole {
    switch role {
    case .user:
      return .user
    case .assistant:
      return .assistant
    case .system:
      return .system
    }
  }
}

// MARK: - Error Types

enum ClaudeNativeStorageError: LocalizedError {
  case operationNotSupported(String)
  
  var errorDescription: String? {
    switch self {
    case .operationNotSupported(let message):
      return "Operation not supported: \(message)"
    }
  }
}

// MARK: - Extensions for Enhanced Features

extension ClaudeNativeStorageAdapter {
  /// Get the most recent session for the project
  public func getMostRecentSession() async throws -> StoredSession? {
    if let projectPath = projectPath {
      if let nativeSession = try await nativeStorage.getMostRecentSession(for: projectPath) {
        return convertToStoredSession(nativeSession)
      }
    } else {
      // Get most recent session across all projects
      let allProjects = try await getAllSessionsAcrossProjects()
      return allProjects
        .flatMap { $0.sessions }
        .max(by: { $0.lastAccessedAt < $1.lastAccessedAt })
    }
    return nil
  }
  
  /// Get session with additional native metadata
  public func getNativeSession(id: String) async throws -> ClaudeStoredSession? {
    await refreshCache()
    return sessionCache[id]
  }
  
  /// Check if a session exists in native storage
  public func sessionExists(id: String) async -> Bool {
    await refreshCache()
    return sessionCache[id] != nil
  }
  
  /// Get all sessions across all projects (for global view)
  public func getAllSessionsAcrossProjects() async throws -> [(project: String, sessions: [StoredSession])] {
    // Use cache if available
    if let cached = allProjectsCache {
      return cached
    }
    
    let projects = try await nativeStorage.listProjects()
    
    var result: [(project: String, sessions: [StoredSession])] = []
    
    for project in projects {
      let nativeSessions = try await nativeStorage.getSessions(for: project)
      let storedSessions = nativeSessions.map { convertToStoredSession($0) }
      result.append((project: project, sessions: storedSessions))
    }
    
    // Cache the result
    allProjectsCache = result
    
    return result
  }
  
  /// Get sessions organized in a hierarchical structure
  public func getHierarchicalSessions() async throws -> [ProjectNode] {
    let allProjects = try await getAllSessionsAcrossProjects()
    return ProjectHierarchyBuilder.buildHierarchy(from: allProjects)
  }
}