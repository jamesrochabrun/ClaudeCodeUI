//
//  SettingsStorage.swift
//  ClaudeCodeUI
//
//  Created on 12/6/2025.
//

import Foundation

@MainActor
protocol SettingsStorage: AnyObject {
  var projectPath: String { get set }
  var colorScheme: String { get set }
  var fontSize: Double { get set }
  
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
  
  func resetAllSettings()
}
