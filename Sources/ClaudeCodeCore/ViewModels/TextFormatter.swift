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
    /// A table segment
    case table(_ table: TableElement)
    
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
      case .table(let table): table.id
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
    
    /// Returns the element as a TableElement if it is one, nil otherwise
    var asTable: TableElement? {
      if case .table(let table) = self {
        return table
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
  
  /// Whether we're currently parsing a table
  private var isParsingTable = false
  
  /// Buffer for accumulating table content
  private var tableBuffer = ""
  
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
  
  /// Processes unconsumed text to identify and extract code blocks and tables
  ///
  /// This method scans through the unconsumed text character by character,
  /// detecting triple backticks that mark code block boundaries, tables,
  /// and handling escape sequences.
  private func processUnconsumedText() {
    // Don't detect tables if we're in a code block or parsing a code block header
    let inCodeBlock = elements.last?.asCodeBlock != nil && !(elements.last?.asCodeBlock?.isComplete ?? true)
    
    // Check if we should auto-detect mermaid diagrams
    if !inCodeBlock && !isCodeBlockHeader && detectMermaidStart() {
      return
    }
    
    // First check if we should detect tables (but not if we're in a code block or processing header)
    if !inCodeBlock && !isCodeBlockHeader && detectTableStart() {
      return
    }
    
    // Continue with existing parsing for tables in progress
    if isParsingTable && !inCodeBlock && !isCodeBlockHeader {
      handleTableParsing()
      return
    }
    
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
    let pattern = "^([\\w\\-]+):(.*)$"
    if let regex = try? NSRegularExpression(pattern: pattern),
       let match = regex.firstMatch(in: header, range: NSRange(header.startIndex..., in: header)) {
      if let languageRange = Range(match.range(at: 1), in: header),
         let pathRange = Range(match.range(at: 2), in: header) {
        let language = String(header[languageRange])
        let path = String(header[pathRange])
        currentCodeBlock.language = language.lowercased()
        currentCodeBlock.filePath = path
      }
    } else if !header.isEmpty {
      // For now, assume it's a language if it's a single word, otherwise a path
      if header.contains("/") || (header.contains(".") && !header.lowercased().starts(with: "mermaid")) {
        currentCodeBlock.filePath = header
      } else {
        // Store the language as lowercase for consistent detection
        currentCodeBlock.language = header.lowercased()
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
          
        case .table(let table):
          if !table.isComplete {
            add(table: "\(tableBuffer)\(consumed)", isComplete: false, at: elements.count - 1)
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
  
  /// Adds or updates a table element
  /// - Parameters:
  ///   - table: The table content
  ///   - isComplete: Whether the table is complete
  ///   - idx: Optional index to update existing element (nil to append new)
  private func add(table: String, isComplete: Bool, at idx: Int? = nil) {
    let id = idx ?? elements.count
    if id == elements.count {
      elements.append(Element.table(.init(id: id, rawContent: table, isComplete: isComplete)))
    } else {
      let element = elements[id].asTable
      element?.set(rawContent: table, isComplete: isComplete)
    }
  }
  
  /// Detects if the unconsumed text starts with a mermaid diagram
  /// - Returns: true if a mermaid diagram was detected and started
  private func detectMermaidStart() -> Bool {
    // Don't detect mermaid inside code blocks
    if let lastElement = elements.last?.asCodeBlock, !lastElement.isComplete {
      return false
    }
    
    // Don't auto-detect if we already have triple backticks
    if unconsumed.hasPrefix("```") {
      return false
    }
    
    // Check for common mermaid diagram starters
    let mermaidPatterns = [
      "graph TD", "graph LR", "graph TB", "graph BT", "graph RL", "graph DT",
      "flowchart TD", "flowchart LR", "flowchart TB", "flowchart BT",
      "sequenceDiagram", "classDiagram", "stateDiagram", "erDiagram",
      "journey", "gantt", "pie", "gitGraph", "mindmap", "timeline",
      "quadrantChart", "requirementDiagram", "C4Context"
    ]
    
    // Look for mermaid pattern at the start of a line
    let lines = unconsumed.components(separatedBy: .newlines)
    guard !lines.isEmpty else { return false }
    
    // Check each line to see if it starts with a mermaid pattern
    for (lineIndex, line) in lines.enumerated() {
      let trimmedLine = line.trimmingCharacters(in: .whitespaces)
      
      for pattern in mermaidPatterns {
        if trimmedLine.hasPrefix(pattern) {
          // Found a mermaid diagram starting at this line!
          
          // Process any text before the mermaid diagram
          if lineIndex > 0 {
            let textBeforeMermaid = lines[0..<lineIndex].joined(separator: "\n")
            if !textBeforeMermaid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
              // Add text before mermaid
              if let text = elements.last?.asText {
                add(text: "\(text.text)\(textBeforeMermaid)\n", isComplete: true, at: elements.count - 1)
              } else {
                add(text: "\(textBeforeMermaid)\n", isComplete: true)
              }
              
              // Remove consumed text
              let consumedLength = textBeforeMermaid.count + 1 // +1 for newline
              if consumedLength <= unconsumed.count {
                unconsumed.removeFirst(consumedLength)
              }
            } else if lineIndex > 0 {
              // Remove empty lines before mermaid
              let emptyLinesLength = textBeforeMermaid.count + 1
              if emptyLinesLength <= unconsumed.count {
                unconsumed.removeFirst(emptyLinesLength)
              }
            }
          }
          
          // Now we need to find where the mermaid diagram ends
          // For now, let's collect all the mermaid content until we find a clear end
          // (empty line after substantive content, or end of unconsumed)
          var mermaidLines: [String] = []
          var foundEnd = false
          
          for i in lineIndex..<lines.count {
            let currentLine = lines[i]
            let trimmed = currentLine.trimmingCharacters(in: .whitespaces)
            
            if trimmed.isEmpty && !mermaidLines.isEmpty {
              // Empty line after content - end of mermaid
              foundEnd = true
              break
            } else if !trimmed.isEmpty {
              mermaidLines.append(currentLine)
            }
          }
          
          if !mermaidLines.isEmpty {
            let mermaidContent = mermaidLines.joined(separator: "\n")
            
            // Create a code block with the mermaid content
            add(code: mermaidContent, isComplete: foundEnd)
            if let currentCodeBlock = elements.last?.asCodeBlock {
              currentCodeBlock.language = "mermaid"
            }
            
            // Remove the consumed mermaid content from unconsumed
            let consumedLength = mermaidContent.count
            if consumedLength <= unconsumed.count {
              unconsumed.removeFirst(consumedLength)
              // Also remove trailing newline if we found the end
              if foundEnd && unconsumed.hasPrefix("\n") {
                unconsumed.removeFirst()
              }
            }
            
            return true
          }
        }
      }
    }
    
    return false
  }
  
  /// Detects if the unconsumed text starts with a table
  /// - Returns: true if a table was detected and started
  private func detectTableStart() -> Bool {
    // Don't detect tables inside code blocks
    if let lastElement = elements.last?.asCodeBlock, !lastElement.isComplete {
      return false
    }
    
    // Don't detect tables if we're about to start a code block
    if unconsumed.hasPrefix("```") {
      return false
    }
    
    // Look for table pattern in unconsumed text
    let lines = unconsumed.components(separatedBy: .newlines)
    
    // Need at least 2 lines to detect a table start
    for i in 0..<lines.count {
      let line = lines[i].trimmingCharacters(in: .whitespaces)
      
      // Check if this line looks like a table header
      if line.contains("|") && line.filter({ $0 == "|" }).count >= 2 {
        // Check if next line is a separator
        if i + 1 < lines.count {
          let nextLine = lines[i + 1].trimmingCharacters(in: .whitespaces)
          if nextLine.contains("|") && nextLine.contains("-") {
            // Found a table! Process any text before it
            let linesBeforeTable = lines[0..<i]
            if !linesBeforeTable.isEmpty {
              let textBeforeTable = linesBeforeTable.joined(separator: "\n")
              if !textBeforeTable.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Save text before the table
                if let text = elements.last?.asText {
                  add(text: "\(text.text)\(textBeforeTable)\n", isComplete: true, at: elements.count - 1)
                } else {
                  add(text: "\(textBeforeTable)\n", isComplete: true)
                }
                
                // Remove consumed text from unconsumed
                let consumedLength = textBeforeTable.count + (i > 0 ? 1 : 0) // +1 for newline
                if consumedLength <= unconsumed.count {
                  unconsumed.removeFirst(consumedLength)
                }
              } else if i > 0 {
                // Just remove the empty lines before table
                let emptyLinesLength = linesBeforeTable.joined(separator: "\n").count + 1
                if emptyLinesLength <= unconsumed.count {
                  unconsumed.removeFirst(emptyLinesLength)
                }
              }
            }
            
            // Start parsing the table
            isParsingTable = true
            tableBuffer = ""
            handleTableParsing()
            return true
          }
        }
      }
    }
    
    return false
  }
  
  /// Handles ongoing table parsing
  private func handleTableParsing() {
    let lines = unconsumed.components(separatedBy: .newlines)
    var tableEndIndex: Int? = nil
    var currentTableLines: [String] = []
    
    for (index, line) in lines.enumerated() {
      let trimmedLine = line.trimmingCharacters(in: .whitespaces)
      
      // Check if line is part of table
      if trimmedLine.contains("|") {
        // Count pipes to ensure it's a valid table row
        let pipeCount = trimmedLine.filter({ $0 == "|" }).count
        if pipeCount >= 2 || (index <= 1 && trimmedLine.contains("-")) {
          currentTableLines.append(line)
        } else if !currentTableLines.isEmpty {
          // Line with single pipe after table started - table ended
          tableEndIndex = index
          break
        }
      } else if !trimmedLine.isEmpty && !currentTableLines.isEmpty {
        // Non-empty line that doesn't contain pipes - table has ended
        tableEndIndex = index
        break
      } else if trimmedLine.isEmpty && currentTableLines.count > 2 {
        // Empty line after table content (with at least header and separator) - table has ended
        tableEndIndex = index
        break
      }
    }
    
    // If we found table content with at least header and separator
    if currentTableLines.count >= 2 {
      let tableContent = currentTableLines.joined(separator: "\n")
      tableBuffer = tableContent
      
      // Calculate how much to consume from unconsumed
      let linesToConsume = tableEndIndex ?? currentTableLines.count
      let consumedLines = lines.prefix(linesToConsume)
      let consumedText = consumedLines.joined(separator: "\n")
      
      // Remove consumed text from unconsumed
      if let range = unconsumed.range(of: consumedText) {
        unconsumed.removeSubrange(range)
        // Also remove the trailing newline if present
        if unconsumed.hasPrefix("\n") {
          unconsumed.removeFirst()
        }
      } else {
        // Fallback: remove by character count
        let charsToRemove = min(consumedText.count, unconsumed.count)
        unconsumed.removeFirst(charsToRemove)
        if unconsumed.hasPrefix("\n") {
          unconsumed.removeFirst()
        }
      }
      
      // Check if table is complete
      let isTableComplete = tableEndIndex != nil ||
      lines.count <= linesToConsume ||
      unconsumed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      
      // Add or update the table element
      if elements.last?.asTable != nil {
        add(table: tableBuffer, isComplete: isTableComplete, at: elements.count - 1)
      } else {
        add(table: tableBuffer, isComplete: isTableComplete)
      }
      
      if isTableComplete {
        isParsingTable = false
        tableBuffer = ""
        
        // Process any remaining unconsumed text
        if !unconsumed.isEmpty {
          processUnconsumedText()
        }
      }
    } else if currentTableLines.count == 1 {
      // Only one line found, might be incomplete table, keep buffering
      tableBuffer = currentTableLines[0]
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
