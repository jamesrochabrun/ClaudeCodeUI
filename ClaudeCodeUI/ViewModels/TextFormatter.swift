import Foundation
import Observation

/// A text formatter that parses streaming text content and identifies code blocks.
///
/// `TextFormatter` is designed to handle incremental text updates (deltas) from streaming
/// responses, automatically detecting and extracting code blocks marked with triple backticks (```).
/// It maintains a structured representation of the content as alternating text and code block elements.
///
/// ## Features
/// - Incremental text processing for streaming content
/// - Automatic code block detection and extraction
/// - Language and file path parsing from code block headers
/// - Escape character handling for backticks
/// - Maintains both raw text and structured elements
///
/// ## Usage
/// ```swift
/// let formatter = TextFormatter(projectRoot: projectURL)
/// formatter.ingest(delta: "Here's some code:\n```swift")
/// formatter.ingest(delta: "\nprint(\"Hello\")\n```")
/// ```
@Observable
@MainActor
final class TextFormatter {
  
  // MARK: - Nested Types
  
  /// Represents a parsed element in the formatted text
  enum Element: Identifiable {
    /// A text segment
    case text(_ text: TextElement)
    /// A code block segment
    case codeBlock(_ code: CodeBlockElement)
    
    /// Represents a text element within the formatted content
    @Observable
    @MainActor
    class TextElement {
      /// Initializes a text element
      /// - Parameters:
      ///   - text: The text content
      ///   - isComplete: Whether this text element is complete
      ///   - id: Unique identifier for the element
      init(text: String, isComplete: Bool, id: Int) {
        self.id = id
        _text = text.trimmed(isComplete: isComplete)
        self.isComplete = isComplete
      }
      
      /// Unique identifier for this element
      let id: Int
      
      /// Whether this text element has finished streaming
      var isComplete: Bool
      
      /// The text content, automatically trimmed based on completion status
      var text: String {
        get { _text }
        set { _text = newValue.trimmed(isComplete: isComplete) }
      }
      
      /// Internal storage for the text content
      private var _text: String
    }
    
    /// The unique identifier for this element
    var id: Int {
      switch self {
      case .text(let text): text.id
      case .codeBlock(let code): code.id
      }
    }
    
    /// Returns the element as a TextElement if it is one, nil otherwise
    var asText: TextElement? {
      if case .text(let text) = self {
        return text
      }
      return nil
    }
    
    /// Returns the element as a CodeBlockElement if it is one, nil otherwise
    var asCodeBlock: CodeBlockElement? {
      if case .codeBlock(let code) = self {
        return code
      }
      return nil
    }
  }
  
  // MARK: - Initialization
  
  /// Initializes a new TextFormatter
  /// - Parameter projectRoot: The project root URL for resolving relative file paths in code blocks
  init(projectRoot: URL?) {
    self.projectRoot = projectRoot
    text = ""
    deltas = []
  }
  
  // MARK: - Public Properties
  
  /// The complete accumulated text from all deltas
  private(set) var text: String
  
  /// The parsed elements (text and code blocks) from the formatted content
  private(set) var elements: [Element] = []
  
  /// All delta strings that have been processed
  private(set) var deltas: [String]
  
  /// The project root directory for resolving relative paths
  let projectRoot: URL?
  
  // MARK: - Private Properties
  
  /// Text that has been received but not yet fully processed
  private var unconsumed = ""
  
  /// Whether we're currently in an escape sequence (backslash before character)
  private var isEscaping = false
  
  /// Whether we're currently parsing a code block header (language/filepath)
  private var isCodeBlockHeader = false
  
  // MARK: - Public Methods
  
  /// Synchronizes with a list of deltas, processing any new ones
  /// - Parameter deltas: The complete list of deltas to catch up to
  func catchUp(deltas: [String]) {
    guard deltas.count > self.deltas.count else { return }
    for delta in deltas.suffix(from: self.deltas.count) {
      ingest(delta: delta)
    }
    self.deltas = deltas
  }
  
  /// Processes a new delta (incremental update) of text
  /// - Parameter delta: The new text fragment to process
  /// 
  /// This method accumulates the delta and processes it to identify
  /// code blocks and update the elements array accordingly.
  func ingest(delta: String) {
    deltas.append(delta)
    text = text + delta
    unconsumed = "\(unconsumed)\(delta)"
    processUnconsumedText()
  }
  
  // MARK: - Private Methods
  
  /// Processes unconsumed text to identify and extract code blocks
  /// 
  /// This method scans through the unconsumed text character by character,
  /// detecting triple backticks that mark code block boundaries and handling
  /// escape sequences.
  private func processUnconsumedText() {
    var backtickCount = 0
    var i = 0
    var canConsummedUntil = 0
    
    for c in unconsumed {
      i += 1
      if handleBackticks(c: c, i: &i, backtickCount: &backtickCount, canConsummedUntil: &canConsummedUntil) { continue }
      backtickCount = 0
      if handleEscaping(c: c, backtickCount: &backtickCount) { continue }
      isEscaping = false
      if c == "\n", isCodeBlockHeader {
        handleCodeBlockHeader(i: &i, canConsummedUntil: &canConsummedUntil)
      }
      if isCodeBlockHeader {
        continue
      }
      if c != " ", c != "\n", c != "\r", c != "\t" {
        canConsummedUntil = i
      }
    }
    
    consumeUntil(canConsummedUntil: canConsummedUntil)
  }
  
  /// Handles escape character processing
  /// - Parameters:
  ///   - c: The current character
  ///   - backtickCount: Current count of consecutive backticks (reset on escape)
  /// - Returns: true if the character was an escape character
  private func handleEscaping(c: Character, backtickCount: inout Int) -> Bool {
    guard c == #"\"# else { return false }
    isEscaping = !isEscaping
    backtickCount = 0
    return true
  }
  
  /// Handles backtick processing for code block detection
  /// - Parameters:
  ///   - c: The current character
  ///   - i: Current position in unconsumed text
  ///   - backtickCount: Count of consecutive backticks
  ///   - canConsummedUntil: Position up to which text can be consumed
  /// - Returns: true if the character was a backtick
  private func handleBackticks(c: Character, i: inout Int, backtickCount: inout Int, canConsummedUntil: inout Int) -> Bool {
    guard c == "`" else { return false }
    guard !isEscaping else {
      isEscaping = false
      return true
    }
    
    backtickCount += 1
    if backtickCount == 3 {
      backtickCount = 0
      if let codeBlock = elements.last?.asCodeBlock, !codeBlock.isComplete {
        // Close the code block
        var newCode = unconsumed.prefix(i)
        unconsumed.removeFirst(i)
        i = 0
        canConsummedUntil = 0
        newCode.removeLast(3) // Remove ```
        add(code: "\(codeBlock.rawContent)\(newCode)", isComplete: true, at: elements.count - 1)
      } else {
        // Create a new code block
        var newText = unconsumed.prefix(i)
        unconsumed.removeFirst(i)
        i = 0
        canConsummedUntil = 0
        newText.removeLast(3) // Remove ```
        
        if let text = elements.last?.asText {
          add(text: "\(text.text)\(newText)", isComplete: true, at: elements.count - 1)
        } else {
          if !newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            add(text: "\(newText)", isComplete: true)
          }
        }
        add(code: "", isComplete: false)
        isCodeBlockHeader = true
      }
    }
    return true
  }
  
  /// Parses and processes a code block header line
  /// - Parameters:
  ///   - i: Current position in unconsumed text (reset after processing)
  ///   - canConsummedUntil: Position up to which text can be consumed (reset after processing)
  /// 
  /// The header format can be:
  /// - Just a language: `swift`
  /// - Language and file path: `swift:Sources/MyFile.swift`
  /// - Just a file path: `Sources/MyFile.swift`
  private func handleCodeBlockHeader(i: inout Int, canConsummedUntil: inout Int) {
    let header = unconsumed.prefix(i).trimmingCharacters(in: .whitespacesAndNewlines)
    isCodeBlockHeader = false
    unconsumed.removeFirst(i)
    i = 0
    canConsummedUntil = 0
    
    guard let currentCodeBlock = elements.last?.asCodeBlock else {
      assertionFailure("No code block found when parsing code block header")
      return
    }
    
    // Parse language and file path from header
    // Format: language:filepath or just language
    if let match = header.firstMatch(of: /^(?<language>\w+):(?<path>.*)$/) {
      let language = match.output.language
      let path = match.output.path
      currentCodeBlock.language = String(language)
      currentCodeBlock.filePath = String(path)
    } else if !header.isEmpty {
      // For now, assume it's a language if it's a single word, otherwise a path
      if header.contains("/") || header.contains(".") {
        currentCodeBlock.filePath = header
      } else {
        currentCodeBlock.language = header
      }
    }
  }
  
  /// Consumes text up to the specified position and adds it to the appropriate element
  /// - Parameter canConsummedUntil: The position up to which text should be consumed
  /// 
  /// This method moves text from the unconsumed buffer to the current element
  /// (either extending the last element or creating a new one).
  private func consumeUntil(canConsummedUntil: Int) {
    if canConsummedUntil > 0 {
      let consumed = unconsumed.prefix(canConsummedUntil)
      unconsumed.removeFirst(canConsummedUntil)
      
      if let lastElement = elements.last {
        switch lastElement {
        case .text(let text):
          add(text: "\(text.text)\(consumed)", isComplete: false, at: elements.count - 1)
          return
          
        case .codeBlock(let codeBlock):
          if !codeBlock.isComplete {
            add(code: "\(codeBlock.rawContent)\(consumed)", isComplete: false, at: elements.count - 1)
            return
          }
        }
      }
      
      if !consumed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        add(text: "\(consumed)", isComplete: false)
      }
    }
  }
  
  /// Adds or updates a text element
  /// - Parameters:
  ///   - text: The text content
  ///   - isComplete: Whether the text element is complete
  ///   - idx: Optional index to update existing element (nil to append new)
  private func add(text: String, isComplete: Bool, at idx: Int? = nil) {
    let id = idx ?? elements.count
    if id == elements.count {
      elements.append(Element.text(.init(text: text, isComplete: isComplete, id: id)))
    } else {
      let element = elements[id].asText
      element?.isComplete = isComplete
      element?.text = text
    }
  }
  
  /// Adds or updates a code block element
  /// - Parameters:
  ///   - code: The code content
  ///   - isComplete: Whether the code block is complete
  ///   - idx: Optional index to update existing element (nil to append new)
  private func add(code: String, isComplete: Bool, at idx: Int? = nil) {
    let id = idx ?? elements.count
    if id == elements.count {
      elements.append(Element.codeBlock(.init(projectRoot: projectRoot, rawContent: code, isComplete: isComplete, id: id)))
    } else {
      let element = elements[id].asCodeBlock
      element?.set(rawContent: code, isComplete: isComplete)
    }
  }
}

// MARK: - String Extension

extension String {
  /// Trims whitespace based on completion status
  /// - Parameter isComplete: If true, trims both leading and trailing whitespace.
  ///                        If false, only trims leading whitespace.
  /// - Returns: The trimmed string
  func trimmed(isComplete: Bool) -> String {
    isComplete
    ? trimmingCharacters(in: .whitespacesAndNewlines)
    : trimmingLeadingCharacters(in: .whitespacesAndNewlines)
  }
  
  /// Removes leading characters that match the given character set
  /// - Parameter characterSet: The set of characters to trim from the beginning
  /// - Returns: String with leading characters removed
  private func trimmingLeadingCharacters(in characterSet: CharacterSet) -> String {
    guard let index = firstIndex(where: { !CharacterSet(charactersIn: String($0)).isSubset(of: characterSet) }) else {
      return self
    }
    return String(self[index...])
  }
}
