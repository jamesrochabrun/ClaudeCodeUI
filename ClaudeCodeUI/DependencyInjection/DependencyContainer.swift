//
//  DependencyContainer.swift
//  ClaudeCodeUI
//
//  Created on 12/6/2025.
//

import Foundation
import SwiftUI
import XcodeObserverService
import XcodeObserverServiceInterface
import PermissionsService
import PermissionsServiceInterface
import AccessibilityService
import AccessibilityServiceInterface
import TerminalService
import TerminalServiceInterface
import ApplicationServices
import CustomPermissionService
import CustomPermissionServiceInterface

@MainActor
final class DependencyContainer {
  
  let settingsStorage: SettingsStorage
  let sessionStorage: SessionStorageProtocol
  let globalPreferences: GlobalPreferencesStorage
  let terminalService: TerminalService
  let permissionsService: PermissionsService
  /// Service that provides macOS accessibility API functionality.
  /// Used to interact with UI elements, monitor system events, and control accessibility features.
  let accessibilityService: AccessibilityService
  
  /// Observer that monitors Xcode's state and activities.
  /// Tracks active windows, current file context, and editor state changes to provide
  /// real-time information about the user's development environment.
  let xcodeObserver: XcodeObserver
  
  /// View model that manages the presentation logic for Xcode observation data.
  /// Acts as a bridge between the XcodeObserver service and the UI layer,
  /// providing formatted and reactive data for display.
  let xcodeObservationViewModel: XcodeObservationViewModel
  
  /// Manages and coordinates context information from various sources.
  /// Combines data from Xcode observations to provide a unified view of the current
  /// development context, including active files, projects, and code selections.
  let contextManager: ContextManager
  
  // Custom permission service
  let customPermissionService: CustomPermissionService
  
  // Approval bridge for MCP IPC
  let approvalBridge: ApprovalBridge
  
  init(globalPreferences: GlobalPreferencesStorage) {
    self.settingsStorage = SettingsStorageManager()
    self.sessionStorage = UserDefaultsSessionStorage()
    self.globalPreferences = globalPreferences
    
    // Initialize core services
    self.terminalService = DefaultTerminalService()
    
    // Initialize permissions service
    self.permissionsService = DefaultPermissionsService(
      terminalService: terminalService,
      userDefaults: .standard,
      bundle: .main,
      isAccessibilityPermissionGrantedClosure: { AXIsProcessTrusted() }
    )
    
    // Initialize accessibility service
    self.accessibilityService = DefaultAccessibilityService()
    
    // Initialize custom permission service
    self.customPermissionService = DefaultCustomPermissionService()
    
    // Initialize approval bridge for MCP IPC
    self.approvalBridge = ApprovalBridge(permissionService: customPermissionService)
    
    // Initialize XcodeObserver with dependencies
    self.xcodeObserver = DefaultXcodeObserver(
      accessibilityService: accessibilityService,
      permissionsService: permissionsService
    )
    self.xcodeObservationViewModel = XcodeObservationViewModel(xcodeObserver: xcodeObserver)
    self.contextManager = ContextManager(xcodeObservationViewModel: xcodeObservationViewModel)
  }
  
  func setCurrentSession(_ sessionId: String) {
    // Load session-specific working directory if available
    if let sessionPath = settingsStorage.getProjectPath(forSessionId: sessionId) {
      // Existing session - load its working directory
      settingsStorage.setProjectPath(sessionPath)
      print("[DependencyContainer] Loaded existing session path '\(sessionPath)' for session '\(sessionId)'")
    } else {
      // New session - save the current working directory if it exists
      let currentPath = settingsStorage.projectPath
      if !currentPath.isEmpty {
        settingsStorage.setProjectPath(currentPath, forSessionId: sessionId)
        print("[DependencyContainer] Saved current path '\(currentPath)' to new session '\(sessionId)'")
      } else {
        print("[DependencyContainer] New session '\(sessionId)' with no working directory")
      }
    }
  }
}
