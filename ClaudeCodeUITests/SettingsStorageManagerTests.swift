//
//  SettingsStorageManagerTests.swift
//  ClaudeCodeUITests
//
//  Created on 12/19/24.
//

import XCTest
@testable import ClaudeCodeUI

@MainActor
final class SettingsStorageManagerTests: XCTestCase {
    
    var storage: SettingsStorageManager!
    
    override func setUp() async throws {
        try await super.setUp()
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "projectPath")
        UserDefaults.standard.removeObject(forKey: "session.projectPath.test-session-1")
        UserDefaults.standard.removeObject(forKey: "session.projectPath.test-session-2")
        storage = SettingsStorageManager()
    }
    
    override func tearDown() async throws {
        storage = nil
        try await super.tearDown()
    }
    
    // MARK: - Project Path Tests
    
    func testProjectPathDefaultValue() {
        XCTAssertEqual(storage.projectPath, "", "Project path should default to empty string")
        XCTAssertNil(storage.getProjectPath(), "getProjectPath should return nil for empty path")
    }
    
    func testSetProjectPath() {
        let testPath = "/Users/test/project"
        storage.setProjectPath(testPath)
        
        XCTAssertEqual(storage.projectPath, testPath)
        XCTAssertEqual(storage.getProjectPath(), testPath)
    }
    
    func testClearProjectPath() {
        storage.setProjectPath("/test/path")
        storage.clearProjectPath()
        
        XCTAssertEqual(storage.projectPath, "")
        XCTAssertNil(storage.getProjectPath())
    }
    
    func testProjectPathNonPersistence() {
        let testPath = "/persistent/path"
        storage.setProjectPath(testPath)
        
        // Create new instance - should NOT have the previous path
        let newStorage = SettingsStorageManager()
        XCTAssertEqual(newStorage.projectPath, "", "Project path should NOT persist across instances")
    }
    
    // MARK: - Per-Session Project Path Tests
    
    func testPerSessionProjectPath() {
        let sessionId1 = "test-session-1"
        let sessionId2 = "test-session-2"
        let path1 = "/path/for/session1"
        let path2 = "/path/for/session2"
        
        // Set paths for different sessions
        storage.setProjectPath(path1, forSessionId: sessionId1)
        storage.setProjectPath(path2, forSessionId: sessionId2)
        
        // Verify paths are stored separately
        XCTAssertEqual(storage.getProjectPath(forSessionId: sessionId1), path1)
        XCTAssertEqual(storage.getProjectPath(forSessionId: sessionId2), path2)
    }
    
    func testPerSessionProjectPathDefaultValue() {
        XCTAssertNil(storage.getProjectPath(forSessionId: "non-existent-session"))
    }
    
    func testPerSessionProjectPathEmptyString() {
        let sessionId = "empty-path-session"
        storage.setProjectPath("", forSessionId: sessionId)
        
        // Empty string should return nil
        XCTAssertNil(storage.getProjectPath(forSessionId: sessionId))
    }
    
    func testPerSessionProjectPathPersistence() {
        let sessionId = "persistent-session"
        let testPath = "/persistent/session/path"
        
        storage.setProjectPath(testPath, forSessionId: sessionId)
        
        // Create new instance
        let newStorage = SettingsStorageManager()
        XCTAssertEqual(newStorage.getProjectPath(forSessionId: sessionId), testPath)
    }
    
    // MARK: - Observation Tests
    
    func testProjectPathObservation() {
        let expectation = expectation(description: "Property change observed")
        
        withObservationTracking {
            _ = storage.projectPath
        } onChange: {
            expectation.fulfill()
        }
        
        storage.setProjectPath("/new/path")
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Current Session Management Tests
    
    func testCurrentSessionTracking() {
        let sessionId = "current-session"
        let sessionPath = "/current/session/path"
        
        // Simulate setting current session
        storage.setProjectPath(sessionPath)
        storage.setProjectPath(sessionPath, forSessionId: sessionId)
        
        // Verify both current and session-specific paths are set
        XCTAssertEqual(storage.projectPath, sessionPath)
        XCTAssertEqual(storage.getProjectPath(forSessionId: sessionId), sessionPath)
    }
}
