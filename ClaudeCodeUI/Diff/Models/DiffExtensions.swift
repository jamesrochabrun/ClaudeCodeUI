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
    func splitLines() -> [String.SubSequence] {
        split(omittingEmptySubsequences: false) { $0.isNewline }
    }
    
    var utf8Data: Data {
        data(using: .utf8)!
    }
    
    var formattedToApplyGitDiff: String {
        let emptyLineToken = "<l>"
        return replacingOccurrences(of: "\n\(emptyLineToken)", with: "\n\(emptyLineToken)\(emptyLineToken)")
            .replacingOccurrences(
                of: "(\n)(?=\n|$)",
                with: "$1\(emptyLineToken)",
                options: .regularExpression)
    }
    
    var formatAppliedGitDiff: String {
        let emptyLineToken = "<l>"
        return replacingOccurrences(of: "\n \(emptyLineToken)", with: "\n ")
            .replacingOccurrences(of: "\n+\(emptyLineToken)", with: "\n+")
            .replacingOccurrences(of: "\n-\(emptyLineToken)", with: "\n-")
    }
}

extension StringProtocol {
    func splitLines() -> [SubSequence] {
        split(omittingEmptySubsequences: false) { $0.isNewline }
    }
    
    func substring(_ range: Range<Int>) -> SubSequence {
        self[index(startIndex, offsetBy: range.lowerBound)..<index(startIndex, offsetBy: range.upperBound)]
    }
}

// MARK: - Range Extensions

extension Range where Bound == Int {
    func clamped(to limits: Range<Int>) -> Range<Int> {
        let lowerBound = Swift.max(self.lowerBound, limits.lowerBound)
        let upperBound = Swift.min(self.upperBound, limits.upperBound)
        return Swift.max(lowerBound, upperBound)..<upperBound
    }
    
    var id: String {
        "\(lowerBound)-\(upperBound)"
    }
}

// MARK: - Collection Extensions

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - AttributedString Extensions

extension AttributedString {
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
    func changedSection(minSeparation: Int) -> [Range<Int>] {
        var partialDiffRanges = [Range<Int>]()
        
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