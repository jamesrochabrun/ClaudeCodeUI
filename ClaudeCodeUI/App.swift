//
//  App.swift
//  ClaudeCodeUI
//
//  App entry point using ClaudeCodeCore package
//

import SwiftUI
import ClaudeCodeCore
import ClaudeCodeSDK

@main
struct ClaudeCodeUIAppWrapper: App {

  var config: ClaudeCodeConfiguration {
    var config = ClaudeCodeConfiguration.default
    config.enableDebugLogging = true
    let homeDir = NSHomeDirectory()
    config.additionalPaths = [
      "/usr/local/bin",
      "/opt/homebrew/bin",
      "/usr/bin",
      "\(homeDir)/.claude/local",  // Claude standalone installation
      "\(homeDir)/.nvm/versions/node/v22.16.0/bin",  // Common Node versions
      "\(homeDir)/.nvm/current/bin",
      "\(homeDir)/.nvm/versions/node/v20.11.1/bin",
      "\(homeDir)/.nvm/versions/node/v18.19.0/bin"
    ]
    return config
  }
  var body: some Scene {
    WindowGroup {
      ClaudeCodeContainer(
        appsRepoRootPath: nil,
        claudeCodeConfiguration: config,
        uiConfiguration: UIConfiguration(
        appName: "Claude Code UI",
        showSettingsInNavBar: true,
        showRiskData: false,
        workingDirectoryToolTip: "Tip: Select a folder to enable AI assistance"))
    }
  }
}

