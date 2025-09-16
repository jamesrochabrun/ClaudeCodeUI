//
//  UserMessageLoggingExample.swift
//  ClaudeCodeUI
//
//  Example showing how to use the onUserMessageSent callback
//  to log user messages in your application.
//

import SwiftUI
import ClaudeCodeCore
import ClaudeCodeSDK

struct UserMessageLoggingExampleApp: App {

  var config: ClaudeCodeConfiguration {
    ClaudeCodeConfiguration.default
  }

  var body: some Scene {
    WindowGroup {
      ClaudeCodeContainer(
        claudeCodeConfiguration: config,
        uiConfiguration: UIConfiguration(
          appName: "Claude Code with Logging",
          showSettingsInNavBar: true
        ),
        onUserMessageSent: { message, codeSelections, attachments in
          // Log user message to your analytics system
          logUserMessage(message, codeSelections: codeSelections, attachments: attachments)
        }
      )
    }
  }

  private func logUserMessage(_ message: String, codeSelections: [TextSelection]?, attachments: [FileAttachment]?) {
    // Example: Log to console
    print("📝 User Message Sent:")
    print("   Message: \(message)")

    if let codeSelections = codeSelections, !codeSelections.isEmpty {
      print("   Code Selections: \(codeSelections.count) files")
      for selection in codeSelections {
        print("     - \(selection.filePath)")
      }
    }

    if let attachments = attachments, !attachments.isEmpty {
      print("   Attachments: \(attachments.count) files")
      for attachment in attachments {
        print("     - \(attachment.fileName)")
      }
    }

    // Example: Send to analytics service
    // AnalyticsService.shared.track(.userMessageSent, properties: [
    //   "message_length": message.count,
    //   "has_code_selections": codeSelections != nil,
    //   "has_attachments": attachments != nil,
    //   "attachment_count": attachments?.count ?? 0
    // ])

    // Example: Store in local database for usage metrics
    // UsageMetrics.shared.recordUserMessage(
    //   message: message,
    //   timestamp: Date(),
    //   metadata: [
    //     "code_selections": codeSelections?.count ?? 0,
    //     "attachments": attachments?.count ?? 0
    //   ]
    // )
  }
}

// MARK: - Advanced Example with Custom Logging Service

class MessageLoggingService {
  static let shared = MessageLoggingService()

  private init() {}

  func logUserMessage(_ message: String, codeSelections: [TextSelection]?, attachments: [FileAttachment]?) {
    // Create a structured log entry
    let logEntry = UserMessageLogEntry(
      timestamp: Date(),
      message: message,
      codeSelectionCount: codeSelections?.count ?? 0,
      attachmentCount: attachments?.count ?? 0,
      hasCodeContext: codeSelections != nil && !codeSelections.isEmpty,
      hasAttachments: attachments != nil && !attachments.isEmpty
    )

    // Save to persistent storage, send to server, etc.
    save(logEntry)
  }

  private func save(_ entry: UserMessageLogEntry) {
    // Implementation for saving log entries
    // This could be CoreData, SQLite, or remote API
  }
}

struct UserMessageLogEntry {
  let timestamp: Date
  let message: String
  let codeSelectionCount: Int
  let attachmentCount: Int
  let hasCodeContext: Bool
  let hasAttachments: Bool
}

// MARK: - Usage in Existing App

struct ExistingAppWithLogging: App {
  @StateObject private var analyticsManager = AnalyticsManager()

  var body: some Scene {
    WindowGroup {
      ClaudeCodeContainer(
        claudeCodeConfiguration: .default,
        uiConfiguration: UIConfiguration(appName: "My App"),
        onUserMessageSent: analyticsManager.handleUserMessage
      )
    }
  }
}

class AnalyticsManager: ObservableObject {
  func handleUserMessage(_ message: String, codeSelections: [TextSelection]?, attachments: [FileAttachment]?) {
    // Your custom logging implementation
    Task {
      await logToServer(message: message, metadata: [
        "has_context": codeSelections != nil,
        "attachment_count": attachments?.count ?? 0
      ])
    }
  }

  private func logToServer(message: String, metadata: [String: Any]) async {
    // Async logging to remote server
  }
}