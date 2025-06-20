//
//  AppearanceSettingsTests.swift
//  ClaudeCodeUITests
//
//  Created on 12/19/24.
//

import XCTest
@testable import ClaudeCodeUI

@MainActor
final class AppearanceSettingsTests: XCTestCase {
    
    var settings: AppearanceSettings!
    
    override func setUp() async throws {
        try await super.setUp()
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "colorScheme")
        UserDefaults.standard.removeObject(forKey: "fontSize")
        settings = AppearanceSettings()
    }
    
    override func tearDown() async throws {
        settings = nil
        try await super.tearDown()
    }
    
    // MARK: - Color Scheme Tests
    
    func testColorSchemeDefaultValue() {
        XCTAssertEqual(settings.colorScheme, "system", "Color scheme should default to 'system'")
    }
    
    func testColorSchemePersistence() {
        settings.colorScheme = "dark"
        XCTAssertEqual(settings.colorScheme, "dark")
        
        // Create new instance to test persistence
        let newSettings = AppearanceSettings()
        XCTAssertEqual(newSettings.colorScheme, "dark", "Color scheme should persist")
    }
    
    func testColorSchemeValues() {
        let schemes = ["system", "light", "dark"]
        
        for scheme in schemes {
            settings.colorScheme = scheme
            XCTAssertEqual(settings.colorScheme, scheme)
        }
    }
    
    // MARK: - Font Size Tests
    
    func testFontSizeDefaultValue() {
        XCTAssertEqual(settings.fontSize, 12.0, "Font size should default to 12.0")
    }
    
    func testFontSizePersistence() {
        settings.fontSize = 16.0
        XCTAssertEqual(settings.fontSize, 16.0)
        
        // Create new instance to test persistence
        let newSettings = AppearanceSettings()
        XCTAssertEqual(newSettings.fontSize, 16.0, "Font size should persist")
    }
    
    func testFontSizeRange() {
        // Test minimum
        settings.fontSize = 8.0
        XCTAssertEqual(settings.fontSize, 8.0)
        
        // Test maximum
        settings.fontSize = 24.0
        XCTAssertEqual(settings.fontSize, 24.0)
        
        // Test decimal values
        settings.fontSize = 13.5
        XCTAssertEqual(settings.fontSize, 13.5)
    }
    
    // MARK: - Observation Tests
    
    func testColorSchemeObservation() {
        let expectation = expectation(description: "Color scheme change observed")
        var observedChange = false
        
        withObservationTracking {
            _ = settings.colorScheme
        } onChange: {
            observedChange = true
            expectation.fulfill()
        }
        
        settings.colorScheme = "dark"
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(observedChange, "Color scheme change should be observable")
    }
    
    func testFontSizeObservation() {
        let expectation = expectation(description: "Font size change observed")
        var observedChange = false
        
        withObservationTracking {
            _ = settings.fontSize
        } onChange: {
            observedChange = true
            expectation.fulfill()
        }
        
        settings.fontSize = 14.0
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(observedChange, "Font size change should be observable")
    }
    
    // MARK: - UserDefaults Tests
    
    func testUserDefaultsKeyPersistence() {
        // Set values
        settings.colorScheme = "dark"
        settings.fontSize = 18.0
        
        // Verify values are in UserDefaults
        XCTAssertEqual(UserDefaults.standard.string(forKey: "colorScheme"), "dark")
        XCTAssertEqual(UserDefaults.standard.double(forKey: "fontSize"), 18.0)
    }
    
    func testInitializationFromUserDefaults() {
        // Pre-set values in UserDefaults
        UserDefaults.standard.set("light", forKey: "colorScheme")
        UserDefaults.standard.set(15.0, forKey: "fontSize")
        
        // Create new instance
        let newSettings = AppearanceSettings()
        
        // Verify it loads from UserDefaults
        XCTAssertEqual(newSettings.colorScheme, "light")
        XCTAssertEqual(newSettings.fontSize, 15.0)
    }
}