import AppKit
import Foundation

// MARK: - EditorState

public struct EditorState: Equatable, Sendable {

  // MARK: Lifecycle

  public init(
    element: AXUIElement,
    content: EditorInformation.SourceEditorContent,
    tabs: [String],
    activeTab: String?,
    activeTabURL: URL?,
    isFocussed: Bool
  ) {
    self.element = element
    self.content = content
    self.tabs = tabs
    self.activeTab = activeTab
    self.activeTabURL = activeTabURL
    self.isFocussed = isFocussed
  }

  // MARK: Public

  public let element: AXUIElement
  public let content: EditorInformation.SourceEditorContent
  public let tabs: [String]
  public let activeTab: String?
  public let activeTabURL: URL?
  public let isFocussed: Bool

}

// MARK: - EditorInformation

public enum EditorInformation {
  public struct LineAnnotation: Equatable, Sendable {
    public let type: String
    public let line: Int
    public let message: String
  }

  public struct SourceEditorContent: Equatable, Sendable {

    // MARK: Lifecycle

    public init(
      content: String,
      lines: [String],
      selection: CursorRange?,
      cursorPosition: CursorPosition,
      lineAnnotations: [String]
    ) {
      self.content = content
      self.lines = lines
      self.selection = selection
      self.cursorPosition = cursorPosition
      self.lineAnnotations = lineAnnotations.map(Self.parseLineAnnotation)
    }

    // MARK: Public

    /// The content of the source editor.
    public let content: String
    /// The content of the source editor in lines. Every line should ends with `\n`.
    public let lines: [String]
    /// The selection ranges of the source editor.
    public let selection: CursorRange?
    /// The cursor position of the source editor.
    public let cursorPosition: CursorPosition
    /// Line annotations of the source editor.
    public let lineAnnotations: [LineAnnotation]

    /// The content in the current selection.
    public var selectedContent: String? {
      if let range = selection {
        // Handle reversed selection
        let start: CursorPosition
        let end: CursorPosition

        let asc: Bool
        if range.start.line == range.end.line {
          if range.start.character == range.end.character {
            return nil
          }
          asc = range.start.character < range.end.character
        } else {
          asc = range.start.line < range.end.line
        }

        if asc {
          start = range.start
          end = range.end
        } else {
          start = range.end
          end = range.start
        }

        var selectedLines = lines[start.line...end.line]

        selectedLines.indices.last.map { selectedLines[$0] = String(selectedLines[$0].prefix(end.character)) }
        selectedLines.indices.first.map { selectedLines[$0] = String(selectedLines[$0].dropFirst(start.character)) }
        return selectedLines.joined()
      }
      return nil
    }

    // MARK: Internal

    /// Parse an annotation such as:
    /// Error Line 25: FileName.swift:25 Cannot convert Type
    /// Warning Line 8: Runtime Issue annotation
    static func parseLineAnnotation(_ annotation: String) -> LineAnnotation {
      if let match = annotation.wholeMatch(of: /(.*):(.*):([0-9]+)(.*)/), let line = Int(match.output.3) {
        // Matches "Error Line 25: FileName.swift:25 Cannot convert Type"
        let prefix = match.output.1
        let message = match.output.4
        let type = String(prefix.split(separator: " ").first ?? prefix)

        return LineAnnotation(
          type: type.trimmingCharacters(in: .whitespacesAndNewlines),
          line: line,
          message: message.trimmingCharacters(in: .whitespacesAndNewlines)
        )
      } else if let match = annotation.wholeMatch(of: /(.*)([0-9]+):(.*)/), let line = Int(match.output.2) {
        // Matches "Warning Line 8: Runtime Issue annotation"
        let prefix = match.output.1
        let message = match.output.3
        let type = String(prefix.split(separator: " ").first ?? prefix)

        return LineAnnotation(
          type: type.trimmingCharacters(in: .whitespacesAndNewlines),
          line: line,
          message: message.trimmingCharacters(in: .whitespacesAndNewlines)
        )
      } else {
        return .init(type: "", line: 0, message: annotation)
      }
    }
  }
}

// MARK: - CursorPosition

public struct CursorPosition: Equatable, Codable, Hashable, Sendable {
  public static let zero = CursorPosition(line: 0, character: 0)

  public let line: Int
  public let character: Int

  public init(line: Int, character: Int) {
    self.line = line
    self.character = character
  }

  public init(_ pair: (Int, Int)) {
    line = pair.0
    character = pair.1
  }
}

// MARK: Comparable

extension CursorPosition: Comparable {
  public static func <(lhs: CursorPosition, rhs: CursorPosition) -> Bool {
    if lhs.line == rhs.line {
      return lhs.character < rhs.character
    }

    return lhs.line < rhs.line
  }
}

extension CursorPosition {
  public static var outOfScope: CursorPosition { .init(line: -1, character: -1) }

  public var readableText: String {
    "[\(line + 1), \(character)]"
  }

  public var readableTextWithoutCharacter: String {
    "\(line + 1)"
  }
}

// MARK: - CursorRange

public struct CursorRange: Codable, Hashable, Sendable, Equatable, CustomStringConvertible {

  // MARK: Lifecycle

  public init(start: CursorPosition, end: CursorPosition) {
    self.start = start
    self.end = end
  }

  public init(startPair: (Int, Int), endPair: (Int, Int)) {
    start = CursorPosition(startPair)
    end = CursorPosition(endPair)
  }

  // MARK: Public

  public static let zero = CursorRange(start: .zero, end: .zero)

  public var start: CursorPosition
  public var end: CursorPosition

  public var isEmpty: Bool {
    start == end
  }

  public var isOneLine: Bool {
    start.line == end.line
  }

  /// The number of lines in the range.
  public var lineCount: Int {
    end.line - start.line + 1
  }

  public var description: String {
    "\(start.readableText) - \(end.readableText)"
  }

  /// The range for UI display purposes
  public var rangeDisplayText: String {
    if isOneLine {
      start.readableTextWithoutCharacter
    } else {
      "\(start.readableTextWithoutCharacter)-\(end.readableTextWithoutCharacter)"
    }
  }

  public func contains(_ position: CursorPosition) -> Bool {
    position >= start && position <= end
  }

  public func contains(_ range: CursorRange) -> Bool {
    range.start >= start && range.end <= end
  }

  public func strictlyContains(_ range: CursorRange) -> Bool {
    range.start > start && range.end < end
  }

}

extension CursorRange {
  public static var outOfScope: CursorRange { .init(start: .outOfScope, end: .outOfScope) }

  public static func cursor(_ position: CursorPosition) -> CursorRange {
    .init(start: position, end: position)
  }
}
