//
//  DiffTypes.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 7/7/2025.
//

import Foundation
import SwiftUI

// MARK: - Core Types

public enum DiffContentType: String, Sendable, Codable {
    case removed
    case added
    case unchanged
}

public struct LineChange: Sendable, Codable {
    public let characterRange: Range<Int>
    public let lineOffset: Int
    public let content: String
    public let type: DiffContentType
    
    public init(_ lineOffset: Int, _ characterRange: Range<Int>, _ content: String, _ type: DiffContentType) {
        self.lineOffset = lineOffset
        self.characterRange = characterRange
        self.content = content
        self.type = type
    }
}

public struct FormattedLineChange: Sendable {
    public let formattedContent: AttributedString
    public let change: LineChange
    
    public init(formattedContent: AttributedString, change: LineChange) {
        self.formattedContent = formattedContent
        self.change = change
    }
}

public struct FormattedFileChange: Sendable {
    public let changes: [FormattedLineChange]
    
    public init(changes: [FormattedLineChange]) {
        self.changes = changes
    }
}

// MARK: - FileDiff Namespace

public enum FileDiff { }