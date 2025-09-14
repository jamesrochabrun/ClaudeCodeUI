import Foundation
import SQLite

// MARK: - SimplifiedClaudeCodeSQLiteStorage

/// Simple SQLite storage for Claude Code sessions using SQLite.swift without macros
/// Completely independent from Claude Code sessions
public actor SimplifiedClaudeCodeSQLiteStorage: SessionStorageProtocol {

  public init() {}

  public func saveSession(id: String, firstMessage: String, workingDirectory: String?) async throws {
    print("[zizou] SimplifiedClaudeCodeSQLiteStorage.saveSession - Saving session id: \(id), firstMessage: \(firstMessage), workingDirectory: \(workingDirectory ?? "nil")")
    try await initializeDatabaseIfNeeded()

    let insert = sessionsTable.insert(
      sessionIdColumn <- id,
      createdAtColumn <- Date(),
      firstUserMessageColumn <- firstMessage,
      lastAccessedAtColumn <- Date(),
      workingDirectoryColumn <- workingDirectory
    )

    try database.run(insert)
    print("[zizou] SimplifiedClaudeCodeSQLiteStorage.saveSession - Successfully saved session \(id)")
  }
  
  public func getAllSessions() async throws -> [StoredSession] {
    print("[zizou] SimplifiedClaudeCodeSQLiteStorage.getAllSessions - Loading all sessions")
    try await initializeDatabaseIfNeeded()

    var storedSessions = [StoredSession]()
    
    for sessionRow in try database.prepare(sessionsTable.order(lastAccessedAtColumn.desc)) {
      let sessionId = sessionRow[sessionIdColumn]
      
      // Load messages for this session
      let messages = try await getMessagesForSession(sessionId: sessionId)
      
      let storedSession = StoredSession(
        id: sessionId,
        createdAt: sessionRow[createdAtColumn],
        firstUserMessage: sessionRow[firstUserMessageColumn],
        lastAccessedAt: sessionRow[lastAccessedAtColumn],
        messages: messages,
        workingDirectory: sessionRow[workingDirectoryColumn]
      )
      
      storedSessions.append(storedSession)
    }
    print("[zizou] SimplifiedClaudeCodeSQLiteStorage.getAllSessions - Loaded \(storedSessions.count) sessions")
    return storedSessions
  }
  
  public func getSession(id: String) async throws -> StoredSession? {
    try await initializeDatabaseIfNeeded()
    
    guard let sessionRow = try database.pluck(sessionsTable.filter(sessionIdColumn == id)) else {
      return nil
    }
    
    // Load messages for this session
    let messages = try await getMessagesForSession(sessionId: id)
    
    let storedSession = StoredSession(
      id: sessionRow[sessionIdColumn],
      createdAt: sessionRow[createdAtColumn],
      firstUserMessage: sessionRow[firstUserMessageColumn],
      lastAccessedAt: sessionRow[lastAccessedAtColumn],
      messages: messages,
      workingDirectory: sessionRow[workingDirectoryColumn]
    )
    return storedSession
  }
  
  public func updateLastAccessed(id: String) async throws {
    try await initializeDatabaseIfNeeded()
    
    let session = sessionsTable.filter(sessionIdColumn == id)
    let update = session.update(lastAccessedAtColumn <- Date())
    try database.run(update)
  }
  
  public func deleteSession(id: String) async throws {
    try await initializeDatabaseIfNeeded()
    
    // Delete session (foreign key constraints will cascade to messages and attachments)
    let deleteSession = sessionsTable.filter(sessionIdColumn == id)
    try database.run(deleteSession.delete())
  }
  
  public func deleteAllSessions() async throws {
    try await initializeDatabaseIfNeeded()
    
    // Delete all sessions (foreign key constraints will cascade to messages and attachments)
    try database.run(sessionsTable.delete())
  }
  
  public func updateSessionMessages(id: String, messages: [ChatMessage]) async throws {
    print("[zizou] SimplifiedClaudeCodeSQLiteStorage.updateSessionMessages - Updating messages for session \(id), count: \(messages.count)")
    try await initializeDatabaseIfNeeded()

    // Delete existing messages for this session (foreign key constraints will cascade to attachments)
    let deleteMessages = messagesTable.filter(messageSessionIdColumn == id)
    let deletedCount = try database.run(deleteMessages.delete())
    print("[zizou] SimplifiedClaudeCodeSQLiteStorage.updateSessionMessages - Deleted \(deletedCount) existing messages for session \(id)")

    // Insert new messages
    for message in messages {
      let insertMessage = messagesTable.insert(
        messageIdColumn <- message.id.uuidString,
        messageSessionIdColumn <- id,
        messageContentColumn <- message.content,
        messageRoleColumn <- message.role.rawValue,
        messageTimestampColumn <- message.timestamp,
        messageTypeColumn <- message.messageType.rawValue,
        messageToolNameColumn <- message.toolName,
        messageToolInputDataColumn <- try? JSONEncoder().encode(message.toolInputData).base64EncodedString(),
        messageIsErrorColumn <- message.isError,
        messageIsCompleteColumn <- message.isComplete,
        messageWasCancelledColumn <- message.wasCancelled,
        messageTaskGroupIdColumn <- message.taskGroupId?.uuidString,
        messageIsTaskContainerColumn <- message.isTaskContainer,
      )
      
      try database.run(insertMessage)
      
      // Insert attachments if any
      if let attachments = message.attachments {
        for (index, attachment) in attachments.enumerated() {
          let insertAttachment = attachmentsTable.insert(
            attachmentIdColumn <- "\(message.id.uuidString)_\(index)",
            attachmentMessageIdColumn <- message.id.uuidString,
            attachmentFileNameColumn <- attachment.fileName,
            attachmentFilePathColumn <- attachment.filePath,
            attachmentFileTypeColumn <- attachment.type,
          )
          
          try database.run(insertAttachment)
        }
      }
    }
    print("[zizou] SimplifiedClaudeCodeSQLiteStorage.updateSessionMessages - Successfully inserted \(messages.count) messages for session \(id)")
  }
  
  public func updateSessionId(oldId: String, newId: String) async throws {
    print("[zizou] SimplifiedClaudeCodeSQLiteStorage.updateSessionId - Updating session ID from \(oldId) to \(newId)")
    try await initializeDatabaseIfNeeded()

    // First, check if the new session already exists (phantom session case)
    let existingNewSession = try database.pluck(sessionsTable.filter(sessionIdColumn == newId))
    if existingNewSession != nil {
      print("[zizou] SimplifiedClaudeCodeSQLiteStorage.updateSessionId - New session \(newId) already exists, skipping update to avoid conflicts")
      return
    }

    // Get the old session details
    guard let oldSessionRow = try database.pluck(sessionsTable.filter(sessionIdColumn == oldId)) else {
      print("[zizou] SimplifiedClaudeCodeSQLiteStorage.updateSessionId - Old session \(oldId) not found, cannot update")
      return
    }

    // Create new session record FIRST with data from old session
    let insertNewSession = sessionsTable.insert(
      sessionIdColumn <- newId,
      createdAtColumn <- oldSessionRow[createdAtColumn],
      firstUserMessageColumn <- oldSessionRow[firstUserMessageColumn],
      lastAccessedAtColumn <- Date(),
      workingDirectoryColumn <- oldSessionRow[workingDirectoryColumn]
    )
    try database.run(insertNewSession)
    print("[zizou] SimplifiedClaudeCodeSQLiteStorage.updateSessionId - Created new session record with ID \(newId)")

    // Now update message session IDs (foreign key constraint satisfied)
    let messages = messagesTable.filter(messageSessionIdColumn == oldId)
    let updateMessages = messages.update(messageSessionIdColumn <- newId)
    let messagesUpdated = try database.run(updateMessages)
    print("[zizou] SimplifiedClaudeCodeSQLiteStorage.updateSessionId - Updated \(messagesUpdated) messages from oldId to newId")

    // Finally, delete the old session record
    let deleteOldSession = sessionsTable.filter(sessionIdColumn == oldId)
    try database.run(deleteOldSession.delete())
    print("[zizou] SimplifiedClaudeCodeSQLiteStorage.updateSessionId - Deleted old session record \(oldId). Complete.")
  }
  
  private var database: Connection!
  private var isInitialized = false
  
  // Table definitions
  private let sessionsTable = Table("sessions")
  private let messagesTable = Table("messages")
  private let attachmentsTable = Table("attachments")
  
  // Session columns
  private let sessionIdColumn = Expression<String>("id")
  private let createdAtColumn = Expression<Date>("created_at")
  private let firstUserMessageColumn = Expression<String>("first_user_message")
  private let lastAccessedAtColumn = Expression<Date>("last_accessed_at")
  private let workingDirectoryColumn = Expression<String?>("working_directory")
  
  // Message columns
  private let messageIdColumn = Expression<String>("id")
  private let messageSessionIdColumn = Expression<String>("session_id")
  private let messageContentColumn = Expression<String>("content")
  private let messageRoleColumn = Expression<String>("role")
  private let messageTimestampColumn = Expression<Date>("timestamp")
  private let messageTypeColumn = Expression<String>("message_type")
  private let messageToolNameColumn = Expression<String?>("tool_name")
  private let messageToolInputDataColumn = Expression<String?>("tool_input_data")
  private let messageIsErrorColumn = Expression<Bool>("is_error")
  private let messageIsCompleteColumn = Expression<Bool>("is_complete")
  private let messageWasCancelledColumn = Expression<Bool>("was_cancelled")
  private let messageTaskGroupIdColumn = Expression<String?>("task_group_id")
  private let messageIsTaskContainerColumn = Expression<Bool>("is_task_container")
  
  // Attachment columns
  private let attachmentIdColumn = Expression<String>("id")
  private let attachmentMessageIdColumn = Expression<String>("message_id")
  private let attachmentFileNameColumn = Expression<String>("file_name")
  private let attachmentFilePathColumn = Expression<String>("file_path")
  private let attachmentFileTypeColumn = Expression<String>("file_type")
  
  private func initializeDatabaseIfNeeded() async throws {
    guard !isInitialized else { return }
    
    // Create database in Application Support directory
    let fileManager = FileManager.default
    let appSupportDir = try fileManager.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true,
    )
    
    // Create application-specific directory within Application Support
    // Structure: ~/Library/Application Support/ClaudeCodeUI/
    let appDir = appSupportDir.appendingPathComponent("ClaudeCodeUI", isDirectory: true)
    try fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
    
    // Create SQLite database file path
    // Final path: ~/Library/Application Support/ClaudeCodeUI/claude_code_sessions.sqlite
    let dbPath = appDir.appendingPathComponent("claude_code_sessions.sqlite").path
    
    // Initialize SQLite connection using SQLite.swift
    // This creates the database file if it doesn't exist
    database = try Connection(dbPath)
    
    // Enable foreign key constraints (disabled by default in SQLite)
    try database.execute("PRAGMA foreign_keys = ON")
    
    // Create tables
    try await createTables()
    
    isInitialized = true
  }
  
  private func createTables() async throws {
    // Create sessions table
    try database.run(sessionsTable.create(ifNotExists: true) { table in
      table.column(sessionIdColumn, primaryKey: true)
      table.column(createdAtColumn)
      table.column(firstUserMessageColumn)
      table.column(lastAccessedAtColumn)
      table.column(workingDirectoryColumn)
    })
    
    // Create messages table
    try database.run(messagesTable.create(ifNotExists: true) { table in
      table.column(messageIdColumn, primaryKey: true)
      table.column(messageSessionIdColumn)
      table.column(messageContentColumn)
      table.column(messageRoleColumn)
      table.column(messageTimestampColumn)
      table.column(messageTypeColumn)
      table.column(messageToolNameColumn)
      table.column(messageToolInputDataColumn)
      table.column(messageIsErrorColumn)
      table.column(messageIsCompleteColumn)
      table.column(messageWasCancelledColumn)
      table.column(messageTaskGroupIdColumn)
      table.column(messageIsTaskContainerColumn)
      table.foreignKey(messageSessionIdColumn, references: sessionsTable, sessionIdColumn, delete: .cascade)
    })
    
    // Create attachments table
    try database.run(attachmentsTable.create(ifNotExists: true) { table in
      table.column(attachmentIdColumn, primaryKey: true)
      table.column(attachmentMessageIdColumn)
      table.column(attachmentFileNameColumn)
      table.column(attachmentFilePathColumn)
      table.column(attachmentFileTypeColumn)
      table.foreignKey(attachmentMessageIdColumn, references: messagesTable, messageIdColumn, delete: .cascade)
    })
  }
  
  private func getMessagesForSession(sessionId: String) async throws -> [ChatMessage] {
    var messages = [ChatMessage]()
    
    let query = messagesTable
      .filter(messageSessionIdColumn == sessionId)
      .order(messageTimestampColumn.asc)
    
    for messageRow in try database.prepare(query) {
      guard
        let role = MessageRole(rawValue: messageRow[messageRoleColumn]),
        let messageType = MessageType(rawValue: messageRow[messageTypeColumn]),
        let messageId = UUID(uuidString: messageRow[messageIdColumn])
      else {
        continue
      }
      
      let taskGroupId = messageRow[messageTaskGroupIdColumn].flatMap { UUID(uuidString: $0) }
      
      let message = ChatMessage(
        id: messageId,
        role: role,
        content: messageRow[messageContentColumn],
        timestamp: messageRow[messageTimestampColumn],
        isComplete: messageRow[messageIsCompleteColumn],
        messageType: messageType,
        toolName: messageRow[messageToolNameColumn],
        toolInputData: {
          guard
            let base64String = messageRow[messageToolInputDataColumn],
            let data = Data(base64Encoded: base64String)
          else { return nil }
          return try? JSONDecoder().decode(ToolInputData.self, from: data)
        }(),
        isError: messageRow[messageIsErrorColumn],
        codeSelections: nil, // Simplified for now
        attachments: nil, // Could load from attachments table if needed
        wasCancelled: messageRow[messageWasCancelledColumn],
        taskGroupId: taskGroupId,
        isTaskContainer: messageRow[messageIsTaskContainerColumn],
      )
      
      messages.append(message)
    }
    
    return messages
  }
}
