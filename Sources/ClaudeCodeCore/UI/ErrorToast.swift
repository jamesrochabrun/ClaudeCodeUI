//
//  ErrorToast.swift
//  ClaudeCodeUI
//
//  Created by Claude on 2025.
//

import SwiftUI
import Foundation

/// Toast-style error display that slides up from the bottom
public struct ErrorToast: View {
  let errorInfo: ErrorInfo
  let onDismiss: () -> Void
  let onRetry: (() -> Void)?

  @State private var showDetails = false
  @State private var timeRemaining = 10.0 // seconds until auto-dismiss
  @State private var timer: Timer?
  @State private var isPaused = false

  public init(
    errorInfo: ErrorInfo,
    onDismiss: @escaping () -> Void,
    onRetry: (() -> Void)? = nil
  ) {
    self.errorInfo = errorInfo
    self.onDismiss = onDismiss
    self.onRetry = onRetry
  }

  public var body: some View {
    VStack(spacing: 0) {
      mainCompactView

      if showDetails {
        expandableDetailsView
      }
    }
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(severityColor.opacity(0.3), lineWidth: 1)
    )
    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
    .onTapGesture {
      withAnimation(.easeInOut(duration: 0.2)) {
        showDetails.toggle()
      }
    }
    .onHover { hovering in
      isPaused = hovering
    }
    .onAppear {
      startTimer()
    }
    .onDisappear {
      timer?.invalidate()
    }
  }

  private var mainCompactView: some View {
    HStack(spacing: 12) {
      // Severity indicator icon
      Image(systemName: errorInfo.severity.iconName)
        .foregroundColor(severityColor)
        .font(.system(size: 16))

      // Error information
      VStack(alignment: .leading, spacing: 2) {
        HStack {
          Text(errorInfo.context)
            .font(.system(size: 13, weight: .medium))

          Spacer()

          // Severity badge
          Text(errorInfo.severity.displayName)
            .font(.system(size: 11))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(severityColor.opacity(0.2))
            .foregroundColor(severityColor)
            .cornerRadius(4)
        }

        Text(errorInfo.displayMessage)
          .font(.system(size: 12))
          .foregroundColor(.secondary)
          .lineLimit(showDetails ? nil : 2)
          .truncationMode(.tail)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      // Action buttons
      HStack(spacing: 8) {
        // Expand/collapse indicator
        Button(action: {
          withAnimation(.easeInOut(duration: 0.2)) {
            showDetails.toggle()
          }
        }) {
          Image(systemName: showDetails ? "chevron.down" : "chevron.up")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
        .help(showDetails ? "Hide details" : "Show details (subprocess output, error type, etc.)")

        // Recovery action button (if available)
        if let recoveryAction = errorInfo.recoveryAction {
          Button(action: {
            timer?.invalidate()
            recoveryAction()
            onDismiss()
          }) {
            Label("Fix", systemImage: "wrench.and.screwdriver")
              .font(.system(size: 12))
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.small)
        }

        if onRetry != nil {
          Button(action: {
            timer?.invalidate()
            onRetry?()
            onDismiss()
          }) {
            Label("Retry", systemImage: "arrow.clockwise")
              .font(.system(size: 12))
          }
          .buttonStyle(.bordered)
          .controlSize(.small)
        }

        Button(action: {
          timer?.invalidate()
          onDismiss()
        }) {
          Image(systemName: "xmark")
            .font(.system(size: 12, weight: .medium))
        }
        .buttonStyle(.plain)
        .foregroundColor(.secondary)
        .help("Dismiss (or wait \(Int(timeRemaining))s)")
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }

  private var expandableDetailsView: some View {
    VStack(alignment: .leading, spacing: 8) {
      Divider()

      // Operation type
      Label {
        Text("Operation: \(errorInfo.operation.displayName)")
          .font(.system(size: 12))
          .foregroundColor(.secondary)
      } icon: {
        Image(systemName: "gear")
          .font(.system(size: 11))
          .foregroundColor(.secondary)
      }

      // Recovery suggestion
      if let suggestion = errorInfo.recoverySuggestion {
        Label {
          Text(suggestion)
            .font(.system(size: 12))
            .foregroundColor(.primary)
        } icon: {
          Image(systemName: "lightbulb")
            .font(.system(size: 11))
            .foregroundColor(.yellow)
        }
      }

      // Show command details if available in the error message
      if errorInfo.displayMessage.contains("Command attempted:") {
        Label {
          // Extract and show just the command line
          if let commandRange = errorInfo.displayMessage.range(of: "Command attempted: ") {
            let commandPart = String(errorInfo.displayMessage[commandRange.upperBound...])
            Text(commandPart)
              .font(.system(size: 11, design: .monospaced))
              .foregroundColor(.secondary)
              .lineLimit(2)
          } else {
            Text(errorInfo.displayMessage)
              .font(.system(size: 11, design: .monospaced))
              .foregroundColor(.secondary)
              .lineLimit(3)
          }
        } icon: {
          Image(systemName: "terminal")
            .font(.system(size: 10))
            .foregroundColor(.secondary)
        }
      }

      // Error details (for debugging)
      Label {
        Text("Error: \(errorInfo.error.localizedDescription)")
          .font(.system(size: 11, design: .monospaced))
          .foregroundColor(.secondary)
      } icon: {
        Image(systemName: "exclamationmark.triangle")
          .font(.system(size: 10))
          .foregroundColor(.secondary)
      }

      // Show subprocess stderr if available (from Phase 2 & 3)
      if let stderr = errorInfo.subprocessStderr, !stderr.isEmpty {
        Divider()
          .padding(.vertical, 4)

        VStack(alignment: .leading, spacing: 4) {
          Label {
            Text("Subprocess Output:")
              .font(.system(size: 11, weight: .semibold))
              .foregroundColor(.red)
          } icon: {
            Image(systemName: "terminal.fill")
              .font(.system(size: 10))
              .foregroundColor(.red)
          }

          Text(stderr)
            .font(.system(size: 10, design: .monospaced))
            .foregroundColor(.red.opacity(0.9))
            .textSelection(.enabled)
            .padding(8)
            .background(Color.red.opacity(0.05))
            .cornerRadius(6)
        }
      }

      // Timestamp
      Label {
        Text(errorInfo.timestamp, style: .time)
          .font(.system(size: 11))
          .foregroundColor(.secondary)
      } icon: {
        Image(systemName: "clock")
          .font(.system(size: 10))
          .foregroundColor(.secondary)
      }
    }
    .padding(.horizontal, 16)
    .padding(.bottom, 12)
  }

  private var severityColor: Color {
    switch errorInfo.severity {
    case .warning: return .yellow
    case .error: return .orange
    case .critical: return .red
    }
  }

  private func startTimer() {
    // Auto-dismiss timer based on severity
    let duration: TimeInterval = {
      switch errorInfo.severity {
      case .warning: return 5.0
      case .error: return 10.0
      case .critical: return 15.0
      }
    }()

    timeRemaining = duration

    timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
      if !isPaused {
        timeRemaining -= 0.1
        if timeRemaining <= 0 {
          timer?.invalidate()
          onDismiss()
        }
      }
    }
  }
}

/// Container for error toasts with queue support
public struct ErrorToastContainer: View {
  @Binding var errorQueue: [ErrorInfo]
  let onRetry: (() -> Void)?
  let isDebugEnabled: Bool

  public init(
    errorQueue: Binding<[ErrorInfo]>,
    onRetry: (() -> Void)? = nil,
    isDebugEnabled: Bool = false
  ) {
    _errorQueue = errorQueue
    self.onRetry = onRetry
    self.isDebugEnabled = isDebugEnabled
  }

  public var body: some View {
    return GeometryReader { _ in
      VStack {
        Spacer()

        // Show only the first error in the queue
        if let firstError = errorQueue.first {
          #if DEBUG
          if isDebugEnabled {
            let _ = print("[DEBUG] ErrorToastContainer - Showing error: \(firstError.displayMessage)")
          }
          #endif
          ErrorToast(
            errorInfo: firstError,
            onDismiss: {
              withAnimation(.easeOut(duration: 0.2)) {
                _ = errorQueue.removeFirst()
              }
            },
            onRetry: onRetry
          )
          .padding(.horizontal, 16)
          .padding(.bottom, 20)
          .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
          ))
          .animation(.spring(response: 0.5, dampingFraction: 0.8), value: errorQueue.count)

          // Show count of additional errors if any
          if errorQueue.count > 1 {
            Text("\(errorQueue.count - 1) more error\(errorQueue.count == 2 ? "" : "s") pending")
              .font(.system(size: 11))
              .foregroundColor(.secondary)
              .padding(.horizontal, 12)
              .padding(.vertical, 4)
              .background(.regularMaterial)
              .cornerRadius(6)
              .padding(.bottom, 8)
          }
        }
      }
    }
    .allowsHitTesting(!errorQueue.isEmpty)
  }
}

// MARK: - Preview

#if DEBUG
struct ErrorToast_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      // Warning example
      ZStack {
        Color.gray.opacity(0.1)
          .ignoresSafeArea()

        VStack {
          Spacer()

          ErrorToast(
            errorInfo: ErrorInfo(
              error: NSError(domain: "Test", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Request was cancelled by user"
              ]),
              severity: .warning,
              context: "Streaming operation cancelled",
              recoverySuggestion: nil,
              operation: .streaming
            ),
            onDismiss: { }
          )
          .padding(.horizontal, 16)
          .padding(.bottom, 20)
        }
      }
      .previewDisplayName("Warning Toast")

      // Error example
      ZStack {
        Color.gray.opacity(0.1)
          .ignoresSafeArea()

        VStack {
          Spacer()

          ErrorToast(
            errorInfo: ErrorInfo.sessionError(
              NSError(domain: "Claude", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Session not found"
              ])
            ),
            onDismiss: { },
            onRetry: {
              #if DEBUG
              print("Retry clicked")
              #endif
            }
          )
          .padding(.horizontal, 16)
          .padding(.bottom, 20)
        }
      }
      .previewDisplayName("Error Toast with Retry")

      // Critical error example
      ZStack {
        Color.gray.opacity(0.1)
          .ignoresSafeArea()

        VStack {
          Spacer()

          ErrorToast(
            errorInfo: ErrorInfo(
              error: NSError(domain: "Network", code: 500, userInfo: [
                NSLocalizedDescriptionKey: "Failed to connect to Claude API"
              ]),
              severity: .critical,
              context: "Unable to establish connection to Claude service",
              recoverySuggestion: "Check your internet connection and API key configuration in settings",
              operation: .networkRequest
            ),
            onDismiss: { }
          )
          .padding(.horizontal, 16)
          .padding(.bottom, 20)
        }
      }
      .previewDisplayName("Critical Error Toast")
    }
  }
}
#endif
