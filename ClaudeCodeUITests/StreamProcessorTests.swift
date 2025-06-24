//
//  StreamProcessorTests.swift
//  ClaudeCodeUITests
//
//  Unit tests for StreamProcessor sequence of messages fix
//

import XCTest
import Combine
import ClaudeCodeSDK
import SwiftAnthropic
@testable import ClaudeCodeUI

/// Mock implementations for testing
class MockSessionManager: SessionManager {
    var updateCurrentSessionCalled = false
    var updateCurrentSessionId: String?
    
    override func updateCurrentSession(id: String) {
        updateCurrentSessionCalled = true
        updateCurrentSessionId = id
        super.updateCurrentSession(id: id)
    }
}

class MockMessageStore: MessageStore {
    var addMessageCalled = false
    var updateMessageCalled = false
    
    override func addMessage(_ message: ChatMessage) {
        addMessageCalled = true
        super.addMessage(message)
    }
    
    override func updateMessage(id: UUID, content: String, isComplete: Bool) {
        updateMessageCalled = true
        super.updateMessage(id: id, content: content, isComplete: isComplete)
    }
}

final class StreamProcessorTests: XCTestCase {
    var streamProcessor: StreamProcessor!
    var mockSessionManager: MockSessionManager!
    var mockMessageStore: MockMessageStore!
    var onSessionChangeCalled = false
    var onSessionChangeId: String?
    
    override func setUp() {
        super.setUp()
        
        // Create mock session storage
        let mockSessionStorage = MockSessionStorage()
        
        // Initialize mocks
        mockSessionManager = MockSessionManager(sessionStorage: mockSessionStorage)
        mockMessageStore = MockMessageStore()
        
        // Create stream processor with mocks
        streamProcessor = StreamProcessor(
            messageStore: mockMessageStore,
            sessionManager: mockSessionManager,
            onSessionChange: { [weak self] sessionId in
                self?.onSessionChangeCalled = true
                self?.onSessionChangeId = sessionId
            }
        )
        
        // Reset test state
        onSessionChangeCalled = false
        onSessionChangeId = nil
    }
    
    override func tearDown() {
        streamProcessor = nil
        mockSessionManager = nil
        mockMessageStore = nil
        super.tearDown()
    }
    
    // MARK: - Session ID Update Tests
    
    /// Tests that a new session is started when no current session exists
    func testHandleInitSystem_NewSession() async {
        // Given
        let initMessage = InitSystemMessage(
            sessionId: "new-session-123",
            cwd: "/test",
            tools: [],
            mcpServers: [],
            model: "claude-3",
            permissionMode: "default",
            apiKeySource: "none"
        )
        
        // Create a publisher that emits the init message
        let subject = PassthroughSubject<ResponseChunk, Error>()
        let publisher = subject.eraseToAnyPublisher()
        
        // When
        Task {
            await streamProcessor.processStream(
                publisher,
                messageId: UUID(),
                firstMessageInSession: "Test message"
            )
        }
        
        // Send init message
        subject.send(.initSystem(initMessage))
        subject.send(completion: .finished)
        
        // Allow async processing
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertEqual(mockSessionManager.currentSessionId, "new-session-123")
        XCTAssertTrue(onSessionChangeCalled)
        XCTAssertEqual(onSessionChangeId, "new-session-123")
        XCTAssertFalse(mockSessionManager.updateCurrentSessionCalled)
    }
    
    /// Tests that session ID is updated when Claude returns a different one
    func testHandleInitSystem_UpdatesSessionIdWhenDifferent() async {
        // Given
        mockSessionManager.currentSessionId = "existing-session-456"
        
        let initMessage = InitSystemMessage(
            sessionId: "different-session-789",
            cwd: "/test",
            tools: [],
            mcpServers: [],
            model: "claude-3",
            permissionMode: "default",
            apiKeySource: "none"
        )
        
        // Create a publisher that emits the init message
        let subject = PassthroughSubject<ResponseChunk, Error>()
        let publisher = subject.eraseToAnyPublisher()
        
        // When
        Task {
            await streamProcessor.processStream(
                publisher,
                messageId: UUID(),
                firstMessageInSession: nil
            )
        }
        
        // Send init message
        subject.send(.initSystem(initMessage))
        subject.send(completion: .finished)
        
        // Allow async processing
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertTrue(mockSessionManager.updateCurrentSessionCalled)
        XCTAssertEqual(mockSessionManager.updateCurrentSessionId, "different-session-789")
        XCTAssertEqual(mockSessionManager.currentSessionId, "different-session-789")
        XCTAssertTrue(onSessionChangeCalled)
        XCTAssertEqual(onSessionChangeId, "different-session-789")
    }
    
    /// Tests that session ID is not updated when it matches the current one
    func testHandleInitSystem_NoUpdateWhenSessionIdMatches() async {
        // Given
        mockSessionManager.currentSessionId = "matching-session-123"
        
        let initMessage = InitSystemMessage(
            sessionId: "matching-session-123",
            cwd: "/test",
            tools: [],
            mcpServers: [],
            model: "claude-3",
            permissionMode: "default",
            apiKeySource: "none"
        )
        
        // Create a publisher that emits the init message
        let subject = PassthroughSubject<ResponseChunk, Error>()
        let publisher = subject.eraseToAnyPublisher()
        
        // When
        Task {
            await streamProcessor.processStream(
                publisher,
                messageId: UUID(),
                firstMessageInSession: nil
            )
        }
        
        // Send init message
        subject.send(.initSystem(initMessage))
        subject.send(completion: .finished)
        
        // Allow async processing
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertFalse(mockSessionManager.updateCurrentSessionCalled)
        XCTAssertEqual(mockSessionManager.currentSessionId, "matching-session-123")
        XCTAssertFalse(onSessionChangeCalled)
        XCTAssertNil(onSessionChangeId)
    }
    
    // MARK: - Integration Tests
    
    /// Tests that multiple messages maintain the same session after ID update
    func testMultipleMessages_MaintainSessionAfterUpdate() async {
        // Given
        mockSessionManager.currentSessionId = "original-session"
        
        // Create messages with different session IDs (simulating Claude's behavior)
        let initMessage1 = InitSystemMessage(
            sessionId: "new-session-1",
            cwd: "/test",
            tools: [],
            mcpServers: [],
            model: "claude-3",
            permissionMode: "default",
            apiKeySource: "none"
        )
        
        let assistantMessage1 = AssistantMessage(
            sessionId: "new-session-1",
            message: MessageResponse(
                id: "msg-1",
                type: .message,
                role: .assistant,
                model: "claude-3",
                content: [.text("Response 1", nil)],
                stopReason: nil,
                stopSequence: nil,
                usage: MessageUsage(inputTokens: 10, outputTokens: 5, cacheCreationInputTokens: nil, cacheReadInputTokens: nil, serviceTier: nil)
            ),
            parentToolUseId: nil
        )
        
        // Create a publisher
        let subject = PassthroughSubject<ResponseChunk, Error>()
        let publisher = subject.eraseToAnyPublisher()
        
        // When
        Task {
            await streamProcessor.processStream(
                publisher,
                messageId: UUID(),
                firstMessageInSession: nil
            )
        }
        
        // Send first set of messages
        subject.send(.initSystem(initMessage1))
        subject.send(.assistant(assistantMessage1))
        subject.send(completion: .finished)
        
        // Allow async processing
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Then
        XCTAssertEqual(mockSessionManager.currentSessionId, "new-session-1")
        XCTAssertTrue(mockSessionManager.updateCurrentSessionCalled)
        XCTAssertTrue(mockMessageStore.addMessageCalled)
        
        // Verify all messages were processed correctly
        XCTAssertEqual(mockMessageStore.messages.count, 1)
        XCTAssertEqual(mockMessageStore.messages.first?.content, "Response 1")
    }
}

// MARK: - Mock Session Storage

class MockSessionStorage: SessionStorageProtocol {
    var sessions: [StoredSession] = []
    
    func saveSession(id: String, firstMessage: String) async throws {
        let session = StoredSession(
            id: id,
            title: firstMessage,
            createdAt: Date(),
            lastAccessedAt: Date()
        )
        sessions.append(session)
    }
    
    func getAllSessions() async throws -> [StoredSession] {
        return sessions
    }
    
    func deleteSession(id: String) async throws {
        sessions.removeAll { $0.id == id }
    }
    
    func updateLastAccessed(id: String) async throws {
        if let index = sessions.firstIndex(where: { $0.id == id }) {
            sessions[index] = StoredSession(
                id: sessions[index].id,
                title: sessions[index].title,
                createdAt: sessions[index].createdAt,
                lastAccessedAt: Date()
            )
        }
    }
}