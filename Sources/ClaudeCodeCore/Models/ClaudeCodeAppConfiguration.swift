//
//  ClaudeCodeAppConfiguration.swift
//  ClaudeCodeUI
//
//  Created on 12/22/24.
//

import Foundation
import ClaudeCodeSDK

/// Complete configuration for ClaudeCodeCore including both SDK and UI settings
public struct ClaudeCodeAppConfiguration {
  /// Configuration for the ClaudeCode SDK (command, paths, etc.)
  public let claudeCodeConfiguration: ClaudeCodeConfiguration
  
  /// Configuration for UI customization
  public let uiConfiguration: UIConfiguration
  
  /// Default configuration for the main ClaudeCodeUI app
  public static var `default`: ClaudeCodeAppConfiguration {
    ClaudeCodeAppConfiguration(
      claudeCodeConfiguration: .default,
      uiConfiguration: .default
    )
  }
  
  /// Configuration for library consumers (minimal UI)
  public static var library: ClaudeCodeAppConfiguration {
    ClaudeCodeAppConfiguration(
      claudeCodeConfiguration: .default,
      uiConfiguration: .library
    )
  }
  
  /// Initialize with both configurations
  public init(
    claudeCodeConfiguration: ClaudeCodeConfiguration = .default,
    uiConfiguration: UIConfiguration = .library
  ) {
    self.claudeCodeConfiguration = claudeCodeConfiguration
    self.uiConfiguration = uiConfiguration
  }
  
  /// Convenience initializer with just app name
  public init(appName: String) {
    self.init(
      claudeCodeConfiguration: .default,
      uiConfiguration: UIConfiguration(appName: appName)
    )
  }
  
  /// Convenience initializer with app name and settings visibility
  public init(
    appName: String,
    showSettingsInNavBar: Bool
  ) {
    self.init(
      claudeCodeConfiguration: .default,
      uiConfiguration: UIConfiguration(
        appName: appName,
        showSettingsInNavBar: showSettingsInNavBar
      )
    )
  }
  
  /// Convenience initializer with app name and working directory
  public init(
    appName: String,
    workingDirectory: String? = nil
  ) {
    var config = ClaudeCodeConfiguration.default
    config.workingDirectory = workingDirectory
    self.init(
      claudeCodeConfiguration: config,
      uiConfiguration: UIConfiguration(appName: appName)
    )
  }
  
  /// Convenience initializer with app name, working directory, and settings visibility
  public init(
    appName: String,
    workingDirectory: String? = nil,
    showSettingsInNavBar: Bool
  ) {
    var config = ClaudeCodeConfiguration.default
    config.workingDirectory = workingDirectory
    self.init(
      claudeCodeConfiguration: config,
      uiConfiguration: UIConfiguration(
        appName: appName,
        showSettingsInNavBar: showSettingsInNavBar
      )
    )
  }
}