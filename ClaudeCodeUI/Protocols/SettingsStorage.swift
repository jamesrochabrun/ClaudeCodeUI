//
//  SettingsStorage.swift
//  ClaudeCodeUI
//
//  Created on 12/6/2025.
//

import Foundation

@MainActor
public protocol SettingsStorage: AnyObject {
  var projectPath: String { get set }
  var colorScheme: String { get set }
  var fontSize: Double { get set }
  var debugMode: Bool { get set }
  var verboseMode: Bool { get set }
  var maxTurns: Int { get set }
  var allowedTools: [String] { get set }
  var systemPrompt: String { get set }
  var appendSystemPrompt: String { get set }
  
  func setProjectPath(_ path: String)
  func getProjectPath() -> String?
  func clearProjectPath()
  
  func setColorScheme(_ scheme: String)
  func getColorScheme() -> String
  
  func setFontSize(_ size: Double)
  func getFontSize() -> Double
  
  func saveSecureValue(_ value: String, forKey key: String)
  func getSecureValue(forKey key: String) -> String?
  func removeSecureValue(forKey key: String)
  
  func setDebugMode(_ enabled: Bool)
  func getDebugMode() -> Bool
  
  func setVerboseMode(_ enabled: Bool)
  func getVerboseMode() -> Bool
  
  func setMaxTurns(_ turns: Int)
  func getMaxTurns() -> Int
  
  func setAllowedTools(_ tools: [String])
  func getAllowedTools() -> [String]
  
  func setSystemPrompt(_ prompt: String)
  func getSystemPrompt() -> String?
  
  func setAppendSystemPrompt(_ prompt: String)
  func getAppendSystemPrompt() -> String?
  
  func resetAllSettings()
}
