//
//  DiffExtensions.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 7/7/2025.
//

import Foundation
import SwiftUI

// MARK: - String Extensions

extension String {
  /// Splits a string into lines based on newline characters.
  ///
  /// This method preserves empty lines by setting `omittingEmptySubsequences` to `false`.
  /// It splits on any newline character (including `\n`, `\r`, and `\r\n`).
  ///
  /// - Returns: An array of substring representing each line in the original string.
  ///            Empty lines are preserved as empty subsequences.
  ///
  /// - Example:
  ///   ```swift
  ///   let text = "Line 1\nLine 2\n\nLine 4"
  ///   let lines = text.splitLines()
  ///   // Result: ["Line 1", "Line 2", "", "Line 4"]
  ///   ```
  func splitLines() -> [String.SubSequence] {
    split(omittingEmptySubsequences: false) { $0.isNewline }
  }
  
  /// Converts the string to UTF-8 encoded data.
  ///
  /// This property force-unwraps the result as UTF-8 encoding should always succeed
  /// for valid Swift strings.
  ///
  /// - Returns: The string encoded as UTF-8 data.
  var utf8Data: Data {
    data(using: .utf8)!
  }
  
  /// Formats the string for applying Git diff by adding special tokens to empty lines.
  ///
  /// This method adds `<l>` tokens to preserve empty lines when processing Git diffs.
  /// It handles both existing empty line tokens and actual empty lines in the text.
  ///
  /// - Returns: A string with empty lines marked with `<l>` tokens for Git diff processing.
  var formattedToApplyGitDiff: String {
    let emptyLineToken = "<l>"
    return replacingOccurrences(of: "\n\(emptyLineToken)", with: "\n\(emptyLineToken)\(emptyLineToken)")
      .replacingOccurrences(
        of: "(\n)(?=\n|$)",
        with: "$1\(emptyLineToken)",
        options: .regularExpression)
  }
  
  /// Formats an applied Git diff by removing empty line tokens from diff lines.
  ///
  /// This method removes `<l>` tokens from lines that start with diff markers
  /// (space, +, or -) to clean up the diff output after processing.
  ///
  /// - Returns: A string with empty line tokens removed from diff-marked lines.
  var formatAppliedGitDiff: String {
    let emptyLineToken = "<l>"
    return replacingOccurrences(of: "\n \(emptyLineToken)", with: "\n ")
      .replacingOccurrences(of: "\n+\(emptyLineToken)", with: "\n+")
      .replacingOccurrences(of: "\n-\(emptyLineToken)", with: "\n-")
  }
}

extension StringProtocol {
  /// Splits a string protocol into lines based on newline characters.
  ///
  /// This method preserves empty lines by setting `omittingEmptySubsequences` to `false`.
  /// It splits on any newline character (including `\n`, `\r`, and `\r\n`).
  ///
  /// - Returns: An array of subsequences representing each line in the original string.
  ///            Empty lines are preserved as empty subsequences.
  func splitLines() -> [SubSequence] {
    split(omittingEmptySubsequences: false) { $0.isNewline }
  }
  
  /// Extracts a subsequence from the string protocol based on integer indices.
  ///
  /// This method provides a convenient way to extract a substring using integer indices
  /// instead of String.Index values.
  ///
  /// - Parameter range: A range of integer indices specifying the substring to extract.
  /// - Returns: A subsequence of the string from the given range.
  ///
  /// - Example:
  ///   ```swift
  ///   let text = "Hello, World!"
  ///   let sub = text.substring(0..<5)
  ///   // Result: "Hello"
  ///   ```
  func substring(_ range: Range<Int>) -> SubSequence {
    self[index(startIndex, offsetBy: range.lowerBound)..<index(startIndex, offsetBy: range.upperBound)]
  }
}

// MARK: - Range Extensions

extension Range where Bound == Int {
  /// Clamps the range to fit within the specified limits.
  ///
  /// This method ensures that the range stays within the specified boundaries,
  /// adjusting both the lower and upper bounds as necessary. It also prevents
  /// creating invalid ranges where the lower bound would exceed the upper bound.
  ///
  /// - Parameter limits: The range representing the minimum and maximum allowed values.
  /// - Returns: A new range that fits within the specified limits.
  ///
  /// - Example:
  ///   ```swift
  ///   let range = 5..<15
  ///   let clamped = range.clamped(to: 0..<10)
  ///   // Result: 5..<10
  ///   ```
  func clamped(to limits: Range<Int>) -> Range<Int> {
    let lowerBound = Swift.max(self.lowerBound, limits.lowerBound)
    let upperBound = Swift.min(self.upperBound, limits.upperBound)
    // Ensure we don't create an invalid range where lower > upper
    let clampedLower = Swift.min(lowerBound, upperBound)
    return clampedLower..<upperBound
  }
  
  /// Returns a string identifier for the range.
  ///
  /// This property creates a unique string representation of the range
  /// using the format "lowerBound-upperBound".
  ///
  /// - Returns: A string identifier in the format "lowerBound-upperBound".
  ///
  /// - Example:
  ///   ```swift
  ///   let range = 5..<10
  ///   let identifier = range.id
  ///   // Result: "5-10"
  ///   ```
  var id: String {
    "\(lowerBound)-\(upperBound)"
  }
}

// MARK: - Collection Extensions

extension Collection {
  /// Safely accesses the element at the specified index.
  ///
  /// This subscript returns `nil` if the index is out of bounds instead of
  /// causing a runtime error. It provides a safe way to access collection elements.
  ///
  /// - Parameter index: The index of the element to access.
  /// - Returns: The element at the specified index if it exists, otherwise `nil`.
  ///
  /// - Example:
  ///   ```swift
  ///   let array = [1, 2, 3]
  ///   let value = array[safe: 5]
  ///   // Result: nil (instead of runtime error)
  ///   ```
  subscript(safe index: Index) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}

// MARK: - AttributedString Extensions

extension AttributedString {
  /// Converts an integer range to an AttributedString index range.
  ///
  /// This method provides a convenient way to work with AttributedString ranges
  /// using integer indices instead of AttributedString.Index values.
  ///
  /// - Parameter range: A range of integer indices to convert.
  /// - Returns: The corresponding AttributedString index range if valid, otherwise `nil`.
  ///
  /// - Note: Returns `nil` if the range is invalid or out of bounds.
  ///
  /// - Example:
  ///   ```swift
  ///   let attrString = AttributedString("Hello, World!")
  ///   if let indexRange = attrString.range(0..<5) {
  ///     // Use indexRange to manipulate the attributed string
  ///   }
  ///   ```
  func range(_ range: Range<Int>) -> Range<AttributedString.Index>? {
    guard 0 <= range.lowerBound, range.lowerBound <= range.upperBound, range.upperBound <= characters.count else {
      return nil
    }
    
    let startIndex = index(startIndex, offsetByCharacters: range.lowerBound)
    let endIndex = index(self.startIndex, offsetByCharacters: range.upperBound)
    
    return startIndex..<endIndex
  }
}

// MARK: - FormattedLineChange Array Extensions

extension [FormattedLineChange] {
  /// Identifies sections of the array that contain changes with context lines.
  ///
  /// This method groups changed lines into sections, including a specified number of
  /// context lines before and after each change. It merges sections that are close
  /// together (within `2 * minSeparation` lines).
  ///
  /// - Parameter minSeparation: The minimum number of context lines to include around changes.
  /// - Returns: An array of ranges representing sections that contain changes with context.
  ///
  /// - Note: If no changes are found and the array is not empty, returns the entire array as one range.
  ///
  /// - Example:
  ///   ```swift
  ///   let changes: [FormattedLineChange] = [...]
  ///   let sections = changes.changedSection(minSeparation: 3)
  ///   // Returns ranges of changed sections with 3 lines of context
  ///   ```
  func changedSection(minSeparation: Int) -> [Range<Int>] {
    var partialDiffRanges = [Range<Int>]()
    
    // Handle empty array
    guard !isEmpty else { return [] }
    
    var l = 0
    var rangeStart: Int?
    var lastChangedLine: Int?
    
    while l < count {
      if self[l].change.type != .unchanged {
        lastChangedLine = l
        rangeStart = rangeStart ?? Swift.max(0, l - minSeparation)
      } else if let start = rangeStart, let end = lastChangedLine,
                l - end > 2 * minSeparation {
        partialDiffRanges.append(start..<l - minSeparation)
        rangeStart = nil
        lastChangedLine = nil
      }
      l += 1
    }
    
    if let rangeStart = rangeStart {
      partialDiffRanges.append(rangeStart..<count)
    }
    
    // If no ranges were found, return the entire array as one range
    if partialDiffRanges.isEmpty && !isEmpty {
      partialDiffRanges.append(0..<count)
    }
    
    return partialDiffRanges.map { $0.clamped(to: 0..<count) }
  }
  
  func continousChanges(in range: Range<Int>) -> [Range<Int>] {
    var changes = [Range<Int>]()
    var start = range.lowerBound
    
    while start < range.upperBound {
      // Move to next change
      while start < range.upperBound && self[start].change.type == .unchanged {
        start += 1
      }
      if start == range.upperBound {
        break
      }
      
      var end = start
      // Move to next unchanged
      while end < range.upperBound && self[end].change.type != .unchanged {
        end += 1
      }
      changes.append(start..<end)
      
      if end == range.upperBound {
        break
      }
      start = end + 1
    }
    
    return changes
  }
}

// MARK: - Color Extensions

extension ColorScheme {
  var xcodeEditorBackground: Color {
    self == .dark ? Color(red: 41.0 / 255, green: 42.0 / 255, blue: 48.0 / 255) : .white
  }
  
  var addedLineDiffBackground: Color {
    self == .dark
    ? Color(red: 18 / 255, green: 58 / 255, blue: 27 / 255)
    : Color(red: 230 / 255, green: 255 / 255, blue: 237 / 255)
  }
  
  var removedLineDiffBackground: Color {
    self == .dark
    ? Color(red: 69 / 255, green: 12 / 255, blue: 15 / 255)
    : Color(red: 255 / 255, green: 238 / 255, blue: 240 / 255)
  }
}
