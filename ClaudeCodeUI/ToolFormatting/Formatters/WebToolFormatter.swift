//
//  WebToolFormatter.swift
//  ClaudeCodeUI
//
//  Created on 1/10/2025.
//

import Foundation

/// Formatter for web-related tools (WebFetch, WebSearch)
struct WebToolFormatter: ToolFormatterProtocol {
  
  func formatOutput(_ output: String, tool: ToolType) -> (String, ToolDisplayFormatter.ToolContentFormatter.ContentType) {
    // Web content is usually already well-formatted markdown
    // Just ensure it's not too long
    let trimmed = output.limitToLines(100, maxCharacters: 5000)
    return (trimmed, .markdown)
  }
  
  func formatArguments(_ arguments: String, tool: ToolType) -> String {
    if let jsonDict = arguments.toDictionary() {
      var filtered: [String: Any] = [:]
      
      switch tool.identifier {
      case "WebFetch":
        if let url = jsonDict["url"] as? String {
          filtered["url"] = url
        }
        if let prompt = jsonDict["prompt"] as? String {
          filtered["prompt"] = prompt.truncateIntelligently(to: 100)
        }
        
      case "WebSearch":
        if let query = jsonDict["query"] as? String {
          filtered["query"] = query
        }
        if let allowedDomains = jsonDict["allowed_domains"] as? [String], !allowedDomains.isEmpty {
          filtered["allowed_domains"] = allowedDomains
        }
        if let blockedDomains = jsonDict["blocked_domains"] as? [String], !blockedDomains.isEmpty {
          filtered["blocked_domains"] = blockedDomains
        }
        
      default:
        break
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
    
    switch tool.identifier {
    case "WebFetch":
      if let url = jsonDict["url"] as? String {
        // Show just the domain for brevity
        if let host = URL(string: url)?.host {
          return host
        }
        return url.truncateIntelligently(to: 40)
      }
      
    case "WebSearch":
      if let query = jsonDict["query"] as? String {
        return query.truncateIntelligently(to: 40)
      }
      
    default:
      break
    }
    
    return nil
  }
}
