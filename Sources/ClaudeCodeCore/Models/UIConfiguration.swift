//
//  UIConfiguration.swift
//  ClaudeCodeUI
//
//  Created on 12/22/24.
//

import Foundation

/// Configuration for UI customization in ClaudeCodeCore
public struct UIConfiguration {
  /// The name of the application to display in the UI
  public let appName: String
  
  /// Whether to show the settings button in the navigation bar
  public let showSettingsInNavBar: Bool
  
  /// Whether to show the risk label in approval toasts
  public let showRiskLabel: Bool
  
  /// Default configuration for ClaudeCodeUI app
  public static var `default`: UIConfiguration {
    UIConfiguration(
      appName: "Claude Code UI",
      showSettingsInNavBar: true,
      showRiskLabel: true
    )
  }
  
  /// Library consumer configuration (without settings in nav bar)
  public static var library: UIConfiguration {
    UIConfiguration(
      appName: "Claude Code",
      showSettingsInNavBar: false,
      showRiskLabel: true
    )
  }
  
  /// Initialize a custom UI configuration
  public init(
    appName: String,
    showSettingsInNavBar: Bool = false,
    showRiskLabel: Bool = true
  ) {
    self.appName = appName
    self.showSettingsInNavBar = showSettingsInNavBar
    self.showRiskLabel = showRiskLabel
  }
}