//
//  AppLogger.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 9/2/25.
//

import Foundation
import os

public struct AppLogger {
  static func error(_ message: String) {
    Logger(subsystem: "ClaudeCodeUI", category: "").error("\(message)")
  }
  
  static func info(_ message: String) {
    Logger(subsystem: "ClaudeCodeUI", category: "").info("\(message)")
  }
}
