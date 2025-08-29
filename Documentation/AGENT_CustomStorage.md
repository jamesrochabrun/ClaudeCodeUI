# ClaudeCodeUI Custom Storage Integration - Agent Documentation

## Executive Summary

This document outlines the custom storage integration capabilities added to ClaudeCodeUI, enabling consumers to inject their own persistence backends while maintaining full compatibility with the library's features.

<summary>
<key-benefits>
- Enterprise-grade flexibility for data storage compliance
- Support for custom persistence backends (SQLite, CoreData, CloudKit, etc.)
- Full backward compatibility with existing implementations
- Zero breaking changes for current users
- Enhanced testability through dependency injection
</key-benefits>
</summary>

## API Changes

<api-change>
<component>DependencyContainer</component>
<status>Modified</status>
<visibility>internal → public</visibility>
<changes>
- Made class public
- Added public initializer with optional customSessionStorage parameter
- All properties now public for external access
- Added public setCurrentSession method
</changes>
</api-change>

<api-change>
<component>StoredSession</component>
<status>Modified</status>
<changes>
- Added public memberwise initializer
- Maintains Codable conformance
- All properties remain public
</changes>
</api-change>

<api-change>
<component>RootView</component>
<status>Modified</status>
<changes>
- Added new public initializer accepting DependencyContainer
- Maintains existing initializer for backward compatibility
- Supports both default and custom dependency injection
</changes>
</api-change>

## Integration Guide

### Step 1: Implement SessionStorageProtocol

<example>
<title>Basic Custom Storage Implementation</title>
<code>
import ClaudeCodeCore
import Foundation

// Custom storage implementation
actor MyCustomSessionStorage: SessionStorageProtocol {
    private var sessions: [String: StoredSession] = [:]
    
    func saveSession(id: String, firstMessage: String) async throws {
        let session = StoredSession(
            id: id,
            createdAt: Date(),
            firstUserMessage: firstMessage,
            lastAccessedAt: Date(),
            messages: []
        )
        sessions[id] = session
    }
    
    func getAllSessions() async throws -> [StoredSession] {
        return Array(sessions.values)
            .sorted { $0.lastAccessedAt > $1.lastAccessedAt }
    }
    
    func getSession(id: String) async throws -> StoredSession? {
        return sessions[id]
    }
    
    func updateLastAccessed(id: String) async throws {
        if var session = sessions[id] {
            session.lastAccessedAt = Date()
            sessions[id] = session
        }
    }
    
    func deleteSession(id: String) async throws {
        sessions.removeValue(forKey: id)
    }
    
    func deleteAllSessions() async throws {
        sessions.removeAll()
    }
    
    func updateSessionMessages(id: String, messages: [ChatMessage]) async throws {
        if var session = sessions[id] {
            session.messages = messages
            session.lastAccessedAt = Date()
            sessions[id] = session
        }
    }
    
    func updateSessionId(oldId: String, newId: String) async throws {
        if let session = sessions[oldId] {
            let newSession = StoredSession(
                id: newId,
                createdAt: session.createdAt,
                firstUserMessage: session.firstUserMessage,
                lastAccessedAt: Date(),
                messages: session.messages
            )
            sessions.removeValue(forKey: oldId)
            sessions[newId] = newSession
        }
    }
}
</code>
</example>

### Step 2: Create DependencyContainer with Custom Storage

<example>
<title>Dependency Injection Setup</title>
<code>
import ClaudeCodeCore

@MainActor
func setupCustomStorage() -> DependencyContainer {
    // Initialize your custom storage
    let customStorage = MyCustomSessionStorage()
    
    // Create global preferences
    let globalPreferences = GlobalPreferencesStorage()
    
    // Create dependency container with custom storage
    let dependencies = DependencyContainer(
        globalPreferences: globalPreferences,
        customSessionStorage: customStorage
    )
    
    return dependencies
}
</code>
</example>

### Step 3: Initialize RootView with Custom Dependencies

<example>
<title>SwiftUI Integration</title>
<code>
import SwiftUI
import ClaudeCodeCore

struct ContentView: View {
    @State private var dependencies: DependencyContainer?
    
    var body: some View {
        Group {
            if let dependencies = dependencies {
                ClaudeCodeCore.RootView(
                    sessionId: nil,
                    configuration: .default,
                    dependencies: dependencies
                )
            } else {
                ProgressView()
                    .onAppear {
                        self.dependencies = setupCustomStorage()
                    }
            }
        }
    }
}
</code>
</example>

## Advanced Implementations

### SQLite Storage

<example>
<title>SQLite-Based Storage</title>
<code>
import SQLite3
import ClaudeCodeCore

actor SQLiteSessionStorage: SessionStorageProtocol {
    private let db: OpaquePointer?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    init(databasePath: String) throws {
        var database: OpaquePointer?
        
        if sqlite3_open(databasePath, &database) != SQLITE_OK {
            throw StorageError.databaseConnectionFailed
        }
        
        self.db = database
        try createTablesIfNeeded()
    }
    
    private func createTablesIfNeeded() throws {
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS sessions (
                id TEXT PRIMARY KEY,
                created_at REAL,
                first_message TEXT,
                last_accessed REAL,
                messages_json TEXT
            );
        """
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            throw StorageError.tableCreationFailed
        }
    }
    
    func saveSession(id: String, firstMessage: String) async throws {
        let query = """
            INSERT OR REPLACE INTO sessions 
            (id, created_at, first_message, last_accessed, messages_json)
            VALUES (?, ?, ?, ?, ?)
        """
        
        var statement: OpaquePointer?
        sqlite3_prepare_v2(db, query, -1, &statement, nil)
        
        sqlite3_bind_text(statement, 1, id, -1, nil)
        sqlite3_bind_double(statement, 2, Date().timeIntervalSince1970)
        sqlite3_bind_text(statement, 3, firstMessage, -1, nil)
        sqlite3_bind_double(statement, 4, Date().timeIntervalSince1970)
        sqlite3_bind_text(statement, 5, "[]", -1, nil)
        
        if sqlite3_step(statement) != SQLITE_DONE {
            sqlite3_finalize(statement)
            throw StorageError.saveFailed
        }
        
        sqlite3_finalize(statement)
    }
    
    func updateSessionMessages(id: String, messages: [ChatMessage]) async throws {
        let messagesData = try encoder.encode(messages)
        let messagesJSON = String(data: messagesData, encoding: .utf8) ?? "[]"
        
        let query = """
            UPDATE sessions 
            SET messages_json = ?, last_accessed = ?
            WHERE id = ?
        """
        
        var statement: OpaquePointer?
        sqlite3_prepare_v2(db, query, -1, &statement, nil)
        
        sqlite3_bind_text(statement, 1, messagesJSON, -1, nil)
        sqlite3_bind_double(statement, 2, Date().timeIntervalSince1970)
        sqlite3_bind_text(statement, 3, id, -1, nil)
        
        if sqlite3_step(statement) != SQLITE_DONE {
            sqlite3_finalize(statement)
            throw StorageError.updateFailed
        }
        
        sqlite3_finalize(statement)
    }
    
    // ... implement other protocol methods
}

enum StorageError: Error {
    case databaseConnectionFailed
    case tableCreationFailed
    case saveFailed
    case updateFailed
}
</code>
</example>

### CoreData Storage

<example>
<title>CoreData-Based Storage</title>
<code>
import CoreData
import ClaudeCodeCore

@MainActor
class CoreDataSessionStorage: SessionStorageProtocol {
    private let container: NSPersistentContainer
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    init(containerName: String = "ClaudeCodeSessions") {
        container = NSPersistentContainer(name: containerName)
        
        // Configure for app group if needed
        let storeURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.yourcompany.claudecode")?
            .appendingPathComponent("\(containerName).sqlite")
        
        if let storeURL = storeURL {
            let storeDescription = NSPersistentStoreDescription(url: storeURL)
            container.persistentStoreDescriptions = [storeDescription]
        }
        
        container.loadPersistentStores { _, error in
            if let error = error {
                print("CoreData failed to load: \(error)")
            }
        }
    }
    
    func saveSession(id: String, firstMessage: String) async throws {
        let context = container.viewContext
        
        let fetchRequest: NSFetchRequest<SessionEntity> = SessionEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        
        let existingSessions = try context.fetch(fetchRequest)
        
        if let existing = existingSessions.first {
            existing.lastAccessedAt = Date()
        } else {
            let newSession = SessionEntity(context: context)
            newSession.id = id
            newSession.createdAt = Date()
            newSession.firstUserMessage = firstMessage
            newSession.lastAccessedAt = Date()
            newSession.messagesData = Data() // Empty initially
        }
        
        try context.save()
    }
    
    func getAllSessions() async throws -> [StoredSession] {
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<SessionEntity> = SessionEntity.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \SessionEntity.lastAccessedAt, ascending: false)
        ]
        
        let entities = try context.fetch(fetchRequest)
        
        return try entities.map { entity in
            let messages: [ChatMessage]
            if let messagesData = entity.messagesData, !messagesData.isEmpty {
                messages = try decoder.decode([ChatMessage].self, from: messagesData)
            } else {
                messages = []
            }
            
            return StoredSession(
                id: entity.id ?? "",
                createdAt: entity.createdAt ?? Date(),
                firstUserMessage: entity.firstUserMessage ?? "",
                lastAccessedAt: entity.lastAccessedAt ?? Date(),
                messages: messages
            )
        }
    }
    
    // ... implement other protocol methods
}
</code>
</example>

## Migration Guide

<migration-step>
<number>1</number>
<title>Assess Current Implementation</title>
<description>
Determine if you're using default storage or have existing customizations.
Check for any direct references to UserDefaultsSessionStorage or ClaudeNativeStorageAdapter.
</description>
</migration-step>

<migration-step>
<number>2</number>
<title>Export Existing Data</title>
<code>
// Export sessions from default storage
@MainActor
func exportExistingSessions() async throws -> [StoredSession] {
    let defaultContainer = DependencyContainer(
        globalPreferences: GlobalPreferencesStorage()
    )
    return try await defaultContainer.sessionStorage.getAllSessions()
}
</code>
</migration-step>

<migration-step>
<number>3</number>
<title>Import to Custom Storage</title>
<code>
// Import sessions to your custom storage
@MainActor
func migrateToCustomStorage(sessions: [StoredSession]) async throws {
    let customStorage = MyCustomSessionStorage()
    
    for session in sessions {
        try await customStorage.saveSession(
            id: session.id,
            firstMessage: session.firstUserMessage
        )
        
        if !session.messages.isEmpty {
            try await customStorage.updateSessionMessages(
                id: session.id,
                messages: session.messages
            )
        }
    }
    
    print("Migrated \(sessions.count) sessions to custom storage")
}
</code>
</migration-step>

<migration-step>
<number>4</number>
<title>Update Application Initialization</title>
<code>
// Replace default initialization
// OLD:
let rootView = ClaudeCodeCore.RootView(configuration: .default)

// NEW:
let dependencies = DependencyContainer(
    globalPreferences: GlobalPreferencesStorage(),
    customSessionStorage: customStorage
)
let rootView = ClaudeCodeCore.RootView(
    configuration: .default,
    dependencies: dependencies
)
</code>
</migration-step>

## Testing Guide

<test-case>
<title>Unit Test for Custom Storage</title>
<code>
import XCTest
@testable import ClaudeCodeCore

class CustomStorageTests: XCTestCase {
    var storage: MyCustomSessionStorage!
    
    override func setUp() async throws {
        storage = MyCustomSessionStorage()
    }
    
    func testSaveAndRetrieveSession() async throws {
        // Given
        let sessionId = "test-session-123"
        let firstMessage = "Hello, Claude!"
        
        // When
        try await storage.saveSession(id: sessionId, firstMessage: firstMessage)
        let retrieved = try await storage.getSession(id: sessionId)
        
        // Then
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, sessionId)
        XCTAssertEqual(retrieved?.firstUserMessage, firstMessage)
    }
    
    func testUpdateSessionMessages() async throws {
        // Given
        let sessionId = "test-session-456"
        try await storage.saveSession(id: sessionId, firstMessage: "Initial message")
        
        let messages = [
            ChatMessage(role: .user, content: "Hello", messageType: .text),
            ChatMessage(role: .assistant, content: "Hi there!", messageType: .text)
        ]
        
        // When
        try await storage.updateSessionMessages(id: sessionId, messages: messages)
        let retrieved = try await storage.getSession(id: sessionId)
        
        // Then
        XCTAssertEqual(retrieved?.messages.count, 2)
        XCTAssertEqual(retrieved?.messages.first?.content, "Hello")
    }
    
    func testSessionIdUpdate() async throws {
        // Given
        let oldId = "old-session-id"
        let newId = "new-session-id"
        try await storage.saveSession(id: oldId, firstMessage: "Test")
        
        // When
        try await storage.updateSessionId(oldId: oldId, newId: newId)
        
        // Then
        let oldSession = try await storage.getSession(id: oldId)
        let newSession = try await storage.getSession(id: newId)
        
        XCTAssertNil(oldSession)
        XCTAssertNotNil(newSession)
        XCTAssertEqual(newSession?.firstUserMessage, "Test")
    }
}
</code>
</test-case>

<test-case>
<title>Integration Test with DependencyContainer</title>
<code>
import XCTest
@testable import ClaudeCodeCore

class DependencyContainerIntegrationTests: XCTestCase {
    
    @MainActor
    func testCustomStorageInjection() async throws {
        // Given
        let customStorage = MockSessionStorage()
        let globalPreferences = GlobalPreferencesStorage()
        
        // When
        let container = DependencyContainer(
            globalPreferences: globalPreferences,
            customSessionStorage: customStorage
        )
        
        // Then
        XCTAssertTrue(container.sessionStorage === customStorage)
        
        // Test that it works
        try await container.sessionStorage.saveSession(
            id: "integration-test",
            firstMessage: "Testing injection"
        )
        
        let sessions = try await container.sessionStorage.getAllSessions()
        XCTAssertEqual(sessions.count, 1)
    }
    
    @MainActor
    func testDefaultStorageFallback() {
        // Given
        let globalPreferences = GlobalPreferencesStorage()
        
        // When - no custom storage provided
        let container = DependencyContainer(
            globalPreferences: globalPreferences
        )
        
        // Then - should use default storage
        XCTAssertTrue(
            container.sessionStorage is UserDefaultsSessionStorage ||
            container.sessionStorage is ClaudeNativeStorageAdapter
        )
    }
}
</code>
</test-case>

## Troubleshooting

<troubleshooting>
<issue>
<problem>Import errors when trying to use custom storage</problem>
<solution>
Ensure you're importing ClaudeCodeCore, not just ClaudeCodeUI:
```swift
import ClaudeCodeCore  // ✅ Correct
import ClaudeCodeUI    // ❌ May not expose all needed types
```
</solution>
</issue>

<issue>
<problem>Thread safety issues with custom storage</problem>
<solution>
Use Swift's actor model for automatic synchronization:
```swift
actor MyCustomStorage: SessionStorageProtocol {
    // Actor provides thread safety automatically
}
```
Or use manual synchronization:
```swift
class MyCustomStorage: SessionStorageProtocol {
    private let queue = DispatchQueue(label: "storage.queue")
    
    func saveSession(...) async throws {
        await withCheckedContinuation { continuation in
            queue.async {
                // Thread-safe operations
                continuation.resume()
            }
        }
    }
}
```
</solution>
</issue>

<issue>
<problem>Sessions not appearing after migration</problem>
<solution>
Check that you're properly awaiting async operations:
```swift
// ❌ Wrong - not awaiting
customStorage.saveSession(id: id, firstMessage: message)

// ✅ Correct
try await customStorage.saveSession(id: id, firstMessage: message)
```
</solution>
</issue>

<issue>
<problem>Memory leaks with large message histories</problem>
<solution>
Implement pagination or cleanup for old messages:
```swift
func updateSessionMessages(id: String, messages: [ChatMessage]) async throws {
    // Keep only last 1000 messages
    let trimmedMessages = messages.suffix(1000)
    // Save trimmed messages
}
```
</solution>
</issue>
</troubleshooting>

## Performance Considerations

<summary>
<performance-tips>
1. **Caching**: Implement in-memory caching for frequently accessed sessions
2. **Batch Operations**: Group multiple storage operations when possible
3. **Lazy Loading**: Load message content only when needed
4. **Indexing**: Create indexes on frequently queried fields (id, lastAccessedAt)
5. **Compression**: Consider compressing message data for large conversations
</performance-tips>
</summary>

## Security Considerations

<summary>
<security-guidelines>
1. **Encryption**: Encrypt sensitive data at rest
2. **Access Control**: Implement proper authentication for storage access
3. **Data Sanitization**: Sanitize user input before storage
4. **Audit Logging**: Log all storage operations for compliance
5. **Backup Strategy**: Implement secure backup and recovery procedures
</security-guidelines>
</summary>

## API Compatibility Matrix

<summary>
<compatibility>
| Feature | Default Storage | Custom Storage |
|---------|----------------|----------------|
| Session CRUD | ✅ | ✅ |
| Message History | ✅ | ✅ |
| Session ID Updates | ✅ | ✅ |
| Bulk Operations | ✅ | ✅ |
| Async Operations | ✅ | ✅ |
| Thread Safety | ✅ | Implementation-dependent |
| Performance | Good | Implementation-dependent |
| Data Persistence | Local | Customizable |
</compatibility>
</summary>

## Support and Resources

<summary>
<resources>
- **Documentation**: `/Documentation/CustomStorageIntegration.md`
- **Tests**: `/ClaudeCodeUITests/CustomStorageIntegrationTests.swift`
- **Mock Implementation**: `/ClaudeCodeUITests/MockSessionStorage.swift`
- **Issue Tracker**: GitHub Issues (tag: custom-storage)
- **Community**: Discord #custom-storage channel
</resources>
</summary>

## Version History

<summary>
<changelog>
| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-08-29 | Initial custom storage support |
| - | - | Made DependencyContainer public |
| - | - | Added StoredSession public initializer |
| - | - | Added RootView dependency injection |
| - | - | Complete SessionStorageProtocol exposure |
</changelog>
</summary>

---

*This documentation was generated for ClaudeCodeUI Custom Storage Integration v1.0.0*