//
//  DependencyContainer.swift
//  ClaudeCodeUI
//
//  Created on 12/6/2025.
//

import Foundation
import SwiftUI
import CCXcodeObserverService
import CCXcodeObserverServiceInterface
import CCPermissionsService
import CCPermissionsServiceInterface
import CCAccessibilityService
import CCAccessibilityServiceInterface
import CCTerminalService
import CCTerminalServiceInterface
import ApplicationServices
import CCCustomPermissionService
import CCCustomPermissionServiceInterface
import ClaudeCodeSDK

/// Container for managing application-wide dependencies and services.
/// This class provides dependency injection for all major services used throughout the application.
@MainActor
public final class DependencyContainer {
  
  public let settingsStorage: SettingsStorage
  public let sessionStorage: SessionStorageProtocol
  public let globalPreferences: GlobalPreferencesStorage
  public let terminalService: TerminalService
  public let permissionsService: PermissionsService
  /// Service that provides macOS accessibility API functionality.
  /// Used to interact with UI elements, monitor system events, and control accessibility features.
  public let accessibilityService: AccessibilityService
  
  /// Observer that monitors Xcode's state and activities.
  /// Tracks active windows, current file context, and editor state changes to provide
  /// real-time information about the user's development environment.
  public let xcodeObserver: XcodeObserver
  
  /// View model that manages the presentation logic for Xcode observation data.
  /// Acts as a bridge between the XcodeObserver service and the UI layer,
  /// providing formatted and reactive data for display.
  public let xcodeObservationViewModel: XcodeObservationViewModel
  
  /// Manages and coordinates context information from various sources.
  /// Combines data from Xcode observations to provide a unified view of the current
  /// development context, including active files, projects, and code selections.
  public let contextManager: ContextManager
  
  // Custom permission service
  public let customPermissionService: CustomPermissionService
  
  // Approval bridge for MCP IPC
  public let approvalBridge: ApprovalBridge
  
  /// Creates a new dependency container with optional custom session storage.
  /// - Parameters:
  ///   - globalPreferences: The global preferences storage instance
  ///   - customSessionStorage: Optional custom implementation of SessionStorageProtocol.
  ///     If nil, the default storage will be selected based on available Claude CLI storage.
  public init(
    globalPreferences: GlobalPreferencesStorage,
    customSessionStorage: SessionStorageProtocol? = nil
  ) {
    self.settingsStorage = SettingsStorageManager()
    
    // Use custom storage if provided, otherwise use default logic
    if let customStorage = customSessionStorage {
      self.sessionStorage = customStorage
      print("[DependencyContainer] Using custom session storage")
    } else {
      // Use native Claude session storage when available
      // Try to use native storage, fallback to UserDefaults if needed
      if FileManager.default.fileExists(atPath: NSHomeDirectory() + "/.claude/projects") {
        // Native Claude CLI storage is available - don't specify a project path initially
        // This allows us to show ALL projects in the hierarchical view
        self.sessionStorage = ClaudeNativeStorageAdapter(projectPath: nil)
        print("[DependencyContainer] Using native Claude session storage (global mode)")
      } else {
        // Fallback to UserDefaults storage
        self.sessionStorage = UserDefaultsSessionStorage()
        print("[DependencyContainer] Using UserDefaults session storage (Claude CLI storage not found)")
      }
    }
    
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
  
  public func setCurrentSession(_ sessionId: String) {
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
