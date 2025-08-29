# Custom Storage Integration Guide

ClaudeCodeUI supports custom storage backends for session persistence, allowing you to integrate with your preferred data storage solution while maintaining full compatibility with the library's features.

## Overview

The custom storage integration enables you to:

- Use your own persistence layer (SQLite, CoreData, CloudKit, etc.)
- Integrate with existing data storage systems
- Implement custom sync and backup solutions
- Control where conversation data is stored for compliance requirements

## Quick Start

### 1. Implement SessionStorageProtocol

Create a class that implements the `SessionStorageProtocol`:

```swift
import ClaudeCodeCore
import SQLite

class SQLiteSessionStorage: SessionStorageProtocol {
  private let db: Connection
  private let sessions = Table("sessions")
  // ... table schema definitions
  
  init(databasePath: String) throws {
    self.db = try Connection(databasePath)
    try createTablesIfNeeded()
  }
  
  func saveSession(id: String, firstMessage: String) async throws {
    // Your SQLite implementation
  }
  
  func getAllSessions() async throws -> [StoredSession] {
    // Your SQLite implementation
  }
  
  // ... implement other required methods
}
```

### 2. Create Custom DependencyContainer

```swift
import ClaudeCodeCore

// Initialize your custom storage
let customStorage = try SQLiteSessionStorage(databasePath: "/path/to/database.sqlite")

// Create dependency container with custom storage
let dependencies = DependencyContainer(
  globalPreferences: GlobalPreferencesStorage(),
  customSessionStorage: customStorage
)
```

### 3. Use with RootView

```swift
import SwiftUI
import ClaudeCodeCore

struct ContentView: View {
  var body: some View {
    ClaudeCodeCore.RootView(
      configuration: .default,
      dependencies: dependencies
    )
  }
}
```

## API Reference

### SessionStorageProtocol

All methods in the protocol are async and can throw errors:

```swift
public protocol SessionStorageProtocol {
  /// Saves a new session or updates existing one
  func saveSession(id: String, firstMessage: String) async throws
  
  /// Retrieves all stored sessions, sorted by last accessed date
  func getAllSessions() async throws -> [StoredSession]
  
  /// Retrieves a specific session by ID
  func getSession(id: String) async throws -> StoredSession?
  
  /// Updates the last accessed time for a session
  func updateLastAccessed(id: String) async throws
  
  /// Deletes a session
  func deleteSession(id: String) async throws
  
  /// Deletes all sessions
  func deleteAllSessions() async throws
  
  /// Updates the complete message history for a session
  func updateSessionMessages(id: String, messages: [ChatMessage]) async throws
  
  /// Updates a session ID (when Claude returns a new ID for the same conversation)
  func updateSessionId(oldId: String, newId: String) async throws
}
```

### StoredSession

Create sessions using the public initializer:

```swift
let session = StoredSession(
  id: "unique-session-id",
  createdAt: Date(),
  firstUserMessage: "Hello, Claude!",
  lastAccessedAt: Date(),
  messages: [] // ChatMessage array
)
```

### ChatMessage

Create messages with the public initializer:

```swift
let message = ChatMessage(
  role: .user,
  content: "Hello, world!",
  messageType: .text
)
```

## Implementation Examples

### SQLite Storage Example

```swift
import SQLite
import ClaudeCodeCore

actor SQLiteSessionStorage: SessionStorageProtocol {
  private let db: Connection
  
  // Table definitions
  private let sessionsTable = Table("sessions")
  private let idColumn = Expression<String>("id")
  private let createdAtColumn = Expression<Date>("created_at")
  private let firstMessageColumn = Expression<String>("first_message")
  private let lastAccessedColumn = Expression<Date>("last_accessed")
  private let messagesColumn = Expression<Data>("messages_data")
  
  init(databasePath: String) throws {
    self.db = try Connection(databasePath)
    try createTables()
  }
  
  private func createTables() throws {
    try db.run(sessionsTable.create(ifNotExists: true) { t in
      t.column(idColumn, primaryKey: true)
      t.column(createdAtColumn)
      t.column(firstMessageColumn)
      t.column(lastAccessedColumn)
      t.column(messagesColumn)
    })
  }
  
  func saveSession(id: String, firstMessage: String) async throws {
    let exists = try db.scalar(sessionsTable.filter(idColumn == id).count) > 0
    
    if exists {
      try db.run(sessionsTable.filter(idColumn == id).update(
        lastAccessedColumn <- Date()
      ))
    } else {
      try db.run(sessionsTable.insert(
        idColumn <- id,
        createdAtColumn <- Date(),
        firstMessageColumn <- firstMessage,
        lastAccessedColumn <- Date(),
        messagesColumn <- Data() // Empty initially
      ))
    }
  }
  
  func getAllSessions() async throws -> [StoredSession] {
    var sessions: [StoredSession] = []
    
    for row in try db.prepare(sessionsTable.order(lastAccessedColumn.desc)) {
      let messagesData = row[messagesColumn]
      let messages = try messagesData.isEmpty ? [] : 
        JSONDecoder().decode([ChatMessage].self, from: messagesData)
      
      let session = StoredSession(
        id: row[idColumn],
        createdAt: row[createdAtColumn],
        firstUserMessage: row[firstMessageColumn],
        lastAccessedAt: row[lastAccessedColumn],
        messages: messages
      )
      sessions.append(session)
    }
    
    return sessions
  }
  
  func updateSessionMessages(id: String, messages: [ChatMessage]) async throws {
    let messagesData = try JSONEncoder().encode(messages)
    
    try db.run(sessionsTable.filter(idColumn == id).update(
      messagesColumn <- messagesData,
      lastAccessedColumn <- Date()
    ))
  }
  
  // ... implement other methods
}
```

### CoreData Storage Example

```swift
import CoreData
import ClaudeCodeCore

class CoreDataSessionStorage: SessionStorageProtocol {
  private let context: NSManagedObjectContext
  
  init(context: NSManagedObjectContext) {
    self.context = context
  }
  
  func saveSession(id: String, firstMessage: String) async throws {
    await context.perform {
      let fetchRequest: NSFetchRequest<SessionEntity> = SessionEntity.fetchRequest()
      fetchRequest.predicate = NSPredicate(format: "id == %@", id)
      
      if let existingSession = try? self.context.fetch(fetchRequest).first {
        existingSession.lastAccessedAt = Date()
      } else {
        let newSession = SessionEntity(context: self.context)
        newSession.id = id
        newSession.createdAt = Date()
        newSession.firstUserMessage = firstMessage
        newSession.lastAccessedAt = Date()
      }
      
      try self.context.save()
    }
  }
  
  // ... implement other methods
}
```

### CloudKit Storage Example

```swift
import CloudKit
import ClaudeCodeCore

actor CloudKitSessionStorage: SessionStorageProtocol {
  private let container: CKContainer
  private let database: CKDatabase
  
  init() {
    self.container = CKContainer(identifier: "your.cloudkit.container")
    self.database = container.privateCloudDatabase
  }
  
  func saveSession(id: String, firstMessage: String) async throws {
    let recordID = CKRecord.ID(recordName: id)
    
    do {
      // Try to fetch existing record
      let existingRecord = try await database.record(for: recordID)
      existingRecord["lastAccessedAt"] = Date()
      try await database.save(existingRecord)
    } catch CKError.unknownItem {
      // Create new record
      let record = CKRecord(recordType: "Session", recordID: recordID)
      record["id"] = id
      record["createdAt"] = Date()
      record["firstUserMessage"] = firstMessage
      record["lastAccessedAt"] = Date()
      record["messagesData"] = Data() // Empty initially
      
      try await database.save(record)
    }
  }
  
  // ... implement other methods
}
```

## Best Practices

### 1. Error Handling

Always properly handle and propagate errors from your storage layer:

```swift
func saveSession(id: String, firstMessage: String) async throws {
  do {
    // Your storage logic
  } catch {
    // Log error appropriately
    print("Failed to save session: \(error)")
    throw StorageError.saveFailed(error)
  }
}
```

### 2. Thread Safety

Use `actor` for automatic thread safety or ensure your implementation is thread-safe:

```swift
actor MyCustomStorage: SessionStorageProtocol {
  // Actor provides automatic synchronization
  private var inMemoryCache: [String: StoredSession] = [:]
  
  // All methods are automatically thread-safe
}
```

### 3. Performance Optimization

Consider implementing caching and batch operations:

```swift
actor OptimizedStorage: SessionStorageProtocol {
  private var cache: [String: StoredSession] = [:]
  private var isDirty = false
  
  func getAllSessions() async throws -> [StoredSession] {
    if cache.isEmpty {
      // Load from persistent storage
      cache = try await loadFromDisk()
    }
    return Array(cache.values).sorted { $0.lastAccessedAt > $1.lastAccessedAt }
  }
}
```

### 4. Data Migration

Handle schema changes gracefully:

```swift
private func migrateIfNeeded() throws {
  let currentVersion = UserDefaults.standard.integer(forKey: "StorageVersion")
  
  if currentVersion < 2 {
    try migrateTo_v2()
    UserDefaults.standard.set(2, forKey: "StorageVersion")
  }
}
```

## Testing

Use the provided `MockSessionStorage` for testing:

```swift
import XCTest
@testable import ClaudeCodeCore

class MyCustomStorageTests: XCTestCase {
  func testCustomStorageIntegration() async throws {
    let mockStorage = MockSessionStorage()
    
    let container = DependencyContainer(
      globalPreferences: GlobalPreferencesStorage(),
      customSessionStorage: mockStorage
    )
    
    // Test your integration
    try await container.sessionStorage.saveSession(id: "test", firstMessage: "Hello")
    let sessions = try await container.sessionStorage.getAllSessions()
    
    XCTAssertEqual(sessions.count, 1)
  }
}
```

## Migration from Default Storage

To migrate existing data from the default storage:

```swift
// 1. Get existing sessions from default storage
let defaultContainer = DependencyContainer(globalPreferences: globalPreferences)
let existingSessions = try await defaultContainer.sessionStorage.getAllSessions()

// 2. Migrate to your custom storage
let customStorage = MyCustomStorage()

for session in existingSessions {
  try await customStorage.saveSession(
    id: session.id, 
    firstMessage: session.firstUserMessage
  )
  try await customStorage.updateSessionMessages(
    id: session.id, 
    messages: session.messages
  )
}

// 3. Use custom storage going forward
let newContainer = DependencyContainer(
  globalPreferences: globalPreferences,
  customSessionStorage: customStorage
)
```

## Troubleshooting

### Common Issues

1. **Import Errors**: Make sure to import `ClaudeCodeCore` not just `ClaudeCodeUI`
2. **Thread Safety**: Use `actor` or ensure manual thread safety
3. **Data Serialization**: ChatMessage conforms to Codable for easy JSON serialization
4. **Memory Management**: Consider implementing proper cleanup for large message histories

### Debug Logging

Enable debug logging to trace storage operations:

```swift
class DebugSessionStorage: SessionStorageProtocol {
  private let underlyingStorage: SessionStorageProtocol
  
  init(wrapping storage: SessionStorageProtocol) {
    self.underlyingStorage = storage
  }
  
  func saveSession(id: String, firstMessage: String) async throws {
    print("[Storage] Saving session: \(id)")
    try await underlyingStorage.saveSession(id: id, firstMessage: firstMessage)
    print("[Storage] Session saved successfully")
  }
  
  // ... wrap other methods similarly
}
```

## Support

For additional help with custom storage integration:

1. Check the included integration tests for examples
2. Review the default `UserDefaultsSessionStorage` implementation
3. File issues at [ClaudeCodeUI GitHub repository](https://github.com/anthropics/claude-code-ui)