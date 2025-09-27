//
//  SessionRow.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 9/13/25.
//

import Foundation
import SwiftUI

// MARK: - SessionRow

struct SessionRow: View {
  let session: StoredSession
  let isCurrentSession: Bool
  let onTap: () -> Void
  let onDelete: () -> Void
  
  var body: some View {
    HStack {
      Button(action: onTap) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              Text(session.firstUserMessage.truncateIntelligently(to: 100))
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(1)
              
              if isCurrentSession {
                Image(systemName: "circle.fill")
                  .font(.caption2)
                  .foregroundColor(.brandTertiary)
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            SessionMetadata(
              messageCount: session.messages.count,
              lastAccessedAt: session.lastAccessedAt,
              workingDirectory: session.workingDirectory,
              branchName: session.branchName,
              isWorktree: session.isWorktree
            )
          }
          Spacer()
        }
        .padding(10)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .frame(maxWidth: .infinity, alignment: .leading)
      
      Button(action: onDelete) {
        Image(systemName: "trash")
          .font(.caption)
      }
      .buttonStyle(.plain)
      .padding(.leading, 8)
    }
    .padding(.horizontal, 8)
    .overlay(
      RoundedRectangle(cornerRadius: 6)
        .stroke(isCurrentSession ? Color.brandPrimary : Color.clear, lineWidth: isCurrentSession ? 1 : 0)
    )
  }
  
  @Environment(\.colorScheme) private var colorScheme
}

#Preview {
  VStack(spacing: 16) {
    // Current session with worktree
    SessionRow(
      session: StoredSession(
        id: UUID().uuidString,
        createdAt: Date(),
        firstUserMessage: "Help me implement a new feature for handling git worktrees",
        lastAccessedAt: Date(),
        messages: [
          ChatMessage(role: .user, content: "Help me implement a new feature for handling git worktrees"),
          ChatMessage(role: .assistant, content: "I'll help you implement worktree support."),
          ChatMessage(role: .user, content: "Can you show me how to detect worktrees?")
        ],
        workingDirectory: "/Users/jamesrochabrun/Desktop/git/ClaudeCodeUI-feature",
        branchName: "feature/worktree-support",
        isWorktree: true
      ),
      isCurrentSession: true,
      onTap: { print("Tapped current worktree session") },
      onDelete: { print("Delete current worktree session") }
    )

    // Regular session on main branch
    SessionRow(
      session: StoredSession(
        id: UUID().uuidString,
        createdAt: Date().addingTimeInterval(-3600),
        firstUserMessage: "Fix the navigation bug in the sidebar",
        lastAccessedAt: Date().addingTimeInterval(-3600),
        messages: [
          ChatMessage(role: .user, content: "Fix the navigation bug in the sidebar"),
          ChatMessage(role: .assistant, content: "I'll help you fix the navigation bug.")
        ],
        workingDirectory: "/Users/jamesrochabrun/Desktop/git/ClaudeCodeUI",
        branchName: "main",
        isWorktree: false
      ),
      isCurrentSession: false,
      onTap: { print("Tapped main branch session") },
      onDelete: { print("Delete main branch session") }
    )

    // Session with long message on worktree
    SessionRow(
      session: StoredSession(
        id: UUID().uuidString,
        createdAt: Date().addingTimeInterval(-7200),
        firstUserMessage: "I need to refactor the entire authentication system to support OAuth2, SAML, and social logins while maintaining backward compatibility",
        lastAccessedAt: Date().addingTimeInterval(-7200),
        messages: [
          ChatMessage(role: .user, content: "I need to refactor the entire authentication system to support OAuth2, SAML, and social logins while maintaining backward compatibility"),
          ChatMessage(role: .assistant, content: "Let's refactor the authentication system."),
          ChatMessage(role: .user, content: "Start with OAuth2 implementation"),
          ChatMessage(role: .assistant, content: "I'll implement OAuth2 first."),
          ChatMessage(role: .user, content: "Add SAML support")
        ],
        workingDirectory: "/Users/jamesrochabrun/Desktop/git/auth-refactor",
        branchName: "refactor/authentication",
        isWorktree: true
      ),
      isCurrentSession: false,
      onTap: { print("Tapped auth refactor session") },
      onDelete: { print("Delete auth refactor session") }
    )

    // Session without working directory
    SessionRow(
      session: StoredSession(
        id: UUID().uuidString,
        createdAt: Date().addingTimeInterval(-86400),
        firstUserMessage: "Explain how SwiftUI state management works",
        lastAccessedAt: Date().addingTimeInterval(-86400),
        messages: [
          ChatMessage(role: .user, content: "Explain how SwiftUI state management works")
        ],
        workingDirectory: nil,
        branchName: nil,
        isWorktree: false
      ),
      isCurrentSession: false,
      onTap: { print("Tapped session without directory") },
      onDelete: { print("Delete session without directory") }
    )

    // Older session with many messages on bugfix worktree
    SessionRow(
      session: StoredSession(
        id: UUID().uuidString,
        createdAt: Date().addingTimeInterval(-604800), // 1 week ago
        firstUserMessage: "Debug message",
        lastAccessedAt: Date().addingTimeInterval(-604800),
        messages: Array(repeating: ChatMessage(
          role: .user,
          content: "Debug message"
        ), count: 47),
        workingDirectory: "/Users/jamesrochabrun/Desktop/git/ClaudeCodeUI-bugfix",
        branchName: "bugfix/memory-leak",
        isWorktree: true
      ),
      isCurrentSession: false,
      onTap: { print("Tapped old bugfix session") },
      onDelete: { print("Delete old bugfix session") }
    )

    Spacer()
  }
  .padding()
  .frame(width: 600)
}
