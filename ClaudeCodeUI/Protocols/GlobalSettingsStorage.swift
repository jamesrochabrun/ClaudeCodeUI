//
//  GlobalSettingsStorage.swift
//  ClaudeCodeUI
//
//  Created on 12/14/2025.
//

import Foundation

public protocol GlobalSettingsStorage: AnyObject {
  var colorScheme: String { get set }
  var fontSize: Double { get set }
  
  func setColorScheme(_ scheme: String)
  func getColorScheme() -> String
  
  func setFontSize(_ size: Double)
  func getFontSize() -> Double
}