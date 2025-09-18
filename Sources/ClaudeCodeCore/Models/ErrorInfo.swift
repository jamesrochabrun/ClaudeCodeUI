//
//  ErrorInfo.swift
//  ClaudeCodeUI
//
//  Created by Claude on 2025.
//

import Foundation
import ClaudeCodeSDK

/// Detailed error information for display to users
public struct ErrorInfo: Identifiable, Equatable {
  public let id = UUID()
  public let error: Error
  public let severity: ErrorSeverity
  public let context: String
  public let recoverySuggestion: String?
  public let timestamp: Date
  public let operation: ErrorOperation
  public let recoveryAction: (() -> Void)?

  public var displayMessage: String {
    // For ClaudeCodeError, use its localizedDescription which has the actual error details
    if let claudeError = error as? ClaudeCodeError {
      return claudeError.localizedDescription
    }
    return error.localizedDescription
  }

  public init(
    error: Error,
    severity: ErrorSeverity = .error,
    context: String,
    recoverySuggestion: String? = nil,
    operation: ErrorOperation = .general,
    recoveryAction: (() -> Void)? = nil
  ) {
    self.error = error
    self.severity = severity
    self.context = context
    self.recoverySuggestion = recoverySuggestion
    self.timestamp = Date()
    self.operation = operation
    self.recoveryAction = recoveryAction
  }

  // Equatable conformance (excluding id, timestamp, and recoveryAction for logical equality)
  public static func == (lhs: ErrorInfo, rhs: ErrorInfo) -> Bool {
    lhs.displayMessage == rhs.displayMessage &&
    lhs.severity == rhs.severity &&
    lhs.context == rhs.context &&
    lhs.operation == rhs.operation
  }
}

/// Error severity levels for visual indication
public enum ErrorSeverity: String, CaseIterable {
  case warning
  case error
  case critical

  public var displayName: String {
    switch self {
    case .warning: return "Warning"
    case .error: return "Error"
    case .critical: return "Critical Error"
    }
  }

  public var iconName: String {
    switch self {
    case .warning: return "exclamationmark.triangle"
    case .error: return "exclamationmark.circle"
    case .critical: return "exclamationmark.octagon"
    }
  }
}

/// Types of operations that can fail
public enum ErrorOperation: String, CaseIterable {
  case general
  case sessionManagement
  case streaming
  case apiCall
  case fileOperation
  case networkRequest
  case configuration

  public var displayName: String {
    switch self {
    case .general: return "Operation"
    case .sessionManagement: return "Session Management"
    case .streaming: return "Message Streaming"
    case .apiCall: return "API Call"
    case .fileOperation: return "File Operation"
    case .networkRequest: return "Network Request"
    case .configuration: return "Configuration"
    }
  }
}

// MARK: - Error Extensions for Common Cases

extension ErrorInfo {
  /// Creates error info for session-related errors
  static func sessionError(_ error: Error, isResume: Bool = false) -> ErrorInfo {
    let context = isResume ? "Failed to resume session" : "Failed to manage session"
    let suggestion: String?

    let errorMessage = error.localizedDescription.lowercased()
    if errorMessage.contains("not found") || errorMessage.contains("no conversation") {
      suggestion = "The session no longer exists. Start a new conversation to continue."
    } else if errorMessage.contains("timeout") {
      suggestion = "The operation timed out. Please try again."
    } else {
      suggestion = "Try starting a new session or check your connection."
    }

    return ErrorInfo(
      error: error,
      severity: .error,
      context: context,
      recoverySuggestion: suggestion,
      operation: .sessionManagement
    )
  }

  /// Creates error info for streaming errors
  static func streamingError(_ error: Error) -> ErrorInfo {
    let context = "Failed to stream response from Claude"
    let suggestion: String?

    let errorMessage = error.localizedDescription.lowercased()
    if errorMessage.contains("cancelled") {
      // Don't show error for user-initiated cancellations
      return ErrorInfo(
        error: error,
        severity: .warning,
        context: "Request cancelled",
        recoverySuggestion: nil,
        operation: .streaming
      )
    } else if errorMessage.contains("network") || errorMessage.contains("connection") {
      suggestion = "Check your internet connection and try again."
    } else if errorMessage.contains("rate limit") {
      suggestion = "Too many requests. Please wait a moment and try again."
    } else {
      suggestion = "Try sending your message again or restart the conversation."
    }

    return ErrorInfo(
      error: error,
      severity: .error,
      context: context,
      recoverySuggestion: suggestion,
      operation: .streaming
    )
  }

  /// Creates error info for file operation errors
  static func fileError(_ error: Error, fileName: String? = nil) -> ErrorInfo {
    let context = fileName != nil ? "Failed to process file: \(fileName!)" : "Failed to process file"
    let suggestion: String?

    let errorMessage = error.localizedDescription.lowercased()
    if errorMessage.contains("permission") {
      suggestion = "Check file permissions and try again."
    } else if errorMessage.contains("not found") {
      suggestion = "The file could not be found. Verify the path and try again."
    } else if errorMessage.contains("too large") {
      suggestion = "The file is too large to process. Try a smaller file."
    } else {
      suggestion = "Verify the file exists and you have permission to access it."
    }

    return ErrorInfo(
      error: error,
      severity: .error,
      context: context,
      recoverySuggestion: suggestion,
      operation: .fileOperation
    )
  }

  /// Creates error info for API errors
  static func apiError(_ error: Error) -> ErrorInfo {
    // Check if it's a ClaudeCodeError for more specific handling
    if let claudeError = error as? ClaudeCodeError {
      return claudeCodeError(claudeError)
    }

    let context = "API request failed"
    let suggestion: String?

    let errorMessage = error.localizedDescription.lowercased()
    if errorMessage.contains("unauthorized") || errorMessage.contains("401") {
      suggestion = "Check your API key in settings."
    } else if errorMessage.contains("rate limit") || errorMessage.contains("429") {
      suggestion = "Rate limit exceeded. Please wait before trying again."
    } else if errorMessage.contains("timeout") {
      suggestion = "Request timed out. Try again with a simpler request."
    } else {
      suggestion = "Check your connection and Claude service status."
    }

    return ErrorInfo(
      error: error,
      severity: .error,
      context: context,
      recoverySuggestion: suggestion,
      operation: .apiCall
    )
  }

  /// Creates error info specifically for ClaudeCodeError types
  static func claudeCodeError(_ error: ClaudeCodeError) -> ErrorInfo {
    let severity: ErrorSeverity
    let operation: ErrorOperation
    let context: String
    let suggestion: String?

    // Use the actual error's localizedDescription for the full details
    // The error already contains the specific message

    switch error {
    case .processLaunchFailed(let message):
      severity = .critical
      operation = .configuration
      context = "Process Launch Failed"

      // Provide suggestions based on the actual error content
      let lowerMessage = message.lowercased()
      if lowerMessage.contains("syntax error") || lowerMessage.contains("parse error") {
        suggestion = "Check your system prompt for invalid syntax or special characters."
      } else if lowerMessage.contains("unexpected") {
        suggestion = "Invalid configuration detected. Review your settings."
      } else if lowerMessage.contains("zsh:") || lowerMessage.contains("bash:") {
        suggestion = "Shell error detected. Check your system prompt formatting."
      } else {
        suggestion = nil // Let the actual error message speak for itself
      }

    case .notInstalled:
      severity = .critical
      operation = .configuration

      // The SDK throws .notInstalled for exit code 127, which could mean:
      // 1. Claude is actually not installed
      // 2. There's a typo in the command name
      // 3. The PATH is incorrect

      // We can't extract the command from the error message because the SDK
      // doesn't include it in .notInstalled errors. Instead, show a more generic message
      context = "Command Not Found"
      suggestion = "The command could not be found. This could mean:\n• Claude is not installed (run: npm install -g @anthropic/claude-code)\n• There's a typo in the command name (check Settings)\n• The command is not in your PATH"

    case .executionFailed:
      severity = .error
      operation = .apiCall
      context = "Execution Failed"
      suggestion = nil // The error message has the details

    case .invalidOutput:
      severity = .error
      operation = .apiCall
      context = "Invalid Output"
      suggestion = nil // The error message has the details

    case .jsonParsingError:
      severity = .error
      operation = .apiCall
      context = "Parsing Error"
      suggestion = "This may be a temporary issue. Please try again."

    case .cancelled:
      severity = .warning
      operation = .apiCall
      context = "Cancelled"
      suggestion = nil

    case .timeout(let duration):
      severity = .warning
      operation = .apiCall
      context = "Timeout"
      suggestion = "Try a simpler request or check your connection."

    case .rateLimitExceeded(let retryAfter):
      severity = .warning
      operation = .apiCall
      context = "Rate Limited"
      if let retryAfter = retryAfter {
        suggestion = "Wait \(Int(retryAfter)) seconds before retrying."
      } else {
        suggestion = "Wait a moment before retrying."
      }

    case .networkError:
      severity = .error
      operation = .networkRequest
      context = "Network Error"
      suggestion = "Check your internet connection."

    case .permissionDenied:
      severity = .error
      operation = .fileOperation
      context = "Permission Denied"
      suggestion = nil // The error message has the details
    }

    return ErrorInfo(
      error: error,
      severity: severity,
      context: context,
      recoverySuggestion: suggestion,
      operation: operation
    )
  }
}