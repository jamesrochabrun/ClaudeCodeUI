//
//  AppInstanceIdentifier.swift
//  ClaudeCodeUI
//
//  Provides unique instance identification for multi-instance app support.
//  Each app launch gets a unique identifier to enable instance-specific
//  IPC communication via DistributedNotificationCenter.
//

import Foundation

/// Manages unique instance identification for the app.
/// This enables multiple instances of the app to run simultaneously
/// without interfering with each other's IPC notifications.
public final class AppInstanceIdentifier: Sendable {
  /// The unique identifier for this app instance.
  /// Generated once at initialization and remains constant for the app's lifetime.
  public let instanceId: String

  /// Environment variable name used to pass instance ID to MCP servers
  public static let environmentKey = "CLAUDE_CODE_UI_INSTANCE_ID"

  /// Notification name prefix for approval requests
  public static let approvalRequestPrefix = "ClaudeCodeUIApprovalRequest"

  /// Notification name prefix for approval responses
  public static let approvalResponsePrefix = "ClaudeCodeUIApprovalResponse"

  /// Creates a new instance identifier.
  /// Uses a combination of process ID and timestamp for uniqueness.
  public init() {
    // Use process ID + timestamp for a compact but unique identifier
    // This ensures uniqueness even if an app crashes and restarts quickly
    let pid = ProcessInfo.processInfo.processIdentifier
    let timestamp = Int(Date().timeIntervalSince1970 * 1000) % 1_000_000
    self.instanceId = "\(pid)_\(timestamp)"
  }

  /// Creates an instance identifier from an environment variable.
  /// Used by MCP servers to discover which app instance they belong to.
  /// - Returns: An identifier if the environment variable is set, nil otherwise.
  public static func fromEnvironment() -> AppInstanceIdentifier? {
    guard let envValue = ProcessInfo.processInfo.environment[environmentKey],
          !envValue.isEmpty else {
      return nil
    }
    return AppInstanceIdentifier(existingId: envValue)
  }

  /// Internal initializer for creating from existing ID (used by MCP servers)
  private init(existingId: String) {
    self.instanceId = existingId
  }

  /// Returns the notification name for approval requests specific to this instance
  public var approvalRequestNotificationName: String {
    "\(Self.approvalRequestPrefix)_\(instanceId)"
  }

  /// Returns the notification name for approval responses specific to this instance
  public var approvalResponseNotificationName: String {
    "\(Self.approvalResponsePrefix)_\(instanceId)"
  }

  /// Returns environment dictionary to pass to child processes (MCP servers)
  public var environmentForChildProcess: [String: String] {
    [Self.environmentKey: instanceId]
  }
}
