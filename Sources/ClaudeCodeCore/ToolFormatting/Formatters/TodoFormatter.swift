//
//  TodoFormatter.swift
//  ClaudeCodeUI
//
//  Created on 1/9/2025.
//

import Foundation

/// Specialized formatter for todo list content
public struct TodoFormatter: ToolFormatterProtocol {
  
  public struct Todo: Codable {
    let content: String
    let id: String
    let priority: String
    let status: String
  }
  
  public init() {}
  
  // MARK: - ToolFormatterProtocol
  
  public func formatOutput(_ output: String, tool: ToolType) -> (String, ToolDisplayFormatter.ToolContentFormatter.ContentType) {
    // Try to parse and format as todos
    if let formattedTodos = parseAndFormatTodos(from: output) {
      return (formattedTodos, .todos)
    }
    
    // Fallback to raw output
    return (output, .todos)
  }
  
  // Uses default implementations for formatArguments and extractKeyParameters
  
  /// Formats todos as a markdown checklist with priority indicators
  public func formatTodosAsMarkdown(todos: [Todo]) -> String {
    guard !todos.isEmpty else {
      return "No todos"
    }
    
    var markdown = ""
    
    // Group by priority
    let grouped = Dictionary(grouping: todos) { $0.priority }
    let priorities = ["high", "medium", "low"]
    
    for priority in priorities {
      guard let todosForPriority = grouped[priority], !todosForPriority.isEmpty else {
        continue
      }
      
      // Add priority header
      let priorityEmoji = priorityEmoji(for: priority)
      markdown += "\n\(priorityEmoji) **\(priority.capitalized) Priority**\n\n"
      
      // Add todos
      for todo in todosForPriority {
        let checkbox = todo.status == "completed" ? "[x]" : "[ ]"
        let text = todo.status == "completed" ? "~~\(todo.content)~~" : todo.content
        markdown += "- \(checkbox) \(text)\n"
      }
    }
    
    // Add summary
    let completed = todos.filter { $0.status == "completed" }.count
    let total = todos.count
    let percentage = total > 0 ? Int((Double(completed) / Double(total)) * 100) : 0
    
    markdown += "\n---\n"
    markdown += "📊 **Progress**: \(completed)/\(total) completed (\(percentage)%)"
    
    return markdown.trimmingCharacters(in: .whitespacesAndNewlines)
  }
  
  /// Parses JSON string and formats as todos
  public func parseAndFormatTodos(from jsonString: String) -> String? {
    guard let jsonData = jsonString.data(using: .utf8) else { return nil }
    
    do {
      let todos = try JSONDecoder().decode([Todo].self, from: jsonData)
      return formatTodosAsMarkdown(todos: todos)
    } catch {
      // Try alternative format (array of dictionaries)
      return parseAlternativeFormat(jsonString)
    }
  }
  
  /// Creates a compact summary for headers
  public func createTodoSummary(from jsonString: String) -> String {
    guard let jsonData = jsonString.data(using: .utf8),
          let todos = try? JSONDecoder().decode([Todo].self, from: jsonData) else {
      return "todos"
    }
    
    let completed = todos.filter { $0.status == "completed" }.count
    let total = todos.count
    
    if total == 0 {
      return "empty"
    } else if completed == total {
      return "✅ all done"
    } else {
      return "\(completed)/\(total) done"
    }
  }
  
  // MARK: - Private Helpers
  
  private func priorityEmoji(for priority: String) -> String {
    switch priority.lowercased() {
    case "high":
      return "🔴"
    case "medium":
      return "🟡"
    case "low":
      return "🟢"
    default:
      return "⚪"
    }
  }
  
  private func parseAlternativeFormat(_ jsonString: String) -> String? {
    guard let data = jsonString.data(using: .utf8),
          let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
      return nil
    }
    
    var todos: [Todo] = []
    
    for dict in jsonArray {
      guard let content = dict["content"] as? String ?? dict["description"] as? String ?? dict["task"] as? String,
            let id = dict["id"] as? String else {
        continue
      }
      
      let priority = dict["priority"] as? String ?? "medium"
      let status = dict["status"] as? String ?? "pending"
      
      todos.append(Todo(content: content, id: id, priority: priority, status: status))
    }
    
    return todos.isEmpty ? nil : formatTodosAsMarkdown(todos: todos)
  }
}
