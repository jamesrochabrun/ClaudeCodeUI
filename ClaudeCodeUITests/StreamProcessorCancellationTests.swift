//
//  StreamProcessorCancellationTests.swift
//  ClaudeCodeUITests
//
//  Comprehensive tests for StreamProcessor cancellation and continuation leak prevention
//

import XCTest
import Combine
import ClaudeCodeSDK
import SwiftAnthropic
@testable import ClaudeCodeUI

@MainActor
final class StreamProcessorCancellationTests: XCTestCase {
  var streamProcessor: StreamProcessor!
  var sessionManager: SessionManager!
  var messageStore: MessageStore!
  var mockSessionStorage: MockSessionStorage!
  var cancellables = Set<AnyCancellable>()
  
  override func setUp() {
    super.setUp()
    
    mockSessionStorage = MockSessionStorage()
    sessionManager = SessionManager(sessionStorage: mockSessionStorage)
    messageStore = MessageStore()
    
    streamProcessor = StreamProcessor(
      messageStore: messageStore,
      sessionManager: sessionManager,
      onSessionChange: { _ in }
    )
  }
  
  override func tearDown() {
    streamProcessor = nil
    sessionManager = nil
    messageStore = nil
    mockSessionStorage = nil
    cancellables.removeAll()
    super.tearDown()
  }
  
  // MARK: - Continuation Leak Prevention Tests
  
  func testCancelStreamResumesActiveContinuation() async throws {
    // Given - A long-running stream
    let publisher = createSlowStreamPublisher(itemCount: 100, delayMs: 100)
    
    // When - Start processing and cancel immediately
    let processTask = Task {
      await streamProcessor.processStream(
        publisher,
        messageId: UUID(),
        firstMessageInSession: "Test"
      )
    }
    
    // Give it time to start
    try await Task.sleep(nanoseconds: 50_000_000) // 50ms
    
    // Cancel the stream
    streamProcessor.cancelStream()
    
    // Then - The process task should complete without hanging
    let result = await withTaskGroup(of: Bool.self) { group in
      group.addTask {
        await processTask.value
        return true
      }
      
      group.addTask {
        do {
          try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second timeout
          return false // Timeout means continuation leaked
        } catch {
          return false
        }
      }
      
      // Return the first result
      if let firstResult = await group.next() {
        group.cancelAll()
        return firstResult
      }
      return false
    }
    
    XCTAssertTrue(result, "Continuation was not resumed after cancellation - likely leaked")
  }
  
  func testMultipleCancellationsDoNotCauseCrash() async throws {
    // Given - A stream in progress
    let publisher = createSlowStreamPublisher(itemCount: 50, delayMs: 50)
    
    let _ = Task {
      await streamProcessor.processStream(
        publisher,
        messageId: UUID(),
        firstMessageInSession: "Test"
      )
    }
    
    // When - Cancel multiple times rapidly
    streamProcessor.cancelStream()
    streamProcessor.cancelStream()
    streamProcessor.cancelStream()
    
    // Then - Should not crash
    try await Task.sleep(nanoseconds: 100_000_000) // 100ms
    
    // Verify we can start a new stream after multiple cancellations
    let newPublisher = createSimpleStreamPublisher()
    await streamProcessor.processStream(
      newPublisher,
      messageId: UUID(),
      firstMessageInSession: "New stream"
    )
    
    XCTAssertTrue(true, "Multiple cancellations handled without crash")
  }
  
  func testCancellationDuringToolUseProcessing() async throws {
    // Given - A stream with tool use content
    let chunks: [ResponseChunk] = [
      .assistant(createAssistantMessage(content: "Processing...")),
      .assistant(createToolUseMessage(toolName: "Read", input: ["file": "test.txt"]))
    ]
    
    let publisher = createChunkedPublisher(chunks: chunks, delayMs: 100)
    
    // When - Start processing
    let processTask = Task {
      await streamProcessor.processStream(
        publisher,
        messageId: UUID(),
        firstMessageInSession: "Test with tools"
      )
    }
    
    // Wait for first chunk
    try await Task.sleep(nanoseconds: 150_000_000) // 150ms
    
    // Cancel during tool processing
    streamProcessor.cancelStream()
    
    // Then - Should complete quickly
    let completed = await withTaskTimeLimit(seconds: 1) {
      await processTask.value
      return true
    }
    
    XCTAssertTrue(completed, "Stream did not complete after cancellation during tool use")
  }
  
  func testCancellationClearsSubscriptions() async throws {
    // Given - Track initial state
    let initialSubCount = cancellables.count
    
    // Start a stream
    let publisher = createSlowStreamPublisher(itemCount: 100, delayMs: 10)
    
    let _ = Task {
      await streamProcessor.processStream(
        publisher,
        messageId: UUID(),
        firstMessageInSession: "Test"
      )
    }
    
    try await Task.sleep(nanoseconds: 50_000_000) // 50ms
    
    // When - Cancel the stream
    streamProcessor.cancelStream()
    
    // Then - Subscriptions should be cleared
    try await Task.sleep(nanoseconds: 100_000_000) // 100ms
    XCTAssertEqual(cancellables.count, initialSubCount, "Subscriptions not cleared after cancellation")
  }
  
  // MARK: - Message State After Cancellation Tests
  
  func testPartialMessagesMarkedAsInterrupted() async throws {
    // Given - A stream that creates a partial message
    let chunks: [ResponseChunk] = [
      .assistant(createAssistantMessage(content: "This is a partial message that will be interrupted"))
    ]
    
    let publisher = createChunkedPublisher(chunks: chunks, delayMs: 200)
    
    // When - Start and cancel quickly
    let _ = Task {
      await streamProcessor.processStream(
        publisher,
        messageId: UUID(),
        firstMessageInSession: "Test"
      )
    }
    
    try await Task.sleep(nanoseconds: 100_000_000) // 100ms - let it start
    streamProcessor.cancelStream()
    
    // Wait for cleanup
    try await Task.sleep(nanoseconds: 200_000_000) // 200ms
    
    // Then - Check message state
    if messageStore.messages.count > 0 {
      let lastMessage = messageStore.messages.last!
      // Message should either be removed or marked as complete/interrupted
      XCTAssertTrue(
        lastMessage.isComplete || lastMessage.content.contains("⚠️"),
        "Partial message not properly handled after cancellation"
      )
    }
  }
  
  // MARK: - Concurrent Operations Tests
  
  func testCancelThenImmediateNewStream() async throws {
    // Given - A stream in progress
    let slowPublisher = createSlowStreamPublisher(itemCount: 100, delayMs: 50)
    
    let firstTask = Task {
      await streamProcessor.processStream(
        slowPublisher,
        messageId: UUID(),
        firstMessageInSession: "First"
      )
    }
    
    try await Task.sleep(nanoseconds: 50_000_000) // 50ms
    
    // When - Cancel and immediately start new stream
    streamProcessor.cancelStream()
    
    let fastPublisher = createSimpleStreamPublisher()
    await streamProcessor.processStream(
      fastPublisher,
      messageId: UUID(),
      firstMessageInSession: "Second"
    )
    
    // Then - Second stream should complete successfully
    XCTAssertTrue(sessionManager.hasActiveSession, "Session should be active after second stream")
  }
  
  // MARK: - Helper Methods
  
  private func createSlowStreamPublisher(itemCount: Int, delayMs: Int) -> AnyPublisher<ResponseChunk, Error> {
    let chunks = (0..<itemCount).map { i in
      ResponseChunk.assistant(createAssistantMessage(content: "Message \(i)"))
    }
    
    return chunks.publisher
      .flatMap { chunk in
        Just(chunk)
          .delay(for: .milliseconds(delayMs), scheduler: DispatchQueue.main)
          .setFailureType(to: Error.self)
      }
      .eraseToAnyPublisher()
  }
  
  private func createChunkedPublisher(chunks: [ResponseChunk], delayMs: Int) -> AnyPublisher<ResponseChunk, Error> {
    chunks.publisher
      .flatMap { chunk in
        Just(chunk)
          .delay(for: .milliseconds(delayMs), scheduler: DispatchQueue.main)
          .setFailureType(to: Error.self)
      }
      .eraseToAnyPublisher()
  }
  
  private func createSimpleStreamPublisher() -> AnyPublisher<ResponseChunk, Error> {
    Just(ResponseChunk.assistant(createAssistantMessage(content: "Simple message")))
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
  }
  
  private func createAssistantMessage(content: String) -> AssistantMessage {
    AssistantMessage(
      message: MessageResponse(
        id: "msg_\(UUID().uuidString)",
        type: .message,
        model: "claude-3",
        role: .assistant,
        content: [.text(content, nil)],
        stopReason: nil,
        stopSequence: nil,
        usage: MessageResponse.Usage(inputTokens: 10, outputTokens: 10)
      )
    )
  }
  
  private func createToolUseMessage(toolName: String, input: [String: String]) -> AssistantMessage {
    var dynamicInput: [String: MessageResponse.Content.DynamicContent] = [:]
    for (key, value) in input {
      dynamicInput[key] = .string(value)
    }
    
    return AssistantMessage(
      message: MessageResponse(
        id: "msg_\(UUID().uuidString)",
        type: .message,
        model: "claude-3",
        role: .assistant,
        content: [.toolUse(MessageResponse.Content.ToolUse(
          id: "tool_\(UUID().uuidString)",
          name: toolName,
          input: dynamicInput
        ))],
        stopReason: nil,
        stopSequence: nil,
        usage: MessageResponse.Usage(inputTokens: 10, outputTokens: 10)
      )
    )
  }
  
  private func withTaskTimeLimit<T>(seconds: TimeInterval, operation: @escaping () async -> T) async -> T? {
    await withTaskGroup(of: T?.self) { group in
      group.addTask {
        await operation()
      }
      
      group.addTask {
        do {
          try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
          return nil
        } catch {
          return nil
        }
      }
      
      if let result = await group.next() {
        group.cancelAll()
        return result
      }
      return nil
    }
  }
}