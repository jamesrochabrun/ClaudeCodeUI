//
//  NotebookToolFormatter.swift
//  ClaudeCodeUI
//
//  Created on 1/10/2025.
//

import Foundation

/// Formatter for Jupyter Notebook tools (NotebookRead, NotebookEdit)
struct NotebookToolFormatter: ToolFormatterProtocol {
  private let codeFormatter = CodeFormatter()
  
  func formatOutput(_ output: String, tool: ToolType) -> (String, ToolDisplayFormatter.ToolContentFormatter.ContentType) {
    // Notebook cells are typically Python code
    let formatted = codeFormatter.formatCode(
      output,
      language: "python",
      filePath: nil,
      maxLines: 50
    )
    return (formatted, .markdown)
  }
  
  func formatArguments(_ arguments: String, tool: ToolType) -> String {
    if let jsonDict = arguments.toDictionary() {
      var filtered: [String: Any] = [:]
      
      // Show notebook path
      if let notebookPath = jsonDict["notebook_path"] as? String {
        filtered["notebook_path"] = URL(fileURLWithPath: notebookPath).lastPathComponent
      }
      
      // Show cell ID if present
      if let cellId = jsonDict["cell_id"] as? String {
        filtered["cell_id"] = cellId
      }
      
      // For edits, show truncated source
      if let newSource = jsonDict["new_source"] as? String {
        filtered["new_source"] = newSource.truncateIntelligently(to: 100) + "..."
      }
      
      if let cellType = jsonDict["cell_type"] as? String {
        filtered["cell_type"] = cellType
      }
      
      if let editMode = jsonDict["edit_mode"] as? String {
        filtered["edit_mode"] = editMode
      }
      
      if let data = try? JSONSerialization.data(withJSONObject: filtered, options: .prettyPrinted),
         let formatted = String(data: data, encoding: .utf8) {
        return formatted
      }
    }
    
    return arguments.formatJSON()
  }
  
  func extractKeyParameters(_ arguments: String, tool: ToolType) -> String? {
    guard let jsonDict = arguments.toDictionary() else {
      return nil
    }
    
    var params: [String] = []
    
    if let notebookPath = jsonDict["notebook_path"] as? String {
      params.append(URL(fileURLWithPath: notebookPath).lastPathComponent)
    }
    
    if let cellId = jsonDict["cell_id"] as? String {
      params.append("cell: \(cellId)")
    }
    
    return params.isEmpty ? nil : params.joined(separator: ", ")
  }
}
