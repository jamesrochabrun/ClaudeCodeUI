//
//  XcodeObservationViewModel+ProjectPath.swift
//  ClaudeCodeUI
//
//  Created on 12/23/25.
//

import Foundation

extension XcodeObservationViewModel {
  
  /// Extracts the project root path from the active file or workspace
  func getProjectRootPath() -> String? {
    // First, check if we have a workspace URL (from .xcworkspace)
    if let documentURL = getWorkspaceDocumentURL() {
      // Return the directory containing the workspace
      return documentURL.deletingLastPathComponent().path
    }
    
    // If no workspace, try to find project root from active file
    if let activeFilePath = workspaceModel.activeFile?.path {
      return findProjectRoot(from: activeFilePath)
    }
    
    return nil
  }
  
  /// Finds the project root by looking for .xcodeproj, .xcworkspace, or .git directory
  private func findProjectRoot(from filePath: String) -> String? {
    let fileURL = URL(fileURLWithPath: filePath)
    var currentURL = fileURL.deletingLastPathComponent()
    
    // Walk up the directory tree looking for project indicators
    while currentURL.path != "/" {
      let fileManager = FileManager.default
      
      // Check for Xcode project files
      let xcodeProjectPath = currentURL.appendingPathComponent(currentURL.lastPathComponent + ".xcodeproj").path
      let xcworkspacePath = currentURL.appendingPathComponent(currentURL.lastPathComponent + ".xcworkspace").path
      
      // Check for common project indicators
      let gitPath = currentURL.appendingPathComponent(".git").path
      let packageSwiftPath = currentURL.appendingPathComponent("Package.swift").path
      
      if fileManager.fileExists(atPath: xcodeProjectPath) ||
         fileManager.fileExists(atPath: xcworkspacePath) ||
         fileManager.fileExists(atPath: gitPath) ||
         fileManager.fileExists(atPath: packageSwiftPath) {
        return currentURL.path
      }
      
      // Also check for any .xcodeproj or .xcworkspace in the current directory
      if let contents = try? fileManager.contentsOfDirectory(atPath: currentURL.path) {
        if contents.contains(where: { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") }) {
          return currentURL.path
        }
      }
      
      // Move up one directory
      currentURL = currentURL.deletingLastPathComponent()
    }
    
    return nil
  }
}