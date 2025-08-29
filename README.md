# ClaudeCodeUI

A native macOS application and Swift Package providing a graphical user interface for Claude Code SDK, enabling seamless AI-powered coding assistance with a beautiful, intuitive interface.

https://github.com/user-attachments/assets/12a3a1ff-1ba5-41b2-b6af-897e53b18331

## 🎉 Now Available as a Swift Package!

ClaudeCodeUI has been completely restructured to work as both a standalone macOS application AND a reusable Swift Package. This means you can:
- **Use the macOS app directly** - Download and run the full application
- **Integrate into your own apps** - Import `ClaudeCodeCore` and use all the functionality in your projects
- **Customize and extend** - Build on top of the comprehensive component library

## Overview

ClaudeCodeUI is a SwiftUI-based macOS application that wraps the Claude Code SDK, providing users with a desktop experience for interacting with Claude's coding capabilities. The app features markdown rendering, syntax highlighting, file management, terminal integration, and a complete MCP (Model Context Protocol) approval system - all within a native macOS interface.

### What's Included in ClaudeCodeCore

The `ClaudeCodeCore` package includes everything:
- ✅ Complete chat interface with streaming support
- ✅ Session management and persistence
- ✅ Code syntax highlighting and markdown rendering
- ✅ File diff visualization
- ✅ Terminal integration
- ✅ Xcode project detection and integration
- ✅ MCP approval system for secure tool usage
- ✅ Custom permissions handling
- ✅ All UI components and view models
- ✅ Complete dependency injection system

## Installation

### Option 1: Use as a macOS Application

#### For End Users (Simplest)
1. Download the latest release from the [Releases page](https://github.com/jamesrochabrun/ClaudeCodeUI/releases)
2. Move ClaudeCodeUI.app to your Applications folder
3. Launch the app

#### For Developers (Build from Source)
1. Clone the repository:
   ```bash
   git clone https://github.com/jamesrochabrun/ClaudeCodeUI.git
   cd ClaudeCodeUI
   ```

2. Open in Xcode:
   ```bash
   open ClaudeCodeUI.xcodeproj
   ```

3. Build and run (⌘R)

### Option 2: Use as a Swift Package

Add ClaudeCodeUI to your project as a Swift Package dependency:

#### In Xcode:
1. File → Add Package Dependencies
2. Enter: `https://github.com/jamesrochabrun/ClaudeCodeUI.git`
3. Choose the `ClaudeCodeCore` library product
4. Click "Add Package"

#### In Package.swift:
```swift
dependencies: [
    .package(url: "https://github.com/jamesrochabrun/ClaudeCodeUI.git", branch: "main")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "ClaudeCodeCore", package: "ClaudeCodeUI")
        ]
    )
]
```

## Usage Examples

### Quick Start - Use the Entire App

The simplest integration - get the full ClaudeCodeUI experience in just 3 lines:

```swift
import SwiftUI
import ClaudeCodeCore

@main
struct MyApp: App {
    var body: some Scene {
        // That's it! You get the complete app
        ClaudeCodeUIApp().body
    }
}
```

### Custom Integration - Mix Your UI with ClaudeCode

Want to integrate ClaudeCode into your existing app? Use individual components:

```swift
import SwiftUI
import ClaudeCodeCore

struct MyCustomApp: App {
    @State private var globalPreferences = GlobalPreferencesStorage()
    
    var body: some Scene {
        WindowGroup {
            NavigationSplitView {
                // Your custom sidebar
                MySidebarView()
            } detail: {
                // ClaudeCode chat interface
                RootView()
                    .environment(globalPreferences)
            }
        }
    }
}
```

### Advanced - Use Individual Components

For maximum control, use the components directly:

```swift
import ClaudeCodeCore

struct MyCustomChatView: View {
    @StateObject private var dependencyContainer: DependencyContainer
    @StateObject private var chatViewModel: ChatViewModel
    
    init() {
        let globalPrefs = GlobalPreferencesStorage()
        let container = DependencyContainer(globalPreferences: globalPrefs)
        
        _dependencyContainer = StateObject(wrappedValue: container)
        _chatViewModel = StateObject(wrappedValue: ChatViewModel(
            claudeClient: container.claudeClient,
            sessionManager: container.sessionManager,
            // ... other dependencies
        ))
    }
    
    var body: some View {
        ChatScreen(
            viewModel: chatViewModel,
            contextManager: dependencyContainer.contextManager,
            xcodeObservationViewModel: dependencyContainer.xcodeObservationViewModel,
            permissionsService: dependencyContainer.permissionsService,
            terminalService: dependencyContainer.terminalService,
            customPermissionService: dependencyContainer.customPermissionService,
            columnVisibility: .constant(.all)
        )
    }
}
```

### Configuration Options

Customize the behavior with your own settings:

```swift
import ClaudeCodeCore

// Use custom storage implementations
let customStorage = MyCustomSessionStorage()
let customSettings = MyCustomSettingsStorage()

// Configure the dependency container
let container = DependencyContainer(
    globalPreferences: globalPreferences,
    sessionStorage: customStorage,
    settingsStorage: customSettings
)
```

## Project Structure

### Package Structure
```
ClaudeCodeUI/
├── Package.swift                    # Swift Package manifest
├── Sources/
│   ├── ClaudeCodeCore/             # Main library (all reusable components)
│   │   ├── App/                    # App structure and entry points
│   │   ├── ViewModels/             # Business logic and state management
│   │   ├── Views/UI/               # All SwiftUI views and components
│   │   ├── Services/               # Core services (permissions, terminal, etc.)
│   │   ├── Storage/                # Session and settings persistence
│   │   ├── Models/                 # Data models
│   │   ├── DependencyInjection/    # DI container
│   │   ├── Diff/                   # File diff visualization
│   │   ├── FileSearch/             # File search functionality
│   │   ├── ToolFormatting/         # Tool output formatting
│   │   └── Extensions/             # Utility extensions
│   └── ClaudeCodeUI/               # Minimal executable wrapper
│       └── main.swift              # App entry point
├── modules/                        # Local Swift packages
│   ├── AccessibilityService/       # macOS accessibility APIs
│   ├── ApprovalMCPServer/          # MCP approval server
│   ├── CustomPermissionService/    # Permission handling
│   ├── TerminalService/            # Terminal integration
│   └── XcodeObserverService/       # Xcode integration
└── ClaudeCodeUI.xcodeproj          # Xcode project (for app distribution)
```

## How It Works

ClaudeCodeUI communicates with the Claude Code SDK through the `ClaudeCodeClient` class. The app:

1. **Initializes the SDK**: Creates a `ClaudeCodeConfiguration` with the current working directory and debug settings
2. **Manages Sessions**: Uses `SessionStorage` to persist chat histories and session metadata
3. **Handles Permissions**: Implements a custom permission service to manage file system access
4. **Processes Responses**: Renders Claude's responses with markdown formatting and code syntax highlighting
5. **Executes Actions**: Handles file operations, terminal commands, and other SDK capabilities through a unified interface

## Migration Guide

### For Existing Users

If you've been using ClaudeCodeUI before the package restructure:

1. **No changes needed for app users** - The macOS app works exactly the same
2. **For developers**: The source code is now in `Sources/ClaudeCodeCore/` instead of `ClaudeCodeUI/`
3. **Package imports**: Use `import ClaudeCodeCore` instead of importing individual files

### For Package Consumers

When adding ClaudeCodeUI as a dependency:
- The main library product is `ClaudeCodeCore`
- All components are public and can be used individually
- The package includes all necessary dependencies (you don't need to add them separately)

## External Storage Integration

ClaudeCodeUI provides a powerful external storage system that allows you to integrate with your own databases, cloud storage, or custom persistence solutions. This enables you to:

- **Save messages to your database** - Automatically persist all conversation history
- **Restore sessions on app launch** - Resume conversations from where users left off  
- **Inject working directories** - Skip manual directory selection by providing project paths
- **Manage sessions externally** - Implement custom session organization and sharing
- **Sync across devices** - Build multi-device conversation synchronization

### Architecture Overview

The external storage system consists of three main components:

1. **`SessionStorageProtocol`** - Interface for custom storage backends
2. **`ChatViewModel.injectSession()`** - Method to inject sessions with messages and working directory
3. **Automatic message persistence** - Real-time saving as conversations progress

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Your Database │◄──►│ SessionStorage   │◄──►│  ClaudeCodeUI   │
│  (Any Backend)  │    │   Protocol       │    │   ChatViewModel │
└─────────────────┘    └──────────────────┘    └─────────────────┘
        │                        │                        │
        │                        │                        │
   ┌─────▼──────┐        ┌───────▼────────┐      ┌──────▼─────────┐
   │  Messages  │        │   Session      │      │   UI Updates   │
   │    Save    │        │  Injection     │      │  Automatically │
   │Automatically│        │  & Restore     │      │               │
   └────────────┘        └────────────────┘      └────────────────┘
```

### Core Components

#### 1. SessionStorageProtocol Implementation

Implement this protocol to connect ClaudeCodeUI to your storage backend:

```swift
import ClaudeCodeCore

class DatabaseSessionStorage: SessionStorageProtocol {
    let database: YourDatabaseLayer
    
    init(database: YourDatabaseLayer) {
        self.database = database
    }
    
    // REQUIRED: Save a new session
    func saveSession(id: String, firstMessage: String) async throws {
        let session = YourSessionModel(
            id: id,
            createdAt: Date(),
            firstMessage: firstMessage,
            lastAccessedAt: Date()
        )
        try await database.save(session)
    }
    
    // REQUIRED: Get all sessions (sorted by last accessed)
    func getAllSessions() async throws -> [StoredSession] {
        let dbSessions = try await database.fetchAllSessions()
        return dbSessions.map { dbSession in
            StoredSession(
                id: dbSession.id,
                createdAt: dbSession.createdAt,
                firstUserMessage: dbSession.firstMessage,
                lastAccessedAt: dbSession.lastAccessedAt,
                messages: dbSession.messages.map { convertToClaudeMessage($0) }
            )
        }.sorted { $0.lastAccessedAt > $1.lastAccessedAt }
    }
    
    // REQUIRED: Get specific session
    func getSession(id: String) async throws -> StoredSession? {
        guard let dbSession = try await database.fetchSession(id: id) else { return nil }
        return StoredSession(
            id: dbSession.id,
            createdAt: dbSession.createdAt,
            firstUserMessage: dbSession.firstMessage,
            lastAccessedAt: dbSession.lastAccessedAt,
            messages: dbSession.messages.map { convertToClaudeMessage($0) }
        )
    }
    
    // REQUIRED: Update session messages (called automatically!)
    func updateSessionMessages(id: String, messages: [ChatMessage]) async throws {
        // This is called every time new messages are added to the conversation
        let dbMessages = messages.map { convertFromClaudeMessage($0) }
        try await database.updateSessionMessages(sessionId: id, messages: dbMessages)
        
        // Also update last accessed time
        try await database.updateLastAccessed(sessionId: id, date: Date())
    }
    
    // REQUIRED: Update last accessed time
    func updateLastAccessed(id: String) async throws {
        try await database.updateLastAccessed(sessionId: id, date: Date())
    }
    
    // REQUIRED: Delete session
    func deleteSession(id: String) async throws {
        try await database.deleteSession(id: id)
    }
    
    // REQUIRED: Delete all sessions
    func deleteAllSessions() async throws {
        try await database.deleteAllSessions()
    }
    
    // REQUIRED: Update session ID (when Claude changes session ID internally)
    func updateSessionId(oldId: String, newId: String) async throws {
        try await database.updateSessionId(oldId: oldId, newId: newId)
    }
    
    // Helper: Convert between your data models and ClaudeCodeUI models
    private func convertToClaudeMessage(_ dbMessage: YourMessageModel) -> ChatMessage {
        ChatMessage(
            id: dbMessage.id,
            role: MessageRole(rawValue: dbMessage.role) ?? .user,
            content: dbMessage.content,
            isComplete: dbMessage.isComplete,
            messageType: MessageType(rawValue: dbMessage.type) ?? .text,
            toolName: dbMessage.toolName,
            toolInputData: dbMessage.toolInputData,
            isError: dbMessage.isError
        )
    }
    
    private func convertFromClaudeMessage(_ claudeMessage: ChatMessage) -> YourMessageModel {
        YourMessageModel(
            id: claudeMessage.id,
            role: claudeMessage.role.rawValue,
            content: claudeMessage.content,
            isComplete: claudeMessage.isComplete,
            type: claudeMessage.messageType.rawValue,
            toolName: claudeMessage.toolName,
            toolInputData: claudeMessage.toolInputData,
            isError: claudeMessage.isError
        )
    }
}
```

#### 2. Storage Backend Examples

**CoreData Implementation:**
```swift
class CoreDataSessionStorage: SessionStorageProtocol {
    let container: NSPersistentContainer
    
    init() {
        container = NSPersistentContainer(name: "ChatSessions")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("CoreData failed to load: \(error)")
            }
        }
    }
    
    func updateSessionMessages(id: String, messages: [ChatMessage]) async throws {
        await withCheckedContinuation { continuation in
            let context = container.newBackgroundContext()
            context.perform {
                // Find or create session entity
                let request: NSFetchRequest<SessionEntity> = SessionEntity.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", id)
                
                do {
                    let sessions = try context.fetch(request)
                    let session = sessions.first ?? SessionEntity(context: context)
                    session.id = id
                    session.lastAccessedAt = Date()
                    
                    // Clear existing messages
                    session.messages?.forEach { context.delete($0 as! NSManagedObject) }
                    
                    // Add new messages
                    for message in messages {
                        let messageEntity = MessageEntity(context: context)
                        messageEntity.id = message.id
                        messageEntity.content = message.content
                        messageEntity.role = message.role.rawValue
                        messageEntity.isComplete = message.isComplete
                        messageEntity.session = session
                    }
                    
                    try context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // ... implement other required methods
}
```

**SQLite Implementation:**
```swift
import SQLite3

class SQLiteSessionStorage: SessionStorageProtocol {
    private var db: OpaquePointer?
    
    init(dbPath: String) throws {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            throw DatabaseError.cannotOpen
        }
        try createTables()
    }
    
    func updateSessionMessages(id: String, messages: [ChatMessage]) async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                do {
                    // Begin transaction
                    try self.executeSQL("BEGIN TRANSACTION")
                    
                    // Delete existing messages for this session
                    try self.executeSQL("DELETE FROM messages WHERE session_id = ?", parameters: [id])
                    
                    // Insert new messages
                    for message in messages {
                        try self.executeSQL("""
                            INSERT INTO messages (id, session_id, role, content, is_complete, created_at) 
                            VALUES (?, ?, ?, ?, ?, ?)
                        """, parameters: [
                            message.id.uuidString,
                            id,
                            message.role.rawValue,
                            message.content,
                            message.isComplete ? 1 : 0,
                            Date().timeIntervalSince1970
                        ])
                    }
                    
                    // Update session last accessed
                    try self.executeSQL("""
                        UPDATE sessions SET last_accessed_at = ? WHERE id = ?
                    """, parameters: [Date().timeIntervalSince1970, id])
                    
                    // Commit transaction
                    try self.executeSQL("COMMIT")
                    
                    continuation.resume()
                } catch {
                    try? self.executeSQL("ROLLBACK")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // ... implement other required methods
}
```

**CloudKit Implementation:**
```swift
import CloudKit

class CloudKitSessionStorage: SessionStorageProtocol {
    private let container: CKContainer
    private let database: CKDatabase
    
    init() {
        container = CKContainer.default()
        database = container.privateCloudDatabase
    }
    
    func updateSessionMessages(id: String, messages: [ChatMessage]) async throws {
        // Fetch existing session record
        let sessionID = CKRecord.ID(recordName: "session_\(id)")
        
        do {
            let sessionRecord = try await database.record(for: sessionID)
            sessionRecord["lastAccessedAt"] = Date()
            
            // Save session updates
            _ = try await database.save(sessionRecord)
            
            // Delete existing message records
            let messageQuery = CKQuery(recordType: "Message", predicate: NSPredicate(format: "sessionID == %@", id))
            let existingMessages = try await database.records(matching: messageQuery).matchResults
            
            var recordsToDelete: [CKRecord.ID] = []
            for (_, result) in existingMessages {
                switch result {
                case .success(let record):
                    recordsToDelete.append(record.recordID)
                case .failure:
                    break
                }
            }
            
            if !recordsToDelete.isEmpty {
                _ = try await database.modifyRecords(saving: [], deleting: recordsToDelete)
            }
            
            // Create new message records
            var newMessageRecords: [CKRecord] = []
            for message in messages {
                let messageRecord = CKRecord(recordType: "Message", recordID: CKRecord.ID(recordName: "message_\(message.id)"))
                messageRecord["sessionID"] = id
                messageRecord["role"] = message.role.rawValue
                messageRecord["content"] = message.content
                messageRecord["isComplete"] = message.isComplete
                messageRecord["createdAt"] = Date()
                newMessageRecords.append(messageRecord)
            }
            
            // Batch save all message records
            if !newMessageRecords.isEmpty {
                _ = try await database.modifyRecords(saving: newMessageRecords, deleting: [])
            }
        } catch CKError.unknownItem {
            // Session doesn't exist, create it
            let newSessionRecord = CKRecord(recordType: "Session", recordID: sessionID)
            newSessionRecord["id"] = id
            newSessionRecord["createdAt"] = Date()
            newSessionRecord["lastAccessedAt"] = Date()
            newSessionRecord["firstMessage"] = messages.first?.content ?? ""
            _ = try await database.save(newSessionRecord)
            
            // Recursively call to save messages
            try await updateSessionMessages(id: id, messages: messages)
        }
    }
    
    // ... implement other required methods
}
```

### Session Injection and Management

#### Basic Session Injection

The `injectSession()` method allows you to restore conversations with pre-loaded messages and working directory:

```swift
import ClaudeCodeCore

class MyApp: App {
    @State private var globalPreferences = GlobalPreferencesStorage()
    @State private var viewModel: ChatViewModel?
    @State private var dependencies: DependencyContainer?
    
    var body: some Scene {
        WindowGroup {
            if let viewModel = viewModel, let deps = dependencies {
                ChatScreen(
                    viewModel: viewModel,
                    contextManager: deps.contextManager,
                    xcodeObservationViewModel: deps.xcodeObservationViewModel,
                    permissionsService: deps.permissionsService,
                    terminalService: deps.terminalService,
                    customPermissionService: deps.customPermissionService,
                    columnVisibility: .constant(.detailOnly),
                    uiConfiguration: UIConfiguration(appName: "My Database App")
                )
            } else {
                ProgressView("Loading conversation...")
                    .onAppear { 
                        Task { await restoreLastSession() }
                    }
            }
        }
    }
    
    func restoreLastSession() async {
        // 1. Set up dependencies with your custom storage
        let deps = DependencyContainer(globalPreferences: globalPreferences)
        let customStorage = DatabaseSessionStorage(database: myDatabase)
        
        // 2. Create ChatViewModel with your storage
        let vm = ChatViewModel(
            claudeClient: ClaudeCodeClient(configuration: .default),
            sessionStorage: customStorage,  // Your custom storage
            settingsStorage: deps.settingsStorage,
            globalPreferences: globalPreferences,
            customPermissionService: deps.customPermissionService
        )
        
        // 3. Load last session from your database
        do {
            if let lastSession = try await customStorage.getAllSessions().first {
                // 4. Inject the session with messages and working directory
                vm.injectSession(
                    sessionId: lastSession.id,
                    messages: lastSession.messages,  // Pre-loaded from your DB
                    workingDirectory: "/path/to/project"  // Skip directory selection
                )
                
                print("✅ Restored session '\(lastSession.id)' with \(lastSession.messages.count) messages")
            } else {
                // No previous sessions, start fresh but still inject working directory
                vm.injectSession(
                    sessionId: UUID().uuidString,
                    messages: [],
                    workingDirectory: "/default/project/path"
                )
                
                print("✅ Started new session with default working directory")
            }
        } catch {
            print("❌ Failed to restore session: \(error)")
            // Fallback to fresh session
            vm.injectSession(
                sessionId: UUID().uuidString,
                messages: [],
                workingDirectory: nil  // User will need to select manually
            )
        }
        
        await MainActor.run {
            self.viewModel = vm
            self.dependencies = deps
        }
    }
}
```

#### Advanced Session Management

**Multi-Session App with Session Switching:**
```swift
class MultiSessionApp: ObservableObject {
    @Published var currentViewModel: ChatViewModel?
    @Published var availableSessions: [StoredSession] = []
    
    private let storage: DatabaseSessionStorage
    private let dependencies: DependencyContainer
    
    init() {
        self.storage = DatabaseSessionStorage(database: MyDatabase.shared)
        self.dependencies = DependencyContainer(globalPreferences: GlobalPreferencesStorage())
        
        Task {
            await loadAvailableSessions()
        }
    }
    
    func loadAvailableSessions() async {
        do {
            let sessions = try await storage.getAllSessions()
            await MainActor.run {
                self.availableSessions = sessions
            }
        } catch {
            print("Failed to load sessions: \(error)")
        }
    }
    
    func switchToSession(_ session: StoredSession) async {
        // Create new view model for this session
        let vm = ChatViewModel(
            claudeClient: ClaudeCodeClient(configuration: .default),
            sessionStorage: storage,
            settingsStorage: dependencies.settingsStorage,
            globalPreferences: dependencies.globalPreferences,
            customPermissionService: dependencies.customPermissionService
        )
        
        // Inject the selected session
        vm.injectSession(
            sessionId: session.id,
            messages: session.messages,
            workingDirectory: getWorkingDirectoryForSession(session.id)
        )
        
        await MainActor.run {
            self.currentViewModel = vm
        }
        
        print("✅ Switched to session: \(session.title)")
    }
    
    func createNewSession(withWorkingDirectory workingDir: String? = nil) async {
        let newSessionId = UUID().uuidString
        
        let vm = ChatViewModel(
            claudeClient: ClaudeCodeClient(configuration: .default),
            sessionStorage: storage,
            settingsStorage: dependencies.settingsStorage,
            globalPreferences: dependencies.globalPreferences,
            customPermissionService: dependencies.customPermissionService
        )
        
        // Inject empty session with working directory
        vm.injectSession(
            sessionId: newSessionId,
            messages: [],
            workingDirectory: workingDir
        )
        
        await MainActor.run {
            self.currentViewModel = vm
        }
        
        // Refresh available sessions
        await loadAvailableSessions()
        
        print("✅ Created new session: \(newSessionId)")
    }
    
    private func getWorkingDirectoryForSession(_ sessionId: String) -> String? {
        // Load working directory from your database/preferences
        return MyDatabase.shared.getWorkingDirectory(forSession: sessionId)
    }
}
```

### Working Directory Injection

ClaudeCodeUI supports three ways to inject working directories:

#### 1. At App Startup (Configuration)
```swift
// Set working directory when creating the app configuration
RootView(configuration: ClaudeCodeAppConfiguration(
    appName: "My Project App",
    workingDirectory: "/Users/me/my-project"  // No manual selection needed!
))
```

#### 2. During Session Injection
```swift
// Set working directory when injecting a session
viewModel.injectSession(
    sessionId: "session-123",
    messages: savedMessages,
    workingDirectory: "/path/to/project"  // Ready to work immediately!
)
```

#### 3. Runtime Updates
```swift
// Update working directory during the conversation
viewModel.updateWorkingDirectory("/new/project/path")
```

#### Working Directory Persistence Strategies

**Strategy 1: Per-Session Storage**
```swift
class SessionWorkingDirectoryManager {
    private let storage: YourDatabaseLayer
    
    func saveWorkingDirectory(_ path: String, forSession sessionId: String) async throws {
        try await storage.execute("""
            INSERT OR REPLACE INTO session_settings (session_id, working_directory, updated_at)
            VALUES (?, ?, ?)
        """, parameters: [sessionId, path, Date().timeIntervalSince1970])
    }
    
    func getWorkingDirectory(forSession sessionId: String) async -> String? {
        return try? await storage.fetchValue("""
            SELECT working_directory FROM session_settings WHERE session_id = ?
        """, parameters: [sessionId])
    }
    
    func restoreSessionWithWorkingDirectory(_ sessionId: String) async -> (messages: [ChatMessage], workingDirectory: String?) {
        async let messages = storage.fetchMessages(sessionId: sessionId)
        async let workingDir = getWorkingDirectory(forSession: sessionId)
        
        return await (messages: messages, workingDirectory: workingDir)
    }
}

// Usage in your app:
let (messages, workingDir) = await directoryManager.restoreSessionWithWorkingDirectory(sessionId)
viewModel.injectSession(
    sessionId: sessionId,
    messages: messages,
    workingDirectory: workingDir
)
```

**Strategy 2: Project-Based Storage**
```swift
class ProjectManager {
    func getLastSessionForProject(_ projectPath: String) async -> String? {
        return try? await storage.fetchValue("""
            SELECT session_id FROM project_sessions 
            WHERE project_path = ? 
            ORDER BY last_accessed_at DESC 
            LIMIT 1
        """, parameters: [projectPath])
    }
    
    func restoreProjectSession(_ projectPath: String) async {
        if let lastSessionId = await getLastSessionForProject(projectPath) {
            let messages = try await storage.fetchMessages(sessionId: lastSessionId)
            
            viewModel.injectSession(
                sessionId: lastSessionId,
                messages: messages,
                workingDirectory: projectPath  // Always use the project path
            )
        }
    }
}
```

### Real-time Message Saving

When you implement `SessionStorageProtocol`, the `updateSessionMessages()` method is called automatically whenever:
- A user sends a message
- Claude responds with a message
- Tool calls are made
- Any conversation update occurs

**Performance Optimization Example:**
```swift
class OptimizedSessionStorage: SessionStorageProtocol {
    private var saveQueue = DispatchQueue(label: "message-save-queue", qos: .utility)
    private var lastSaveTime: [String: Date] = [:]
    private var pendingSaves: [String: [ChatMessage]] = [:]
    private let saveDelay: TimeInterval = 2.0  // Batch saves every 2 seconds
    
    func updateSessionMessages(id: String, messages: [ChatMessage]) async throws {
        // Store messages in memory first for immediate UI updates
        pendingSaves[id] = messages
        
        // Debounce saves to avoid excessive database writes
        let now = Date()
        let lastSave = lastSaveTime[id] ?? Date.distantPast
        
        if now.timeIntervalSince(lastSave) < saveDelay {
            // Schedule a delayed save
            saveQueue.asyncAfter(deadline: .now() + saveDelay) {
                Task {
                    await self.performDelayedSave(sessionId: id)
                }
            }
        } else {
            // Save immediately
            await performImmediateSave(sessionId: id, messages: messages)
        }
    }
    
    private func performImmediateSave(sessionId: String, messages: [ChatMessage]) async {
        do {
            try await database.saveMessages(sessionId: sessionId, messages: messages)
            lastSaveTime[sessionId] = Date()
            pendingSaves.removeValue(forKey: sessionId)
            print("✅ Saved \(messages.count) messages for session \(sessionId)")
        } catch {
            print("❌ Failed to save messages for session \(sessionId): \(error)")
        }
    }
    
    private func performDelayedSave(sessionId: String) async {
        guard let messages = pendingSaves[sessionId] else { return }
        await performImmediateSave(sessionId: sessionId, messages: messages)
    }
    
    // Call this when app is backgrounded or terminating
    func flushPendingSaves() async {
        for (sessionId, messages) in pendingSaves {
            await performImmediateSave(sessionId: sessionId, messages: messages)
        }
    }
}
```

### Advanced Patterns

#### Pattern 1: Multi-Device Synchronization
```swift
class SyncedSessionStorage: SessionStorageProtocol {
    private let localStorage: LocalDatabaseStorage
    private let cloudStorage: CloudSyncStorage
    private let conflictResolver: ConflictResolver
    
    func updateSessionMessages(id: String, messages: [ChatMessage]) async throws {
        // Save locally first for immediate response
        try await localStorage.updateSessionMessages(id: id, messages: messages)
        
        // Queue for cloud sync
        await cloudSyncQueue.enqueue(SyncOperation(
            sessionId: id,
            messages: messages,
            timestamp: Date()
        ))
        
        print("📤 Queued session \(id) for cloud sync")
    }
    
    func syncWithCloud() async throws {
        let localSessions = try await localStorage.getAllSessions()
        let cloudSessions = try await cloudStorage.getAllSessions()
        
        for localSession in localSessions {
            if let cloudSession = cloudSessions.first(where: { $0.id == localSession.id }) {
                // Resolve conflicts and merge
                let mergedMessages = try await conflictResolver.merge(
                    local: localSession.messages,
                    cloud: cloudSession.messages
                )
                
                try await localStorage.updateSessionMessages(id: localSession.id, messages: mergedMessages)
                try await cloudStorage.updateSessionMessages(id: localSession.id, messages: mergedMessages)
                
                print("🔄 Synced session \(localSession.id)")
            }
        }
    }
}
```

#### Pattern 2: Background Message Processing
```swift
class BackgroundProcessingStorage: SessionStorageProtocol {
    private let backgroundQueue = DispatchQueue(label: "message-processing", qos: .utility)
    
    func updateSessionMessages(id: String, messages: [ChatMessage]) async throws {
        // Save immediately for UI consistency
        try await quickSave(sessionId: id, messages: messages)
        
        // Process in background for analytics, search indexing, etc.
        backgroundQueue.async {
            Task {
                await self.processMessagesInBackground(sessionId: id, messages: messages)
            }
        }
    }
    
    private func processMessagesInBackground(sessionId: String, messages: [ChatMessage]) async {
        // Extract code snippets for search indexing
        let codeSnippets = extractCodeSnippets(from: messages)
        await searchIndex.index(snippets: codeSnippets, sessionId: sessionId)
        
        // Analyze conversation for insights
        let insights = await conversationAnalyzer.analyze(messages: messages)
        await analytics.track(insights: insights, sessionId: sessionId)
        
        // Generate conversation summary
        let summary = await summaryGenerator.generate(from: messages)
        await database.updateSessionSummary(sessionId: sessionId, summary: summary)
        
        print("🧠 Background processing completed for session \(sessionId)")
    }
}
```

#### Pattern 3: Offline/Online Handling
```swift
class OfflineCapableStorage: SessionStorageProtocol {
    private let localStorage: SQLiteStorage
    private let cloudStorage: CloudKitStorage
    private var isOnline: Bool = true
    
    func updateSessionMessages(id: String, messages: [ChatMessage]) async throws {
        // Always save locally first
        try await localStorage.updateSessionMessages(id: id, messages: messages)
        
        if isOnline {
            do {
                try await cloudStorage.updateSessionMessages(id: id, messages: messages)
                // Mark as synced
                try await localStorage.markAsSynced(sessionId: id)
            } catch {
                // Network error, mark as pending sync
                try await localStorage.markAsPendingSync(sessionId: id)
                print("📶 Offline: Queued session \(id) for later sync")
            }
        } else {
            try await localStorage.markAsPendingSync(sessionId: id)
        }
    }
    
    func goOnline() async {
        isOnline = true
        
        // Sync all pending sessions
        let pendingSessions = try await localStorage.getPendingSyncSessions()
        
        for session in pendingSessions {
            do {
                try await cloudStorage.updateSessionMessages(id: session.id, messages: session.messages)
                try await localStorage.markAsSynced(sessionId: session.id)
                print("☁️ Synced pending session: \(session.id)")
            } catch {
                print("❌ Failed to sync session \(session.id): \(error)")
            }
        }
    }
}
```

### Troubleshooting and Best Practices

#### Error Handling Patterns

**Graceful Degradation:**
```swift
class RobustSessionStorage: SessionStorageProtocol {
    private let primaryStorage: DatabaseStorage
    private let fallbackStorage: UserDefaultsStorage
    
    func updateSessionMessages(id: String, messages: [ChatMessage]) async throws {
        do {
            // Try primary storage first
            try await primaryStorage.updateSessionMessages(id: id, messages: messages)
        } catch {
            print("⚠️ Primary storage failed, using fallback: \(error)")
            
            do {
                // Fallback to UserDefaults
                try await fallbackStorage.updateSessionMessages(id: id, messages: messages)
                
                // Queue for retry with primary storage
                await retryQueue.enqueue(RetryOperation(sessionId: id, messages: messages))
            } catch {
                print("❌ Both primary and fallback storage failed: \(error)")
                throw StorageError.allBackendsFailed([error])
            }
        }
    }
}
```

#### Performance Monitoring
```swift
class MonitoredSessionStorage: SessionStorageProtocol {
    private let wrappedStorage: SessionStorageProtocol
    private let performanceLogger: PerformanceLogger
    
    func updateSessionMessages(id: String, messages: [ChatMessage]) async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            try await wrappedStorage.updateSessionMessages(id: id, messages: messages)
            
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            await performanceLogger.log(
                operation: "updateSessionMessages",
                sessionId: id,
                messageCount: messages.count,
                duration: duration
            )
            
            if duration > 2.0 {
                print("⚠️ Slow storage operation: \(duration)s for \(messages.count) messages")
            }
        } catch {
            await performanceLogger.logError(
                operation: "updateSessionMessages",
                sessionId: id,
                error: error,
                duration: CFAbsoluteTimeGetCurrent() - startTime
            )
            throw error
        }
    }
}
```

#### Testing Your Implementation

```swift
import XCTest
@testable import YourApp

class SessionStorageTests: XCTestCase {
    var storage: YourSessionStorage!
    
    override func setUp() {
        super.setUp()
        storage = YourSessionStorage(testDatabase: createTestDB())
    }
    
    func testSessionPersistence() async throws {
        let sessionId = "test-session-1"
        let messages = [
            ChatMessage(id: UUID(), role: .user, content: "Hello", isComplete: true),
            ChatMessage(id: UUID(), role: .assistant, content: "Hi there!", isComplete: true)
        ]
        
        // Test saving
        try await storage.updateSessionMessages(id: sessionId, messages: messages)
        
        // Test retrieval
        let retrievedSession = try await storage.getSession(id: sessionId)
        XCTAssertNotNil(retrievedSession)
        XCTAssertEqual(retrievedSession?.messages.count, 2)
        XCTAssertEqual(retrievedSession?.messages.first?.content, "Hello")
    }
    
    func testWorkingDirectoryInjection() async throws {
        let sessionId = "test-session-2"
        let workingDir = "/test/project/path"
        
        // Create view model with test storage
        let viewModel = ChatViewModel(
            claudeClient: MockClaudeClient(),
            sessionStorage: storage,
            settingsStorage: MockSettingsStorage(),
            globalPreferences: GlobalPreferencesStorage(),
            customPermissionService: MockPermissionService()
        )
        
        // Inject session with working directory
        viewModel.injectSession(
            sessionId: sessionId,
            messages: [],
            workingDirectory: workingDir
        )
        
        // Verify working directory is set
        XCTAssertEqual(viewModel.projectPath, workingDir)
    }
    
    func testAutomaticMessageSaving() async throws {
        let sessionId = "test-session-3"
        
        // Set up view model to track saves
        let mockStorage = MockSessionStorage()
        let viewModel = ChatViewModel(
            claudeClient: MockClaudeClient(),
            sessionStorage: mockStorage,
            settingsStorage: MockSettingsStorage(),
            globalPreferences: GlobalPreferencesStorage(),
            customPermissionService: MockPermissionService()
        )
        
        viewModel.injectSession(sessionId: sessionId, messages: [], workingDirectory: nil)
        
        // Simulate sending a message
        await viewModel.sendMessage("Test message", attachments: [])
        
        // Wait for async save
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Verify save was called
        XCTAssertTrue(mockStorage.updateSessionMessagesCalled)
        XCTAssertEqual(mockStorage.lastSavedSessionId, sessionId)
        XCTAssertGreaterThan(mockStorage.lastSavedMessages.count, 0)
    }
}
```

### Migration Strategies

#### From Built-in to External Storage

```swift
class StorageMigration {
    static func migrateFromBuiltIn() async throws {
        let builtInStorage = UserDefaultsSessionStorage()
        let externalStorage = DatabaseSessionStorage(database: MyDatabase.shared)
        
        let existingSessions = try await builtInStorage.getAllSessions()
        
        print("📦 Migrating \(existingSessions.count) sessions to external storage...")
        
        for session in existingSessions {
            do {
                // Save to new storage
                try await externalStorage.saveSession(
                    id: session.id,
                    firstMessage: session.firstUserMessage
                )
                
                try await externalStorage.updateSessionMessages(
                    id: session.id,
                    messages: session.messages
                )
                
                // Update timestamps
                try await externalStorage.updateLastAccessed(id: session.id)
                
                print("✅ Migrated session: \(session.title)")
            } catch {
                print("❌ Failed to migrate session \(session.id): \(error)")
            }
        }
        
        print("🎉 Migration completed!")
    }
}
```

This comprehensive guide provides everything needed to implement external storage with ClaudeCodeUI, including session injection, automatic message saving, working directory management, and advanced patterns for real-world applications.

## Xcode Integration

ClaudeCodeUI can automatically detect your active Xcode project and selected code, making it seamless to work with your current development context.

### Enabling Xcode Integration

To enable Xcode integration, you need to grant Accessibility permissions:

1. **Open System Settings** > **Privacy & Security** > **Accessibility**
2. **Click the lock** to make changes (you'll need to authenticate)
3. **Click the + button** and add ClaudeCodeUI to the list
4. **Enable the toggle** next to ClaudeCodeUI

### What Xcode Integration Provides

Once enabled, ClaudeCodeUI can:
- **Detect Active Project**: Automatically sets the working directory to your currently open Xcode project
- **Read Selected Code**: Access code selections in Xcode to provide context-aware assistance
- **Monitor Active Files**: Track which files you're working on for better context
- **Sync Project Paths**: Automatically update the working directory when you switch between Xcode projects

## MCP Approval Tool

### Overview

The MCP (Model Context Protocol) approval tool provides a secure permission system for Claude Code operations. When Claude needs to perform actions like file operations or execute commands, the approval tool presents a native macOS dialog for user consent.

### Setup Instructions by Use Case

#### For Package Users (Using ClaudeCodeCore in Your App)

When using ClaudeCodeCore as a package dependency, you need to build and include the MCP approval server in your app:

1. **Add the MCP server module to your project**:
   - The server source is included in the package at `modules/ApprovalMCPServer`
   - You'll need to build it as part of your app's build process

2. **Option A: Add Build Phase to Your App**:
   ```bash
   # Add this script to your app's build phases
   cd "$BUILD_DIR/../../SourcePackages/checkouts/ClaudeCodeUI/modules/ApprovalMCPServer"
   swift build -c release
   cp .build/release/ApprovalMCPServer "$BUILT_PRODUCTS_DIR/$PRODUCT_NAME.app/Contents/Resources/"
   ```

3. **Option B: Build Manually and Include**:
   ```bash
   # Build the server manually
   cd path/to/ClaudeCodeUI/modules/ApprovalMCPServer
   swift build -c release
   # Copy the binary to your app's Resources folder
   ```

4. **Option C: Use without MCP** (Simplest):
   - The app will work without the MCP server, but you won't get approval dialogs
   - Claude will use default permissions based on your settings

#### For Building ClaudeCodeUI from Source

When building the ClaudeCodeUI app itself from source:

1. Open `ClaudeCodeUI.xcodeproj`
2. Select the `ClaudeCodeUI` target
3. Go to "Build Phases" tab
4. Click "+" → "New Run Script Phase"
5. **Important**: Drag the new phase to run **before** "Compile Sources"
6. Paste this script: `"${PROJECT_DIR}/Scripts/build-approval-server.sh"`
7. Rename to "Build MCP Approval Server" (optional)
8. Build and run!

### How It Works

1. **Automatic Detection**: ClaudeCodeCore looks for the server in multiple locations
2. **Smart Path Detection**: Checks app bundle, build directories, and package paths
3. **Permission Dialogs**: Native macOS UI for approving/denying Claude's requests
4. **Session-Based**: Permissions are managed per chat session for security

## Development

### Prerequisites

- macOS 15.2 or later (due to package dependencies)
- Xcode 15.0 or later
- Swift 5.9 or later
- Claude Code SDK

### Building from Source

1. Clone the repository:
```bash
git clone https://github.com/jamesrochabrun/ClaudeCodeUI.git
cd ClaudeCodeUI
```

2. **Using Xcode Project** (for app development):
```bash
open ClaudeCodeUI.xcodeproj
# Build and run with ⌘R
```

3. **Using Swift Package Manager** (for package development):
```bash
swift build
swift run ClaudeCodeUI
```

### Testing the Package

```bash
# Run tests for the core library
swift test

# Or in Xcode
# Product → Test (⌘U)
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please ensure your contributions:
- Follow Swift naming conventions
- Include appropriate documentation
- Add tests where applicable
- Update the README if adding new features
- Work with both the Xcode project and Swift Package

## Troubleshooting

### Common Issues

**"MCP tool not found" error on first run**
- You need to add the build phase! See [First-Time Setup](#first-time-setup-required-only-for-building-from-source)
- This is only needed when building from source

**Package resolution issues**
- Clean the package cache: `swift package clean`
- Reset package resolved: `swift package reset`
- In Xcode: File → Packages → Reset Package Caches

**App doesn't launch**
- Ensure you're running macOS 15.2 or later
- Check that all Swift Package dependencies are resolved

**Claude Code SDK not responding**
- Verify your API credentials are properly configured
- Check the debug logs in Console.app for detailed error messages
- Ensure you have an active internet connection

## TODOs

- [ ] Fix diffing UI - improve visual diff presentation and user interaction
- [ ] Improve MCP approval flow - enhance the permission dialog UX
- [ ] Add iOS/iPadOS support (the package structure now makes this possible!)
- [ ] Create example apps demonstrating different integration patterns

## Acknowledgments

Special thanks to [cmd](https://github.com/getcmd-dev/cmd) - The code for diff visualization and markdown rendering has been adapted from this excellent project. Their implementation provided a solid foundation for these features in ClaudeCodeUI.

## License

MIT License