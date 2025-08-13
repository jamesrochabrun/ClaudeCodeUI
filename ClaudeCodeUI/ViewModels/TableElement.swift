import Foundation
import Observation

@Observable
@MainActor
final class TableElement {
  
  let id: Int
  var headers: [String] = []
  var rows: [[String]] = []
  var alignments: [TableAlignment] = []
  var isComplete: Bool = false
  
  private var rawContent: String = ""
  
  enum TableAlignment {
    case left
    case center
    case right
    
    init(from separator: String) {
      let trimmed = separator.trimmingCharacters(in: .whitespaces)
      if trimmed.hasPrefix(":") && trimmed.hasSuffix(":") {
        self = .center
      } else if trimmed.hasSuffix(":") {
        self = .right
      } else {
        self = .left
      }
    }
  }
  
  init(id: Int, rawContent: String = "", isComplete: Bool = false) {
    self.id = id
    self.rawContent = rawContent
    self.isComplete = isComplete
    parseTable()
  }
  
  func set(rawContent: String, isComplete: Bool) {
    self.rawContent = rawContent
    self.isComplete = isComplete
    parseTable()
  }
  
  var copyableContent: String {
    var result = headers.joined(separator: "\t") + "\n"
    for row in rows {
      result += row.joined(separator: "\t") + "\n"
    }
    return result.trimmingCharacters(in: .whitespacesAndNewlines)
  }
  
  var csvContent: String {
    var result = headers.map { escapeCSV($0) }.joined(separator: ",") + "\n"
    for row in rows {
      result += row.map { escapeCSV($0) }.joined(separator: ",") + "\n"
    }
    return result.trimmingCharacters(in: .whitespacesAndNewlines)
  }
  
  private func escapeCSV(_ value: String) -> String {
    if value.contains(",") || value.contains("\"") || value.contains("\n") {
      return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
    return value
  }
  
  private func parseTable() {
    let lines = rawContent.components(separatedBy: .newlines)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    
    guard lines.count >= 2 else { return }
    
    headers = parseRow(lines[0])
    
    if lines.count > 1 && lines[1].contains("-") {
      let separators = lines[1]
        .split(separator: "|")
        .map { String($0).trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
      
      alignments = separators.map { TableAlignment(from: $0) }
      
      rows = lines.dropFirst(2).map { parseRow($0) }
    } else {
      alignments = Array(repeating: .left, count: headers.count)
      rows = lines.dropFirst().map { parseRow($0) }
    }
    
    let columnCount = headers.count
    for i in 0..<rows.count {
      while rows[i].count < columnCount {
        rows[i].append("")
      }
      if rows[i].count > columnCount {
        rows[i] = Array(rows[i].prefix(columnCount))
      }
    }
  }
  
  private func parseRow(_ line: String) -> [String] {
    var row = line
      .split(separator: "|")
      .map { String($0).trimmingCharacters(in: .whitespaces) }
    
    if row.first?.isEmpty == true {
      row.removeFirst()
    }
    if row.last?.isEmpty == true {
      row.removeLast()
    }
    
    return row
  }
}
