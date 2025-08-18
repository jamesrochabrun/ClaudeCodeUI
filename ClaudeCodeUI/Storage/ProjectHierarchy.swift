//
//  ProjectHierarchy.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 8/18/2025.
//

import Foundation

/// Represents a project or sub-project with its sessions
public struct ProjectNode: Identifiable {
  public let id: String // The project path
  public let name: String // Display name (last path component)
  public let fullPath: String // Full decoded path
  public let sessions: [StoredSession]
  public var children: [ProjectNode]
  public let depth: Int // Nesting level for UI indentation
  
  /// Whether this node has any sessions (including children)
  public var hasAnySessions: Bool {
    !sessions.isEmpty || children.contains { $0.hasAnySessions }
  }
  
  /// Total session count including children
  public var totalSessionCount: Int {
    sessions.count + children.reduce(0) { $0 + $1.totalSessionCount }
  }
  
  /// Most recent session date (including children)
  public var mostRecentSessionDate: Date? {
    let allDates = sessions.map { $0.lastAccessedAt } +
    children.compactMap { $0.mostRecentSessionDate }
    return allDates.max()
  }
  
  public init(id: String, name: String, fullPath: String, sessions: [StoredSession], children: [ProjectNode] = [], depth: Int = 0) {
    self.id = id
    self.name = name
    self.fullPath = fullPath
    self.sessions = sessions
    self.children = children
    self.depth = depth
  }
}

/// Builds a hierarchical tree from flat project list
public struct ProjectHierarchyBuilder {
  
  /// Decodes Claude's project path encoding (dash-separated)
  /// Example: "-Users-jamesrochabrun-Desktop-git-ClaudeCodeUI" -> "/Users/jamesrochabrun/Desktop/git/ClaudeCodeUI"
  static func decodePath(_ encodedPath: String) -> String {
    // Remove leading dash and replace dashes with slashes
    let path = encodedPath.replacingOccurrences(of: "-", with: "/")
    // Handle the leading slash
    if path.hasPrefix("/") {
      return path
    }
    return "/" + path
  }
  
  /// Gets the display name from a path
  static func getDisplayName(from path: String) -> String {
    let components = path.split(separator: "/")
    
    // Special handling for common project patterns
    if components.count >= 2 {
      let lastTwo = components.suffix(2)
      
      // If it's a git project, show "owner/repo" format
      if lastTwo.first == "git" || lastTwo.first == "repos" || lastTwo.first == "projects" {
        return String(lastTwo.last ?? "")
      }
    }
    
    // Default to last component
    return String(components.last ?? "Project")
  }
  
  /// Builds a hierarchical tree from project sessions data
  public static func buildHierarchy(from projectSessions: [(project: String, sessions: [StoredSession])]) -> [ProjectNode] {
    var rootNodes: [ProjectNode] = []
    var nodeMap: [String: ProjectNode] = [:]
    
    // First pass: Create all nodes
    for (encodedPath, sessions) in projectSessions {
      let fullPath = decodePath(encodedPath)
      let name = getDisplayName(from: fullPath)
      
      let node = ProjectNode(
        id: encodedPath,
        name: name,
        fullPath: fullPath,
        sessions: sessions,
        children: [],
        depth: 0
      )
      
      nodeMap[encodedPath] = node
    }
    
    // Second pass: Build hierarchy
    for (encodedPath, _) in projectSessions {
      var isChildOfAnother = false
      
      // Check if this path is a child of any other path
      for (otherPath, _) in projectSessions {
        if encodedPath != otherPath && encodedPath.hasPrefix(otherPath + "-") {
          // This is a child of otherPath
          isChildOfAnother = true
          
          // Find the immediate parent
          var immediateParent = otherPath
          for (candidatePath, _) in projectSessions {
            if candidatePath != encodedPath &&
                encodedPath.hasPrefix(candidatePath + "-") &&
                candidatePath.hasPrefix(otherPath + "-") &&
                candidatePath.count > immediateParent.count {
              immediateParent = candidatePath
            }
          }
          
          // Add as child to immediate parent
          if var parentNode = nodeMap[immediateParent] {
            if var childNode = nodeMap[encodedPath] {
              // Update child's depth
              let parentDepth = countDepth(for: immediateParent)
              childNode = ProjectNode(
                id: childNode.id,
                name: childNode.name,
                fullPath: childNode.fullPath,
                sessions: childNode.sessions,
                children: childNode.children,
                depth: parentDepth + 1
              )
              parentNode.children.append(childNode)
              nodeMap[immediateParent] = parentNode
            }
          }
          
          break
        }
      }
      
      // If not a child of any other, it's a root node
      if !isChildOfAnother {
        if let node = nodeMap[encodedPath] {
          rootNodes.append(node)
        }
      }
    }
    
    // Sort root nodes by most recent activity
    rootNodes.sort { node1, node2 in
      let date1 = node1.mostRecentSessionDate ?? Date.distantPast
      let date2 = node2.mostRecentSessionDate ?? Date.distantPast
      return date1 > date2
    }
    
    // Recursively sort children
    for i in 0..<rootNodes.count {
      rootNodes[i] = sortChildren(rootNodes[i])
    }
    
    return rootNodes
  }
  
  /// Counts the depth level based on path separators
  private static func countDepth(for encodedPath: String) -> Int {
    encodedPath.filter { $0 == "-" }.count
  }
  
  /// Recursively sorts children by most recent activity
  private static func sortChildren(_ node: ProjectNode) -> ProjectNode {
    let sortedChildren = node.children
      .map { sortChildren($0) }
      .sorted { child1, child2 in
        let date1 = child1.mostRecentSessionDate ?? Date.distantPast
        let date2 = child2.mostRecentSessionDate ?? Date.distantPast
        return date1 > date2
      }
    
    return ProjectNode(
      id: node.id,
      name: node.name,
      fullPath: node.fullPath,
      sessions: node.sessions.sorted { $0.lastAccessedAt > $1.lastAccessedAt },
      children: sortedChildren,
      depth: node.depth
    )
  }
}
