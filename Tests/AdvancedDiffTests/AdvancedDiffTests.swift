//
//  FileDiffTests.swift
//  ClaudeCodeUITests
//
//  Created on 1/30/2025.
//

import XCTest
@testable import ClaudeCodeCore

final class AdvancedDiffTests: XCTestCase {
  
  // MARK: - LLM Pattern Tests
  
  func testParseSingleSearchReplacePattern() throws {
    let pattern = """
    <<<<<<< SEARCH
    func oldFunction() {
      print("old")
    }
    =======
    func newFunction() {
      print("new")
    }
    >>>>>>> REPLACE
    """
    
    let fileContent = """
    func oldFunction() {
      print("old")
    }
    """
    
    let changes = try AdvancedDiff.parse(searchReplacePattern: pattern, for: fileContent)
    
    XCTAssertEqual(changes.count, 1)
    XCTAssertEqual(changes[0].search, """
    func oldFunction() {
      print("old")
    }
    """)
    XCTAssertEqual(changes[0].replace, """
    func newFunction() {
      print("new")
    }
    """)
  }
  
  func testParseMultipleSearchReplacePatterns() throws {
    let pattern = """
    <<<<<<< SEARCH
    Hello, world!
    =======
    Hello, universe!
    >>>>>>> REPLACE
    <<<<<<< SEARCH
    So lucky to be here!
    =======
    So grateful to be here!
    >>>>>>> REPLACE
    """
    
    let fileContent = """
    Hello, world!
    What a wonderful world!
    So lucky to be here!
    """
    
    let changes = try AdvancedDiff.parse(searchReplacePattern: pattern, for: fileContent)
    
    XCTAssertEqual(changes.count, 2)
    XCTAssertEqual(changes[0].search, "Hello, world!")
    XCTAssertEqual(changes[0].replace, "Hello, universe!")
    XCTAssertEqual(changes[1].search, "So lucky to be here!")
    XCTAssertEqual(changes[1].replace, "So grateful to be here!")
  }
  
  func testApplySearchReplaceToEmptyFile() throws {
    let fileContent = ""
    let pattern = """
    <<<<<<< SEARCH
    =======
    // New content
    >>>>>>> REPLACE
    """
    
    let newContent = try AdvancedDiff.apply(searchReplacePattern: pattern, to: fileContent)
    XCTAssertEqual(newContent, "// New content")
  }
  
  func testApplyMultipleChanges() throws {
    let fileContent = """
    Hello, world!
    What a wonderful world!
    So lucky to be here!
    """
    
    let changes = [
      SearchReplace(search: "Hello, world!", replace: "Hello, universe!"),
      SearchReplace(search: "So lucky to be here!", replace: "So grateful to be here!")
    ]
    
    let newContent = try AdvancedDiff.apply(changes: changes, to: fileContent)
    
    XCTAssertEqual(newContent, """
    Hello, universe!
    What a wonderful world!
    So grateful to be here!
    """)
  }
  
  func testSearchPatternNotFound() {
    let fileContent = "Hello, world!"
    let changes = [
      SearchReplace(search: "Goodbye, world!", replace: "Hello, universe!")
    ]
    
    XCTAssertThrowsError(try AdvancedDiff.apply(changes: changes, to: fileContent)) { error in
      guard case DiffError.searchPatternNotFound = error else {
        XCTFail("Expected searchPatternNotFound error")
        return
      }
    }
  }
  
  // MARK: - Empty Line Handling Tests
  
  func testEmptyLineTokenHandling() {
    let content = """
    Line 1
    
    Line 3
    """
    
    let formatted = content.formattedToApplyGitDiff
    XCTAssertTrue(formatted.contains("<l>"))
    
    let unformatted = formatted.unformattedFromApplyGitDiff
    XCTAssertEqual(unformatted, content)
  }
  
  func testSplitLines() {
    let content = """
    Line 1
    Line 2
    Line 3
    """
    
    let lines = content.splitLines()
    XCTAssertEqual(lines.count, 3)
    XCTAssertEqual(String(lines[0]), "Line 1\n")
    XCTAssertEqual(String(lines[1]), "Line 2\n")
    XCTAssertEqual(String(lines[2]), "Line 3")
  }
  
  // MARK: - isLLMDiff Tests
  
  func testIsLLMDiff() {
    let validDiff = """
    <<<<<<< SEARCH
    old
    =======
    new
    >>>>>>> REPLACE
    """
    
    XCTAssertTrue(AdvancedDiff.isLLMDiff(validDiff))
    
    let invalidDiff = """
    This is not a diff
    """
    
    XCTAssertFalse(AdvancedDiff.isLLMDiff(invalidDiff))
  }
  
  // MARK: - Edge Cases
  
  func testHandleTrailingNewlines() throws {
    // Test when search has trailing newline but replace doesn't
    let pattern = """
    <<<<<<< SEARCH
    old content
    =======
    new content
    >>>>>>> REPLACE
    """
    
    let changes = try FileDiff.parse(searchReplacePattern: pattern, for: "")
    XCTAssertEqual(changes[0].search, "old content")
    XCTAssertEqual(changes[0].replace, "new content")
  }
  
  func testReplaceWholeFile() throws {
    let fileContent = """
    Entire old content
    Multiple lines
    """
    
    let changes = [
      SearchReplace(
        search: fileContent,
        replace: "Completely new content"
      )
    ]
    
    let newContent = try AdvancedDiff.apply(changes: changes, to: fileContent)
    XCTAssertEqual(newContent, "Completely new content")
  }
}