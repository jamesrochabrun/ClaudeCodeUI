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
    customSessionStorage: SessionStorageProtocol? = nil)
  {
    self.settingsStorage = SettingsStorageManager()
    
    if let customStorage = customSessionStorage {
      // Use custom storage if provided
      self.sessionStorage = customStorage
      print("[DependencyContainer] Using custom session storage")
    } else {
      self.sessionStorage = NoOpSessionStorage()
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
  
  /// Creates a ChatViewModel optimized for direct ChatScreen usage without session management.
  /// This factory method is ideal when using ChatScreen as the root of your app,
  /// avoiding unnecessary session loading operations.
  /// - Parameters:
  ///   - claudeClient: The Claude client for API communication
  ///   - workingDirectory: Optional working directory to set
  /// - Returns: A configured ChatViewModel with session management disabled
  public func createChatViewModelWithoutSessions(
    claudeClient: ClaudeCode,
    workingDirectory: String? = nil
  ) -> ChatViewModel {
    // Set working directory if provided
    if let dir = workingDirectory {
      settingsStorage.setProjectPath(dir)
    }

    return ChatViewModel(
      claudeClient: claudeClient,
      sessionStorage: sessionStorage,
      settingsStorage: settingsStorage,
      globalPreferences: globalPreferences,
      customPermissionService: customPermissionService,
      shouldManageSessions: false, // Disable session management for direct usage
      onSessionChange: nil
    )
  }
  
  /// Creates a lightweight DependencyContainer optimized for direct ChatScreen usage.
  /// This factory method avoids all session storage initialization overhead.
  /// - Parameter globalPreferences: The global preferences storage instance
  /// - Returns: A DependencyContainer configured with NoOpSessionStorage
  public static func forDirectChatScreen(globalPreferences: GlobalPreferencesStorage) -> DependencyContainer {
    return DependencyContainer(
      globalPreferences: globalPreferences,
      customSessionStorage: nil)
  }
}
