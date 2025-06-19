//
//  SessionSettingsStorage.swift
//  ClaudeCodeUI
//
//  Created on 12/14/2025.
//

import Foundation

@MainActor
public protocol SessionSettingsStorage: AnyObject {
  var projectPath: String { get set }
  var verboseMode: Bool { get set }
  var maxTurns: Int { get set }
  var allowedTools: [String] { get set }
  var systemPrompt: String { get set }
  var appendSystemPrompt: String { get set }
  
  func setProjectPath(_ path: String, for sessionId: String)
  func getProjectPath(for sessionId: String) -> String?
  func clearProjectPath(for sessionId: String)
  
  func setVerboseMode(_ enabled: Bool, for sessionId: String)
  func getVerboseMode(for sessionId: String) -> Bool
  
  func setMaxTurns(_ turns: Int, for sessionId: String)
  func getMaxTurns(for sessionId: String) -> Int
  
  func setAllowedTools(_ tools: [String], for sessionId: String)
  func getAllowedTools(for sessionId: String) -> [String]
  
  func setSystemPrompt(_ prompt: String, for sessionId: String)
  func getSystemPrompt(for sessionId: String) -> String?
  
  func setAppendSystemPrompt(_ prompt: String, for sessionId: String)
  func getAppendSystemPrompt(for sessionId: String) -> String?
  
  func resetSettings(for sessionId: String)
  func deleteSettings(for sessionId: String)
}