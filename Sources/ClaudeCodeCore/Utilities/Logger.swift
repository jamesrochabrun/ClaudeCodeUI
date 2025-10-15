//
//  Logger.swift
//  ClaudeCodeUI
//
//  Created on 9/14/25.
//

import Foundation

/// A singleton logger for conditional debug logging throughout ClaudeCodeCore
public final class ClaudeCodeLogger {

  // MARK: - Singleton

  public static let shared = ClaudeCodeLogger()

  // MARK: - Properties

  private var isEnabled: Bool = false

  // MARK: - Log Categories

  public enum Category: String {
    case sqlMessages = "SQLMESSAGES"
    case session = "SESSION"
    case stream = "STREAM"
    case chat = "CHAT"
    case messages = "MESSAGES"
    case container = "CONTAINER"
    case preferences = "PREFERENCES"
    case accessibility = "ACCESSIBILITY"
    case permission = "PERMISSION"
  }

  // MARK: - Initialization

  private init() {}

  /// Configure the logger with the debug flag from ClaudeCodeConfiguration
  public func configure(enableDebugLogging: Bool) {
    self.isEnabled = enableDebugLogging
  }

  // MARK: - Logging Methods

  /// Log a message with a specific category
  public func log(_ category: Category, _ message: String) {
    guard isEnabled else { return }
    print("[\(category.rawValue)] \(message)")
  }

  /// Log a SQL-related message
  public func sqlMessages(_ message: String) {
    log(.sqlMessages, message)
  }

  /// Log a session-related message
  public func session(_ message: String) {
    log(.session, message)
  }

  /// Log a stream-related message
  public func stream(_ message: String) {
    log(.stream, message)
  }

  /// Log a chat-related message
  public func chat(_ message: String) {
    log(.chat, message)
  }

  /// Log a messages-related message
  public func messages(_ message: String) {
    log(.messages, message)
  }

  /// Log a container-related message
  public func container(_ message: String) {
    log(.container, message)
  }

  /// Log a preferences-related message
  public func preferences(_ message: String) {
    log(.preferences, message)
  }

  /// Log an accessibility-related message
  public func accessibility(_ message: String) {
    log(.accessibility, message)
  }

  /// Log a permission-related message
  public func permission(_ message: String) {
    log(.permission, message)
  }
}