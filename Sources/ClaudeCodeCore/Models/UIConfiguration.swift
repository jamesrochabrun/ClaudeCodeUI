//
//  UIConfiguration.swift
//  ClaudeCodeUI
//
//  Created on 12/22/24.
//

import Foundation

// MARK: - UIConfiguration

/// Configuration for UI customization in ClaudeCodeCore
public struct UIConfiguration {
  /// The name of the application to display in the UI
  public let appName: String

  /// Whether to show the settings button in the navigation bar
  public let showSettingsInNavBar: Bool

  /// Whether to show risk-related data (risk labels and low-risk auto-approve option)
  public let showRiskData: Bool

  /// Whether to show the token count in the loading indicator
  public let showTokenCount: Bool

  /// Optional tooltip text to display when no working directory is selected
  public let workingDirectoryToolTip: String?

  /// Optional general instructions tip to display in the welcome row
  public let generalInstructionsTip: String?

  /// Optional app icon asset name to display in the welcome row
  public let appIconAssetName: String?

  /// Whether to show the system prompt fields in settings
  public let showSystemPromptFields: Bool

  /// Whether to show the additional system prompt field in settings
  public let showAdditionalSystemPromptField: Bool

  /// Initial additional system prompt prefix that will be prepended to user's additional system prompt
  /// This is not shown in the preferences UI and is set programmatically
  public let initialAdditionalSystemPromptPrefix: String?

  /// Default configuration for ClaudeCodeUI app
  public static var `default`: UIConfiguration {
    UIConfiguration(
      appName: "Claude Code UI",
      showSettingsInNavBar: true,
      showRiskData: true,
      showTokenCount: true,
      workingDirectoryToolTip: nil,
      generalInstructionsTip: nil,
      appIconAssetName: nil,
      showSystemPromptFields: false,
      showAdditionalSystemPromptField: true,
      initialAdditionalSystemPromptPrefix: nil
    )
  }

  /// Library consumer configuration (without settings in nav bar)
  public static var library: UIConfiguration {
    UIConfiguration(
      appName: "Claude Code",
      showSettingsInNavBar: false,
      showRiskData: true,
      showTokenCount: true,
      workingDirectoryToolTip: nil,
      generalInstructionsTip: nil,
      appIconAssetName: nil,
      showSystemPromptFields: false,
      showAdditionalSystemPromptField: true,
      initialAdditionalSystemPromptPrefix: nil
    )
  }

  /// Initialize a custom UI configuration
  public init(
    appName: String,
    showSettingsInNavBar: Bool = false,
    showRiskData: Bool = true,
    showTokenCount: Bool = true,
    workingDirectoryToolTip: String? = nil,
    generalInstructionsTip: String? = nil,
    appIconAssetName: String? = nil,
    showSystemPromptFields: Bool = false,
    showAdditionalSystemPromptField: Bool = true,
    initialAdditionalSystemPromptPrefix: String? = nil
  ) {
    self.appName = appName
    self.showSettingsInNavBar = showSettingsInNavBar
    self.showRiskData = showRiskData
    self.showTokenCount = showTokenCount
    self.workingDirectoryToolTip = workingDirectoryToolTip
    self.generalInstructionsTip = generalInstructionsTip
    self.appIconAssetName = appIconAssetName
    self.showSystemPromptFields = showSystemPromptFields
    self.showAdditionalSystemPromptField = showAdditionalSystemPromptField
    self.initialAdditionalSystemPromptPrefix = initialAdditionalSystemPromptPrefix
  }
}
