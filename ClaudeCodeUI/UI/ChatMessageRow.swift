//
//  ChatMessageRow.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 5/25/25.
//

import Foundation
import SwiftUI

struct ChatMessageRow: View {
  let message: ChatMessage
  @Environment(\ .colorScheme) private var colorScheme

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      if message.role != .user {
        avatarView
      }

      VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 2) {
        if message.role != .user {
          HStack(spacing: 4) {
            Text(roleLabel)
              .font(.caption)
              .fontWeight(.medium)
              .foregroundColor(roleLabelColor)

            Text(timeFormatter.string(from: message.timestamp))
              .font(.caption2)
              .foregroundColor(.secondary)
          }
        }

        messageContentView
          .contextMenu {
            Button(action: {
              NSPasteboard.general.clearContents()
              NSPasteboard.general.setString(message.content, forType: .string)
            }) {
              Label("Copy", systemImage: "doc.on.doc")
            }
          }
      }

      if message.role == .user {
        avatarView
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .animation(.easeInOut(duration: 0.2), value: message.isComplete)
  }

  @ViewBuilder
  private var messageContentView: some View {
    Group {
      if message.content.isEmpty && !message.isComplete {
        loadingView
      } else {
        Text(message.content)
          .textSelection(.enabled)
          .fixedSize(horizontal: false, vertical: true)
          .foregroundColor(contentTextColor)
      }
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 12)
    .background(backgroundShape)
    .frame(maxWidth: 550, alignment: message.role == .user ? .trailing : .leading)
  }

  @ViewBuilder
  private var loadingView: some View {
    HStack(spacing: 4) {
      ForEach(0..<3) { index in
        Circle()
          .fill(messageTint.opacity(0.6))
          .frame(width: 6, height: 6)
          .scaleEffect(animationValues[index] ? 1.0 : 0.5)
          .animation(
            Animation.easeInOut(duration: 0.5)
              .repeatForever(autoreverses: true)
              .delay(Double(index) * 0.2),
            value: animationValues[index]
          )
          .onAppear {
            animationValues[index].toggle()
          }
      }
    }
    .frame(height: 18)
    .frame(width: 36)
  }

  @ViewBuilder
  private var avatarView: some View {
    Group {
      if message.role == .user {
        EmptyView()
      } else {
        Image(systemName: avatarIcon)
          .foregroundStyle(messageTint.opacity(0.8))
      }
    }
    .font(.system(size: 24))
    .frame(width: 28, height: 28)
  }

  private var backgroundShape: some View {
    RoundedRectangle(cornerRadius: 12, style: .continuous)
      .fill(backgroundColor)
      .shadow(color: shadowColor, radius: 2, x: 0, y: 1)
  }

  private var avatarIcon: String {
    switch message.messageType {
    case .text: return "circle"
    case .toolUse: return "hammer.circle.fill"
    case .toolResult: return "checkmark.circle.fill"
    case .toolError: return "exclamationmark.circle.fill"
    case .thinking: return "brain.fill"
    case .webSearch: return "globe.circle.fill"
    }
  }

  private var roleLabel: String {
    switch message.messageType {
    case .text: return message.role == .assistant ? "Claude Code" : "You"
    case .toolUse: return message.toolName ?? "Tool"
    case .toolResult: return "Result"
    case .toolError: return "Error"
    case .thinking: return "Thinking"
    case .webSearch: return "Web Search"
    }
  }

  private var roleLabelColor: Color {
    messageTint.opacity(0.9)
  }

  private var messageTint: Color {
    switch message.messageType {
    case .text: return message.role == .assistant ? .purple : .blue
    case .toolUse: return .orange
    case .toolResult: return .green
    case .toolError: return .red
    case .thinking: return .blue
    case .webSearch: return .teal
    }
  }

  private var backgroundColor: Color {
    colorScheme == .dark
      ? Color.gray.opacity(0.2)
      : Color.gray.opacity(0.1)
  }

  private var contentTextColor: Color {
    colorScheme == .dark ? .white : .primary
  }

  private var shadowColor: Color {
    colorScheme == .dark ? .clear : Color.black.opacity(0.05)
  }

  private var timeFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter
  }

  @State private var animationValues: [Bool] = [false, false, false]
}
