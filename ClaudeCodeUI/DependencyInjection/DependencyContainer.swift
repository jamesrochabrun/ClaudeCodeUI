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

@MainActor
final class DependencyContainer {
  
  let settingsStorage: SettingsStorage
  let sessionStorage: SessionStorageProtocol
  let globalPreferences: GlobalPreferencesStorage
  let terminalService: TerminalService
  let diffService: DiffService
  let permissionsService: PermissionsService
  let accessibilityService: AccessibilityService
  let xcodeObserver: XcodeObserver
  let xcodeObservationViewModel: XcodeObservationViewModel
  let contextManager: ContextManager
  
  init(globalPreferences: GlobalPreferencesStorage) {
    self.settingsStorage = SettingsStorageManager()
    self.sessionStorage = UserDefaultsSessionStorage()
    self.globalPreferences = globalPreferences
    
    // Initialize core services
    self.terminalService = DefaultTerminalService()
    self.diffService = DiffService(terminalService: terminalService)
    
    // Initialize permissions service
    self.permissionsService = DefaultPermissionsService(
      terminalService: terminalService,
      userDefaults: .standard,
      bundle: .main,
      isAccessibilityPermissionGrantedClosure: { AXIsProcessTrusted() }
    )
    
    // Initialize accessibility service
    self.accessibilityService = DefaultAccessibilityService()
    
    // Initialize XcodeObserver with dependencies
    self.xcodeObserver = DefaultXcodeObserver(
      accessibilityService: accessibilityService,
      permissionsService: permissionsService,
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
