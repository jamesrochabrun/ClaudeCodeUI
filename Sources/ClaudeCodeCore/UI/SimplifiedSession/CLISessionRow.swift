//
//  CLISessionRow.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 1/9/26.
//

import Foundation
import SwiftUI

// MARK: - CLISessionRow

/// Individual row for displaying a CLI session with connect action
struct CLISessionRow: View {
  let session: CLISession
  let onConnect: () -> Void
  let onCopyId: () -> Void

  @State private var isHovering = false

  var body: some View {
    HStack(spacing: 12) {
      // Activity indicator
      Circle()
        .fill(session.isActive ? Color.green : Color.gray.opacity(0.5))
        .frame(width: 6, height: 6)

      VStack(alignment: .leading, spacing: 4) {
        // Session ID (prominently displayed)
        sessionIdRow

        // First message preview (if available)
        if let firstMessage = session.firstMessage, !firstMessage.isEmpty {
          Text(firstMessage.prefix(80) + (firstMessage.count > 80 ? "..." : ""))
            .font(.caption)
            .foregroundColor(.primary.opacity(0.8))
            .lineLimit(1)
        }

        // Metadata row
        metadataRow
      }

      Spacer()

      // Connect button
      connectButton
    }
    .padding(.vertical, 6)
    .padding(.horizontal, 8)
    .background(isHovering ? Color.gray.opacity(0.1) : Color.clear)
    .cornerRadius(6)
    .onHover { hovering in
      isHovering = hovering
    }
  }

  // MARK: - Session ID Row

  private var sessionIdRow: some View {
    HStack(spacing: 6) {
      // Short session ID with monospace font
      Text(session.shortId)
        .font(.system(.caption, design: .monospaced))
        .foregroundColor(.brandPrimary)
        .fontWeight(.medium)

      // Copy button
      Button(action: onCopyId) {
        Image(systemName: "doc.on.doc")
          .font(.caption2)
          .foregroundColor(.secondary)
      }
      .buttonStyle(.plain)
      .help("Copy full session ID")

      Spacer()
    }
  }

  // MARK: - Metadata Row

  private var metadataRow: some View {
    HStack(spacing: 6) {
      // Branch info
      if let branch = session.branchName {
        HStack(spacing: 2) {
          Image(systemName: session.isWorktree ? "arrow.triangle.branch" : "arrow.branch")
            .font(.caption2)
          Text(branch)
            .font(.caption)
        }
        .foregroundColor(session.isWorktree ? .brandSecondary : .secondary)

        Text("•")
          .font(.caption)
          .foregroundColor(.secondary)
      }

      // Message count
      Text("\(session.messageCount) msgs")
        .font(.caption)
        .foregroundColor(.secondary)

      Text("•")
        .font(.caption)
        .foregroundColor(.secondary)

      // Last activity
      Text(session.lastActivityAt.timeAgoDisplay())
        .font(.caption)
        .foregroundColor(.secondary)
    }
  }

  // MARK: - Connect Button

  private var connectButton: some View {
    Button(action: onConnect) {
      Image(systemName: "terminal")
        .font(.caption)
        .foregroundColor(.brandPrimary)
    }
    .buttonStyle(.plain)
    .help("Open in Terminal")
  }
}

// MARK: - Date Extension for Time Ago Display

extension Date {
  func timeAgoDisplay() -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: self, relativeTo: Date())
  }
}

// MARK: - Preview

#Preview {
  VStack(spacing: 16) {
    // Active session with first message
    CLISessionRow(
      session: CLISession(
        id: "e1b8aae2-2a33-4402-a8f5-886c4d4da370",
        projectPath: "/Users/james/git/ClaudeCodeUI",
        branchName: "main",
        isWorktree: false,
        lastActivityAt: Date(),
        messageCount: 42,
        isActive: true,
        firstMessage: "I want to add a feature that monitors CLI sessions"
      ),
      onConnect: { print("Connect") },
      onCopyId: { print("Copy ID") }
    )

    // Inactive worktree session with long message
    CLISessionRow(
      session: CLISession(
        id: "f2c9bbf3-3b44-5513-b9f6-997d5e5eb481",
        projectPath: "/Users/james/git/ClaudeCodeUI-feature",
        branchName: "feature/sessions",
        isWorktree: true,
        lastActivityAt: Date().addingTimeInterval(-3600),
        messageCount: 15,
        isActive: false,
        firstMessage: "Help me implement a new SwiftUI view that displays session data in a hierarchical tree structure with expand/collapse functionality"
      ),
      onConnect: { print("Connect") },
      onCopyId: { print("Copy ID") }
    )

    // Session without first message
    CLISessionRow(
      session: CLISession(
        id: "a3d0ccg4-4c55-6624-c0g7-aa8e6f6fc592",
        projectPath: "/Users/james/Desktop",
        branchName: nil,
        isWorktree: false,
        lastActivityAt: Date().addingTimeInterval(-86400),
        messageCount: 5,
        isActive: false,
        firstMessage: nil
      ),
      onConnect: { print("Connect") },
      onCopyId: { print("Copy ID") }
    )
  }
  .padding()
  .frame(width: 350)
}
